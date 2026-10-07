-- RBAC-1 checks. Each case records PASS/FAIL; everything runs in one
-- transaction that is rolled back at the end.
\set ON_ERROR_STOP on

create table public.t_results (n serial, name text, ok boolean, detail text);
grant all on public.t_results to anon, authenticated;
grant usage on sequence public.t_results_n_seq to anon, authenticated;

-- Run p_sql as p_role with auth.uid() = p_uid; returns 'ok' or the SQLSTATE.
create function public.t_try(p_role text, p_uid text, p_sql text)
returns text language plpgsql as $$
declare v_state text;
begin
  perform set_config('test.uid', coalesce(p_uid, ''), true);
  execute format('set local role %I', p_role);
  begin
    execute p_sql;
    v_state := 'ok';
  exception when others then
    v_state := sqlstate || ': ' || sqlerrm;
  end;
  reset role;
  return v_state;
end;
$$;

-- Same, but returns the first column of the first row as text.
create function public.t_value(p_role text, p_uid text, p_sql text)
returns text language plpgsql as $$
declare v_value text;
begin
  perform set_config('test.uid', coalesce(p_uid, ''), true);
  execute format('set local role %I', p_role);
  begin
    execute p_sql into v_value;
  exception when others then
    v_value := 'ERROR ' || sqlstate || ': ' || sqlerrm;
  end;
  reset role;
  return v_value;
end;
$$;

create function public.t_check(p_name text, p_ok boolean, p_detail text default null)
returns void language sql as $$
  insert into public.t_results (name, ok, detail) values (p_name, coalesce(p_ok, false), p_detail);
$$;

create function public.t_denied(p_state text) returns boolean language sql as $$
  select p_state like '42501%'
$$;

\set owner '0000000a-0000-0000-0000-000000000001'
\set att '0000000a-0000-0000-0000-000000000002'
\set susp '0000000a-0000-0000-0000-000000000003'
\set owner_b '0000000b-0000-0000-0000-000000000001'
\set owner_c '0000000c-0000-0000-0000-000000000001'
\set prod_a 'a0000000-0000-0000-0000-00000000000a'
\set prod_b 'b0000000-0000-0000-0000-00000000000b'
\set cust_a 'a1000000-0000-0000-0000-00000000000a'
\set cust_a2 'a1000000-0000-0000-0000-0000000000a2'
\set cust_b 'b1000000-0000-0000-0000-00000000000b'
\set sale_b 'b2000000-0000-0000-0000-00000000000b'

begin;

-- Suppliers for both shops (via the owners, through RLS defaults).
select public.t_try('authenticated', :'owner', 'insert into public.suppliers (name) values (''A Supplier'')');
select public.t_try('authenticated', :'owner', 'insert into public.suppliers (name) values (''A Supplier Two'')');

-- =====================================================================
-- ATTENDANT: allowed operations
-- =====================================================================
create temp table t_ids (k text primary key, v text);
grant all on t_ids to authenticated;

select public.t_check('attendant: create_sale works',
  public.t_try('authenticated', :'att', format(
    'insert into t_ids values (''att_sale'', public.create_sale(null, ''cash'', 100, %L::jsonb)::text)',
    json_build_array(json_build_object('product_id', :'prod_a', 'quantity', 2)))) = 'ok');
select public.t_check('attendant sale: price from the product, stock down, movement written',
  (select si.unit_price = 15 and si.cost_price = 10 and s.created_by = :'att'::uuid
   from public.sales s join public.sale_items si on si.sale_id = s.id
   where s.id = (select v::uuid from t_ids where k = 'att_sale'))
  and (select stock_quantity = 48 from public.products where id = :'prod_a')
  and (select count(*) = 1 from public.stock_movements
       where reference_id = (select v::uuid from t_ids where k = 'att_sale')));

select public.t_check('attendant: create_purchase works',
  public.t_try('authenticated', :'att', format(
    'insert into t_ids values (''att_purchase'', public.create_purchase(''Kofi'', null, ''cash'', 0, current_date, null, %L::jsonb)::text)',
    json_build_array(json_build_object('product_id', :'prod_a', 'quantity', 10, 'unit_cost', 99)))) = 'ok');
