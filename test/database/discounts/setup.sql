-- Throwaway stand-in for the live schema the discount migration builds on.
-- Tables, constraints, indexes, triggers, policies and grants follow the
-- live export of 2026-10-15; create_sale, get_dashboard_summary(_internal),
-- current_shop_id/role and update_updated_at are the live bodies verbatim.
-- Objects created by later repo migrations (the customers/sales (id, shop_id)
-- indexes, the payment ledger, credit sales) are left to those migrations,
-- which run.sh applies next. Not reproduced: product categories (the
-- category_id FK and its sync trigger), which the discount work doesn't use.
\set ON_ERROR_STOP on

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
grant usage on schema public to anon, authenticated, service_role;

create schema auth;
grant usage on schema auth to anon, authenticated, service_role;
create table auth.users (
  id uuid primary key,
  email varchar(255)
);
create function auth.uid() returns uuid language sql stable
as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
grant execute on function auth.uid() to anon, authenticated, service_role;

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status text not null default 'pending'
    check (status = any (array['pending', 'active', 'suspended']))
);

create table public.shop_members (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  user_id uuid not null unique references auth.users (id) on delete cascade,
  role text not null default 'staff' check (role = any (array['owner', 'staff'])),
  status text not null default 'active' check (status = any (array['active', 'suspended']))
);

-- ---------------------------------------------------------------- live helpers
CREATE OR REPLACE FUNCTION public.current_shop_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select m.shop_id
  from public.shop_members m
  join public.shops s on s.id = m.shop_id
  where m.user_id = auth.uid()
    and m.status = 'active'
    and s.status = 'active'
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.current_shop_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select m.role
  from public.shop_members m
  join public.shops s on s.id = m.shop_id
  where m.user_id = auth.uid()
    and m.status = 'active'
    and s.status = 'active'
  limit 1;
$function$;

CREATE OR REPLACE FUNCTION public.update_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at = now();
  return new;
end;
$function$;

-- ---------------------------------------------------------------- live tables
create table public.customers (
  id uuid not null default gen_random_uuid(),
  shop_id uuid not null default current_shop_id(),
  name text not null,
  phone text,
  email text,
  address text,
  notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customers_pkey primary key (id),
  constraint customers_shop_id_fkey foreign key (shop_id) references shops(id)
);
create index customers_name_idx on public.customers using btree (name);
create index customers_phone_idx on public.customers using btree (phone);
create index customers_shop_id_idx on public.customers using btree (shop_id);

create table public.products (
  id uuid not null default gen_random_uuid(),
  shop_id uuid not null default current_shop_id(),
  name text not null,
  sku text,
  barcode text,
  description text,
  category text not null,
  category_id uuid,
  cost_price numeric(12,2) not null default 0,
  selling_price numeric(12,2) not null default 0,
  stock_quantity integer not null default 0,
  low_stock_threshold integer not null default 10,
  image_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint products_pkey primary key (id),
  constraint products_shop_id_fkey foreign key (shop_id) references shops(id),
  constraint products_cost_price_check check ((cost_price >= (0)::numeric)),
  constraint products_selling_price_check check ((selling_price >= (0)::numeric)),
  constraint products_stock_quantity_check check ((stock_quantity >= 0)),
  constraint products_low_stock_threshold_check check ((low_stock_threshold >= 0))
);
create index products_active_idx on public.products using btree (is_active);
create unique index products_barcode_unique on public.products using btree (shop_id, barcode) where ((barcode is not null) and (barcode <> ''::text));
create index products_category_idx on public.products using btree (category);
create index products_created_at_idx on public.products using btree (created_at desc);
create index products_shop_id_idx on public.products using btree (shop_id);
create unique index products_sku_unique on public.products using btree (shop_id, sku) where ((sku is not null) and (sku <> ''::text));

