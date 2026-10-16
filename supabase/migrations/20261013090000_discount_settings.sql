-- Discount Settings, Batch 1: owner-managed percentage discounts, applied by
-- the server.
--
-- * shop_discount_settings: at most one discount configuration per shop.
--   Scope is 'all_products' or 'selected_products'; the percentage is 0.01
--   to 99.99 with at most two decimals; an optional end time. A missing,
--   disabled or expired configuration means normal pricing. Configurations
--   are disabled or edited, never deleted.
-- * shop_discount_products: the products a 'selected_products'
--   configuration applies to. A product can only be selected for its own
--   shop (composite FK); deleting the product removes its selection.
-- * sale_items / sales: discount snapshots. sale_items.unit_price remains the
--   final charged unit price and sale_items.subtotal the final line total.
--   Existing rows are backfilled as "no discount" and keep every existing
--   value.
-- * create_sale: same signature, owner and grants; its body is the live
--   definition with discount resolution, the below-cost rule and the
--   snapshots added. The client still sends only product ids and
--   quantities; the discount is decided here.
--
-- Not changed: create_credit_sale_with_initial_payment (it delegates to
-- create_sale, so credit sales are discounted the same way and keep their
-- idempotency and initial-payment rules), get_dashboard_summary and
-- get_dashboard_summary_internal (today_profit is sum(subtotal - cost_price *
-- quantity), which is the discounted profit once subtotal is the discounted
-- line total), get_business_performance (sales.total_amount and item
-- cost_price).
--
-- RELEASE GATING. This migration gives API roles READ access only: nobody
-- can create or change a discount through the API, so every sale keeps its
-- normal price and current app builds stay correct. A separate, later
-- migration grants the owner writes (the policies below already limit them
-- to the shop owner) only when the compatible app release and rollout plan
-- are ready. That migration is exactly:
--   grant insert, update on table public.shop_discount_settings to authenticated;
--   grant insert, delete on table public.shop_discount_products to authenticated;
--
-- BELOW COST. A discount never takes a line below the product's current
-- cost. 'all_products': such a product is not eligible and sells at its
-- normal price with no discount. 'selected_products': the sale is refused
-- with SQLSTATE SMD01 ("ShopMate discount"), message "Discount cannot be
-- applied to one or more products." (no names, prices or costs). Clients
-- identify the error by the code, not the text.
--
-- APPLYING. Apply with `supabase db push` (verified with CLI 2.75.0: the
-- file is sent as one pipeline and runs as a single transaction) or
-- `psql --single-transaction`. The guard below refuses to run in any mode
-- where the file would not be one transaction. Before applying:
--   * preflight: select count(*) from public.sale_items;  (the backfill
--     rewrites every row while sales and sale_items are locked);
--   * apply outside trading hours: until commit, sales and sale_items are
--     locked ACCESS EXCLUSIVE (no reads or writes) and products SHARE (no
--     writes, including checkout stock updates);
--   * watch for lock waits (pg_stat_activity, wait_event_type = 'Lock').
-- If a lock is not granted within lock_timeout, the migration fails and
-- rolls back completely instead of queueing ahead of every checkout; rerun
-- it later. To change the timeout, edit the value below.

-- ===========================================================================
-- Single transaction and lock timeout
-- ===========================================================================
set local lock_timeout = '5s';
set local shopmate.discount_migration = 'single-transaction';

do $guard$
begin
  -- SET LOCAL only survives to this statement inside one transaction.
  if current_setting('shopmate.discount_migration', true)
     is distinct from 'single-transaction' then
    raise exception
      'Apply 20261013090000_discount_settings.sql as one transaction (supabase db push, or psql --single-transaction).';
  end if;
end;
$guard$;

-- ===========================================================================
-- products: target for same-shop references (as customers and sales have)
-- ===========================================================================
create unique index products_id_shop_id_uidx
  on public.products (id, shop_id);