select public.t_check('attendant purchase: stock up, item records 99, product cost unchanged',
  (select stock_quantity = 58 and cost_price = 10 from public.products where id = :'prod_a')
  and (select unit_cost = 99 from public.purchase_items
       where purchase_id = (select v::uuid from t_ids where k = 'att_purchase'))
  and (select created_by = :'att'::uuid and total_amount = 990 from public.purchases
       where id = (select v::uuid from t_ids where k = 'att_purchase')));

select public.t_check('attendant: sees sales and purchases',
  public.t_value('authenticated', :'att', 'select count(*) from public.sales')::int = 1
  and public.t_value('authenticated', :'att', 'select count(*) from public.purchases')::int = 1);

select public.t_check('attendant: creates a product with initial prices (action)',
  public.t_try('authenticated', :'att',
    'insert into public.products (name, cost_price, selling_price) values (''A Beans'', 4, 6)') = 'ok');
select public.t_check('attendant: creates a product with initial prices (result)',
  (select selling_price = 6 and cost_price = 4 and stock_quantity = 0 and is_active
       from public.products where name = 'A Beans'));
select public.t_check('attendant: product with opening stock rejected',
  public.t_denied(public.t_try('authenticated', :'att',
    'insert into public.products (name, selling_price, stock_quantity) values (''A Salt'', 2, 30)')));
select public.t_check('attendant: inactive product rejected',
  public.t_denied(public.t_try('authenticated', :'att',
    'insert into public.products (name, selling_price, is_active) values (''A Sugar'', 2, false)')));

select public.t_check('attendant: edits basic product fields (action)',
  public.t_try('authenticated', :'att', format(
    'update public.products set name = ''A Rice 5kg'', sku = ''SKU1'', barcode = ''123'', description = ''d'', low_stock_threshold = 3, image_url = ''x'' where id = %L', :'prod_a')) = 'ok');
select public.t_check('attendant: edits basic product fields (result)',
  (select name = 'A Rice 5kg' and low_stock_threshold = 3 from public.products where id = :'prod_a'));
select public.t_check('attendant: same values for price/stock pass (app sends all fields)',
  public.t_try('authenticated', :'att', format(
    'update public.products set name = ''A Rice'', selling_price = 15, cost_price = 10, stock_quantity = 58, is_active = true where id = %L', :'prod_a')) = 'ok');

select public.t_check('attendant: sees inventory and stock history',
  public.t_value('authenticated', :'att', 'select count(*) from public.products')::int >= 2
  and public.t_value('authenticated', :'att', 'select count(*) from public.stock_movements')::int = 2);

select public.t_check('attendant: adds and edits customers (action)',
  public.t_try('authenticated', :'att', 'insert into public.customers (name) values (''A New Customer'')') = 'ok'
  and public.t_try('authenticated', :'att', format(
    'update public.customers set phone = ''024'', notes = ''vip'' where id = %L', :'cust_a')) = 'ok');
select public.t_check('attendant: adds and edits customers (result)',
  (select phone = '024' from public.customers where id = :'cust_a'));

select public.t_check('attendant: adds and edits suppliers (action)',
  public.t_try('authenticated', :'att', 'insert into public.suppliers (name) values (''A Supplier Three'')') = 'ok'
  and public.t_try('authenticated', :'att',
    'update public.suppliers set phone = ''055'' where name = ''A Supplier''') = 'ok');
select public.t_check('attendant: adds and edits suppliers (result)',
  (select phone = '055' from public.suppliers where name = 'A Supplier'));

select public.t_check('attendant dashboard: operational figures, no today_profit',
  (select v ? 'today_sales' and v ? 'total_products' and v ? 'recent_sales'
          and not v ? 'today_profit'
   from (select public.t_value('authenticated', :'att',
           'select public.get_dashboard_summary()::text')::jsonb as v) d));

-- =====================================================================
-- ATTENDANT: rejected operations
-- =====================================================================
select public.t_check('attendant: adjust_stock rejected',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'select public.adjust_stock(%L, 5, ''in'', null)', :'prod_a'))));
select public.t_check('attendant: record_expense rejected',
  public.t_denied(public.t_try('authenticated', :'att',
    'select public.record_expense(''rent'', 10, ''cash'', current_date, null, null, gen_random_uuid())')));
select public.t_check('attendant: business performance rejected',
  public.t_denied(public.t_try('authenticated', :'att',
    'select * from public.get_business_performance(current_date - 7, current_date)')));
