-- Discount Settings (Batch 1) checks. Every action runs in its own statement
-- and is verified in a later one (a single statement may evaluate the check
-- before the action). Everything below is rolled back at the end.
\set ON_ERROR_STOP on

\set oa '0000000a-0000-0000-0000-000000000001'
\set sa '0000000a-0000-0000-0000-000000000002'
\set ob '0000000b-0000-0000-0000-000000000001'
\set shop_a 'aaaaaaaa-0000-0000-0000-000000000000'
\set shop_b 'bbbbbbbb-0000-0000-0000-000000000000'
\set rice 'a0000000-0000-0000-0000-000000000001'
\set oil 'a0000000-0000-0000-0000-000000000002'
\set sugar 'a0000000-0000-0000-0000-000000000003'
\set sweet 'a0000000-0000-0000-0000-000000000004'
\set soap 'a0000000-0000-0000-0000-000000000005'
\set unsold 'a0000000-0000-0000-0000-000000000006'
\set mint 'a0000000-0000-0000-0000-000000000007'
\set loss 'a0000000-0000-0000-0000-000000000008'
\set b_rice 'b0000000-0000-0000-0000-000000000001'
\set customer 'c0000000-0000-0000-0000-00000000000a'

begin;

create table public.t_results (n serial, name text, ok boolean, detail text);
create table public.t_ids (name text primary key, value text);
create table public.t_values (name text primary key, value text);
grant all on public.t_results, public.t_ids, public.t_values to anon, authenticated, service_role;
grant usage on sequence public.t_results_n_seq to anon, authenticated, service_role;

-- Run p_sql as p_role with auth.uid() = p_uid; returns 'ok' or SQLSTATE: message.
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

-- Same, returning the first column of the first row as text.
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

create function public.t_is(p_state text, p_code text) returns boolean language sql as $$
  select p_state like p_code || '%'
$$;

-- A sale through create_sale as p_uid; the sale id (or ERROR ...) is kept
-- under p_name.
create function public.t_sale(
  p_name text, p_uid text, p_method text, p_paid numeric, p_items jsonb,
  p_customer uuid default null)
returns void language sql as $$
  insert into public.t_ids values (p_name, public.t_value('authenticated', p_uid, format(
    'select public.create_sale(%L, %L, %s, %L::jsonb)::text',
    p_customer, p_method, p_paid, p_items)));
$$;

-- A credit sale through create_credit_sale_with_initial_payment.
create function public.t_credit(
  p_name text, p_uid text, p_customer uuid, p_paid numeric, p_method text,
  p_items jsonb, p_key uuid)
returns void language sql as $$
  insert into public.t_ids values (p_name, public.t_value('authenticated', p_uid, format(
    'select public.create_credit_sale_with_initial_payment(%L, %s, %L, %L::jsonb, %L)::text',
    p_customer, p_paid, p_method, p_items, p_key)));
$$;

create function public.t_id(p_name text) returns uuid language sql as $$
  select case when value ~ '^[0-9a-f-]{36}$' then value::uuid end
  from public.t_ids where name = p_name
$$;

create function public.t_raw(p_name text) returns text language sql as $$
  select value from public.t_ids where name = p_name
$$;

-- 'total|discount|change' of a sale.
create function public.t_sale_row(p_name text) returns text language sql as $$
  select s.total_amount || '|' || s.discount_amount || '|' || s.change_amount
  from public.sales as s where s.id = public.t_id(p_name)
$$;

-- 'unit|original|percent|line discount|subtotal' of a sale's line(s) for a
-- product, in insertion order, joined by ';'.
create function public.t_line(p_name text, p_product uuid) returns text language sql as $$
  select string_agg(
    i.unit_price || '|' || i.original_unit_price || '|' || i.discount_percentage
      || '|' || i.discount_amount || '|' || i.subtotal,
    ';' order by i.subtotal, i.quantity)
  from public.sale_items as i
  where i.sale_id = public.t_id(p_name) and i.product_id = p_product
$$;

-- The owner updates shop A's configuration.
create function public.t_discount(
  p_enabled boolean, p_scope text, p_percentage numeric,
  p_ends_at timestamptz default null)
returns text language sql as $$
  select public.t_try('authenticated', '0000000a-0000-0000-0000-000000000001', format(
    'update public.shop_discount_settings set is_enabled = %L, scope = %L, percentage = %s, ends_at = %L',
    p_enabled, p_scope, p_percentage, p_ends_at))
$$;

create function public.t_stock(p_product uuid) returns integer language sql as $$
  select stock_quantity from public.products where id = p_product
$$;

create function public.items(variadic p_pairs text[]) returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object('product_id', p_pairs[i], 'quantity', p_pairs[i + 1]::integer)
                   order by i)
  from generate_series(1, array_length(p_pairs, 1), 2) as i
$$;

-- ===========================================================================
-- 15. Historical sales keep their values and get zero-discount snapshots
-- ===========================================================================
select public.t_check('15 history: every pre-migration line keeps its values',
  (select count(*) = (select count(*) from public.t_history_items)
          and bool_and(i.quantity = h.quantity and i.unit_price = h.unit_price
                       and i.cost_price = h.cost_price and i.subtotal = h.subtotal
                       and i.product_id = h.product_id and i.product_name = h.product_name)
   from public.sale_items as i join public.t_history_items as h on h.id = i.id));
select public.t_check('15 history: lines backfilled as no discount',
  (select bool_and(i.original_unit_price = i.unit_price
                   and i.discount_percentage = 0 and i.discount_amount = 0)
   from public.sale_items as i join public.t_history_items as h on h.id = i.id));
select public.t_check('15 history: sales keep totals, payments and change; discount 0',
  (select count(*) = 2
          and bool_and(s.total_amount = h.total_amount and s.amount_paid = h.amount_paid
                       and s.change_amount = h.change_amount
                       and s.payment_method = h.payment_method
                       and s.discount_amount = 0)
   from public.sales as s join public.t_history_sales as h on h.id = s.id));