-- ===========================================================================
-- shop_discount_settings
-- ===========================================================================
create table public.shop_discount_settings (
  shop_id uuid primary key default public.current_shop_id()
    references public.shops (id) on delete restrict,
  is_enabled boolean not null default false,
  scope text not null default 'all_products',
  percentage numeric not null,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null,

  constraint shop_discount_settings_scope_check
    check (scope in ('all_products', 'selected_products')),
  -- Rejected rather than rounded: what the owner entered is what applies.
  constraint shop_discount_settings_percentage_check
    check (
      percentage > 0
      and percentage < 100
      and percentage = round(percentage, 2)
    )
);

comment on table public.shop_discount_settings is
  'One percentage discount configuration per shop. Owner-managed; disabled or edited, never deleted. Applied only by create_sale.';

-- Audit fields come from the session, never from the client.
create function public.stamp_shop_discount_settings()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
begin
  if tg_op = 'INSERT' then
    new.created_at := now();
    new.created_by := auth.uid();
  else
    new.created_at := old.created_at;
    new.created_by := old.created_by;
  end if;
  new.updated_at := now();
  new.updated_by := auth.uid();
  return new;
end;
$function$;

create trigger shop_discount_settings_stamp
  before insert or update on public.shop_discount_settings
  for each row execute function public.stamp_shop_discount_settings();

alter table public.shop_discount_settings enable row level security;

-- Every active member of the shop can read it (the sale screens show
-- discounted prices); only the owner creates or changes it, once the
-- release-gating migration grants the writes (see the header).
create policy shop_discount_settings_select_current_shop
  on public.shop_discount_settings
  for select
  to authenticated
  using (shop_id = (select public.current_shop_id()));

create policy shop_discount_settings_insert_owner_current_shop
  on public.shop_discount_settings
  for insert
  to authenticated
  with check (
    shop_id = (select public.current_shop_id())
    and (select public.current_shop_role()) = 'owner'
  );

create policy shop_discount_settings_update_owner_current_shop
  on public.shop_discount_settings
  for update
  to authenticated
  using (
    shop_id = (select public.current_shop_id())
    and (select public.current_shop_role()) = 'owner'
  )
  with check (
    shop_id = (select public.current_shop_id())
    and (select public.current_shop_role()) = 'owner'
  );

-- No DELETE policy or privilege: a configuration is disabled, not deleted.
-- Read-only for now: the INSERT and UPDATE grants come with the
-- release-gating migration. service_role is read-only too, so no API key
-- can switch a discount on before then.
revoke all privileges on table public.shop_discount_settings
  from public, anon, authenticated, service_role;
grant select on table public.shop_discount_settings
  to authenticated, service_role;

-- ===========================================================================
-- shop_discount_products
-- ===========================================================================
create table public.shop_discount_products (
  shop_id uuid not null default public.current_shop_id(),
  product_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,

  constraint shop_discount_products_pkey
    primary key (shop_id, product_id),
  -- The product must belong to the same shop.
  constraint shop_discount_products_product_shop_fkey
    foreign key (product_id, shop_id)
    references public.products (id, shop_id)
    on delete cascade
);

comment on table public.shop_discount_products is
  'Products a selected_products discount applies to. Owner-managed; ignored while the scope is all_products.';

create function public.stamp_shop_discount_products()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
begin
  new.created_at := now();
  new.created_by := auth.uid();
  return new;
end;
$function$;

create trigger shop_discount_products_stamp
  before insert on public.shop_discount_products
  for each row execute function public.stamp_shop_discount_products();

alter table public.shop_discount_products enable row level security;

create policy shop_discount_products_select_current_shop
  on public.shop_discount_products
  for select
  to authenticated
  using (shop_id = (select public.current_shop_id()));

create policy shop_discount_products_insert_owner_current_shop
  on public.shop_discount_products
  for insert
  to authenticated
  with check (
    shop_id = (select public.current_shop_id())
    and (select public.current_shop_role()) = 'owner'
  );