select public.t_check('attendant: inventory report rejected',
  public.t_denied(public.t_try('authenticated', :'att',
    'select * from public.get_inventory_report()')));
select public.t_check('attendant: cannot call the internal stock function',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'select public.adjust_stock_internal(%L, 5, ''in'', null)', :'prod_a'))));
select public.t_check('attendant: cannot call the internal dashboard',
  public.t_denied(public.t_try('authenticated', :'att',
    'select public.get_dashboard_summary_internal()')));

select public.t_check('attendant: selling price change rejected',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'update public.products set selling_price = 1 where id = %L', :'prod_a'))));
select public.t_check('attendant: cost price change rejected',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'update public.products set cost_price = 1 where id = %L', :'prod_a'))));
select public.t_check('attendant: direct stock change rejected',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'update public.products set stock_quantity = 999 where id = %L', :'prod_a'))));
select public.t_check('attendant: product deactivation rejected',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'update public.products set is_active = false where id = %L', :'prod_a'))));
select public.t_check('attendant: product hard delete removes nothing (action)',
  public.t_try('authenticated', :'att', format(
    'delete from public.products where id = %L', :'prod_a')) = 'ok');
select public.t_check('attendant: product hard delete removes nothing (result)',
  exists (select 1 from public.products where id = :'prod_a'));
select public.t_check('product A unchanged after every rejected attempt',
  (select selling_price = 15 and cost_price = 10 and stock_quantity = 58 and is_active
   from public.products where id = :'prod_a'));

select public.t_check('attendant: editing an existing purchase changes nothing (action)',
  public.t_try('authenticated', :'att',
    'update public.purchases set total_amount = 1, amount_paid = 0, balance = 0, status = ''cancelled'', created_by = null') = 'ok');
select public.t_check('attendant: editing an existing purchase changes nothing (result)',
  (select total_amount = 990 and status = 'completed' and created_by = :'att'::uuid
       from public.purchases where id = (select v::uuid from t_ids where k = 'att_purchase')));
select public.t_check('attendant: direct purchase insert rejected',
  public.t_denied(public.t_try('authenticated', :'att',
    'insert into public.purchases (purchase_number, total_amount) values (''FAKE'', 1)')));
select public.t_check('attendant: direct purchase-item insert rejected',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'insert into public.purchase_items (purchase_id, product_id, product_name, quantity, unit_cost, subtotal) values (%L, %L, ''x'', 1, 1, 1)',
    (select v from t_ids where k = 'att_purchase'), :'prod_a'))));
select public.t_check('attendant: direct sale insert rejected',
  public.t_denied(public.t_try('authenticated', :'att',
    'insert into public.sales (sale_number, total_amount) values (''FAKE'', 1000)')));
select public.t_check('attendant: direct sale-item insert rejected',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'insert into public.sale_items (sale_id, product_id, product_name, quantity, unit_price, cost_price, subtotal) values (%L, %L, ''x'', 1, 0, 0, 0)',
    (select v from t_ids where k = 'att_sale'), :'prod_a'))));
select public.t_check('attendant: direct stock movement insert rejected (policy name unknown)',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'insert into public.stock_movements (product_id, movement_type, quantity, previous_quantity, new_quantity) values (%L, ''adjustment'', 5, 0, 5)',
    :'prod_a'))));
select public.t_check('attendant: sale/purchase/movement update and delete rejected',
  public.t_denied(public.t_try('authenticated', :'att', 'update public.sales set total_amount = 0'))
  and public.t_denied(public.t_try('authenticated', :'att', 'delete from public.sale_items'))
  and public.t_denied(public.t_try('authenticated', :'att', 'delete from public.stock_movements'))
  and public.t_denied(public.t_try('authenticated', :'att', 'delete from public.purchases')));
select public.t_check('attendant: truncate rejected',
  public.t_denied(public.t_try('authenticated', :'att', 'truncate public.products')));

select public.t_check('attendant: customer deactivation rejected',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'update public.customers set is_active = false where id = %L', :'cust_a'))));
select public.t_check('attendant: customer delete removes nothing (action)',
  public.t_try('authenticated', :'att', format(
    'delete from public.customers where id = %L', :'cust_a')) = 'ok');
select public.t_check('attendant: customer delete removes nothing (result)',
  exists (select 1 from public.customers where id = :'cust_a' and is_active));