select public.t_check('15 history: the pre-migration sales had the expected live totals',
  (select string_agg(total_amount::text, ',' order by total_amount) = '10.00,39.99'
   from public.t_history_sales));

-- ===========================================================================
-- 1. No configuration: normal price, zero discount, same result as before
-- ===========================================================================
select public.t_sale('none', :'oa', 'cash', 50.00, public.items(:'rice', '2', :'oil', '1'));
select public.t_check('1 no configuration: sale succeeds', public.t_id('none') is not null,
  public.t_raw('none'));
select public.t_check('1 no configuration: full price, discount 0, change as before',
  public.t_sale_row('none') = '39.99|0.00|10.01', public.t_sale_row('none'));
select public.t_check('1 no configuration: lines at full price with zero snapshots',
  public.t_line('none', :'rice') = '10.00|10.00|0.00|0.00|20.00'
  and public.t_line('none', :'oil') = '19.99|19.99|0.00|0.00|19.99',
  public.t_line('none', :'rice') || ' / ' || public.t_line('none', :'oil'));
select public.t_check('1 no configuration: identical to the same sale before the migration',
  (select (n.total_amount, n.amount_paid, n.change_amount, n.payment_method)
          = (h.total_amount, h.amount_paid, h.change_amount, h.payment_method)
   from public.sales as n, public.t_history_sales as h
   where n.id = public.t_id('none')
     and h.id = (select sale_id from public.t_history_ids where name = 'h1_cash'))
  and (select array_agg((product_id, quantity, unit_price, cost_price, subtotal) order by product_id)
       from public.sale_items where sale_id = public.t_id('none'))
    = (select array_agg((product_id, quantity, unit_price, cost_price, subtotal) order by product_id)
       from public.t_history_items
       where sale_id = (select sale_id from public.t_history_ids where name = 'h1_cash')));

-- ===========================================================================
-- Release gating: after this migration the API is read-only
-- ===========================================================================
-- Effective table privileges, one privilege per call (a list is true if ANY
-- of them is held).
select public.t_check('gate: ' || r.role || ' on ' || t.tbl || ' has exactly '
    || coalesce(case when r.role = 'anon' then null else t.expected end, 'nothing'),
  (select coalesce(string_agg(p.priv, ',' order by p.priv), 'nothing')
   from unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) as p(priv)
   where has_table_privilege(r.role, t.tbl, p.priv))
  = coalesce(case when r.role = 'anon' then null else t.expected end, 'nothing'))
from (values ('public.shop_discount_settings', 'SELECT'),
             ('public.shop_discount_products', 'SELECT')) as t(tbl, expected)
cross join (values ('anon'), ('authenticated'), ('service_role')) as r(role);

select public.t_check('gate: the owner cannot create a configuration through the API',
  public.t_is(public.t_try('authenticated', :'oa',
    'insert into public.shop_discount_settings (is_enabled, scope, percentage) values (true, ''all_products'', 10)'),
    '42501'));

-- A configuration written directly by the database operator (not an API
-- role), disabled.
-- (on conflict: if a broken grant let the owner's insert above through,
-- keep going so the remaining gate checks report it.)
insert into public.shop_discount_settings (shop_id, is_enabled, scope, percentage)
values (:'shop_a', false, 'all_products', 10)
on conflict (shop_id) do update
  set is_enabled = false, scope = 'all_products', percentage = 10, ends_at = null;

select public.t_check('gate: the owner cannot switch the configuration on',
  public.t_is(public.t_try('authenticated', :'oa',
    'update public.shop_discount_settings set is_enabled = true'), '42501'));
select public.t_check('gate: the owner cannot change the percentage or scope',
  public.t_is(public.t_try('authenticated', :'oa',
    'update public.shop_discount_settings set percentage = 50, scope = ''selected_products'''), '42501'));
select public.t_check('gate: the owner cannot delete the configuration',
  public.t_is(public.t_try('authenticated', :'oa', 'delete from public.shop_discount_settings'), '42501'));
select public.t_check('gate: the attendant cannot write either',
  public.t_is(public.t_try('authenticated', :'sa',
    'update public.shop_discount_settings set is_enabled = true'), '42501'));
select public.t_check('gate: service_role cannot create, change or delete a configuration',
  public.t_is(public.t_try('service_role', null, format(
    'insert into public.shop_discount_settings (shop_id, is_enabled, scope, percentage) values (%L, true, ''all_products'', 10)',
    :'shop_b')), '42501')
  and public.t_is(public.t_try('service_role', null,
    'update public.shop_discount_settings set is_enabled = true'), '42501')
  and public.t_is(public.t_try('service_role', null, 'delete from public.shop_discount_settings'), '42501'));
select public.t_check('gate: nobody can change the selected-products list through the API',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'insert into public.shop_discount_products (product_id) values (%L)', :'oil')), '42501')
  and public.t_is(public.t_try('authenticated', :'oa', 'delete from public.shop_discount_products'), '42501')
  and public.t_is(public.t_try('service_role', null, format(
    'insert into public.shop_discount_products (shop_id, product_id) values (%L, %L)', :'shop_a', :'oil')), '42501')
  and public.t_is(public.t_try('anon', null, 'delete from public.shop_discount_products'), '42501'));
select public.t_check('gate: the configuration is still off and unchanged',
  (select not is_enabled and scope = 'all_products' and percentage = 10
   from public.shop_discount_settings where shop_id = :'shop_a'::uuid)
  and (select count(*) = 1 from public.shop_discount_settings));
select public.t_check('gate: members of the shop can read it; another shop cannot',
  public.t_value('authenticated', :'oa', 'select count(*) from public.shop_discount_settings') = '1'
  and public.t_value('authenticated', :'sa', 'select count(*) from public.shop_discount_settings') = '1'
  and public.t_value('authenticated', :'ob', 'select count(*) from public.shop_discount_settings') = '0');