-- Unselecting a product removes its row; there is nothing to update.
create policy shop_discount_products_delete_owner_current_shop
  on public.shop_discount_products
  for delete
  to authenticated
  using (
    shop_id = (select public.current_shop_id())
    and (select public.current_shop_role()) = 'owner'
  );

-- Read-only for now; INSERT and DELETE come with the release-gating
-- migration.
revoke all privileges on table public.shop_discount_products
  from public, anon, authenticated, service_role;
grant select on table public.shop_discount_products
  to authenticated, service_role;

revoke all on function public.stamp_shop_discount_settings()
  from public, anon, authenticated;
revoke all on function public.stamp_shop_discount_products()
  from public, anon, authenticated;

-- ===========================================================================
-- Sale snapshots
-- ===========================================================================
-- sale_items.unit_price: final charged unit price (unchanged meaning).
-- sale_items.subtotal: final line total (unchanged meaning).
-- original_unit_price: the product's selling price at the time of sale.
-- discount_percentage: the percentage applied to this line (0 = none).
-- discount_amount: the line's total discount, (original - final) * quantity.
alter table public.sale_items
  add column original_unit_price numeric(12, 2),
  add column discount_percentage numeric(5, 2) not null default 0,
  add column discount_amount numeric(12, 2) not null default 0;

-- Existing lines were sold at their recorded unit price with no discount.
update public.sale_items
set original_unit_price = unit_price
where original_unit_price is null;

alter table public.sale_items
  alter column original_unit_price set not null,
  add constraint sale_items_original_unit_price_check
    check (original_unit_price >= 0),
  add constraint sale_items_discount_percentage_check
    check (discount_percentage >= 0 and discount_percentage < 100),
  add constraint sale_items_discount_amount_check
    check (discount_amount >= 0),
  add constraint sale_items_discount_consistency_check
    check (
      unit_price <= original_unit_price
      and discount_amount = (original_unit_price - unit_price) * quantity
    );

-- Any other writer of sale_items keeps working, recorded as "no discount".
create function public.default_sale_item_original_price()
returns trigger
language plpgsql
security invoker
set search_path = public, pg_temp
as $function$
begin
  if new.original_unit_price is null then
    new.original_unit_price := new.unit_price;
  end if;
  return new;
end;
$function$;

create trigger sale_items_default_original_price
  before insert on public.sale_items
  for each row execute function public.default_sale_item_original_price();

revoke all on function public.default_sale_item_original_price()
  from public, anon, authenticated;

-- sales.discount_amount: the sale's total discount (sum of its lines).
-- Existing sales get 0. total_amount stays the amount charged.
alter table public.sales
  add column discount_amount numeric(12, 2) not null default 0,
  add constraint sales_discount_amount_check
    check (discount_amount >= 0);

