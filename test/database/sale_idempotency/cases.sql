-- Batch 4 (sale idempotency) checks. Every action runs in its own statement
-- and is verified in a later one. Everything below is rolled back at the
-- end. Two-session checks are in concurrency.sh.
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
\set b_rice 'b0000000-0000-0000-0000-000000000001'
\set customer 'c0000000-0000-0000-0000-00000000000a'
\set k1 '11111111-0000-4000-8000-000000000001'
\set k2 '11111111-0000-4000-8000-000000000002'
\set k3 '11111111-0000-4000-8000-000000000003'
\set k4 '11111111-0000-4000-8000-000000000004'
\set k6 '11111111-0000-4000-8000-000000000006'
\set k7 '11111111-0000-4000-8000-000000000007'
\set kc1 '22222222-0000-4000-8000-000000000001'
\set unknown '99999999-0000-4000-8000-000000000009'

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

create function public.items(variadic p_pairs text[]) returns jsonb language sql as $$
  select jsonb_agg(jsonb_build_object('product_id', p_pairs[i], 'quantity', p_pairs[i + 1]::integer)
                   order by i)
  from generate_series(1, array_length(p_pairs, 1), 2) as i
$$;

-- create_sale_idempotent as p_uid; keeps 'sale_id|replayed' or 'ERROR ...'.
create function public.t_idem(
  p_name text, p_uid text, p_key uuid, p_method text, p_paid numeric,
  p_items jsonb, p_customer uuid default null)
returns void language sql as $$
  insert into public.t_ids values (p_name, public.t_value('authenticated', p_uid, format(
    'select sale_id::text || ''|'' || replayed::text from public.create_sale_idempotent(%L, %L, %L, %s, %L::jsonb)',
    p_key, p_customer, p_method, p_paid, p_items)));
$$;

create function public.t_raw(p_name text) returns text language sql as $$
  select value from public.t_ids where name = p_name
$$;

create function public.t_sale(p_name text) returns uuid language sql as $$
  select case when value ~ '^[0-9a-f-]{36}\|' then split_part(value, '|', 1)::uuid end
  from public.t_ids where name = p_name
$$;

create function public.t_replayed(p_name text) returns text language sql as $$
  select split_part(value, '|', 2) from public.t_ids where name = p_name
$$;

-- 'sales|items|movements|rice stock|keys' for shop A.
create function public.t_counts() returns text language sql as $$
  select (select count(*) from public.sales where shop_id = 'aaaaaaaa-0000-0000-0000-000000000000')
    || '|' || (select count(*) from public.sale_items where shop_id = 'aaaaaaaa-0000-0000-0000-000000000000')
    || '|' || (select count(*) from public.stock_movements where shop_id = 'aaaaaaaa-0000-0000-0000-000000000000')
    || '|' || (select stock_quantity from public.products where id = 'a0000000-0000-0000-0000-000000000001')
    || '|' || (select count(*) from public.sale_idempotency where shop_id = 'aaaaaaaa-0000-0000-0000-000000000000')
$$;

create function public.t_remember(p_name text) returns void language sql as $$
  insert into public.t_values values (p_name, public.t_counts())
  on conflict (name) do update set value = excluded.value;
$$;

create function public.t_unchanged_since(p_name text) returns boolean language sql as $$
  select public.t_counts() = (select value from public.t_values where name = p_name)
$$;

-- ===========================================================================
-- First submission and replay
-- ===========================================================================
select public.t_remember('before_k1');
select public.t_idem('k1', :'oa', :'k1', 'cash', 30, public.items(:'rice', '1', :'oil', '1'));
select public.t_check('first submission records a sale (replayed = false)',
  public.t_sale('k1') is not null and public.t_replayed('k1') = 'false', public.t_raw('k1'));
select public.t_check('first submission: exactly one sale, its lines, movements, stock and key',
  public.t_counts() = (
    select split_part(value, '|', 1)::int + 1 || '|' || split_part(value, '|', 2)::int + 2
      || '|' || split_part(value, '|', 3)::int + 2 || '|' || split_part(value, '|', 4)::int - 1
      || '|' || split_part(value, '|', 5)::int + 1
    from public.t_values where name = 'before_k1'),
  public.t_counts());
