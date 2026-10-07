-- Throwaway stand-in for the live ShopMate schema (from the RBAC-0 live results).
\set ON_ERROR_STOP on

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
grant usage on schema public to anon, authenticated, service_role;

create schema auth;
grant usage on schema auth to anon, authenticated, service_role;
create table auth.users (id uuid primary key, email text, email_confirmed_at timestamptz);
create function auth.uid() returns uuid language sql stable
as $$ select nullif(current_setting('test.uid', true), '')::uuid $$;
grant execute on function auth.uid() to anon, authenticated, service_role;

-- Supabase's defaults: every API role gets everything on new tables/functions.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;

create table public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text,
  status text not null default 'pending'
    check (status = any (array['pending', 'active', 'suspended'])),
  created_by uuid references auth.users (id) on delete set null,
  approved_at timestamptz,
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

-- Live helper bodies.
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

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text not null default '',
  sku text,
  barcode text,
  description text,
  cost_price numeric not null default 0 check (cost_price >= 0),
  selling_price numeric not null default 0 check (selling_price >= 0),
  stock_quantity integer not null default 0 check (stock_quantity >= 0),
  low_stock_threshold integer not null default 10 check (low_stock_threshold >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  image_url text,
  shop_id uuid not null default public.current_shop_id() references public.shops (id),
  category_id uuid
);

create table public.customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text, email text, address text, notes text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  shop_id uuid not null default public.current_shop_id() references public.shops (id)
);

create table public.purchases (
  id uuid primary key default gen_random_uuid(),
  purchase_number text not null,
  supplier_name text, supplier_phone text,
  total_amount numeric not null default 0 check (total_amount >= 0),
  amount_paid numeric not null default 0 check (amount_paid >= 0),
  balance numeric not null default 0 check (balance >= 0),
  payment_method text not null default 'cash',
  status text not null default 'completed' check (status = any (array['completed', 'cancelled'])),
  purchase_date date not null default current_date,
  notes text,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  shop_id uuid not null default public.current_shop_id() references public.shops (id),
  unique (shop_id, purchase_number)
);

create table public.purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.purchases (id) on delete cascade,
  product_id uuid not null references public.products (id) on delete restrict,
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_cost numeric not null check (unit_cost >= 0),
  subtotal numeric not null check (subtotal >= 0),
  created_at timestamptz not null default now(),
  shop_id uuid not null default public.current_shop_id() references public.shops (id)
);

create table public.sales (
  id uuid primary key default gen_random_uuid(),
  sale_number text not null,
  total_amount numeric not null default 0,
  payment_method text not null default 'cash',
  amount_paid numeric not null default 0,
  change_amount numeric not null default 0,
  created_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  customer_id uuid references public.customers (id) on delete set null,
  shop_id uuid not null default public.current_shop_id() references public.shops (id),
  unique (shop_id, sale_number)
);

create table public.sale_items (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.sales (id) on delete cascade,
  product_id uuid not null references public.products (id),
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price numeric not null check (unit_price >= 0),
  cost_price numeric not null check (cost_price >= 0),
  subtotal numeric not null check (subtotal >= 0),
  created_at timestamptz not null default now(),
  shop_id uuid not null default public.current_shop_id() references public.shops (id)
);

create table public.stock_movements (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null default public.current_shop_id() references public.shops (id),
  product_id uuid not null references public.products (id),
  movement_type text not null,
  quantity integer not null,
  previous_quantity integer not null,
  new_quantity integer not null,
  reference_id uuid,
  note text,
  created_by uuid,
  created_at timestamptz not null default now()
);

-- Live policies.
alter table public.shops enable row level security;
alter table public.shop_members enable row level security;
alter table public.products enable row level security;
alter table public.customers enable row level security;
alter table public.purchases enable row level security;
alter table public.purchase_items enable row level security;
alter table public.sales enable row level security;
alter table public.sale_items enable row level security;
alter table public.stock_movements enable row level security;

create policy "Members can view their shop" on public.shops for select to authenticated
  using (id in (select m.shop_id from public.shop_members m where m.user_id = auth.uid()));
create policy "Users can view their own membership" on public.shop_members for select
  to authenticated using (user_id = auth.uid());
