-- Fingerprints of the existing sale functions before the new migration, so
-- cases.sql can prove they were not changed.
\set ON_ERROR_STOP on

create table public.t_before as
select p.oid::regprocedure::text as signature,
       md5(pg_get_functiondef(p.oid)) as definition_md5,
       coalesce(p.proacl::text, '') as acl
from pg_proc as p
where p.pronamespace = 'public'::regnamespace
  and p.proname in ('create_sale', 'create_credit_sale_with_initial_payment');

create table public.t_before_tables as
select c.relname,
       md5(string_agg(a.attname || ':' || format_type(a.atttypid, a.atttypmod), ',' order by a.attnum)) as columns_md5
from pg_class as c
join pg_attribute as a on a.attrelid = c.oid and a.attnum > 0 and not a.attisdropped
where c.oid = 'public.credit_sale_idempotency'::regclass
group by c.relname;
