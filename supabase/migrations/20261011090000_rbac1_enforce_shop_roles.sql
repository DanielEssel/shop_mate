-- RBAC-1: database enforcement of shop roles.
--
-- Two shop roles: 'owner' (full control) and the non-owner role, stored as
-- 'staff' today and renamed to 'shop_attendant' in a later batch. Every rule
-- below is written as "owner" vs "not owner", so it holds for both names.
--
-- All checks use the existing helpers: current_shop_id() and
-- current_shop_role() only answer for an authenticated, ACTIVE member of an
-- ACTIVE shop, so suspended members and members of inactive shops get null
-- (no shop, no role) and are refused everywhere.
--
-- What changes:
--   1. Owner-only RPCs: record_expense, get_business_performance,
--      get_inventory_report, adjust_stock.
--   2. get_dashboard_summary: attendants no longer receive today_profit.
--   3. create_purchase: attendants may still record purchases, but only an
--      owner's purchase updates a product's stored cost_price.
--   4. Products / customers: a trigger limits which fields a non-owner may
--      change through direct (API) writes.
--   5. Expenses are readable by owners only.
--   6. Sales, sale items, purchase items and stock movements can no longer be
--      written directly; only the database functions write them. Purchases
--      can only be created by create_purchase and edited by owners.
--   7. Table grants for authenticated are cut to what the app uses.
--
-- Not changed: create_sale (already reads prices from the locked product row,
-- and is used by attendants), credit sales and customer payments, suppliers,
-- shop_members, categories, branding, profile, and the platform-admin layer.

-- ===========================================================================
-- 1. Owner-only RPCs
-- ===========================================================================

-- record_expense: unchanged except the owner check and search_path.
create or replace function public.record_expense(
  p_category text,
  p_amount numeric,
  p_payment_method text,
  p_expense_date date,
  p_reference text,
  p_note text,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
  v_expense_id uuid;
  v_existing_category text;
  v_existing_amount numeric(12, 2);
  v_existing_method text;
  v_existing_expense_date date;
  v_existing_reference text;
  v_existing_note text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can record expenses'
      using errcode = '42501';
  end if;

  if p_category is null
     or p_category not in (
       'rent',
       'utilities',
       'transport',
       'salaries',
       'supplies',
       'maintenance',
       'marketing',
       'communication',
       'other'
     ) then
    raise exception 'Invalid expense category: %', p_category;
  end if;

  if p_amount is null
     or p_amount <= 0
     or p_amount >= 10000000000
     or p_amount <> round(p_amount, 2) then
    raise exception 'Expense amount must be positive and have at most two decimal places';
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'mobile_money', 'card', 'bank_transfer') then
    raise exception 'Invalid payment method: %', p_payment_method;
  end if;

  if p_expense_date is null then
    raise exception 'Expense date is required';
  end if;

  if p_idempotency_key is null then
    raise exception 'Idempotency key is required';
  end if;

  -- Serialize retries for this shop/key so a duplicate request returns the original expense.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(v_shop_id::text),
    pg_catalog.hashtext(p_idempotency_key::text)
  );

  select
    expense.id,
    expense.category,
    expense.amount,
    expense.payment_method,
    expense.expense_date,
    expense.reference,
    expense.note
  into
    v_expense_id,
    v_existing_category,
    v_existing_amount,
    v_existing_method,
    v_existing_expense_date,
    v_existing_reference,
    v_existing_note
  from public.expenses as expense
  where expense.shop_id = v_shop_id
    and expense.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_category is distinct from p_category
       or v_existing_amount is distinct from p_amount
       or v_existing_method is distinct from p_payment_method
       or v_existing_expense_date is distinct from p_expense_date
       or v_existing_reference is distinct from p_reference
       or v_existing_note is distinct from p_note then
      raise exception 'Idempotency key was already used for a different expense';
    end if;

    return v_expense_id;
  end if;

  insert into public.expenses (
    shop_id,
    category,
    amount,
    payment_method,
    expense_date,
    reference,
    note,
    created_by,
    idempotency_key
  )
  values (
    v_shop_id,
    p_category,
    p_amount,
    p_payment_method,
    p_expense_date,
    p_reference,
    p_note,
    auth.uid(),
    p_idempotency_key
  )
  returning id into v_expense_id;

  return v_expense_id;
