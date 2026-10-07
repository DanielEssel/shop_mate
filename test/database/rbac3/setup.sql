-- Throwaway stand-in for the live schema RBAC-3A builds on: Supabase roles,
-- auth.users, shops, shop_members (live definition, policies and grants) and
-- two history tables with the live foreign-key behaviour.
\set ON_ERROR_STOP on

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
grant usage on schema public to anon, authenticated, service_role;

create schema auth;
grant usage on schema auth to anon, authenticated, service_role;
create table auth.users (
  id uuid primary key,
  email varchar(255),
  email_confirmed_at timestamptz,
  raw_user_meta_data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create function auth.uid() returns uuid language sql stable
as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- Supabase's defaults: API roles get everything on new objects; RLS and the
-- migration's own revokes are what limit them.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  status text not null default 'pending'
    check (status = any (array['pending', 'active', 'suspended'])),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.shop_members (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  user_id uuid not null unique references auth.users (id) on delete cascade,
  role text not null default 'staff' check (role = any (array['owner', 'staff'])),
  status text not null default 'active' check (status = any (array['active', 'suspended'])),
  created_at timestamptz not null default now()
);

create function public.current_shop_id() returns uuid
language sql stable security definer set search_path to 'public'
as $$
  select m.shop_id from public.shop_members m
  join public.shops s on s.id = m.shop_id
  where m.user_id = auth.uid() and m.status = 'active' and s.status = 'active'
  limit 1;
$$;
create function public.current_shop_role() returns text
language sql stable security definer set search_path to 'public'
as $$
  select m.role from public.shop_members m
  join public.shops s on s.id = m.shop_id
  where m.user_id = auth.uid() and m.status = 'active' and s.status = 'active'
  limit 1;
$$;

alter table public.shops enable row level security;
alter table public.shop_members enable row level security;
create policy "Members can view their shop" on public.shops for select to authenticated
  using (id in (select m.shop_id from public.shop_members m where m.user_id = auth.uid()));
create policy "Users can view their own membership" on public.shop_members for select
  to authenticated using (user_id = auth.uid());
create policy "Owners can view their shop members" on public.shop_members for select
  to authenticated
  using (shop_id = public.current_shop_id() and public.current_shop_role() = 'owner');
-- Live grant: SELECT only.
revoke all on public.shop_members from anon, authenticated;
grant select on public.shop_members to authenticated;

-- History with the live FK behaviour: sales block deleting their creator,
-- purchases null it out.
create table public.sales (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id),
  total_amount numeric not null,
  created_by uuid references auth.users (id)
);
create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id),
  total_amount numeric not null,
  created_by uuid references auth.users (id) on delete set null
);

-- Fixtures: shop A (owner, two staff, one suspended staff), shop B (owner,
-- staff), a pending shop P (owner), a user with no shop, and a second owner
-- row added to shop A by hand to test owner protection.
insert into auth.users (id, email, email_confirmed_at, raw_user_meta_data, created_at) values
  ('0000000a-0000-0000-0000-000000000001', 'owner.a@test', now(), '{}', now() - interval '30 days'),
  ('0000000a-0000-0000-0000-000000000002', 'staff.a@test', now(), '{"display_name": "Ama Staff"}', now() - interval '20 days'),
  ('0000000a-0000-0000-0000-000000000003', 'staff2.a@test', now(), '{"display_name": "Kofi"}', now() - interval '20 days'),
  ('0000000a-0000-0000-0000-000000000004', 'coowner.a@test', now(), '{}', now() - interval '20 days'),
  ('0000000b-0000-0000-0000-000000000001', 'owner.b@test', now(), '{}', now() - interval '30 days'),
  ('0000000b-0000-0000-0000-000000000002', 'staff.b@test', now(), '{}', now() - interval '20 days'),
  ('0000000c-0000-0000-0000-000000000001', 'owner.p@test', now(), '{}', now() - interval '5 days'),
  ('0000000d-0000-0000-0000-000000000001', 'nobody@test', now(), '{}', now() - interval '5 days');

insert into public.shops (id, name, status) values
  ('aaaaaaaa-0000-0000-0000-000000000000', 'Shop A', 'active'),
  ('bbbbbbbb-0000-0000-0000-000000000000', 'Shop B', 'active'),
  ('cccccccc-0000-0000-0000-000000000000', 'Shop P', 'pending');

insert into public.shop_members (shop_id, user_id, role, status, created_at) values
  ('aaaaaaaa-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000001', 'owner', 'active', now() - interval '30 days'),
  ('aaaaaaaa-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000002', 'staff', 'active', now() - interval '20 days'),
  ('aaaaaaaa-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000003', 'staff', 'active', now() - interval '19 days'),
  ('aaaaaaaa-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000004', 'owner', 'active', now() - interval '18 days'),
  ('bbbbbbbb-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000001', 'owner', 'active', now() - interval '30 days'),
  ('bbbbbbbb-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000002', 'staff', 'active', now() - interval '20 days'),
  ('cccccccc-0000-0000-0000-000000000000', '0000000c-0000-0000-0000-000000000001', 'owner', 'active', now() - interval '5 days');

-- Staff A has history.
insert into public.sales (shop_id, total_amount, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000000', 25, '0000000a-0000-0000-0000-000000000002');
insert into public.purchases (shop_id, total_amount, created_by) values
  ('aaaaaaaa-0000-0000-0000-000000000000', 40, '0000000a-0000-0000-0000-000000000002');