-- ===========================================================================
-- create_sale
-- ===========================================================================
-- The live definition, unchanged except:
--   * the shop's discount configuration and its selected product ids are
--     read once per sale, in one statement (one snapshot), so every line
--     uses the same configuration even if the owner edits it meanwhile;
--   * each line's discount is resolved and calculated here, from the locked
--     product row's selling price (never from client input), rounded per
--     unit to two decimals (half away from zero);
--   * below cost: an 'all_products' line sells at its normal price with no
--     discount; a 'selected_products' line refuses the sale (SMD01);
--   * the snapshots and sales.discount_amount are written; a line records a
--     percentage only when it actually got money off;
--   * search_path also pins pg_temp last.
-- Any exception rolls back the whole sale, as before.
create or replace function public.create_sale(
  p_customer_id uuid,
  p_payment_method text,
  p_amount_paid numeric,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_shop_id        uuid := public.current_shop_id();
  v_sale_id        uuid;
  v_sale_number    text;

  v_item           jsonb;
  v_product_id     uuid;
  v_quantity       integer;

  v_product_name   text;
  v_original_price numeric;
  v_unit_price     numeric;
  v_cost_price     numeric;

  v_subtotal       numeric;
  v_total_amount   numeric := 0;

  v_previous_stock integer;
  v_new_stock      integer;

  v_change_amount  numeric := 0;

  -- The active discount configuration, if any (null percentage = none).
  v_discount_percentage  numeric;
  v_discount_scope       text;
  v_selected_product_ids uuid[];

  v_line_percentage numeric;
  v_unit_discount   numeric;
  v_line_discount   numeric;
  v_discount_total  numeric := 0;
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

  -- The shop's discount and, for 'selected_products', its selected product
  -- ids: read together in one statement (one snapshot) so every line of
  -- this sale uses the same configuration. Missing, disabled or expired:
  -- normal pricing.
  select
    setting.percentage,
    setting.scope,
    case
      when setting.scope = 'selected_products' then
        coalesce(
          (
            select array_agg(selected.product_id)
            from public.shop_discount_products as selected
            where selected.shop_id = setting.shop_id
          ),
          '{}'::uuid[]
        )
      else '{}'::uuid[]
    end
  into v_discount_percentage, v_discount_scope, v_selected_product_ids
  from public.shop_discount_settings as setting
  where setting.shop_id = v_shop_id
    and setting.is_enabled = true
    and (setting.ends_at is null or setting.ends_at > now());

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
    into v_product_name, v_original_price, v_cost_price, v_previous_stock
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

    -- Discount for this line: the configuration's percentage when it covers
    -- every product, or this product is in the sale's selection snapshot.
    v_unit_discount   := 0;
    v_line_percentage := 0;
    if v_discount_percentage is not null
       and (
         v_discount_scope = 'all_products'
         or (
           v_discount_scope = 'selected_products'
           and v_product_id = any (v_selected_product_ids)
         )
       ) then
      v_unit_discount :=
        round(v_original_price * v_discount_percentage / 100, 2);

      -- Never below the product's current cost.
      if v_unit_discount > 0
         and v_original_price - v_unit_discount < v_cost_price then
        if v_discount_scope = 'selected_products' then
          -- The owner chose this product (its cost may have risen since):
          -- refuse the sale. No names, prices or costs in the message.
          raise exception 'Discount cannot be applied to one or more products.'
            using errcode = 'SMD01';
        end if;
        -- 'all_products': this product is not eligible; normal price.
        v_unit_discount := 0;
      end if;

      if v_unit_discount > 0 then
        v_line_percentage := v_discount_percentage;
      end if;
    end if;

    v_unit_price := v_original_price - v_unit_discount;

    v_subtotal       := v_unit_price * v_quantity;
    v_line_discount  := v_unit_discount * v_quantity;
    v_total_amount   := v_total_amount + v_subtotal;
    v_discount_total := v_discount_total + v_line_discount;
    v_new_stock      := v_previous_stock - v_quantity;

    insert into public.sale_items (
      shop_id, sale_id, product_id, product_name,
      quantity, unit_price, cost_price, subtotal,
      original_unit_price, discount_percentage, discount_amount
    )
    values (
      v_shop_id, v_sale_id, v_product_id, v_product_name,
      v_quantity, v_unit_price, v_cost_price, v_subtotal,
      v_original_price, v_line_percentage, v_line_discount
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
  set total_amount    = v_total_amount,
      change_amount   = v_change_amount,
      discount_amount = v_discount_total
  where id = v_sale_id
    and shop_id = v_shop_id;

  return v_sale_id;
end;
$function$;

-- create or replace keeps the owner and the existing EXECUTE grants
-- (authenticated and service_role; not PUBLIC or anon).
comment on function public.create_sale(uuid, text, numeric, jsonb) is
  'Creates a sale from product ids and quantities. Prices, cost and the shop discount are read on the server. A discount never takes a line below cost: all_products lines sell at normal price; selected_products lines refuse the sale (SQLSTATE SMD01).';