revoke all on public.shop_members from anon, authenticated;
grant select on public.shop_members to authenticated;

do $$
declare t text;
begin
  foreach t in array array['products', 'customers'] loop
    execute format('create policy "Shop members can create" on public.%I for insert to authenticated with check (shop_id = (select public.current_shop_id()))', t);
    execute format('create policy "Shop members can update" on public.%I for update to authenticated using (shop_id = (select public.current_shop_id())) with check (shop_id = (select public.current_shop_id()))', t);
    execute format('create policy "Shop members can view" on public.%I for select to authenticated using (shop_id = (select public.current_shop_id()))', t);
    execute format('create policy "Shop owners can delete" on public.%I for delete to authenticated using ((shop_id = (select public.current_shop_id())) and ((select public.current_shop_role()) = ''owner''))', t);
  end loop;
  foreach t in array array['purchases', 'purchase_items', 'sales', 'sale_items'] loop
    execute format('create policy "Shop members can create" on public.%I for insert to authenticated with check (shop_id = (select public.current_shop_id()))', t);
    execute format('create policy "Shop members can view" on public.%I for select to authenticated using (shop_id = (select public.current_shop_id()))', t);
  end loop;
end $$;
create policy "Shop members can update" on public.purchases for update to authenticated
  using (shop_id = (select public.current_shop_id()))
  with check (shop_id = (select public.current_shop_id()));
-- Deliberately NOT the name the migration drops: the grant revoke must still close it.
create policy "Members record stock movements" on public.stock_movements for insert
  to authenticated with check (shop_id = (select public.current_shop_id()));
create policy "Shop members can view" on public.stock_movements for select
  to authenticated using (shop_id = (select public.current_shop_id()));

-- Old 7-argument create_purchase so the repo suppliers migration can replace it.
create function public.create_purchase(text, text, text, numeric, date, text, jsonb)
returns uuid language sql as $$ select null::uuid $$;

-- Stand-ins for the live RPCs whose bodies are not in the repo; they follow
-- the reviewed live behaviour (SECURITY DEFINER, current_shop_id, prices read
-- from the locked product row, stock movements with auth.uid()).
create function public.create_sale(
  p_customer_id uuid, p_payment_method text, p_amount_paid numeric, p_items jsonb
) returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_shop uuid := public.current_shop_id();
  v_sale uuid;
  v_item jsonb;
  v_p public.products%rowtype;
  v_qty integer;
  v_total numeric := 0;
begin
  if v_shop is null then raise exception 'No active shop for this account'; end if;
  insert into public.sales (shop_id, sale_number, payment_method, amount_paid, created_by, customer_id)
  values (v_shop, 'S-' || substr(gen_random_uuid()::text, 1, 8), p_payment_method, p_amount_paid, auth.uid(), p_customer_id)
  returning id into v_sale;
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := (v_item->>'quantity')::integer;
    select * into v_p from public.products
    where id = (v_item->>'product_id')::uuid and shop_id = v_shop and is_active
    for update;
    if not found then raise exception 'Product not found'; end if;
    if v_p.stock_quantity < v_qty then raise exception 'Insufficient stock'; end if;
    insert into public.sale_items (shop_id, sale_id, product_id, product_name, quantity, unit_price, cost_price, subtotal)
    values (v_shop, v_sale, v_p.id, v_p.name, v_qty, v_p.selling_price, v_p.cost_price, v_p.selling_price * v_qty);
    update public.products set stock_quantity = stock_quantity - v_qty where id = v_p.id;
    insert into public.stock_movements (shop_id, product_id, movement_type, quantity, previous_quantity, new_quantity, reference_id, created_by)
    values (v_shop, v_p.id, 'sale', v_qty, v_p.stock_quantity, v_p.stock_quantity - v_qty, v_sale, auth.uid());
    v_total := v_total + v_p.selling_price * v_qty;
  end loop;
  update public.sales set total_amount = v_total where id = v_sale;
  return v_sale;
end;
$$;

create function public.adjust_stock(
  p_product_id uuid, p_quantity integer, p_direction text, p_note text
) returns uuid
language plpgsql security definer set search_path to 'public'
as $$
declare
  v_shop uuid := public.current_shop_id();
  v_prev integer;
  v_new integer;
  v_movement uuid;
