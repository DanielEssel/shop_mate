-- save_discount_settings (20261016090000) checks. Every action runs in its
-- own statement and is verified in a later one. Everything below is rolled
-- back at the end.
\set ON_ERROR_STOP on

\set oa '0000000a-0000-0000-0000-000000000001'
\set sa '0000000a-0000-0000-0000-000000000002'
\set ob '0000000b-0000-0000-0000-000000000001'
\set shop_a 'aaaaaaaa-0000-0000-0000-000000000000'
\set shop_b 'bbbbbbbb-0000-0000-0000-000000000000'
\set rice 'a0000000-0000-0000-0000-000000000001'
\set oil 'a0000000-0000-0000-0000-000000000002'
\set sugar 'a0000000-0000-0000-0000-000000000003'
\set soap 'a0000000-0000-0000-0000-000000000005'
\set mint 'a0000000-0000-0000-0000-000000000007'
\set loss 'a0000000-0000-0000-0000-000000000008'
\set b_rice 'b0000000-0000-0000-0000-000000000001'
\set nowhere 'f0000000-0000-0000-0000-000000000000'

begin;

create table public.w_results (n serial, name text, ok boolean, detail text);
create table public.w_values (name text primary key, value text);
grant all on public.w_results, public.w_values to anon, authenticated, service_role;
grant usage on sequence public.w_results_n_seq to anon, authenticated, service_role;

-- Run p_sql as p_role with auth.uid() = p_uid; 'ok' or 'SQLSTATE: message'.
create function public.w_try(p_role text, p_uid text, p_sql text)
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

-- The first column of the first row as text (or 'ERROR SQLSTATE: ...').
create function public.w_value(p_role text, p_uid text, p_sql text)
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

create function public.w_check(p_name text, p_ok boolean, p_detail text default null)
returns void language sql as $$
  insert into public.w_results (name, ok, detail) values (p_name, coalesce(p_ok, false), p_detail);
$$;

create function public.w_is(p_state text, p_code text) returns boolean language sql as $$
  select p_state like p_code || '%'
$$;

-- save_discount_settings as p_uid (role authenticated unless given).
create function public.w_save(
  p_uid text, p_enabled boolean, p_scope text, p_percentage text,
  p_ends_at text, p_ids text, p_role text default 'authenticated')
returns text language sql as $$
  select public.w_try(p_role, p_uid, format(
    'select public.save_discount_settings(%L, %L, %s, %L::timestamptz, %L::uuid[])',
    p_enabled, p_scope, p_percentage, p_ends_at, p_ids));
$$;

-- 'enabled|scope|percentage|ends|ids' of a shop, as stored.
create function public.w_state(p_shop uuid) returns text language sql as $$
  select coalesce(
    (select s.is_enabled || '|' || s.scope || '|' || s.percentage || '|'
            || coalesce(to_char(s.ends_at at time zone 'UTC', 'YYYY-MM-DD HH24:MI'), '-') || '|'
            || coalesce((select string_agg(p.name, ',' order by p.name)
                         from public.shop_discount_products as d
                         join public.products as p on p.id = d.product_id
                         where d.shop_id = p_shop), '-')
     from public.shop_discount_settings as s where s.shop_id = p_shop),
    'none')
$$;

-- A one-line cash sale made with create_sale as p_uid; its id (or ERROR ...)
-- is kept under p_name and read in a later statement.
create function public.w_sale(p_name text, p_uid text, p_product uuid, p_paid numeric)
returns void language sql as $$
  insert into public.w_values values (p_name, public.w_value('authenticated', p_uid, format(
    'select public.create_sale(null, ''cash'', %s, %L::jsonb)::text',
    p_paid, jsonb_build_array(jsonb_build_object('product_id', p_product, 'quantity', 1)))));
$$;

-- 'total|discount' of a sale kept by w_sale.
create function public.w_sale_row(p_name text) returns text language sql as $$
  select coalesce(
    (select s.total_amount || '|' || s.discount_amount
     from public.sales as s
     where s.id::text = (select value from public.w_values where name = p_name)),
    (select value from public.w_values where name = p_name))
$$;

-- ===========================================================================
-- 1. Who may save
-- ===========================================================================
select public.w_check('starts with no configuration in either shop',
  public.w_state(:'shop_a') = 'none' and public.w_state(:'shop_b') = 'none');