select public.t_sale('gate_sale', :'oa', 'cash', 10.00, public.items(:'rice', '1'));
select public.t_check('gate: sales keep their normal price',
  public.t_sale_row('gate_sale') = '10.00|0.00|0.00', public.t_raw('gate_sale'));
select public.t_check('gate: the owner-only write policies are in place for the later grant',
  (select string_agg(tablename || ':' || cmd, ',' order by tablename, cmd)
   from pg_policies where schemaname = 'public'
     and tablename in ('shop_discount_settings', 'shop_discount_products'))
  = 'shop_discount_products:DELETE,shop_discount_products:INSERT,shop_discount_products:SELECT,'
    'shop_discount_settings:INSERT,shop_discount_settings:SELECT,shop_discount_settings:UPDATE');

delete from public.shop_discount_settings;

-- ===========================================================================
-- Simulated release-gating migration (NOT part of 20261013090000): the
-- exact grants the migration header documents. Everything below tests the
-- owner-only policies as they will behave once those grants exist.
-- ===========================================================================
grant insert, update on table public.shop_discount_settings to authenticated;
grant insert, delete on table public.shop_discount_products to authenticated;

-- ===========================================================================
-- 13 / 14. Configuration: owner-only writes, member reads, shop isolation
-- ===========================================================================
insert into public.t_values values ('att_insert', public.t_try('authenticated', :'sa',
  'insert into public.shop_discount_settings (is_enabled, scope, percentage) values (true, ''all_products'', 50)'));
select public.t_check('13 attendant cannot create the configuration',
  public.t_is((select value from public.t_values where name = 'att_insert'), '42501'),
  (select value from public.t_values where name = 'att_insert'));

insert into public.t_values values ('a_into_b', public.t_try('authenticated', :'oa', format(
  'insert into public.shop_discount_settings (shop_id, is_enabled, scope, percentage) values (%L, true, ''all_products'', 50)',
  :'shop_b')));
select public.t_check('14 owner A cannot create a configuration for shop B',
  public.t_is((select value from public.t_values where name = 'a_into_b'), '42501'),
  (select value from public.t_values where name = 'a_into_b'));

-- Owner A creates shop A's configuration, disabled, and tries to forge the
-- audit fields.
insert into public.t_values values ('owner_insert', public.t_try('authenticated', :'oa', format(
  'insert into public.shop_discount_settings (is_enabled, scope, percentage, created_by, updated_by) values (false, ''all_products'', 10, %L, %L)',
  :'sa', :'sa')));
select public.t_check('13 owner creates the configuration',
  (select value from public.t_values where name = 'owner_insert') = 'ok',
  (select value from public.t_values where name = 'owner_insert'));
select public.t_check('audit: created_by / updated_by come from the session, not the client',
  (select created_by = :'oa'::uuid and updated_by = :'oa'::uuid and shop_id = :'shop_a'::uuid
   from public.shop_discount_settings));

-- Suspended members (current_shop_id() is null for them).
update public.shop_members set status = 'suspended' where user_id = :'sa';
select public.t_check('suspended attendant reads no configuration or selections',
  public.t_value('authenticated', :'sa', 'select count(*) from public.shop_discount_settings') = '0'
  and public.t_value('authenticated', :'sa', 'select count(*) from public.shop_discount_products') = '0');
update public.shop_members set status = 'active' where user_id = :'sa';
update public.shop_members set status = 'suspended' where user_id = :'oa';
select public.t_try('authenticated', :'oa', 'update public.shop_discount_settings set is_enabled = true, percentage = 50');
select public.t_check('suspended owner cannot change the configuration',
  (select not is_enabled and percentage = 10 from public.shop_discount_settings));
select public.t_check('suspended owner cannot select products',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'insert into public.shop_discount_products (product_id) values (%L)', :'oil')), '42501'));
update public.shop_members set status = 'active' where user_id = :'oa';

select public.t_check('one configuration per shop',
  public.t_is(public.t_try('authenticated', :'oa',
    'insert into public.shop_discount_settings (is_enabled, scope, percentage) values (true, ''all_products'', 20)'),
    '23505'));

select public.t_check('percentage must be above 0, below 100, at most two decimals; scope must be known',
  public.t_is(public.t_discount(true, 'all_products', 0), '23514')
  and public.t_is(public.t_discount(true, 'all_products', -5), '23514')
  and public.t_is(public.t_discount(true, 'all_products', 100), '23514')
  and public.t_is(public.t_discount(true, 'all_products', 10.555), '23514')
  and public.t_is(public.t_discount(true, 'everything', 10), '23514'));
select public.t_check('the boundary percentages 0.01 and 99.99 are accepted',
  public.t_discount(false, 'all_products', 0.01) = 'ok'
  and public.t_discount(false, 'all_products', 99.99) = 'ok'
  and public.t_discount(false, 'all_products', 10) = 'ok');
select public.t_check('rejected edits left the configuration unchanged',
  (select not is_enabled and scope = 'all_products' and percentage = 10
   from public.shop_discount_settings));

select public.t_check('13 attendant can read the configuration',
  public.t_value('authenticated', :'sa', 'select count(*) from public.shop_discount_settings') = '1');
select public.t_try('authenticated', :'sa',
  'update public.shop_discount_settings set is_enabled = true, percentage = 90');
select public.t_check('13 attendant update changes nothing',
  (select not is_enabled and percentage = 10 from public.shop_discount_settings));
select public.t_check('13 attendant and owner cannot delete the configuration',
  public.t_is(public.t_try('authenticated', :'sa', 'delete from public.shop_discount_settings'), '42501')
  and public.t_is(public.t_try('authenticated', :'oa', 'delete from public.shop_discount_settings'), '42501'));

select public.t_check('14 owner B cannot see shop A''s configuration',
  public.t_value('authenticated', :'ob', 'select count(*) from public.shop_discount_settings') = '0');
select public.t_try('authenticated', :'ob',
  'update public.shop_discount_settings set is_enabled = true, percentage = 90');