end;
$function$;

-- get_business_performance: unchanged except the owner check and search_path.
create or replace function public.get_business_performance(
  p_start_date date,
  p_end_date date
)
returns table (
  total_sales numeric,
  total_cogs numeric,
  gross_profit numeric,
  total_expenses numeric,
  net_profit numeric,
  profit_margin numeric,
  sales_count bigint,
  expense_count bigint
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
  -- Business dates are UTC calendar days (the database timezone; Ghana is
  -- UTC+0 with no daylight saving). Half-open window, independent of the
  -- session timezone: [start 00:00 UTC, end + 1 day 00:00 UTC).
  v_window_start timestamptz;
  v_window_end timestamptz;
  v_total_sales numeric := 0;
  v_sales_count bigint := 0;
  v_total_cogs numeric := 0;
  v_total_expenses numeric := 0;
  v_expense_count bigint := 0;
  v_gross_profit numeric;
  v_net_profit numeric;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can view business performance'
      using errcode = '42501';
  end if;

  if p_start_date is null or p_end_date is null then
    raise exception 'Start and end dates are required';
  end if;

  if p_start_date > p_end_date then
    raise exception 'Start date must be on or before end date';
  end if;

  v_window_start := p_start_date::timestamp at time zone 'UTC';
  v_window_end := (p_end_date + 1)::timestamp at time zone 'UTC';

  -- Net sales: every sale in the window, including credit sales, at the
  -- recorded sale total. Sales have no void/cancel status to exclude.
  select coalesce(sum(sale.total_amount), 0), count(*)
  into v_total_sales, v_sales_count
  from public.sales as sale
  where sale.shop_id = v_shop_id
    and sale.created_at >= v_window_start
    and sale.created_at < v_window_end;

  -- COGS: cost recorded on each sale item at the time of sale, never the
  -- product's current cost.
  select coalesce(sum(item.quantity * item.cost_price), 0)
  into v_total_cogs
  from public.sale_items as item
  join public.sales as sale
    on sale.id = item.sale_id
   and sale.shop_id = v_shop_id
  where item.shop_id = v_shop_id
    and sale.created_at >= v_window_start
    and sale.created_at < v_window_end;

  -- Operating expenses only; purchases and customer payments are excluded.
  select coalesce(sum(expense.amount), 0), count(*)
  into v_total_expenses, v_expense_count
  from public.expenses as expense
  where expense.shop_id = v_shop_id
    and expense.expense_date between p_start_date and p_end_date;

  v_gross_profit := v_total_sales - v_total_cogs;
  v_net_profit := v_gross_profit - v_total_expenses;

  return query
    select
      v_total_sales,
      v_total_cogs,
      v_gross_profit,
      v_total_expenses,
      v_net_profit,
      case
        when v_total_sales > 0 then round(v_net_profit / v_total_sales * 100, 2)
        else 0::numeric
      end,
      v_sales_count,
      v_expense_count;
end;
$function$;

-- get_inventory_report: unchanged except the owner check and search_path.
create or replace function public.get_inventory_report()
returns table (
  total_products bigint,
  total_units numeric,
  inventory_cost_value numeric,
  potential_selling_value numeric,
  expected_gross_profit numeric,
  low_stock_count bigint,
  out_of_stock_count bigint,
  units_purchased numeric,
  units_sold numeric
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
  v_total_products bigint := 0;
  v_total_units numeric := 0;
  v_inventory_cost_value numeric := 0;
  v_potential_selling_value numeric := 0;
  v_low_stock_count bigint := 0;
  v_out_of_stock_count bigint := 0;
  v_units_purchased numeric := 0;
  v_units_sold numeric := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can view the inventory report'
      using errcode = '42501';
  end if;

  -- Stock on hand for active products only; deleted products are soft-deleted
  -- with is_active = false, matching the app's product and inventory lists.
  -- Stock and prices are NOT NULL and nonnegative by table constraints, and
  -- valuation uses current product prices.
  select
    count(*),
    coalesce(sum(product.stock_quantity), 0),
    coalesce(sum(product.stock_quantity * product.cost_price), 0),
    coalesce(sum(product.stock_quantity * product.selling_price), 0),
    count(*) filter (
      where product.stock_quantity > 0
        and product.stock_quantity <= product.low_stock_threshold
    ),
    count(*) filter (where product.stock_quantity = 0)
  into
    v_total_products,
    v_total_units,
    v_inventory_cost_value,
    v_potential_selling_value,
    v_low_stock_count,
    v_out_of_stock_count
  from public.products as product
  where product.shop_id = v_shop_id
    and product.is_active = true;

  -- All completed purchases for the shop, across all dates.
  select coalesce(sum(item.quantity), 0)
  into v_units_purchased
  from public.purchase_items as item
  join public.purchases as purchase
    on purchase.id = item.purchase_id
   and purchase.shop_id = v_shop_id
  where item.shop_id = v_shop_id
    and purchase.status = 'completed';

  -- All sales for the shop, across all dates; credit sales count like any
  -- other sale.
  select coalesce(sum(item.quantity), 0)
  into v_units_sold
  from public.sale_items as item
  join public.sales as sale
    on sale.id = item.sale_id
   and sale.shop_id = v_shop_id
  where item.shop_id = v_shop_id;

  return query
    select
      v_total_products,
      v_total_units,
      v_inventory_cost_value,
      v_potential_selling_value,
      v_potential_selling_value - v_inventory_cost_value,
      v_low_stock_count,
      v_out_of_stock_count,
      v_units_purchased,
      v_units_sold;
end;
$function$;

-- adjust_stock: the live implementation is kept exactly as it is, under an
-- internal name that clients cannot execute. The public name becomes a guard
-- that refuses non-owners before anything is read or written, then delegates.
alter function public.adjust_stock(uuid, integer, text, text)
  rename to adjust_stock_internal;
alter function public.adjust_stock_internal(uuid, integer, text, text)
  set search_path = public, pg_temp;
revoke all on function public.adjust_stock_internal(uuid, integer, text, text)
  from public, anon, authenticated;

create function public.adjust_stock(
  p_product_id uuid,
  p_quantity integer,
  p_direction text,
  p_note text default null
)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if public.current_shop_id() is null then
    raise exception 'No active shop for this account';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can adjust stock'
      using errcode = '42501';
  end if;

  -- The app reads the result as text, whatever the internal return type.
  return (
    select public.adjust_stock_internal(p_product_id, p_quantity, p_direction, p_note)
  )::text;
end;
$function$;

-- ===========================================================================
-- 2. Dashboard: no profit for attendants
-- ===========================================================================

-- Same approach: the live summary is kept as is under an internal name. The
-- public function returns it unchanged to owners and drops today_profit for
-- everyone else. The app already treats a missing today_profit as 0.
alter function public.get_dashboard_summary()
  rename to get_dashboard_summary_internal;
alter function public.get_dashboard_summary_internal()
  set search_path = public, pg_temp;
revoke all on function public.get_dashboard_summary_internal()
  from public, anon, authenticated;

create function public.get_dashboard_summary()
returns jsonb
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
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

-- ===========================================================================
-- 3. create_purchase: an attendant's purchase does not change cost_price
-- ===========================================================================

-- Unchanged except: products.cost_price follows the purchase unit cost only
-- when the caller is the owner (the existing "latest purchase cost" rule).
-- For an attendant the stock, purchase item (with its real unit cost) and
-- stock movement are recorded exactly as before; the product's stored cost
-- stays as the owner set it.
create or replace function public.create_purchase(
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
set search_path = public, pg_temp
as $function$
declare
  v_shop_id         uuid := public.current_shop_id();
  v_is_owner        boolean := public.current_shop_role() = 'owner';
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
        cost_price     = case when v_is_owner then v_unit_cost else cost_price end,
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

-- ===========================================================================
-- Execute grants for the public RPCs (create or replace keeps existing
-- grants; the new guards need them explicitly).
-- ===========================================================================

revoke all on function public.record_expense(text, numeric, text, date, text, text, uuid)
  from public, anon;
revoke all on function public.get_business_performance(date, date) from public, anon;
revoke all on function public.get_inventory_report() from public, anon;
revoke all on function public.adjust_stock(uuid, integer, text, text) from public, anon;
revoke all on function public.get_dashboard_summary() from public, anon;
revoke all on function public.create_purchase(text, text, text, numeric, date, text, jsonb, uuid)
  from public, anon;

grant execute on function public.record_expense(text, numeric, text, date, text, text, uuid)
  to authenticated;
grant execute on function public.get_business_performance(date, date) to authenticated;
grant execute on function public.get_inventory_report() to authenticated;
grant execute on function public.adjust_stock(uuid, integer, text, text) to authenticated;
grant execute on function public.get_dashboard_summary() to authenticated;
grant execute on function public.create_purchase(text, text, text, numeric, date, text, jsonb, uuid)
  to authenticated;

-- ===========================================================================
-- 4. Field limits for non-owners on direct product / customer writes
-- ===========================================================================

-- Only direct API writes (current_user = 'authenticated') are checked. The
-- database's own SECURITY DEFINER functions (create_sale, create_purchase,
-- adjust_stock, ...) run as their owner and keep working for attendants.
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
    -- An attendant may create a product and set its initial prices, but not
    -- conjure stock or create it already deactivated.
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
  for each row
  execute function public.enforce_product_role_limits();

-- Deactivating a customer is deleting it (owner-only); restoring one is too.
create function public.enforce_customer_role_limits()
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

  if new.is_active is distinct from old.is_active then
    raise exception 'Only the shop owner can delete or restore a customer'
      using errcode = '42501';
  end if;

  return new;
end;
$function$;

revoke all on function public.enforce_customer_role_limits() from public, anon, authenticated;

create trigger customers_enforce_role_limits
  before update on public.customers
  for each row
  execute function public.enforce_customer_role_limits();

-- ===========================================================================
-- 5. Expenses: owner-only read
-- ===========================================================================

drop policy expenses_select_current_shop on public.expenses;

create policy expenses_select_owner_current_shop
  on public.expenses
  for select
  to authenticated
  using (
    shop_id = public.current_shop_id()
    and public.current_shop_role() = 'owner'
  );

-- ===========================================================================
-- 6. RPC-only tables: no direct inserts; purchases editable by owners only
-- ===========================================================================

drop policy if exists "Shop members can create" on public.sales;
drop policy if exists "Shop members can create" on public.sale_items;
drop policy if exists "Shop members can create" on public.purchase_items;
drop policy if exists "Shop members can create" on public.purchases;
drop policy if exists "Shop members can update" on public.purchases;
drop policy if exists "Shop members can create" on public.stock_movements;

create policy purchases_update_owner_current_shop
  on public.purchases
  for update
  to authenticated
  using (
    shop_id = public.current_shop_id()
    and public.current_shop_role() = 'owner'
  )
  with check (
    shop_id = public.current_shop_id()
    and public.current_shop_role() = 'owner'
  );

-- ===========================================================================
-- 7. Table grants: only what the app uses; RPC-only tables are read-only.
-- The privileges removed by the "revoke all" below are re-granted only where
-- the app writes directly (products, customers) or owners may (purchases).
-- ===========================================================================

revoke all on table public.sales from anon, authenticated;
revoke all on table public.sale_items from anon, authenticated;
revoke all on table public.purchases from anon, authenticated;
revoke all on table public.purchase_items from anon, authenticated;
revoke all on table public.stock_movements from anon, authenticated;
revoke all on table public.products from anon, authenticated;
revoke all on table public.customers from anon, authenticated;

grant select on table public.sales to authenticated;
grant select on table public.sale_items to authenticated;
grant select, update on table public.purchases to authenticated;
grant select on table public.purchase_items to authenticated;
grant select on table public.stock_movements to authenticated;
grant select, insert, update, delete on table public.products to authenticated;
grant select, insert, update, delete on table public.customers to authenticated;