select public.w_check('anon cannot run it',
  public.w_is(public.w_save(null, false, 'all_products', '10', null, '{}', 'anon'), '42501'));
select public.w_check('an unauthenticated request is refused (42501)',
  public.w_is(public.w_save(null, false, 'all_products', '10', null, '{}'), '42501'));
select public.w_check('the attendant is refused (42501)',
  public.w_is(public.w_save(:'sa', true, 'all_products', '10', null, '{}'), '42501'),
  public.w_save(:'sa', true, 'all_products', '10', null, '{}'));
select public.w_check('a signed-in user with no shop is refused (42501)',
  public.w_is(public.w_save('0000000c-0000-0000-0000-000000000001', true, 'all_products', '10', null, '{}'), '42501'));
select public.w_check('... and none of them wrote anything',
  public.w_state(:'shop_a') = 'none');

-- A suspended owner gets no shop and no role.
update public.shop_members set status = 'suspended' where user_id = :'oa'::uuid;
select public.w_check('a suspended owner is refused (42501)',
  public.w_is(public.w_save(:'oa', true, 'all_products', '10', null, '{}'), '42501'));
update public.shop_members set status = 'active' where user_id = :'oa'::uuid;

select public.w_check('the tables stay read-only: direct writes are refused, even for the owner',
  public.w_is(public.w_try('authenticated', :'oa',
    'insert into public.shop_discount_settings (is_enabled, scope, percentage) values (true, ''all_products'', 10)'), '42501')
  and public.w_is(public.w_try('authenticated', :'oa', format(
    'insert into public.shop_discount_products (product_id) values (%L)', :'rice')), '42501')
  and public.w_is(public.w_try('authenticated', :'sa',
    'update public.shop_discount_settings set is_enabled = true'), '42501')
  and public.w_is(public.w_try('authenticated', :'sa',
    'delete from public.shop_discount_products'), '42501'));

-- ===========================================================================
-- 2. The owner creates, updates, switches on and off
-- ===========================================================================
select public.w_check('owner creates a configuration (off, all products, 10%)',
  public.w_save(:'oa', false, 'all_products', '10', null, '{}') = 'ok');
select public.w_check('... stored exactly, stamped with the owner',
  public.w_state(:'shop_a') = 'false|all_products|10|-|-'
  and (select created_by = :'oa'::uuid and updated_by = :'oa'::uuid
       from public.shop_discount_settings where shop_id = :'shop_a'::uuid),
  public.w_state(:'shop_a'));
insert into public.w_values
select 'created', created_at::text from public.shop_discount_settings where shop_id = :'shop_a'::uuid;

select public.w_check('owner switches on 12.5% for selected products with an end date',
  public.w_save(:'oa', true, 'selected_products', '12.50', '2099-01-01 00:00:00+00',
    format('{%s,%s}', :'rice', :'oil')) = 'ok');
select public.w_check('... configuration and selection saved together',
  public.w_state(:'shop_a') = 'true|selected_products|12.50|2099-01-01 00:00|Oil 1L,Rice 1kg',
  public.w_state(:'shop_a'));
select public.w_check('... still one row; created_at and created_by kept',
  (select count(*) = 1 from public.shop_discount_settings where shop_id = :'shop_a'::uuid)
  and (select created_at::text = (select value from public.w_values where name = 'created')
              and created_by = :'oa'::uuid
       from public.shop_discount_settings where shop_id = :'shop_a'::uuid));

select public.w_check('the owner reads back what was saved',
  public.w_value('authenticated', :'oa',
    'select is_enabled || ''|'' || scope || ''|'' || percentage from public.shop_discount_settings') = 'true|selected_products|12.50'
  and public.w_value('authenticated', :'oa',
    'select string_agg(product_id::text, '','' order by product_id) from public.shop_discount_products')
    = :'rice' || ',' || :'oil');
select public.w_check('the attendant can read it (checkout prices) but not change it',
  public.w_value('authenticated', :'sa', 'select percentage::text from public.shop_discount_settings') = '12.50'
  and public.w_is(public.w_save(:'sa', false, 'selected_products', '12.50', null, '{}'), '42501')
  and public.w_state(:'shop_a') like 'true|selected_products|12.50|%');