create table public.sales (
  id uuid not null default gen_random_uuid(),
  shop_id uuid not null default current_shop_id(),
  sale_number text not null,
  customer_id uuid,
  total_amount numeric(12,2) not null default 0,
  payment_method text not null default 'cash'::text,
  amount_paid numeric(12,2) not null default 0,
  change_amount numeric(12,2) not null default 0,
  created_by uuid,
  created_at timestamptz not null default now(),
  constraint sales_pkey primary key (id),
  constraint sales_shop_id_fkey foreign key (shop_id) references shops(id),
  constraint sales_customer_id_fkey foreign key (customer_id) references customers(id) on delete set null,
  constraint sales_created_by_fkey foreign key (created_by) references auth.users(id),
  constraint sales_sale_number_key unique (shop_id, sale_number),
  constraint sales_payment_method_check check ((payment_method = any (array['cash'::text, 'mobile_money'::text, 'card'::text, 'bank_transfer'::text, 'credit'::text])))
);
create index sales_customer_id_idx on public.sales using btree (customer_id);
create index sales_shop_id_idx on public.sales using btree (shop_id, created_at desc);

create table public.sale_items (
  id uuid not null default gen_random_uuid(),
  shop_id uuid not null default current_shop_id(),
  sale_id uuid not null,
  product_id uuid not null,
  product_name text not null,
  quantity integer not null,
  unit_price numeric(12,2) not null,
  cost_price numeric(12,2) not null,
  subtotal numeric(12,2) not null,
  created_at timestamptz not null default now(),
  constraint sale_items_pkey primary key (id),
  constraint sale_items_shop_id_fkey foreign key (shop_id) references shops(id),
  constraint sale_items_sale_id_fkey foreign key (sale_id) references sales(id) on delete cascade,
  constraint sale_items_product_id_fkey foreign key (product_id) references products(id),
  constraint sale_items_quantity_check check ((quantity > 0)),
  constraint sale_items_unit_price_check check ((unit_price >= (0)::numeric)),
  constraint sale_items_cost_price_check check ((cost_price >= (0)::numeric)),
  constraint sale_items_subtotal_check check ((subtotal >= (0)::numeric))
);
create index sale_items_shop_id_idx on public.sale_items using btree (shop_id);

create table public.stock_movements (
  id uuid not null default gen_random_uuid(),
  shop_id uuid not null default current_shop_id(),
  product_id uuid not null,
  movement_type text not null,
  quantity integer not null,
  previous_quantity integer not null,
  new_quantity integer not null,
  reference_id uuid,
  note text,
  created_by uuid,
  created_at timestamptz not null default now(),
  constraint stock_movements_pkey primary key (id),
  constraint stock_movements_shop_id_fkey foreign key (shop_id) references shops(id),
  constraint stock_movements_product_id_fkey foreign key (product_id) references products(id),
  constraint stock_movements_created_by_fkey foreign key (created_by) references auth.users(id),
  constraint stock_movement_type_check check ((movement_type = any (array['sale'::text, 'purchase'::text, 'adjustment'::text, 'return'::text, 'opening'::text])))
);
create index stock_movements_shop_id_idx on public.stock_movements using btree (shop_id, created_at desc);

-- ---------------------------------------------------------------- live triggers
create trigger products_updated_at before update on public.products
  for each row execute function update_updated_at();

-- From supabase/migrations/20261011090000_rbac1_enforce_shop_roles.sql (deployed).
create function public.enforce_product_role_limits()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
begin
  if current_user <> 'authenticated'
     or public.current_shop_role() = 'owner' then
    return new;
  end if;
  if tg_op = 'INSERT' then
    if new.stock_quantity is distinct from 0 then
      raise exception 'Only the shop owner can set opening stock. Record a purchase to add stock.'
        using errcode = '42501';
    end if;
    if new.is_active is distinct from true then
      raise exception 'Only the shop owner can create an inactive product'
        using errcode = '42501';
    end if;
    return new;
  end if;
  if new.selling_price is distinct from old.selling_price then
    raise exception 'Only the shop owner can change a product''s selling price'
      using errcode = '42501';
  end if;
  if new.cost_price is distinct from old.cost_price then
    raise exception 'Only the shop owner can change a product''s cost price'
      using errcode = '42501';
  end if;
  if new.stock_quantity is distinct from old.stock_quantity then
    raise exception 'Only the shop owner can change stock directly. Use a sale or purchase.'
      using errcode = '42501';
  end if;
  if new.is_active is distinct from old.is_active then
    raise exception 'Only the shop owner can deactivate or restore a product'
      using errcode = '42501';
  end if;
  return new;