select public.t_check('the recorded sale is priced by create_sale (10.00 + 19.99)',
  (select total_amount = 29.99 and change_amount = 0.01 and payment_method = 'cash'
   from public.sales where id = public.t_sale('k1')));
select public.t_check('the key row records the shop, the sale and the caller',
  (select shop_id = :'shop_a'::uuid and sale_id = public.t_sale('k1') and created_by = :'oa'::uuid
   from public.sale_idempotency where idempotency_key = :'k1'::uuid and shop_id = :'shop_a'::uuid));

select public.t_remember('after_k1');
select public.t_idem('k1_again', :'oa', :'k1', 'cash', 30, public.items(:'rice', '1', :'oil', '1'));
select public.t_check('same key, same request: the original sale, replayed = true',
  public.t_sale('k1_again') = public.t_sale('k1') and public.t_replayed('k1_again') = 'true',
  public.t_raw('k1_again'));
select public.t_check('a replay creates nothing (no sale, lines, movements, stock or key)',
  public.t_unchanged_since('after_k1'), public.t_counts());

select public.t_idem('k1_decimals', :'oa', :'k1', 'cash', 30.00, public.items(:'rice', '1', :'oil', '1'));
select public.t_check('amounts compare by value: 30 and 30.00 are the same request',
  public.t_sale('k1_decimals') = public.t_sale('k1') and public.t_replayed('k1_decimals') = 'true',
  public.t_raw('k1_decimals'));

-- Prices, the discount and stock all change after the original sale.
update public.products set selling_price = 12.00 where id = :'rice';
update public.products set stock_quantity = 0 where id = :'oil';
insert into public.shop_discount_settings (shop_id, is_enabled, scope, percentage)
values (:'shop_a', true, 'all_products', 50);
select public.t_idem('k1_changed', :'oa', :'k1', 'cash', 30, public.items(:'rice', '1', :'oil', '1'));
select public.t_check('a replay after price, discount and stock changes returns the original sale',
  public.t_sale('k1_changed') = public.t_sale('k1') and public.t_replayed('k1_changed') = 'true',
  public.t_raw('k1_changed'));
select public.t_check('... still unrepriced and without touching stock',
  (select total_amount = 29.99 and discount_amount = 0 from public.sales where id = public.t_sale('k1'))
  and (select stock_quantity = 0 from public.products where id = :'oil'));
update public.products set selling_price = 10.00 where id = :'rice';
update public.products set stock_quantity = 199 where id = :'oil';
delete from public.shop_discount_settings;

-- ===========================================================================
-- Same key, different request
-- ===========================================================================
select public.t_remember('before_conflicts');
select public.t_idem('c_customer', :'oa', :'k1', 'cash', 30, public.items(:'rice', '1', :'oil', '1'), :'customer');
select public.t_idem('c_method', :'oa', :'k1', 'card', 30, public.items(:'rice', '1', :'oil', '1'));
select public.t_idem('c_amount', :'oa', :'k1', 'cash', 31, public.items(:'rice', '1', :'oil', '1'));
select public.t_idem('c_product', :'oa', :'k1', 'cash', 30, public.items(:'rice', '1', :'sweet', '1'));
select public.t_idem('c_quantity', :'oa', :'k1', 'cash', 30, public.items(:'rice', '2', :'oil', '1'));
select public.t_idem('c_order', :'oa', :'k1', 'cash', 30, public.items(:'oil', '1', :'rice', '1'));
select public.t_check('a changed customer, method, amount, product, quantity or item order is refused with SMI01',
  (select bool_and(public.t_is(public.t_raw(n), 'ERROR SMI01'))
   from unnest(array['c_customer', 'c_method', 'c_amount', 'c_product', 'c_quantity', 'c_order']) as n),
  (select string_agg(n || '=' || coalesce(public.t_raw(n), 'null'), '; ')
   from unnest(array['c_customer', 'c_method', 'c_amount', 'c_product', 'c_quantity', 'c_order']) as n));
select public.t_check('SMI01 says nothing about the original request',
  public.t_raw('c_amount') = 'ERROR SMI01: This request key was already used for a different sale');