select public.w_check('changing the selection removes and adds exactly (duplicates once)',
  public.w_save(:'oa', true, 'selected_products', '10', null,
    format('{%s,%s,%s}', :'oil', :'soap', :'soap')) = 'ok'
  and public.w_state(:'shop_a') = 'true|selected_products|10|-|Oil 1L,Soap',
  public.w_state(:'shop_a'));

select public.w_check('switching it off keeps the settings and selection',
  public.w_save(:'oa', false, 'selected_products', '10', null, format('{%s,%s}', :'oil', :'soap')) = 'ok'
  and public.w_state(:'shop_a') = 'false|selected_products|10|-|Oil 1L,Soap');

select public.w_check('all products keeps the selection the app shows; an empty list clears it',
  public.w_save(:'oa', true, 'all_products', '10', null, format('{%s}', :'oil')) = 'ok'
  and public.w_state(:'shop_a') = 'true|all_products|10|-|Oil 1L'
  and public.w_save(:'oa', true, 'all_products', '10', null, '{}') = 'ok'
  and public.w_state(:'shop_a') = 'true|all_products|10|-|-');

-- ===========================================================================
-- 3. Sales use what was saved; history does not change
-- ===========================================================================
select public.w_check('selected Rice at 10%: saved',
  public.w_save(:'oa', true, 'selected_products', '10', null, format('{%s}', :'rice')) = 'ok');
select public.w_sale('on', :'oa', :'rice', 9);
select public.w_sale('not_selected', :'sa', :'oil', 19.99);
select public.w_check('... create_sale charges 9.00 with 1.00 off',
  public.w_sale_row('on') = '9.00|1.00', public.w_sale_row('on'));
select public.w_check('... and an attendant''s sale of an unselected product is not discounted',
  public.w_sale_row('not_selected') = '19.99|0.00', public.w_sale_row('not_selected'));

select public.w_check('switched off: normal price',
  public.w_save(:'oa', false, 'selected_products', '10', null, format('{%s}', :'rice')) = 'ok');
select public.w_sale('off', :'sa', :'rice', 10);
select public.w_check('... an attendant''s sale: 10.00 with nothing off',
  public.w_sale_row('off') = '10.00|0.00', public.w_sale_row('off'));
select public.w_check('the earlier discounted sale and its line are unchanged',
  public.w_sale_row('on') = '9.00|1.00'
  and (select unit_price = 9.00 and original_unit_price = 10.00 and discount_percentage = 10
              and discount_amount = 1.00
       from public.sale_items
       where sale_id::text = (select value from public.w_values where name = 'on')));

-- ===========================================================================
-- 4. Other shops
-- ===========================================================================
select public.w_check('the function takes no shop id',
  (select pg_get_function_identity_arguments('public.save_discount_settings(boolean, text, numeric, timestamptz, uuid[])'::regprocedure))
  = 'p_is_enabled boolean, p_scope text, p_percentage numeric, p_ends_at timestamp with time zone, p_product_ids uuid[]');
insert into public.w_values values ('a_before', public.w_state(:'shop_a'));
select public.w_check('shop B''s owner cannot select shop A''s products (22023)',
  public.w_is(public.w_save(:'ob', true, 'selected_products', '10', null, format('{%s}', :'rice')), '22023'));
select public.w_check('shop A''s owner cannot select shop B''s product (22023)',
  public.w_is(public.w_save(:'oa', true, 'selected_products', '10', null, format('{%s}', :'b_rice')), '22023'));
select public.w_check('an unknown product is refused the same way (22023)',
  public.w_is(public.w_save(:'oa', true, 'selected_products', '10', null, format('{%s}', :'nowhere')), '22023'));
select public.w_check('shop B''s owner saving writes shop B only',
  public.w_save(:'ob', true, 'all_products', '25', null, format('{%s}', :'b_rice')) = 'ok'
  and public.w_state(:'shop_b') = 'true|all_products|25|-|B Rice'
  and public.w_state(:'shop_a') = (select value from public.w_values where name = 'a_before'));
select public.w_check('each owner reads only their own shop''s configuration',
  public.w_value('authenticated', :'ob', 'select string_agg(shop_id::text, '','') from public.shop_discount_settings') = :'shop_b'
  and public.w_value('authenticated', :'oa', 'select string_agg(shop_id::text, '','') from public.shop_discount_settings') = :'shop_a'
  and public.w_value('authenticated', :'ob', 'select count(*)::text from public.shop_discount_products') = '1');

