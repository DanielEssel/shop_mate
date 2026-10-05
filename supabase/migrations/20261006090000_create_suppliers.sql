create table public.suppliers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null default public.current_shop_id()
    references public.shops(id) on delete restrict,
  name text not null,
  phone text,
  email text,
  address text,
  notes text,
  is_active boolean not null default true,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint suppliers_name_check
    check (btrim(name) <> '' and char_length(name) <= 120),
  constraint suppliers_phone_check
    check (phone is null or char_length(phone) <= 40),
  constraint suppliers_email_check
    check (email is null or char_length(email) <= 254),
  constraint suppliers_address_check
    check (address is null or char_length(address) <= 250),
  constraint suppliers_notes_check
    check (notes is null or char_length(notes) <= 1000),
  -- Target for tenant-safe composite foreign keys from purchases.
  constraint suppliers_id_shop_id_key
    unique (id, shop_id)
);

-- One active supplier per normalised name per shop; inactive suppliers may
-- share a name with an active one.
create unique index suppliers_shop_active_name_uidx
  on public.suppliers (shop_id, lower(btrim(name)))
  where is_active = true;

create index suppliers_shop_name_idx
  on public.suppliers (shop_id, name);

alter table public.suppliers enable row level security;

create policy suppliers_select_current_shop
  on public.suppliers
  for select
  to authenticated
  using (shop_id = public.current_shop_id());

create policy suppliers_insert_current_shop
  on public.suppliers
  for insert
  to authenticated
  with check (shop_id = public.current_shop_id());

create policy suppliers_update_current_shop
  on public.suppliers
  for update
  to authenticated
  using (shop_id = public.current_shop_id())
  with check (shop_id = public.current_shop_id());

create policy suppliers_delete_owner_current_shop
  on public.suppliers
  for delete
  to authenticated
  using (
    shop_id = public.current_shop_id()
    and public.current_shop_role() = 'owner'
  );

revoke all privileges on table public.suppliers
  from anon, authenticated;
grant select, insert, update, delete on table public.suppliers
  to authenticated;

comment on table public.suppliers is
  'Shop suppliers; purchases may reference one, while purchase supplier_name/supplier_phone remain historical snapshots.';

-- Purchases may optionally reference a supplier from the same shop. Existing
-- purchases keep supplier_id null; no backfill.
alter table public.purchases
  add column supplier_id uuid;

alter table public.purchases
  add constraint purchases_supplier_shop_fkey
    foreign key (supplier_id, shop_id)
    references public.suppliers (id, shop_id) on delete restrict;

create index purchases_shop_supplier_purchase_date_idx
  on public.purchases (shop_id, supplier_id, purchase_date desc);

-- Replace the 7-argument create_purchase with an 8-argument version whose new
-- trailing p_supplier_id defaults to null, so existing app versions that send
-- the original named parameters still resolve to it. Dropping the old
-- signature avoids PostgREST overload ambiguity. Business logic is unchanged
-- apart from the supplier validation and supplier_id on the purchase row.
drop function public.create_purchase(
  text, text, text, numeric, date, text, jsonb
);