select public.t_check('refused conflicts create nothing',
  public.t_unchanged_since('before_conflicts'), public.t_counts());

-- ===========================================================================
-- A sale that fails leaves no key behind
-- ===========================================================================
select public.t_remember('before_failures');
select public.t_idem('k2_short', :'oa', :'k2', 'cash', 1, public.items(:'rice', '1'));
select public.t_idem('k3_stock', :'oa', :'k3', 'cash', 100000, public.items(:'rice', '100000'));
-- An unsafe selected-products discount (Sugar 7.00 at 10% is below 6.80).
insert into public.shop_discount_settings (shop_id, is_enabled, scope, percentage)
values (:'shop_a', true, 'selected_products', 10);
insert into public.shop_discount_products (shop_id, product_id) values (:'shop_a', :'sugar');
select public.t_idem('k4_smd01', :'oa', :'k4', 'cash', 10, public.items(:'sugar', '1'));
delete from public.shop_discount_products;
delete from public.shop_discount_settings;
select public.t_check('underpayment, missing stock and SMD01 are refused as before',
  public.t_raw('k2_short') like 'ERROR P0001: Amount paid (1) is less than total amount (10.00)%'
  and public.t_raw('k3_stock') like 'ERROR P0001: Insufficient stock for Rice 1kg%'
  and public.t_is(public.t_raw('k4_smd01'), 'ERROR SMD01'),
  public.t_raw('k2_short') || ' / ' || public.t_raw('k3_stock') || ' / ' || public.t_raw('k4_smd01'));
select public.t_check('failed sales leave no sale, line, movement, stock change or key',
  public.t_unchanged_since('before_failures')
  and not exists (select 1 from public.sale_idempotency
                  where idempotency_key in (:'k2'::uuid, :'k3'::uuid, :'k4'::uuid)),
  public.t_counts());
select public.t_idem('k2_fixed', :'oa', :'k2', 'cash', 10, public.items(:'rice', '1'));
select public.t_check('the same key can then record the corrected sale',
  public.t_sale('k2_fixed') is not null and public.t_replayed('k2_fixed') = 'false', public.t_raw('k2_fixed'));

-- The key row cannot be written: the whole sale must roll back.
create function public.t_refuse_key() returns trigger language plpgsql as $$
begin
  raise exception 'simulated key insert failure' using errcode = 'XX001';
end;
$$;
create trigger t_refuse_key before insert on public.sale_idempotency
  for each row execute function public.t_refuse_key();
select public.t_remember('before_rollback');
select public.t_idem('k7_rollback', :'oa', :'k7', 'cash', 10, public.items(:'rice', '1'));
drop trigger t_refuse_key on public.sale_idempotency;
select public.t_check('if the key cannot be saved, the sale and its stock changes roll back too',
  public.t_is(public.t_raw('k7_rollback'), 'ERROR XX001') and public.t_unchanged_since('before_rollback'),
  public.t_raw('k7_rollback') || ' / ' || public.t_counts());
select public.t_idem('k7_after', :'oa', :'k7', 'cash', 10, public.items(:'rice', '1'));
select public.t_check('... and the key is still free afterwards',
  public.t_replayed('k7_after') = 'false', public.t_raw('k7_after'));

-- ===========================================================================
-- Input, scope and permissions
-- ===========================================================================
select public.t_idem('credit_method', :'oa', :'k6', 'credit', 0, public.items(:'rice', '1'), :'customer');
select public.t_check('the credit method is refused (credit has its own function)',
  public.t_is(public.t_raw('credit_method'), 'ERROR 22023'), public.t_raw('credit_method'));
select public.t_check('a missing key is refused',
  public.t_value('authenticated', :'oa', format(
    'select sale_id from public.create_sale_idempotent(null, null, ''cash'', 10, %L::jsonb)',
    public.items(:'rice', '1'))) like 'ERROR 22023%');
select public.t_check('an unauthenticated caller is refused',
  public.t_value('authenticated', null, format(
    'select sale_id from public.create_sale_idempotent(%L, null, ''cash'', 10, %L::jsonb)',
    :'k6', public.items(:'rice', '1'))) like 'ERROR 42501: Authentication is required%');