end;
$function$;
revoke all on function public.enforce_product_role_limits() from public, anon, authenticated;
create trigger products_enforce_role_limits
  before insert or update on public.products
  for each row execute function public.enforce_product_role_limits();

-- ---------------------------------------------------------------- live RLS
alter table public.customers enable row level security;
alter table public.products enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.stock_movements enable row level security;

create policy "Shop members can create" on public.customers for insert to authenticated
  with check (shop_id = ( select current_shop_id() as current_shop_id));
create policy "Shop members can update" on public.customers for update to authenticated
  using (shop_id = ( select current_shop_id() as current_shop_id))
  with check (shop_id = ( select current_shop_id() as current_shop_id));
create policy "Shop members can view" on public.customers for select to authenticated
  using (shop_id = ( select current_shop_id() as current_shop_id));
create policy "Shop owners can delete" on public.customers for delete to authenticated
  using ((shop_id = ( select current_shop_id() as current_shop_id))
         and (( select current_shop_role() as current_shop_role) = 'owner'::text));

create policy "Shop members can create" on public.products for insert to authenticated
  with check (shop_id = ( select current_shop_id() as current_shop_id));
create policy "Shop members can update" on public.products for update to authenticated
  using (shop_id = ( select current_shop_id() as current_shop_id))
  with check (shop_id = ( select current_shop_id() as current_shop_id));
create policy "Shop members can view" on public.products for select to authenticated
  using (shop_id = ( select current_shop_id() as current_shop_id));
create policy "Shop owners can delete" on public.products for delete to authenticated
  using ((shop_id = ( select current_shop_id() as current_shop_id))
         and (( select current_shop_role() as current_shop_role) = 'owner'::text));

create policy "Shop members can view" on public.sale_items for select to authenticated
  using (shop_id = ( select current_shop_id() as current_shop_id));
create policy "Shop members can view" on public.sales for select to authenticated
  using (shop_id = ( select current_shop_id() as current_shop_id));
create policy "Shop members can view" on public.stock_movements for select to authenticated
  using (shop_id = ( select current_shop_id() as current_shop_id));

-- ---------------------------------------------------------------- live grants
revoke all on public.customers, public.products, public.sales, public.sale_items,
  public.stock_movements from public, anon, authenticated;
grant delete, insert, select, update on public.customers, public.products to authenticated;
grant select on public.sales, public.sale_items, public.stock_movements to authenticated;
grant all on public.customers, public.products, public.sales, public.sale_items,
  public.stock_movements to service_role;
grant select on public.shops, public.shop_members to authenticated;

-- ---------------------------------------------------------------- live functions
CREATE OR REPLACE FUNCTION public.create_sale(p_customer_id uuid, p_payment_method text, p_amount_paid numeric, p_items jsonb)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_shop_id        uuid := public.current_shop_id();
  v_sale_id        uuid;
  v_sale_number    text;

  v_item           jsonb;
  v_product_id     uuid;
  v_quantity       integer;

  v_product_name   text;
  v_unit_price     numeric;
  v_cost_price     numeric;

  v_subtotal       numeric;
  v_total_amount   numeric := 0;

  v_previous_stock integer;
  v_new_stock      integer;

  v_change_amount  numeric := 0;