-- ===========================================================================
-- 5. Validation (each refusal leaves the saved configuration as it was)
-- ===========================================================================
select public.w_check('percentage limits: 0, 100, 3 decimals and negative are refused (23514)',
  public.w_is(public.w_save(:'oa', true, 'all_products', '0', null, '{}'), '23514')
  and public.w_is(public.w_save(:'oa', true, 'all_products', '100', null, '{}'), '23514')
  and public.w_is(public.w_save(:'oa', true, 'all_products', '12.345', null, '{}'), '23514')
  and public.w_is(public.w_save(:'oa', true, 'all_products', '-5', null, '{}'), '23514'));
select public.w_check('the extremes 0.01 and 99.99 are accepted',
  public.w_save(:'oa', false, 'all_products', '0.01', null, '{}') = 'ok'
  and public.w_save(:'oa', false, 'all_products', '99.99', null, '{}') = 'ok');
select public.w_check('an unknown scope is refused (23514)',
  public.w_is(public.w_save(:'oa', true, 'some_products', '10', null, '{}'), '23514'));
select public.w_check('missing values or a null product id are refused (22023)',
  public.w_is(public.w_save(:'oa', null, 'all_products', '10', null, '{}'), '22023')
  and public.w_is(public.w_save(:'oa', true, null, '10', null, '{}'), '22023')
  and public.w_is(public.w_save(:'oa', true, 'all_products', 'null', null, '{}'), '22023')
  and public.w_is(public.w_save(:'oa', true, 'all_products', '10', null, null), '22023')
  and public.w_is(public.w_save(:'oa', true, 'selected_products', '10', null, format('{%s,NULL}', :'rice')), '22023'));
select public.w_check('switched on with an end in the past is refused (SMD04); switched off is allowed',
  public.w_is(public.w_save(:'oa', true, 'all_products', '10', '2020-01-01 00:00:00+00', '{}'), 'SMD04')
  and public.w_save(:'oa', false, 'all_products', '10', '2020-01-01 00:00:00+00', '{}') = 'ok');
select public.w_check('selected products switched on with none selected is refused (SMD03); switched off is allowed',
  public.w_is(public.w_save(:'oa', true, 'selected_products', '10', null, '{}'), 'SMD03')
  and public.w_save(:'oa', false, 'selected_products', '10', null, '{}') = 'ok');

-- Below cost, as create_sale computes it: Sugar 7.00 at 10% is 6.30 < 6.80;
-- the loss leader is already below cost; Mint 0.10 at 1% rounds to no
-- discount at all.
select public.w_check('a selected product that would go below cost is refused (SMD02), switched on or off',
  public.w_is(public.w_save(:'oa', true, 'selected_products', '10', null, format('{%s,%s}', :'rice', :'sugar')), 'SMD02')
  and public.w_is(public.w_save(:'oa', false, 'selected_products', '10', null, format('{%s}', :'loss')), 'SMD02'));
select public.w_check('... the SMD02 message names no product, price or cost',
  public.w_save(:'oa', true, 'selected_products', '10', null, format('{%s}', :'sugar'))
  = 'SMD02: Discount cannot be applied to one or more products.');
select public.w_check('... at 2% Sugar stays above cost and is accepted',
  public.w_save(:'oa', true, 'selected_products', '2', null, format('{%s}', :'sugar')) = 'ok');
select public.w_check('... a discount that rounds to nothing is not below cost',
  public.w_save(:'oa', true, 'selected_products', '1', null, format('{%s}', :'mint')) = 'ok');
select public.w_check('... all products may include below-cost products (they sell at normal price)',
  public.w_save(:'oa', true, 'all_products', '10', null, format('{%s,%s}', :'sugar', :'loss')) = 'ok');
update public.products set is_active = false where id = :'loss'::uuid;
select public.w_check('... an inactive selected product is not checked (it cannot be sold)',
  public.w_save(:'oa', true, 'selected_products', '10', null, format('{%s,%s}', :'rice', :'loss')) = 'ok');
update public.products set is_active = true where id = :'loss'::uuid;