select public.t_idem('k6_staff', :'sa', :'k6', 'cash', 10, public.items(:'rice', '1'));
select public.t_idem('k6_staff_again', :'sa', :'k6', 'cash', 10, public.items(:'rice', '1'));
select public.t_check('attendants record and replay sales the same way',
  public.t_replayed('k6_staff') = 'false' and public.t_replayed('k6_staff_again') = 'true'
  and public.t_sale('k6_staff') = public.t_sale('k6_staff_again'));

select public.t_idem('k1_shop_b', :'ob', :'k1', 'cash', 10, public.items(:'b_rice', '1'));
select public.t_check('keys are per shop: shop B''s k1 is a new sale in shop B',
  public.t_replayed('k1_shop_b') = 'false'
  and (select shop_id = :'shop_b'::uuid from public.sales where id = public.t_sale('k1_shop_b'))
  and public.t_sale('k1_shop_b') <> public.t_sale('k1'),
  public.t_raw('k1_shop_b'));
select public.t_check('shop B cannot sell shop A''s products under a new key',
  public.t_value('authenticated', :'ob', format(
    'select sale_id from public.create_sale_idempotent(%L, null, ''cash'', 10, %L::jsonb)',
    :'unknown', public.items(:'rice', '1'))) like 'ERROR P0001: Product % not found or inactive%');

select public.t_check('anon cannot run either new function',
  public.t_is(public.t_try('anon', null, format(
    'select * from public.create_sale_idempotent(%L, null, ''cash'', 10, %L::jsonb)',
    :'k6', public.items(:'rice', '1'))), '42501')
  and public.t_is(public.t_try('anon', null, format(
    'select public.find_sale_by_idempotency_key(%L)', :'k1')), '42501'));
select public.t_check('no API role can read or write either idempotency table',
  public.t_is(public.t_try('authenticated', :'oa', 'select 1 from public.sale_idempotency'), '42501')
  and public.t_is(public.t_try('authenticated', :'oa', 'select 1 from public.credit_sale_idempotency'), '42501')
  and public.t_is(public.t_try('anon', null, 'select 1 from public.sale_idempotency'), '42501')
  and public.t_is(public.t_try('authenticated', :'oa', format(
    'insert into public.sale_idempotency (shop_id, idempotency_key, request_fingerprint, sale_id) values (%L, %L, ''{}'', %L)',
    :'shop_a', :'unknown', public.t_sale('k1'))), '42501')
  and public.t_is(public.t_try('authenticated', :'oa', 'delete from public.sale_idempotency'), '42501'));
select public.t_check('sale_idempotency: RLS on, no policies',
  (select relrowsecurity from pg_class where oid = 'public.sale_idempotency'::regclass)
  and not exists (select 1 from pg_policies where tablename = 'sale_idempotency'));
select public.t_check('both functions: SECURITY DEFINER, search_path pinned, authenticated and service_role only',
  (select bool_and(p.prosecdef and p.proconfig = array['search_path=public, pg_temp']
                   and has_function_privilege('authenticated', p.oid, 'execute')
                   and has_function_privilege('service_role', p.oid, 'execute')
                   and not has_function_privilege('anon', p.oid, 'execute')
                   and not has_function_privilege('public', p.oid, 'execute'))
   from pg_proc as p
   where p.pronamespace = 'public'::regnamespace
     and p.proname in ('create_sale_idempotent', 'find_sale_by_idempotency_key')));

-- ===========================================================================
-- Existing functions are untouched and still work
-- ===========================================================================
select public.t_check('create_sale and the credit function are byte-for-byte unchanged (definition and grants)',
  (select bool_and(b.definition_md5 = md5(pg_get_functiondef(p.oid))
                   and b.acl = coalesce(p.proacl::text, ''))
   from public.t_before as b
   join pg_proc as p on p.oid::regprocedure::text = b.signature)
  and (select count(*) = 2 from public.t_before));