begin
  if v_shop is null then raise exception 'No active shop for this account'; end if;
  select stock_quantity into v_prev from public.products
  where id = p_product_id and shop_id = v_shop for update;
  if not found then raise exception 'Product not found'; end if;
  v_new := case when p_direction = 'in' then v_prev + p_quantity else v_prev - p_quantity end;
  update public.products set stock_quantity = v_new where id = p_product_id;
  insert into public.stock_movements (shop_id, product_id, movement_type, quantity, previous_quantity, new_quantity, note, created_by)
  values (v_shop, p_product_id, 'adjustment', p_quantity, v_prev, v_new, p_note, auth.uid())
  returning id into v_movement;
  return v_movement;
end;
$$;

create function public.get_dashboard_summary() returns json
language plpgsql stable security definer set search_path to 'public'
as $$
declare v_shop uuid := public.current_shop_id();
begin
  if v_shop is null then raise exception 'No active shop for this account'; end if;
  return json_build_object(
    'today_sales', (select coalesce(sum(total_amount), 0) from public.sales where shop_id = v_shop),
    'today_profit', (select coalesce(sum(subtotal - cost_price * quantity), 0) from public.sale_items where shop_id = v_shop),
    'today_transactions', (select count(*) from public.sales where shop_id = v_shop),
    'total_products', (select count(*) from public.products where shop_id = v_shop and is_active),
    'low_stock_products', 0,
    'out_of_stock_products', 0,
    'recent_sales', '[]'::json
  );
end;
$$;

-- Fixtures: shop A (owner, attendant, suspended attendant), shop B (owner),
-- shop C (suspended shop with its owner).
insert into auth.users (id, email, email_confirmed_at) values
  ('0000000a-0000-0000-0000-000000000001', 'owner.a@test', now()),
  ('0000000a-0000-0000-0000-000000000002', 'attendant.a@test', now()),
  ('0000000a-0000-0000-0000-000000000003', 'suspended.a@test', now()),
  ('0000000b-0000-0000-0000-000000000001', 'owner.b@test', now()),
  ('0000000c-0000-0000-0000-000000000001', 'owner.c@test', now());

insert into public.shops (id, name, status) values
  ('aaaaaaaa-0000-0000-0000-000000000000', 'Shop A', 'active'),
  ('bbbbbbbb-0000-0000-0000-000000000000', 'Shop B', 'active'),
  ('cccccccc-0000-0000-0000-000000000000', 'Shop C', 'suspended');

insert into public.shop_members (shop_id, user_id, role, status) values
  ('aaaaaaaa-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000001', 'owner', 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000002', 'staff', 'active'),
  ('aaaaaaaa-0000-0000-0000-000000000000', '0000000a-0000-0000-0000-000000000003', 'staff', 'suspended'),
  ('bbbbbbbb-0000-0000-0000-000000000000', '0000000b-0000-0000-0000-000000000001', 'owner', 'active'),
  ('cccccccc-0000-0000-0000-000000000000', '0000000c-0000-0000-0000-000000000001', 'owner', 'active');

insert into public.products (id, shop_id, name, cost_price, selling_price, stock_quantity) values
  ('a0000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000000', 'A Rice', 10, 15, 50),
  ('b0000000-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-000000000000', 'B Soap', 3, 5, 20),
  ('c0000000-0000-0000-0000-00000000000c', 'cccccccc-0000-0000-0000-000000000000', 'C Oil', 7, 9, 5);

insert into public.customers (id, shop_id, name) values
  ('a1000000-0000-0000-0000-00000000000a', 'aaaaaaaa-0000-0000-0000-000000000000', 'A Customer'),
  ('a1000000-0000-0000-0000-0000000000a2', 'aaaaaaaa-0000-0000-0000-000000000000', 'A Customer Two'),
  ('b1000000-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-000000000000', 'B Customer');

insert into public.sales (id, shop_id, sale_number, total_amount, created_by) values
  ('b2000000-0000-0000-0000-00000000000b', 'bbbbbbbb-0000-0000-0000-000000000000', 'S-B-1', 5,
   '0000000b-0000-0000-0000-000000000001');