create function public.create_purchase(
  p_supplier_name text,
  p_supplier_phone text,
  p_payment_method text,
  p_amount_paid numeric,
  p_purchase_date date,
  p_notes text default null::text,
  p_items jsonb default '[]'::jsonb,
  p_supplier_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_shop_id         uuid := public.current_shop_id();
  v_purchase_id     uuid;
  v_purchase_number text;

  v_item            jsonb;
  v_product_id      uuid;
  v_quantity        integer;

  v_product_name    text;
  v_unit_cost       numeric;

  v_subtotal        numeric;
  v_total_amount    numeric := 0;
  v_balance         numeric := 0;

  v_previous_stock  integer;
  v_new_stock       integer;
begin
  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if p_supplier_id is not null then
    perform 1
    from public.suppliers as supplier
    where supplier.id = p_supplier_id
      and supplier.shop_id = v_shop_id
      and supplier.is_active = true;

    if not found then
      raise exception 'Supplier % not found, inactive, or unavailable for this shop',
        p_supplier_id;
    end if;
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'mobile_money', 'card', 'bank_transfer', 'credit') then
    raise exception 'Invalid payment method: %', p_payment_method;
  end if;

  if p_amount_paid is null then
    raise exception 'Amount paid is required';
  end if;

  if p_amount_paid < 0 then
    raise exception 'Amount paid cannot be negative';
  end if;

  if p_purchase_date is null then
    raise exception 'Purchase date is required';
  end if;

  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'A purchase must contain at least one item';
  end if;

  v_purchase_number :=
    'PU-' ||
    to_char(now(), 'YYYYMMDDHH24MISS') ||
    '-' ||
    upper(substr(gen_random_uuid()::text, 1, 6));

  insert into public.purchases (
    shop_id, purchase_number, supplier_id, supplier_name, supplier_phone,
    total_amount, amount_paid, balance, payment_method,
    status, purchase_date, notes, created_by
  )
  values (
    v_shop_id,
    v_purchase_number,
    p_supplier_id,
    nullif(trim(p_supplier_name), ''),
    nullif(trim(p_supplier_phone), ''),
    0,
    p_amount_paid,
    0,
    p_payment_method,
    'completed',
    p_purchase_date,
    nullif(trim(p_notes), ''),
    auth.uid()
  )
  returning id into v_purchase_id;

  for v_item in
    select * from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity   := (v_item->>'quantity')::integer;
    v_unit_cost  := (v_item->>'unit_cost')::numeric;

    if v_product_id is null then
      raise exception 'Product ID is required for every purchase item';
    end if;

    if v_quantity is null or v_quantity <= 0 then
      raise exception 'Purchase quantity must be greater than zero';
    end if;

    if v_unit_cost is null or v_unit_cost < 0 then
      raise exception 'Purchase unit cost cannot be negative';
    end if;

    select name, stock_quantity
    into v_product_name, v_previous_stock
    from public.products
    where id = v_product_id
      and shop_id = v_shop_id
      and is_active = true
    for update;

    if not found then
      raise exception 'Product % not found or inactive', v_product_id;
    end if;

    v_subtotal     := v_unit_cost * v_quantity;
    v_total_amount := v_total_amount + v_subtotal;
    v_new_stock    := v_previous_stock + v_quantity;

    insert into public.purchase_items (
      shop_id, purchase_id, product_id, product_name,
      quantity, unit_cost, subtotal
    )
    values (
      v_shop_id, v_purchase_id, v_product_id, v_product_name,
      v_quantity, v_unit_cost, v_subtotal
    );

    update public.products
    set stock_quantity = v_new_stock,
        cost_price     = v_unit_cost,
        updated_at     = now()
    where id = v_product_id
      and shop_id = v_shop_id;

    insert into public.stock_movements (
      shop_id, product_id, movement_type, quantity,
      previous_quantity, new_quantity, reference_id, note, created_by
    )
    values (
      v_shop_id, v_product_id, 'purchase', v_quantity,
      v_previous_stock, v_new_stock, v_purchase_id,
      'Stock added from purchase ' || v_purchase_number,
      auth.uid()
    );
  end loop;

  if p_amount_paid > v_total_amount then
    raise exception
      'Amount paid (%) cannot exceed purchase total (%)',
      p_amount_paid,
      v_total_amount;
  end if;

  v_balance := v_total_amount - p_amount_paid;

  update public.purchases
  set total_amount = v_total_amount,
      balance      = v_balance,
      status       = 'completed'
  where id = v_purchase_id
    and shop_id = v_shop_id;

  return v_purchase_id;
end;
$function$;

revoke all privileges on function public.create_purchase(
  text, text, text, numeric, date, text, jsonb, uuid
) from public, anon, authenticated;
grant execute on function public.create_purchase(
  text, text, text, numeric, date, text, jsonb, uuid
) to authenticated, service_role;

comment on function public.create_purchase(
  text, text, text, numeric, date, text, jsonb, uuid
) is
  'Creates a completed purchase with items, stock and cost updates, and stock movements; optional p_supplier_id must be an active supplier of the caller shop, while supplier_name/supplier_phone are stored as given snapshots.';