select public.t_check('attendant: supplier delete removes nothing (action)',
  public.t_try('authenticated', :'att',
    'delete from public.suppliers where name = ''A Supplier''') = 'ok');
select public.t_check('attendant: supplier delete removes nothing (result)',
  exists (select 1 from public.suppliers where name = 'A Supplier'));

select public.t_check('attendant: shop_members insert/update/delete rejected (action)',
  public.t_denied(public.t_try('authenticated', :'att', format(
    'insert into public.shop_members (shop_id, user_id, role) values (%L, %L, ''owner'')',
    'aaaaaaaa-0000-0000-0000-000000000000', :'owner_c')))
  and public.t_denied(public.t_try('authenticated', :'att',
    'update public.shop_members set role = ''owner'''))
  and public.t_denied(public.t_try('authenticated', :'att', 'delete from public.shop_members')));
select public.t_check('attendant: shop_members insert/update/delete rejected (result)',
  (select role = 'staff' from public.shop_members where user_id = :'att'::uuid));

select public.t_try('authenticated', :'owner',
  'select public.record_expense(''rent'', 25, ''cash'', current_date, null, null, gen_random_uuid())');
select public.t_check('attendant: sees no expenses (owner does)',
  public.t_value('authenticated', :'att', 'select count(*) from public.expenses')::int = 0
  and public.t_value('authenticated', :'owner', 'select count(*) from public.expenses')::int = 1);

-- =====================================================================
-- OWNER: full control
-- =====================================================================
select public.t_check('owner: create_sale works',
  public.t_try('authenticated', :'owner', format(
    'select public.create_sale(null, ''cash'', 15, %L::jsonb)',
    json_build_array(json_build_object('product_id', :'prod_a', 'quantity', 1)))) = 'ok');
select public.t_check('owner: purchase updates the product cost price (action)',
  public.t_try('authenticated', :'owner', format(
    'select public.create_purchase(null, null, ''cash'', 0, current_date, null, %L::jsonb)',
    json_build_array(json_build_object('product_id', :'prod_a', 'quantity', 5, 'unit_cost', 12)))) = 'ok');
select public.t_check('owner: purchase updates the product cost price (result)',
  (select cost_price = 12 and stock_quantity = 62 from public.products where id = :'prod_a'));
insert into t_ids
select 'owner_adjust', public.t_value('authenticated', :'owner', format(
  'select public.adjust_stock(%L, 3, ''out'', ''count'')', :'prod_a'));
select public.t_check('owner: adjust_stock works and returns the movement id as text',
  (select v ~ '^[0-9a-f-]{36}$' from t_ids where k = 'owner_adjust'));
select public.t_check('owner: adjust_stock moved the stock and wrote the movement',
  (select stock_quantity = 59 from public.products where id = :'prod_a')
  and exists (select 1 from public.stock_movements
              where id = (select v::uuid from t_ids where k = 'owner_adjust')
                and movement_type = 'adjustment' and created_by = :'owner'::uuid));
select public.t_check('owner: adjust_stock still works without a note',
  public.t_try('authenticated', :'owner', format(
    'select public.adjust_stock(p_product_id => %L, p_quantity => 1, p_direction => ''in'')', :'prod_a')) = 'ok');
select public.t_check('owner: record_expense works',
  public.t_try('authenticated', :'owner',
    'select public.record_expense(''utilities'', 5, ''cash'', current_date, null, null, gen_random_uuid())') = 'ok');
select public.t_check('owner: business performance works',
  public.t_try('authenticated', :'owner',
    'select * from public.get_business_performance(current_date - 7, current_date)') = 'ok');
select public.t_check('owner: inventory report works',
  public.t_try('authenticated', :'owner', 'select * from public.get_inventory_report()') = 'ok');
select public.t_check('owner dashboard: includes today_profit',
  (select v ? 'today_profit' and v ? 'today_sales'
   from (select public.t_value('authenticated', :'owner',
           'select public.get_dashboard_summary()::text')::jsonb as v) d));
select public.t_check('owner: edits price, cost, stock and active flag (action)',
  public.t_try('authenticated', :'owner', format(
    'update public.products set selling_price = 16, cost_price = 11, stock_quantity = 70, is_active = false where id = %L', :'prod_a')) = 'ok');