begin
  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  -- Customer (optional) must belong to the caller's shop
  if p_customer_id is not null then
    if not exists (
      select 1
      from public.customers
      where id = p_customer_id
        and shop_id = v_shop_id
        and is_active = true
    ) then
      raise exception 'Customer % not found or inactive', p_customer_id;
    end if;
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'mobile_money', 'card', 'bank_transfer', 'credit') then
    raise exception 'Invalid payment method: %', p_payment_method;
  end if;

  if p_amount_paid is null or p_amount_paid < 0 then
    raise exception 'Amount paid cannot be negative';
  end if;

  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'A sale must contain at least one item';
  end if;

  v_sale_number :=
    'SL-' ||
    to_char(now(), 'YYYYMMDDHH24MISS') ||
    '-' ||
    upper(substr(gen_random_uuid()::text, 1, 6));

  insert into public.sales (
    shop_id, sale_number, customer_id, total_amount,
    payment_method, amount_paid, change_amount, created_by
  )
  values (
    v_shop_id, v_sale_number, p_customer_id, 0,
    p_payment_method, p_amount_paid, 0, auth.uid()
  )
  returning id into v_sale_id;

  for v_item in
    select * from jsonb_array_elements(p_items)
  loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity   := (v_item->>'quantity')::integer;

    if v_quantity is null or v_quantity <= 0 then
      raise exception 'Quantity must be greater than zero';
    end if;

    -- Lock the product row (scoped to this shop). Price and cost always
    -- come from the database, never from the client.
    select name, selling_price, cost_price, stock_quantity
    into v_product_name, v_unit_price, v_cost_price, v_previous_stock
    from public.products
    where id = v_product_id
      and shop_id = v_shop_id
      and is_active = true
    for update;

    if not found then
      raise exception 'Product % not found or inactive', v_product_id;
    end if;

    if v_previous_stock < v_quantity then
      raise exception
        'Insufficient stock for %. Available: %, requested: %',
        v_product_name,
        v_previous_stock,
        v_quantity;
    end if;

    v_subtotal     := v_unit_price * v_quantity;
    v_total_amount := v_total_amount + v_subtotal;
    v_new_stock    := v_previous_stock - v_quantity;

    insert into public.sale_items (
      shop_id, sale_id, product_id, product_name,
      quantity, unit_price, cost_price, subtotal
    )
    values (
      v_shop_id, v_sale_id, v_product_id, v_product_name,
      v_quantity, v_unit_price, v_cost_price, v_subtotal
    );

    update public.products
    set stock_quantity = v_new_stock
    where id = v_product_id
      and shop_id = v_shop_id;

    insert into public.stock_movements (
      shop_id, product_id, movement_type, quantity,
      previous_quantity, new_quantity, reference_id, note, created_by
    )
    values (
      v_shop_id, v_product_id, 'sale', v_quantity,
      v_previous_stock, v_new_stock, v_sale_id,
      'Stock reduced from sale ' || v_sale_number,
      auth.uid()
    );
  end loop;

  if p_payment_method = 'credit' then
    v_change_amount := 0;
  else
    if p_amount_paid < v_total_amount then
      raise exception
        'Amount paid (%) is less than total amount (%)',
        p_amount_paid,
        v_total_amount;
    end if;

    v_change_amount := p_amount_paid - v_total_amount;
  end if;

  update public.sales
  set total_amount  = v_total_amount,
      change_amount = v_change_amount
  where id = v_sale_id
    and shop_id = v_shop_id;

  return v_sale_id;
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_dashboard_summary_internal()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_shop_id            uuid := public.current_shop_id();
  v_today_start        timestamptz;
  v_today_end          timestamptz;

  v_today_sales        numeric := 0;
  v_today_profit       numeric := 0;
  v_today_transactions integer := 0;

  v_total_products     integer := 0;
  v_low_stock          integer := 0;
  v_out_of_stock       integer := 0;

  v_recent_sales       jsonb := '[]'::jsonb;