select public.t_check('14 owner B cannot change shop A''s configuration',
  (select not is_enabled and percentage = 10 from public.shop_discount_settings));
select public.t_check('anon cannot read either table',
  public.t_is(public.t_try('anon', null, 'select 1 from public.shop_discount_settings'), '42501')
  and public.t_is(public.t_try('anon', null, 'select 1 from public.shop_discount_products'), '42501'));

-- Product selections.
select public.t_check('13 attendant cannot select products',
  public.t_is(public.t_try('authenticated', :'sa', format(
    'insert into public.shop_discount_products (product_id) values (%L)', :'oil')), '42501'));
select public.t_check('14 owner B cannot select shop A''s product',
  public.t_is(public.t_try('authenticated', :'ob', format(
    'insert into public.shop_discount_products (product_id) values (%L)', :'oil')), '23503'));
select public.t_check('14 owner A cannot select shop B''s product',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'insert into public.shop_discount_products (product_id) values (%L)', :'b_rice')), '23503'));
select public.t_check('14 owner A cannot file a selection under shop B',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'insert into public.shop_discount_products (shop_id, product_id) values (%L, %L)',
    :'shop_b', :'oil')), '42501'));
select public.t_check('owner selects products',
  public.t_try('authenticated', :'oa', format(
    'insert into public.shop_discount_products (product_id) values (%L), (%L)', :'oil', :'unsold')) = 'ok');
select public.t_check('selections: same shop, stamped with the owner',
  (select count(*) = 2 and bool_and(shop_id = :'shop_a'::uuid and created_by = :'oa'::uuid)
   from public.shop_discount_products));
select public.t_try('authenticated', :'sa', 'delete from public.shop_discount_products');
select public.t_check('13 attendant cannot remove selections',
  (select count(*) = 2 from public.shop_discount_products));
select public.t_check('attendant can read selections; owner B cannot',
  public.t_value('authenticated', :'sa', 'select count(*) from public.shop_discount_products') = '2'
  and public.t_value('authenticated', :'ob', 'select count(*) from public.shop_discount_products') = '0');

-- ===========================================================================
-- 2 / 3. Disabled and expired configurations: normal pricing
-- ===========================================================================
select public.t_sale('disabled', :'oa', 'cash', 10.00, public.items(:'rice', '1'));
select public.t_check('2 disabled: full price, no discount',
  public.t_sale_row('disabled') = '10.00|0.00|0.00'
  and public.t_line('disabled', :'rice') = '10.00|10.00|0.00|0.00|10.00',
  coalesce(public.t_sale_row('disabled'), public.t_raw('disabled')));

select public.t_check('enable 10% on all products, ending yesterday',
  public.t_discount(true, 'all_products', 10, now() - interval '1 day') = 'ok');
select public.t_sale('expired', :'oa', 'cash', 10.00, public.items(:'rice', '1'));
select public.t_check('3 expired: full price, no discount',
  public.t_sale_row('expired') = '10.00|0.00|0.00'
  and public.t_line('expired', :'rice') = '10.00|10.00|0.00|0.00|10.00',
  coalesce(public.t_sale_row('expired'), public.t_raw('expired')));

-- ===========================================================================
-- 4 / 7 / 12. All products: price, rounding, totals, stock and movements
-- ===========================================================================
select public.t_check('enable 10% on all products, ending tomorrow',
  public.t_discount(true, 'all_products', 10, now() + interval '1 day') = 'ok');
select public.t_check('audit: updated_by is the owner after an update',
  (select updated_by = :'oa'::uuid from public.shop_discount_settings));

insert into public.t_values values
  ('rice_before', public.t_stock(:'rice')::text),
  ('oil_before', public.t_stock(:'oil')::text);
-- Extra fields in the items (a price, a percentage) must be ignored.
select public.t_sale('all', :'oa', 'cash', 40.00,
  '[{"product_id": "a0000000-0000-0000-0000-000000000001", "quantity": 2, "unit_price": 0.01, "discount_percentage": 90},
    {"product_id": "a0000000-0000-0000-0000-000000000002", "quantity": 1, "subtotal": 0}]'::jsonb);
select public.t_check('4 all products: Rice 10.00 -> 9.00 x2',
  public.t_line('all', :'rice') = '9.00|10.00|10.00|2.00|18.00', public.t_line('all', :'rice'));
select public.t_check('7 rounding: Oil 19.99 at 10% -> 1.999 rounds to 2.00 -> 17.99',
  public.t_line('all', :'oil') = '17.99|19.99|10.00|2.00|17.99', public.t_line('all', :'oil'));
select public.t_check('7 sale total, total discount and change',
  public.t_sale_row('all') = '35.99|4.00|4.01', public.t_sale_row('all'));
select public.t_check('client-sent price, percentage and subtotal are ignored',
  public.t_sale_row('all') = '35.99|4.00|4.01');
select public.t_check('12 stock reduced by the quantities sold',
  public.t_stock(:'rice') = (select value::integer - 2 from public.t_values where name = 'rice_before')
  and public.t_stock(:'oil') = (select value::integer - 1 from public.t_values where name = 'oil_before'));
select public.t_check('12 stock movements recorded as before',
  (select count(*) = 2
          and bool_and(m.movement_type = 'sale' and m.new_quantity = m.previous_quantity - m.quantity
                       and m.note = 'Stock reduced from sale ' || s.sale_number
                       and m.created_by = :'oa'::uuid and m.shop_id = :'shop_a'::uuid)
   from public.stock_movements as m join public.sales as s on s.id = m.reference_id
   where m.reference_id = public.t_id('all')));

select public.t_sale('repeat', :'oa', 'cash', 30.00, public.items(:'rice', '1', :'rice', '2'));
select public.t_check('the same product twice: each line discounted, total 27.00',
  public.t_line('repeat', :'rice') = '9.00|10.00|10.00|1.00|9.00;9.00|10.00|10.00|2.00|18.00'
  and public.t_sale_row('repeat') = '27.00|3.00|3.00',
  public.t_line('repeat', :'rice') || ' / ' || public.t_sale_row('repeat'));