select public.t_check('owner: edits price, cost, stock and active flag (result)',
  (select selling_price = 16 and cost_price = 11 and stock_quantity = 70 and not is_active
       from public.products where id = :'prod_a'));
select public.t_try('authenticated', :'owner', format(
  'update public.products set is_active = true where id = %L', :'prod_a'));
select public.t_check('owner: creates a product with opening stock',
  public.t_try('authenticated', :'owner',
    'insert into public.products (name, selling_price, stock_quantity) values (''A Oil'', 9, 12)') = 'ok');
select public.t_check('owner: edits an existing purchase (action)',
  public.t_try('authenticated', :'owner', format(
    'update public.purchases set notes = ''checked'' where id = %L',
    (select v from t_ids where k = 'att_purchase'))) = 'ok');
select public.t_check('owner: edits an existing purchase (result)',
  (select notes = 'checked' from public.purchases
       where id = (select v::uuid from t_ids where k = 'att_purchase')));
select public.t_check('owner: deactivates and deletes customers (action)',
  public.t_try('authenticated', :'owner', format(
    'update public.customers set is_active = false where id = %L', :'cust_a')) = 'ok'
  and public.t_try('authenticated', :'owner', format(
    'delete from public.customers where id = %L', :'cust_a2')) = 'ok');
select public.t_check('owner: deactivates and deletes customers (result)',
  not exists (select 1 from public.customers where id = :'cust_a2'));
select public.t_check('owner: deletes suppliers (action)',
  public.t_try('authenticated', :'owner',
    'delete from public.suppliers where name = ''A Supplier Two''') = 'ok');
select public.t_check('owner: deletes suppliers (result)',
  not exists (select 1 from public.suppliers where name = 'A Supplier Two'));
select public.t_check('owner: still cannot write sales/movements directly',
  public.t_denied(public.t_try('authenticated', :'owner',
    'insert into public.sales (sale_number, total_amount) values (''FAKE'', 1)'))
  and public.t_denied(public.t_try('authenticated', :'owner', format(
    'insert into public.stock_movements (product_id, movement_type, quantity, previous_quantity, new_quantity) values (%L, ''x'', 1, 0, 1)',
    :'prod_a'))));

-- =====================================================================
-- CROSS-SHOP
-- =====================================================================
select public.t_check('attendant A sees nothing of shop B',
  public.t_value('authenticated', :'att', format(
    'select count(*) from public.products where id = %L', :'prod_b'))::int = 0
  and public.t_value('authenticated', :'att', format(
    'select count(*) from public.sales where id = %L', :'sale_b'))::int = 0
  and public.t_value('authenticated', :'att', format(
    'select count(*) from public.customers where id = %L', :'cust_b'))::int = 0);
select public.t_check('attendant A cannot change shop B rows (action)',
  public.t_try('authenticated', :'att', format(
    'update public.products set name = ''hacked'' where id = %L', :'prod_b')) = 'ok'
  and public.t_try('authenticated', :'att', format(
    'update public.customers set name = ''hacked'' where id = %L', :'cust_b')) = 'ok');
select public.t_check('attendant A cannot change shop B rows (result)',
  (select name = 'B Soap' from public.products where id = :'prod_b')
  and (select name = 'B Customer' from public.customers where id = :'cust_b'));
select public.t_check('owner A cannot sell, buy or adjust shop B stock (action)',
  public.t_try('authenticated', :'owner', format(
    'select public.create_sale(null, ''cash'', 5, %L::jsonb)',
    json_build_array(json_build_object('product_id', :'prod_b', 'quantity', 1)))) <> 'ok'
  and public.t_try('authenticated', :'owner', format(
    'select public.create_purchase(null, null, ''cash'', 0, current_date, null, %L::jsonb)',
    json_build_array(json_build_object('product_id', :'prod_b', 'quantity', 1, 'unit_cost', 1)))) <> 'ok'
  and public.t_try('authenticated', :'owner', format(
    'select public.adjust_stock(%L, 1, ''in'', null)', :'prod_b')) <> 'ok');
select public.t_check('owner A cannot sell, buy or adjust shop B stock (result)',
  (select stock_quantity = 20 and cost_price = 3 from public.products where id = :'prod_b'));
select public.t_check('owner B sees no shop A expenses',
  public.t_value('authenticated', :'owner_b', 'select count(*) from public.expenses')::int = 0);

