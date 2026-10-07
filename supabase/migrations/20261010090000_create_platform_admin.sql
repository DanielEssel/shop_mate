-- Admin Phase 1: platform administrators and shop approval.
--
-- A platform admin runs the ShopMate platform itself. This is separate from
-- shop_members.role (owner/staff), which only controls access inside a shop:
-- owning a shop never makes anyone a platform admin.
--
-- Security model:
--   * public.platform_admins lists the admins. RLS is on with no policies and
--     every client privilege is revoked, so no app user can read it or add
--     themselves. Admins are added by the project owner in the SQL editor.
--   * Every admin RPC is SECURITY DEFINER with an empty search_path, checks
--     public.is_platform_admin() first and raises 42501 otherwise.
--   * No policy or grant on public.shops is added or changed; clients still
--     cannot update shops directly.
--
-- Shop status model (shops_status_check): pending | active | suspended.
--   approve:    pending   -> active  (approved_at = now())
--   suspend:    active    -> suspended
--   reactivate: suspended -> active  (approved_at kept)

-- ---------------------------------------------------------------------------
-- Platform admins
-- ---------------------------------------------------------------------------

create table public.platform_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

comment on table public.platform_admins is
  'ShopMate platform administrators. Managed only from the SQL editor; no client access.';

alter table public.platform_admins enable row level security;

-- No policies on purpose: with RLS on, API roles see and change nothing.
revoke all on table public.platform_admins from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- is_platform_admin(): whether the caller is a platform admin
-- ---------------------------------------------------------------------------

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.platform_admins as admin
    where admin.user_id = auth.uid()
  );
$$;

revoke execute on function public.is_platform_admin() from public, anon;
grant execute on function public.is_platform_admin() to authenticated;

-- ---------------------------------------------------------------------------
-- admin_list_shops(p_status): shops in one status, for the admin screen
-- ---------------------------------------------------------------------------

create or replace function public.admin_list_shops(p_status text)
returns table (
  shop_id uuid,
  shop_name text,
  shop_phone text,
  shop_status text,
  owner_email text,
  created_at timestamptz,
  approved_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = ''
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'Platform admin access is required'
      using errcode = '42501';
  end if;

  if p_status is null or p_status not in ('pending', 'active', 'suspended') then
    raise exception 'Unknown shop status'
      using errcode = '22023';
  end if;

  return query
  select
    shop.id,
    shop.name,
    shop.phone,
    shop.status,
    -- Only the owner's email is exposed: enough to identify the shop.
    coalesce(owner_user.email, creator.email)::text,
    shop.created_at,
    shop.approved_at,
    shop.updated_at
  from public.shops as shop
  left join lateral (
    select account.email
    from public.shop_members as member
    join auth.users as account on account.id = member.user_id
    where member.shop_id = shop.id
      and member.role = 'owner'
    order by member.created_at
    limit 1
  ) as owner_user on true
  left join auth.users as creator on creator.id = shop.created_by
  where shop.status = p_status
  -- Pending shops oldest first (a review queue); the others by name.
  order by
    case when p_status = 'pending' then shop.created_at end asc nulls last,
    lower(shop.name),
    shop.id;
end;
$$;

revoke execute on function public.admin_list_shops(text) from public, anon;
grant execute on function public.admin_list_shops(text) to authenticated;

-- ---------------------------------------------------------------------------
-- Status changes. One private helper does the locked, checked transition;
-- the three public RPCs each name exactly one allowed move.
-- ---------------------------------------------------------------------------

create or replace function public.admin_change_shop_status(
  p_shop_id uuid,
  p_from text,
  p_to text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_status text;
begin
  if not public.is_platform_admin() then
    raise exception 'Platform admin access is required'
      using errcode = '42501';
  end if;

  -- Lock the row so two admins acting at once cannot both succeed.
  select shop.status
  into v_status
  from public.shops as shop
  where shop.id = p_shop_id
  for update;

  if not found then
    raise exception 'Shop not found'
      using errcode = 'P0002';
  end if;

  if v_status is distinct from p_from then
    raise exception 'This shop is % and cannot be changed to %', v_status, p_to
      using errcode = '55000';
  end if;

  update public.shops as shop
  set
    status = p_to,
    approved_at = case
      when p_from = 'pending' then now()
      when p_to = 'active' then coalesce(shop.approved_at, now())
      else shop.approved_at
    end,
    updated_at = now()
  where shop.id = p_shop_id;
end;
$$;

-- Internal only: reachable through the three RPCs below, never directly.
revoke execute on function public.admin_change_shop_status(uuid, text, text)
  from public, anon, authenticated;

create or replace function public.admin_approve_shop(p_shop_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select public.admin_change_shop_status(p_shop_id, 'pending', 'active');
$$;

create or replace function public.admin_suspend_shop(p_shop_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select public.admin_change_shop_status(p_shop_id, 'active', 'suspended');
$$;

create or replace function public.admin_reactivate_shop(p_shop_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  select public.admin_change_shop_status(p_shop_id, 'suspended', 'active');
$$;

revoke execute on function public.admin_approve_shop(uuid) from public, anon;
revoke execute on function public.admin_suspend_shop(uuid) from public, anon;
revoke execute on function public.admin_reactivate_shop(uuid) from public, anon;
grant execute on function public.admin_approve_shop(uuid) to authenticated;
grant execute on function public.admin_suspend_shop(uuid) to authenticated;
grant execute on function public.admin_reactivate_shop(uuid) to authenticated;