begin
  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  v_today_start := date_trunc('day', now());
  v_today_end   := v_today_start + interval '1 day';

  select coalesce(sum(total_amount), 0), count(*)
  into v_today_sales, v_today_transactions
  from public.sales
  where shop_id = v_shop_id
    and created_at >= v_today_start
    and created_at <  v_today_end;

  select coalesce(sum(si.subtotal - (si.cost_price * si.quantity)), 0)
  into v_today_profit
  from public.sale_items si
  join public.sales s
    on s.id = si.sale_id
   and s.shop_id = v_shop_id
  where si.shop_id = v_shop_id
    and s.created_at >= v_today_start
    and s.created_at <  v_today_end;

  select count(*)
  into v_total_products
  from public.products
  where shop_id = v_shop_id
    and is_active = true;

  select count(*)
  into v_low_stock
  from public.products
  where shop_id = v_shop_id
    and is_active = true
    and stock_quantity > 0
    and stock_quantity <= low_stock_threshold;

  select count(*)
  into v_out_of_stock
  from public.products
  where shop_id = v_shop_id
    and is_active = true
    and stock_quantity <= 0;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', s.id,
        'sale_number', s.sale_number,
        'total_amount', s.total_amount,
        'payment_method', s.payment_method,
        'created_at', s.created_at,
        'item_count', (
          select coalesce(sum(si.quantity), 0)
          from public.sale_items si
          where si.sale_id = s.id
            and si.shop_id = v_shop_id
        )
      )
      order by s.created_at desc
    ),
    '[]'::jsonb
  )
  into v_recent_sales
  from (
    select *
    from public.sales
    where shop_id = v_shop_id
    order by created_at desc
    limit 5
  ) s;

  return jsonb_build_object(
    'today_sales',           v_today_sales,
    'today_profit',          v_today_profit,
    'today_transactions',    v_today_transactions,
    'total_products',        v_total_products,
    'low_stock_products',    v_low_stock,
    'out_of_stock_products', v_out_of_stock,
    'recent_sales',          v_recent_sales
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.get_dashboard_summary()
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
declare
  v_summary jsonb;
begin
  -- to_jsonb keeps the exact keys the live summary returns.
  v_summary := to_jsonb(public.get_dashboard_summary_internal());

  if public.current_shop_role() is distinct from 'owner' then
    v_summary := v_summary - 'today_profit';
  end if;

  return v_summary;
end;
$function$;

-- Live EXECUTE grants.
revoke all on function public.create_sale(uuid, text, numeric, jsonb) from public, anon;
grant execute on function public.create_sale(uuid, text, numeric, jsonb) to authenticated, service_role;
revoke all on function public.get_dashboard_summary_internal() from public, anon, authenticated;
grant execute on function public.get_dashboard_summary_internal() to service_role;
revoke all on function public.get_dashboard_summary() from public, anon;
grant execute on function public.get_dashboard_summary() to authenticated, service_role;

-- Supabase's defaults for objects created from here on (the migrations): API
-- roles get everything; the migrations' own revokes must limit them.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;

-- ---------------------------------------------------------------- fixtures
-- Shop A: owner, attendant; shop B: owner. Prices chosen for the cases.
insert into auth.users (id, email) values
  ('0000000a-0000-0000-0000-000000000001', 'owner.a@test'),
  ('0000000a-0000-0000-0000-000000000002', 'staff.a@test'),
  ('0000000b-0000-0000-0000-000000000001', 'owner.b@test');

insert into public.shops (id, name, status) values
  ('aaaaaaaa-0000-0000-0000-000000000000', 'Shop A', 'active'),
  ('bbbbbbbb-0000-0000-0000-000000000000', 'Shop B', 'active');

insert into public.shop_members (shop_id, user_id, role, status) values
  ('aaaaaaaa-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000001', 'owner', 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000002', 'staff', 'active'),
  ('bbbbbbbb-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000001', 'owner', 'active');

insert into public.products (id, shop_id, name, category, selling_price, cost_price, stock_quantity) values
  ('a0000000-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000000', 'Rice 1kg',    'Food',  10.00, 6.00, 200),
  ('a0000000-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000000', 'Oil 1L',      'Food',  19.99, 5.00, 200),
  ('a0000000-0000-0000-0000-000000000003', 'aaaaaaaa-0000-0000-0000-000000000000', 'Sugar',       'Food',   7.00, 6.80, 200),
  ('a0000000-0000-0000-0000-000000000004', 'aaaaaaaa-0000-0000-0000-000000000000', 'Sweet',       'Snack',  0.33, 0.10, 200),
  ('a0000000-0000-0000-0000-000000000005', 'aaaaaaaa-0000-0000-0000-000000000000', 'Soap',        'Home',   2.50, 0.00, 200),
  ('a0000000-0000-0000-0000-000000000006', 'aaaaaaaa-0000-0000-0000-000000000000', 'Never sold',  'Home',   5.00, 1.00,  10),
  ('a0000000-0000-0000-0000-000000000007', 'aaaaaaaa-0000-0000-0000-000000000000', 'Mint',        'Snack',  0.10, 0.00, 200),
  ('a0000000-0000-0000-0000-000000000008', 'aaaaaaaa-0000-0000-0000-000000000000', 'Loss leader', 'Food',   4.00, 5.00, 200),
  ('b0000000-0000-0000-0000-000000000001', 'bbbbbbbb-0000-0000-0000-000000000000', 'B Rice',      'Food',  10.00, 5.00, 200);

insert into public.customers (id, shop_id, name) values
  ('c0000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000000', 'Ama Customer');