select public.t_check('15% on all products', public.t_discount(true, 'all_products', 15) = 'ok');
select public.t_sale('round15', :'oa', 'cash', 5.00, public.items(:'sweet', '3', :'mint', '1'));
select public.t_check('7 rounding: Sweet 0.33 at 15% = 0.0495 -> 0.05 off -> 0.28 x3 = 0.84',
  public.t_line('round15', :'sweet') = '0.28|0.33|15.00|0.15|0.84', public.t_line('round15', :'sweet'));
select public.t_check('7 rounding: Mint 0.10 at 15% = 0.015 -> half up to 0.02 -> 0.08',
  public.t_line('round15', :'mint') = '0.08|0.10|15.00|0.02|0.08', public.t_line('round15', :'mint'));
select public.t_check('7 totals add up from the rounded lines',
  public.t_sale_row('round15') = '0.92|0.17|4.08', public.t_sale_row('round15'));

select public.t_check('12.5% on all products', public.t_discount(true, 'all_products', 12.5) = 'ok');
select public.t_sale('round125', :'oa', 'mobile_money', 2.19, public.items(:'soap', '1'));
select public.t_check('7 rounding: Soap 2.50 at 12.5% = 0.3125 -> 0.31 -> 2.19, exact payment',
  public.t_line('round125', :'soap') = '2.19|2.50|12.50|0.31|2.19'
  and public.t_sale_row('round125') = '2.19|0.31|0.00',
  coalesce(public.t_line('round125', :'soap'), public.t_raw('round125')));

-- ===========================================================================
-- 5 / 6. Selected products only
-- ===========================================================================
select public.t_check('10% on selected products (Oil, Never sold)',
  public.t_discount(true, 'selected_products', 10) = 'ok');
select public.t_sale('selected', :'oa', 'card', 27.99, public.items(:'rice', '1', :'oil', '1'));
select public.t_check('5 selected: Oil discounted',
  public.t_line('selected', :'oil') = '17.99|19.99|10.00|2.00|17.99', public.t_line('selected', :'oil'));
select public.t_check('6 selected: unselected Rice stays at full price',
  public.t_line('selected', :'rice') = '10.00|10.00|0.00|0.00|10.00', public.t_line('selected', :'rice'));
select public.t_check('5 selected: total 27.99, discount 2.00',
  public.t_sale_row('selected') = '27.99|2.00|0.00', public.t_sale_row('selected'));

select public.t_check('a deliberately loss-making product with no discount still sells',
  public.t_value('authenticated', :'oa', format(
    'select public.create_sale(null, ''cash'', 4.00, %L::jsonb) is not null',
    public.items(:'loss', '1'))) = 'true');

select public.t_check('switching to all products ignores the selection list',
  public.t_discount(true, 'all_products', 10) = 'ok');
select public.t_sale('all_again', :'oa', 'cash', 9.00, public.items(:'rice', '1'));
select public.t_check('all products again: unselected Rice discounted',
  public.t_line('all_again', :'rice') = '9.00|10.00|10.00|1.00|9.00', public.t_raw('all_again'));

select public.t_check('selected products with an empty selection discounts nothing',
  public.t_discount(true, 'selected_products', 10) = 'ok'
  and public.t_try('authenticated', :'oa', 'delete from public.shop_discount_products') = 'ok');
select public.t_sale('empty_selection', :'oa', 'cash', 19.99, public.items(:'oil', '1'));
select public.t_check('empty selection: Oil at full price',
  public.t_line('empty_selection', :'oil') = '19.99|19.99|0.00|0.00|19.99', public.t_raw('empty_selection'));

-- ===========================================================================
-- Boundary percentages in sales
-- ===========================================================================
select public.t_check('0.01% on all products', public.t_discount(true, 'all_products', 0.01) = 'ok');
select public.t_sale('pct_min', :'oa', 'cash', 10.10, public.items(:'rice', '1', :'mint', '1'));
select public.t_check('0.01%: discounts that round to 0.00 record no percentage and no discount',
  public.t_line('pct_min', :'rice') = '10.00|10.00|0.00|0.00|10.00'
  and public.t_line('pct_min', :'mint') = '0.10|0.10|0.00|0.00|0.10'
  and public.t_sale_row('pct_min') = '10.10|0.00|0.00',
  coalesce(public.t_line('pct_min', :'rice') || ' / ' || public.t_line('pct_min', :'mint'), public.t_raw('pct_min')));
select public.t_check('99.99% on all products', public.t_discount(true, 'all_products', 99.99) = 'ok');
select public.t_sale('pct_max', :'oa', 'cash', 10.00, public.items(:'rice', '1', :'mint', '1'));
select public.t_check('99.99%: Mint (cost 0.00) 0.10 -> 0.00; Rice would fall below cost, so full price',
  public.t_line('pct_max', :'mint') = '0.00|0.10|99.99|0.10|0.00'
  and public.t_line('pct_max', :'rice') = '10.00|10.00|0.00|0.00|10.00'
  and public.t_sale_row('pct_max') = '10.00|0.10|0.00',
  coalesce(public.t_line('pct_max', :'rice') || ' / ' || public.t_line('pct_max', :'mint'), public.t_raw('pct_max')));

-- ===========================================================================
-- 8. Below cost
-- ===========================================================================
-- all_products: an unsafe product is not eligible and sells at full price.
select public.t_check('10% on all products', public.t_discount(true, 'all_products', 10) = 'ok');
select public.t_sale('mixed', :'oa', 'cash', 20.00, public.items(:'rice', '1', :'sugar', '1'));
select public.t_check('8 all products: Sugar (6.30 < 6.80 cost) sells at full price, no discount',
  public.t_line('mixed', :'sugar') = '7.00|7.00|0.00|0.00|7.00',
  coalesce(public.t_line('mixed', :'sugar'), public.t_raw('mixed')));