-- A failing save is all or nothing.
select public.w_save(:'oa', true, 'selected_products', '10', null, format('{%s,%s}', :'rice', :'oil'));
insert into public.w_values values ('good', public.w_state(:'shop_a'));
select public.w_check('a refused save changes neither the settings nor the selection',
  public.w_is(public.w_save(:'oa', false, 'selected_products', '50', null, format('{%s,%s}', :'soap', :'sugar')), 'SMD02')
  and public.w_is(public.w_save(:'oa', false, 'all_products', '150', null, format('{%s}', :'soap')), '23514')
  and public.w_state(:'shop_a') = (select value from public.w_values where name = 'good'),
  public.w_state(:'shop_a'));

-- ===========================================================================
-- 6. Function, grants, and what did not change
-- ===========================================================================
select public.w_check('SECURITY DEFINER, search_path pinned, returns nothing',
  (select p.prosecdef and p.proconfig = array['search_path=public, pg_temp']
          and p.prorettype = 'void'::regtype
   from pg_proc as p
   where p.oid = 'public.save_discount_settings(boolean, text, numeric, timestamptz, uuid[])'::regprocedure));
select public.w_check('EXECUTE: authenticated only (not anon, PUBLIC or service_role)',
  has_function_privilege('authenticated', 'public.save_discount_settings(boolean, text, numeric, timestamptz, uuid[])', 'execute')
  and not has_function_privilege('anon', 'public.save_discount_settings(boolean, text, numeric, timestamptz, uuid[])', 'execute')
  and not has_function_privilege('service_role', 'public.save_discount_settings(boolean, text, numeric, timestamptz, uuid[])', 'execute')
  and not exists (
    select 1 from pg_proc as p, aclexplode(p.proacl) as a
    where p.oid = 'public.save_discount_settings(boolean, text, numeric, timestamptz, uuid[])'::regprocedure
      and a.grantee = 0));
select public.w_check('discount tables: SELECT only for authenticated and service_role, nothing for anon',
  (select string_agg(r.rolname || ':' || p.priv, ',' order by r.rolname, p.priv)
   from unnest(array['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER']) as p(priv),
        (values ('anon'), ('authenticated'), ('service_role')) as r(rolname),
        unnest(array['public.shop_discount_settings', 'public.shop_discount_products']) as t(name)
   where has_table_privilege(r.rolname, t.name, p.priv))
  = 'authenticated:SELECT,authenticated:SELECT,service_role:SELECT,service_role:SELECT');
select public.w_check('create_sale, the credit function, the helpers, triggers, tables, policies and grants are unchanged',
  (select count(*) = 10 from public.t_writes_before)
  and not exists (
    select object, fingerprint from public.t_writes_before
    except
    (select 'function ' || p.oid::regprocedure::text,
           md5(pg_get_functiondef(p.oid)) || '|' || coalesce(p.proacl::text, '')
    from pg_proc as p
    where p.pronamespace = 'public'::regnamespace
      and p.proname in ('create_sale', 'create_credit_sale_with_initial_payment',
                        'current_shop_id', 'current_shop_role',
                        'stamp_shop_discount_settings', 'stamp_shop_discount_products')
    union all
    select 'table ' || c.relname,
           md5(
             (select string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod)
                                || ':' || a.attnotnull, ',' order by a.attnum)
              from pg_attribute as a
              where a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped)
             || '|' || coalesce(c.relacl::text, '') || '|' || c.relrowsecurity
             || '|' || coalesce((select string_agg(pg_get_constraintdef(k.oid), ',' order by k.conname)
                                 from pg_constraint as k where k.conrelid = c.oid), '')
             || '|' || coalesce((select string_agg(pol.polname || ':' || pg_get_expr(pol.polqual, pol.polrelid, true)
                                                    || ':' || coalesce(pg_get_expr(pol.polwithcheck, pol.polrelid, true), ''),
                                                   ',' order by pol.polname)
                                 from pg_policy as pol where pol.polrelid = c.oid), '')
           )
    from pg_class as c
    where c.oid in ('public.shop_discount_settings'::regclass,
                    'public.shop_discount_products'::regclass,
                    'public.sales'::regclass,
                    'public.sale_items'::regclass))));

\pset format aligned
select n, case when ok then 'PASS' else 'FAIL' end as result, name, coalesce(detail, '') as detail
from public.w_results order by n;
select count(*) filter (where ok) as passed, count(*) filter (where not ok) as failed
from public.w_results;

do $$
begin
  if exists (select 1 from public.w_results where not ok) then
    raise exception 'discount write tests failed';
  end if;
end;
$$;

rollback;