select public.t_check('credit_sale_idempotency is unchanged',
  (select b.columns_md5 = md5(string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' order by a.attnum))
   from public.t_before_tables as b
   join pg_attribute as a on a.attrelid = 'public.credit_sale_idempotency'::regclass
     and a.attnum > 0 and not a.attisdropped
   group by b.columns_md5));
select public.t_check('create_sale is still callable directly (older app builds)',
  public.t_value('authenticated', :'oa', format(
    'select public.create_sale(null, ''cash'', 10, %L::jsonb) is not null',
    public.items(:'rice', '1'))) = 'true');

insert into public.t_ids values ('kc1', public.t_value('authenticated', :'oa', format(
  'select public.create_credit_sale_with_initial_payment(%L, 0, null, %L::jsonb, %L)::text',
  :'customer', public.items(:'rice', '1'), :'kc1')));
insert into public.t_ids values ('kc1_again', public.t_value('authenticated', :'oa', format(
  'select public.create_credit_sale_with_initial_payment(%L, 0, null, %L::jsonb, %L)::text',
  :'customer', public.items(:'rice', '1'), :'kc1')));
insert into public.t_ids values ('kc1_other', public.t_value('authenticated', :'oa', format(
  'select public.create_credit_sale_with_initial_payment(%L, 0, null, %L::jsonb, %L)::text',
  :'customer', public.items(:'rice', '2'), :'kc1')));
select public.t_check('credit sales keep their own idempotency, unchanged',
  public.t_raw('kc1') ~ '^[0-9a-f-]{36}$'
  and public.t_raw('kc1_again') = public.t_raw('kc1')
  and public.t_raw('kc1_other') like 'ERROR P0001: Idempotency key has already been used with a different credit-sale request%',
  public.t_raw('kc1') || ' / ' || public.t_raw('kc1_again') || ' / ' || public.t_raw('kc1_other'));

-- ===========================================================================
-- Recovery lookup
-- ===========================================================================
select public.t_check('lookup finds a non-credit sale by its key',
  public.t_value('authenticated', :'oa', format(
    'select public.find_sale_by_idempotency_key(%L)::text', :'k1')) = public.t_sale('k1')::text);
select public.t_check('lookup finds a credit sale by its key',
  public.t_value('authenticated', :'oa', format(
    'select public.find_sale_by_idempotency_key(%L)::text', :'kc1')) = public.t_raw('kc1'));
select public.t_check('lookup of an unknown key or a failed sale''s key is null',
  public.t_value('authenticated', :'oa', format(
    'select coalesce(public.find_sale_by_idempotency_key(%L)::text, ''null'')', :'unknown')) = 'null'
  and public.t_value('authenticated', :'oa', format(
    'select coalesce(public.find_sale_by_idempotency_key(%L)::text, ''null'')', :'k4')) = 'null');
select public.t_check('lookup is per shop: shop B''s k1 is shop B''s own sale',
  public.t_value('authenticated', :'ob', format(
    'select public.find_sale_by_idempotency_key(%L)::text', :'k1')) = public.t_sale('k1_shop_b')::text
  and public.t_value('authenticated', :'ob', format(
    'select coalesce(public.find_sale_by_idempotency_key(%L)::text, ''null'')', :'kc1')) = 'null');
select public.t_check('attendants can look up; unauthenticated callers cannot',
  public.t_value('authenticated', :'sa', format(
    'select public.find_sale_by_idempotency_key(%L)::text', :'k1')) = public.t_sale('k1')::text
  and public.t_value('authenticated', null, format(
    'select public.find_sale_by_idempotency_key(%L)', :'k1')) like 'ERROR 42501%');
select public.t_remember('before_lookup');
select public.t_try('authenticated', :'oa', format(
  'select public.find_sale_by_idempotency_key(%L)', :'unknown'));
select public.t_check('lookup changes nothing',
  public.t_unchanged_since('before_lookup'));

\pset format aligned
select n, case when ok then 'PASS' else 'FAIL' end as result, name, coalesce(detail, '') as detail
from public.t_results order by n;
select count(*) filter (where ok) as passed, count(*) filter (where not ok) as failed
from public.t_results;

do $$
begin
  if exists (select 1 from public.t_results where not ok) then
    raise exception 'sale idempotency tests failed';
  end if;
end;
$$;

rollback;