select public.t_check('8 all products: Rice in the same cart is still discounted',
  public.t_line('mixed', :'rice') = '9.00|10.00|10.00|1.00|9.00', public.t_line('mixed', :'rice'));
select public.t_check('8 all products: the mixed cart reconciles (16.00 total, 1.00 discount, 4.00 change)',
  public.t_sale_row('mixed') = '16.00|1.00|4.00', public.t_sale_row('mixed'));
select public.t_sale('loss_all', :'oa', 'cash', 4.00, public.items(:'loss', '1'));
select public.t_check('8 all products: a product already below cost sells normally, undiscounted',
  public.t_line('loss_all', :'loss') = '4.00|4.00|0.00|0.00|4.00',
  coalesce(public.t_line('loss_all', :'loss'), public.t_raw('loss_all')));

-- selected_products: an unsafe selected product refuses the whole sale.
select public.t_check('10% on selected products: Rice and Sugar',
  public.t_discount(true, 'selected_products', 10) = 'ok'
  and public.t_try('authenticated', :'oa', format(
    'insert into public.shop_discount_products (product_id) values (%L), (%L)', :'rice', :'sugar')) = 'ok');
insert into public.t_values values
  ('sales_before_cost', (select count(*)::text from public.sales)),
  ('items_before_cost', (select count(*)::text from public.sale_items)),
  ('moves_before_cost', (select count(*)::text from public.stock_movements)),
  ('rice_before_cost', public.t_stock(:'rice')::text),
  ('sugar_before_cost', public.t_stock(:'sugar')::text);
select public.t_sale('below_cost', :'oa', 'cash', 50.00, public.items(:'rice', '1', :'sugar', '1'));
select public.t_check('8 selected: an unsafe selected product refuses the sale with SQLSTATE SMD01',
  public.t_is(public.t_raw('below_cost'), 'ERROR SMD01'), public.t_raw('below_cost'));
select public.t_check('8 selected: the message is generic (no product name, price or cost)',
  public.t_raw('below_cost') = 'ERROR SMD01: Discount cannot be applied to one or more products.'
  and substr(public.t_raw('below_cost'), 14) !~ '[0-9]'
  and position('Sugar' in public.t_raw('below_cost')) = 0,
  public.t_raw('below_cost'));
select public.t_check('8 selected: the whole sale rolled back (sale, lines, movements, stock)',
  (select count(*)::text from public.sales) = (select value from public.t_values where name = 'sales_before_cost')
  and (select count(*)::text from public.sale_items) = (select value from public.t_values where name = 'items_before_cost')
  and (select count(*)::text from public.stock_movements) = (select value from public.t_values where name = 'moves_before_cost')
  and public.t_stock(:'rice')::text = (select value from public.t_values where name = 'rice_before_cost')
  and public.t_stock(:'sugar')::text = (select value from public.t_values where name = 'sugar_before_cost'));
select public.t_sale('safe_selected', :'oa', 'cash', 9.00, public.items(:'rice', '1'));
select public.t_check('8 selected: a safe selected product alone still sells discounted',
  public.t_sale_row('safe_selected') = '9.00|1.00|0.00',
  coalesce(public.t_sale_row('safe_selected'), public.t_raw('safe_selected')));
\set k3 'e0000000-0000-0000-0000-0000000000c3'
insert into public.t_values values
  ('payments_before_cost', (select count(*)::text from public.customer_payments)),
  ('sales_before_credit_cost', (select count(*)::text from public.sales));
select public.t_credit('credit_unsafe', :'oa', :'customer', 0, null, public.items(:'sugar', '1'), :'k3');
select public.t_check('8 selected: a credit sale is refused the same way (SMD01), creating nothing',
  public.t_is(public.t_raw('credit_unsafe'), 'ERROR SMD01')
  and (select count(*)::text from public.sales) = (select value from public.t_values where name = 'sales_before_credit_cost')
  and (select count(*)::text from public.customer_payments) = (select value from public.t_values where name = 'payments_before_cost')
  and not exists (select 1 from public.credit_sale_idempotency where idempotency_key = :'k3'::uuid),
  public.t_raw('credit_unsafe'));
select public.t_check('8 selected: a discount on a selected loss-making product refuses the sale too',
  public.t_try('authenticated', :'oa', format(
    'insert into public.shop_discount_products (product_id) values (%L)', :'loss')) = 'ok'
  and public.t_is(public.t_value('authenticated', :'oa', format(
    'select public.create_sale(null, ''cash'', 4.00, %L::jsonb)', public.items(:'loss', '1'))), 'ERROR SMD01'));

-- A cost rise after the configuration was saved.
select public.t_check('10% on selected products: Oil only',
  public.t_try('authenticated', :'oa', 'delete from public.shop_discount_products') = 'ok'
  and public.t_try('authenticated', :'oa', format(
    'insert into public.shop_discount_products (product_id) values (%L)', :'oil')) = 'ok');
select public.t_sale('oil_safe', :'oa', 'cash', 17.99, public.items(:'oil', '1'));
select public.t_check('cost change: Oil (cost 5.00) is discounted while safe',
  public.t_sale_row('oil_safe') = '17.99|2.00|0.00',
  coalesce(public.t_sale_row('oil_safe'), public.t_raw('oil_safe')));
update public.products set cost_price = 18.50 where id = :'oil';
select public.t_check('cost change: Oil cost rises to 18.50, the selected discount now refuses the sale',
  public.t_is(public.t_value('authenticated', :'oa', format(
    'select public.create_sale(null, ''cash'', 19.99, %L::jsonb)', public.items(:'oil', '1'))), 'ERROR SMD01'));