-- =====================================================================
-- SUSPENDED membership / suspended shop
-- =====================================================================
select public.t_check('suspended member: no shop and no role',
  public.t_value('authenticated', :'susp', 'select public.current_shop_id()') is null
  and public.t_value('authenticated', :'susp', 'select public.current_shop_role()') is null);
select public.t_check('suspended member: every RPC refused',
  public.t_try('authenticated', :'susp', format(
    'select public.create_sale(null, ''cash'', 15, %L::jsonb)',
    json_build_array(json_build_object('product_id', :'prod_a', 'quantity', 1)))) <> 'ok'
  and public.t_try('authenticated', :'susp', format(
    'select public.create_purchase(null, null, ''cash'', 0, current_date, null, %L::jsonb)',
    json_build_array(json_build_object('product_id', :'prod_a', 'quantity', 1, 'unit_cost', 1)))) <> 'ok'
  and public.t_try('authenticated', :'susp', format(
    'select public.adjust_stock(%L, 1, ''in'', null)', :'prod_a')) <> 'ok'
  and public.t_try('authenticated', :'susp', 'select public.get_dashboard_summary()') <> 'ok'
  and public.t_try('authenticated', :'susp',
    'select public.record_expense(''rent'', 1, ''cash'', current_date, null, null, gen_random_uuid())') <> 'ok');
select public.t_check('suspended member: tables show nothing and accept nothing (action)',
  public.t_try('authenticated', :'susp',
    'insert into public.products (name, selling_price) values (''x'', 1)') <> 'ok'
  and public.t_try('authenticated', :'susp', format(
    'update public.products set name = ''x'' where id = %L', :'prod_a')) = 'ok');
select public.t_check('suspended member: tables show nothing and accept nothing (result)',
  public.t_value('authenticated', :'susp', 'select count(*) from public.products')::int = 0
  and public.t_value('authenticated', :'susp', 'select count(*) from public.sales')::int = 0
  and (select name <> 'x' from public.products where id = :'prod_a'));
select public.t_check('owner of a suspended shop: refused',
  public.t_value('authenticated', :'owner_c', 'select public.current_shop_id()') is null
  and public.t_try('authenticated', :'owner_c', 'select * from public.get_inventory_report()') <> 'ok'
  and public.t_value('authenticated', :'owner_c', 'select count(*) from public.products')::int = 0);
select public.t_check('anon: refused everywhere',
  public.t_denied(public.t_try('anon', null, 'select count(*) from public.products'))
  and public.t_denied(public.t_try('anon', null, 'select public.get_dashboard_summary()'))
  and public.t_denied(public.t_try('anon', null, 'select * from public.get_inventory_report()')));

-- =====================================================================
-- Hardening
-- =====================================================================
select public.t_check('changed RPCs: SECURITY DEFINER with search_path public, pg_temp',
  (select bool_and(p.prosecdef and p.proconfig = array['search_path=public, pg_temp'])
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('record_expense', 'get_business_performance', 'get_inventory_report',
                       'adjust_stock', 'adjust_stock_internal', 'get_dashboard_summary',
                       'get_dashboard_summary_internal', 'create_purchase')
   having count(*) = 8));
select public.t_check('internal functions not executable by API roles',
  (select bool_and(not has_function_privilege('authenticated', p.oid, 'execute')
                   and not has_function_privilege('anon', p.oid, 'execute'))
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('adjust_stock_internal', 'get_dashboard_summary_internal',
                       'enforce_product_role_limits', 'enforce_customer_role_limits')));
select public.t_check('authenticated has no TRUNCATE/TRIGGER/REFERENCES on protected tables',
  not exists (
    select 1 from information_schema.role_table_grants
    where table_schema = 'public' and grantee = 'authenticated'
      and table_name in ('products', 'customers', 'sales', 'sale_items', 'purchases',
                         'purchase_items', 'stock_movements')
      and privilege_type in ('TRUNCATE', 'TRIGGER', 'REFERENCES')));

\pset format aligned
select n, case when ok then 'PASS' else 'FAIL' end as result, name, coalesce(detail, '') as detail
from public.t_results order by n;
select count(*) filter (where ok) as passed, count(*) filter (where not ok) as failed
from public.t_results;

rollback;
