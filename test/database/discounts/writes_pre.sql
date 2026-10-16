-- Fingerprints taken before 20261016090000_discount_settings_writes.sql, so
-- writes.sql can prove it changed none of the existing functions, tables,
-- policies or grants.
\set ON_ERROR_STOP on

create table public.t_writes_before as
select 'function ' || p.oid::regprocedure::text as object,
       md5(pg_get_functiondef(p.oid)) || '|' || coalesce(p.proacl::text, '') as fingerprint
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
                'public.sale_items'::regclass);