select public.t_check('10% on all products', public.t_discount(true, 'all_products', 10) = 'ok');
select public.t_sale('oil_costly_all', :'oa', 'cash', 19.99, public.items(:'oil', '1'));
select public.t_check('cost change: with all products, Oil sells at full price instead',
  public.t_sale_row('oil_costly_all') = '19.99|0.00|0.00'
  and public.t_line('oil_costly_all', :'oil') = '19.99|19.99|0.00|0.00|19.99',
  coalesce(public.t_sale_row('oil_costly_all'), public.t_raw('oil_costly_all')));
update public.products set cost_price = 5.00 where id = :'oil';
select public.t_try('authenticated', :'oa', 'delete from public.shop_discount_products');

-- ===========================================================================
-- 9. Payment is checked against the discounted total
-- ===========================================================================
select public.t_sale('short', :'oa', 'cash', 8.99, public.items(:'rice', '1'));
select public.t_check('9 paying 8.99 for a 9.00 discounted total is rejected',
  public.t_raw('short') like 'ERROR P0001: Amount paid (8.99) is less than total amount (9.00)%',
  public.t_raw('short'));
select public.t_sale('exact', :'oa', 'bank_transfer', 9.00, public.items(:'rice', '1'));
select public.t_check('9 paying exactly the discounted 9.00 succeeds with no change',
  public.t_sale_row('exact') = '9.00|1.00|0.00', coalesce(public.t_sale_row('exact'), public.t_raw('exact')));

-- ===========================================================================
-- 10 / 11. Credit sales and their idempotency
-- ===========================================================================
\set k1 'e0000000-0000-0000-0000-0000000000c1'
\set k2 'e0000000-0000-0000-0000-0000000000c2'
select public.t_credit('credit', :'oa', :'customer', 18.00, 'cash', public.items(:'rice', '2'), :'k1');
select public.t_check('10 credit sale uses the discounted total (Rice x2 = 18.00)',
  public.t_sale_row('credit') = '18.00|2.00|0.00'
  and (select payment_method = 'credit' from public.sales where id = public.t_id('credit')),
  coalesce(public.t_sale_row('credit'), public.t_raw('credit')));
select public.t_check('10 initial payment allocated in full against the discounted total',
  (select sum(amount) = 18.00 from public.customer_payment_allocations
   where sale_id = public.t_id('credit')));

insert into public.t_values values ('sales_before_credit', (select count(*)::text from public.sales));
select public.t_credit('credit_over', :'oa', :'customer', 18.01, 'cash', public.items(:'rice', '2'), :'k2');
select public.t_check('10 initial payment above the discounted total is rejected',
  public.t_raw('credit_over') like 'ERROR P0001: Initial payment (18.01) exceeds sale total (18.00)%',
  public.t_raw('credit_over'));
select public.t_check('10 ... and creates nothing',
  (select count(*)::text from public.sales) = (select value from public.t_values where name = 'sales_before_credit'));

select public.t_check('20% on all products', public.t_discount(true, 'all_products', 20) = 'ok');
select public.t_credit('credit_retry', :'oa', :'customer', 18.00, 'cash', public.items(:'rice', '2'), :'k1');
select public.t_check('11 a retry with the same key returns the original sale, unchanged',
  public.t_id('credit_retry') = public.t_id('credit')
  and public.t_sale_row('credit') = '18.00|2.00|0.00'
  and (select count(*)::text from public.sales) = (select value from public.t_values where name = 'sales_before_credit'),
  public.t_raw('credit_retry'));
select public.t_credit('credit_mismatch', :'oa', :'customer', 18.00, 'cash', public.items(:'rice', '3'), :'k1');
select public.t_check('11 the same key with a different request is still refused',
  public.t_raw('credit_mismatch') like 'ERROR P0001: Idempotency key has already been used with a different credit-sale request%',
  public.t_raw('credit_mismatch'));

-- ===========================================================================
-- 14. Another shop's sales are unaffected
-- ===========================================================================
select public.t_sale('shop_b', :'ob', 'cash', 10.00, public.items(:'b_rice', '1'));
select public.t_check('14 shop B sells at full price while shop A has 20% on',
  public.t_sale_row('shop_b') = '10.00|0.00|0.00', coalesce(public.t_sale_row('shop_b'), public.t_raw('shop_b')));
select public.t_check('14 shop A still cannot sell shop B''s product',
  public.t_value('authenticated', :'oa', format(
    'select public.create_sale(null, ''cash'', 10, %L::jsonb)', public.items(:'b_rice', '1')))
  like 'ERROR P0001: Product % not found or inactive%');

-- ===========================================================================
-- 16. Dashboard profit uses the discounted line totals
-- ===========================================================================
select public.t_check('10% on all products', public.t_discount(true, 'all_products', 10) = 'ok');
insert into public.t_values values
  ('profit_before', public.t_value('authenticated', :'oa', 'select public.get_dashboard_summary()->>''today_profit''')),
  ('sales_before_dash', public.t_value('authenticated', :'oa', 'select public.get_dashboard_summary()->>''today_sales'''));
select public.t_sale('dash', :'oa', 'cash', 18.00, public.items(:'rice', '2'));
select public.t_check('16 today_profit rises by the discounted profit (18.00 - 2 x 6.00 = 6.00)',
  public.t_value('authenticated', :'oa', 'select public.get_dashboard_summary()->>''today_profit''')::numeric
    = (select value::numeric + 6.00 from public.t_values where name = 'profit_before'),
  public.t_value('authenticated', :'oa', 'select public.get_dashboard_summary()->>''today_profit''')
    || ' vs before ' || (select value from public.t_values where name = 'profit_before'));
select public.t_check('16 today_sales rises by the discounted total (18.00)',
  public.t_value('authenticated', :'oa', 'select public.get_dashboard_summary()->>''today_sales''')::numeric
    = (select value::numeric + 18.00 from public.t_values where name = 'sales_before_dash'));
select public.t_check('16 attendants still get no today_profit',
  public.t_value('authenticated', :'sa', 'select public.get_dashboard_summary() ? ''today_profit''') = 'false');

-- ===========================================================================
-- Deleting a selected product removes its selection
-- ===========================================================================
select public.t_try('authenticated', :'oa', format(
  'insert into public.shop_discount_products (product_id) values (%L)', :'unsold'));
select public.t_check('owner deletes a selected, never-sold product',
  public.t_try('authenticated', :'oa', format('delete from public.products where id = %L', :'unsold')) = 'ok');
select public.t_check('... and its selection row is gone',
  (select count(*) = 0 from public.shop_discount_products where product_id = :'unsold'::uuid));

-- ===========================================================================
-- Grants, function properties and constraints
-- ===========================================================================
select public.t_check('create_sale: one function, same signature, SECURITY DEFINER, search_path pinned',
  (select count(*) = 1 and bool_and(p.prosecdef
                                     and p.oid = 'public.create_sale(uuid, text, numeric, jsonb)'::regprocedure
                                     and p.proconfig = array['search_path=public, pg_temp'])
   from pg_proc as p where p.proname = 'create_sale' and p.pronamespace = 'public'::regnamespace));
select public.t_check('create_sale EXECUTE unchanged: authenticated and service_role, not anon or PUBLIC',
  has_function_privilege('authenticated', 'public.create_sale(uuid, text, numeric, jsonb)', 'execute')
  and has_function_privilege('service_role', 'public.create_sale(uuid, text, numeric, jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.create_sale(uuid, text, numeric, jsonb)', 'execute')
  and not has_function_privilege('public', 'public.create_sale(uuid, text, numeric, jsonb)', 'execute'));
select public.t_check('credit sale EXECUTE unchanged: authenticated, not anon',
  has_function_privilege('authenticated', 'public.create_credit_sale_with_initial_payment(uuid, numeric, text, jsonb, uuid)', 'execute')
  and not has_function_privilege('anon', 'public.create_credit_sale_with_initial_payment(uuid, numeric, text, jsonb, uuid)', 'execute'));
select public.t_check('get_dashboard_summary_internal still service_role only',
  not has_function_privilege('authenticated', 'public.get_dashboard_summary_internal()', 'execute')
  and not has_function_privilege('anon', 'public.get_dashboard_summary_internal()', 'execute')
  and has_function_privilege('service_role', 'public.get_dashboard_summary_internal()', 'execute'));
select public.t_check('new trigger functions are not executable by API roles',
  (select bool_and(not has_function_privilege('anon', p.oid, 'execute')
                   and not has_function_privilege('authenticated', p.oid, 'execute'))
   from pg_proc as p
   where p.pronamespace = 'public'::regnamespace
     and p.proname in ('stamp_shop_discount_settings', 'stamp_shop_discount_products',
                       'default_sale_item_original_price')));
-- (The migration's own grants are checked in the release-gating section
-- above; these are the grants once the later gating migration has run.)
select public.t_check('after the release gate: RLS on; anon nothing; authenticated only what the policies need',
  (select bool_and(relrowsecurity) from pg_class
   where oid in ('public.shop_discount_settings'::regclass, 'public.shop_discount_products'::regclass))
  and (select coalesce(string_agg(p.priv, ',' order by p.priv), 'nothing')
       from unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) as p(priv)
       where has_table_privilege('authenticated', 'public.shop_discount_settings', p.priv)) = 'INSERT,SELECT,UPDATE'
  and (select coalesce(string_agg(p.priv, ',' order by p.priv), 'nothing')
       from unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) as p(priv)
       where has_table_privilege('authenticated', 'public.shop_discount_products', p.priv)) = 'DELETE,INSERT,SELECT'
  and not has_table_privilege('anon', 'public.shop_discount_settings', 'select')
  and not has_table_privilege('anon', 'public.shop_discount_products', 'select'));
select public.t_check('sales and sale_items stay read-only for authenticated',
  not has_table_privilege('authenticated', 'public.sale_items', 'insert')
  and not has_table_privilege('authenticated', 'public.sale_items', 'update')
  and not has_table_privilege('authenticated', 'public.sales', 'update'));
select public.t_check('every sale line satisfies the discount consistency rule',
  (select bool_and(unit_price <= original_unit_price
                   and discount_amount = (original_unit_price - unit_price) * quantity
                   and subtotal = unit_price * quantity)
   from public.sale_items));
select public.t_check('every sale''s discount is the sum of its lines; total the sum of subtotals',
  (select bool_and(s.discount_amount = l.discount and s.total_amount = l.total)
   from public.sales as s
   join (select sale_id, sum(discount_amount) as discount, sum(subtotal) as total
         from public.sale_items group by sale_id) as l on l.sale_id = s.id));
select public.t_check('an inconsistent snapshot is rejected by the table',
  public.t_is(public.t_try('service_role', null, format(
    'update public.sale_items set discount_amount = 1.00 where sale_id = %L', public.t_id('none'))),
    '23514'));
select public.t_check('another writer of sale_items gets a zero-discount snapshot',
  public.t_try('service_role', null, format(
    'insert into public.sale_items (shop_id, sale_id, product_id, product_name, quantity, unit_price, cost_price, subtotal) '
    'values (%L, %L, %L, ''Rice 1kg'', 1, 10.00, 6.00, 10.00)',
    :'shop_a', public.t_id('none'), :'rice')) = 'ok'
  and (select bool_and(original_unit_price = 10.00 and discount_percentage = 0 and discount_amount = 0)
       from public.sale_items where sale_id = public.t_id('none') and product_name = 'Rice 1kg'));

\pset format aligned
select n, case when ok then 'PASS' else 'FAIL' end as result, name, coalesce(detail, '') as detail
from public.t_results order by n;
select count(*) filter (where ok) as passed, count(*) filter (where not ok) as failed
from public.t_results;

-- Any failure makes psql (and run.sh) exit non-zero; the transaction is
-- discarded either way.
do $$
begin
  if exists (select 1 from public.t_results where not ok) then
    raise exception 'discount tests failed';
  end if;
end;
$$;

rollback;
