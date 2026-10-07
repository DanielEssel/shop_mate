-- RBAC-3A: owner-created shop attendant accounts (database side).
--
-- An owner adds an attendant from the app. The app calls the
-- create-shop-attendant Edge Function, which:
--   1. verifies the caller's JWT with Supabase Auth,
--   2. asks shop_attendant_owner_shop() for the caller's shop (active owner
--      of an active shop, or refused),
--   3. creates the Auth user (temporary password; display name and
--      must_change_password in user metadata),
--   4. calls create_shop_attendant_membership() to add the 'staff' membership
--      and its 'created' event; if that fails it deletes the new Auth user.
-- Steps 2 and 4 are callable by service_role only (the Edge Function), never
-- by app users: they take the owner's id as a parameter, so exposing them
-- would let anyone act as any owner.
--
-- Owners then manage members with list_shop_members, set_shop_member_status
-- and remove_shop_member, which act on the caller's own shop only.
--
-- Revoking access deletes only the membership row. Auth users are never
-- deleted here: sales, purchases, expenses and stock movements keep pointing
-- at them. The role value stays 'staff'.

-- ===========================================================================
-- shop_members.updated_at
-- ===========================================================================

-- Existing rows get the migration time.
alter table public.shop_members
  add column updated_at timestamptz not null default now();

-- ===========================================================================
-- shop_member_events: who added, suspended, restored or revoked whom
-- ===========================================================================

create table public.shop_member_events (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops (id) on delete cascade,
  -- No ON DELETE action: an Auth user with membership history can't be
  -- deleted, matching the rule that attendants' accounts are kept.
  member_user_id uuid not null references auth.users (id),
  actor_user_id uuid not null references auth.users (id),
  event_type text not null,
  created_at timestamptz not null default now(),
  constraint shop_member_events_event_type_check
    check (event_type in ('created', 'suspended', 'restored', 'revoked'))
);

create index shop_member_events_shop_created_idx
  on public.shop_member_events (shop_id, created_at desc);

comment on table public.shop_member_events is
  'Membership history per shop. Written only by the member-management functions; no client access.';

alter table public.shop_member_events enable row level security;

-- No policies: API roles can neither read nor write it.
revoke all on table public.shop_member_events from public, anon, authenticated;

-- ===========================================================================
-- Owner RPCs (authenticated). All are scoped to current_shop_id(), which only
-- answers for an active member of an active shop, and require the owner role.
-- ===========================================================================

-- list_shop_members: the members of the caller's shop, owner first.
create function public.list_shop_members()
returns table (
  member_id uuid,
  user_id uuid,
  role text,
  status text,
  email text,
  display_name text,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account' using errcode = '42501';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can manage shop members'
      using errcode = '42501';
  end if;

  return query
  select
    member.id,
    member.user_id,
    member.role,
    member.status,
    account.email::text,
    -- Display name is a convenience label set when the account is created;
    -- it is never used for access decisions.
    nullif(btrim(account.raw_user_meta_data ->> 'display_name'), ''),
    member.created_at,
    member.updated_at
  from public.shop_members as member
  join auth.users as account on account.id = member.user_id
  where member.shop_id = v_shop_id
  order by (member.role = 'owner') desc, member.created_at, member.id;
end;
$function$;

-- set_shop_member_status: suspend (active -> suspended) or restore
-- (suspended -> active) one attendant of the caller's shop.
create function public.set_shop_member_status(
  p_member_user_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor uuid := auth.uid();
  v_shop_id uuid := public.current_shop_id();
  v_member public.shop_members%rowtype;
begin
  if v_actor is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account' using errcode = '42501';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can manage shop members'
      using errcode = '42501';
  end if;

  if p_status is null or p_status not in ('active', 'suspended') then
    raise exception 'Status must be active or suspended' using errcode = '22023';
  end if;

  if p_member_user_id is null or p_member_user_id = v_actor then
    raise exception 'You cannot change your own access' using errcode = '42501';
  end if;

  -- Only members of the caller's own shop are visible here; anyone else is
  -- simply "not found", without revealing that they exist elsewhere.
  select *
  into v_member
  from public.shop_members as member
  where member.shop_id = v_shop_id
    and member.user_id = p_member_user_id
  for update;

  if not found then
    raise exception 'Member not found' using errcode = 'P0002';
  end if;

  if v_member.role is distinct from 'staff' then
    raise exception 'Only attendants can be suspended or restored'
      using errcode = '42501';
  end if;

  if v_member.status = p_status then
    raise exception 'This member is already %', p_status using errcode = '55000';
  end if;

  update public.shop_members as member
  set status = p_status,
      updated_at = now()
  where member.id = v_member.id;

  insert into public.shop_member_events (shop_id, member_user_id, actor_user_id, event_type)
  values (
    v_shop_id,
    p_member_user_id,
    v_actor,
    case when p_status = 'suspended' then 'suspended' else 'restored' end
  );
end;
$function$;

-- remove_shop_member: revoke an attendant's access to the caller's shop.
-- Deletes only the membership; the Auth user and every record they created
-- stay. The person may later register their own shop or be added elsewhere.
create function public.remove_shop_member(p_member_user_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_actor uuid := auth.uid();
  v_shop_id uuid := public.current_shop_id();
  v_member public.shop_members%rowtype;
begin
  if v_actor is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account' using errcode = '42501';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can manage shop members'
      using errcode = '42501';
  end if;

  if p_member_user_id is null or p_member_user_id = v_actor then
    raise exception 'You cannot remove your own access' using errcode = '42501';
  end if;

  select *
  into v_member
  from public.shop_members as member
  where member.shop_id = v_shop_id
    and member.user_id = p_member_user_id
  for update;

  if not found then
    raise exception 'Member not found' using errcode = 'P0002';
  end if;

  if v_member.role is distinct from 'staff' then
    raise exception 'Only attendants can be removed' using errcode = '42501';
  end if;

  -- The event outlives the membership row.
  insert into public.shop_member_events (shop_id, member_user_id, actor_user_id, event_type)
  values (v_shop_id, p_member_user_id, v_actor, 'revoked');

  delete from public.shop_members as member
  where member.id = v_member.id;
end;
$function$;

revoke all on function public.list_shop_members() from public, anon;
revoke all on function public.set_shop_member_status(uuid, text) from public, anon;
revoke all on function public.remove_shop_member(uuid) from public, anon;
grant execute on function public.list_shop_members() to authenticated;
grant execute on function public.set_shop_member_status(uuid, text) to authenticated;
grant execute on function public.remove_shop_member(uuid) to authenticated;

-- ===========================================================================
-- Edge Function helpers (service_role only)
-- ===========================================================================

-- The shop an owner may add attendants to: they must be an ACTIVE 'owner'
-- member of an ACTIVE shop. p_owner_user_id comes from the caller's verified
-- JWT inside the Edge Function, never from the request body.
create function public.shop_attendant_owner_shop(p_owner_user_id uuid)
returns uuid
language plpgsql
stable
security definer
set search_path = public, pg_temp
as $function$
declare
  v_shop_id uuid;
begin
  select member.shop_id
  into v_shop_id
  from public.shop_members as member
  join public.shops as shop on shop.id = member.shop_id
  where member.user_id = p_owner_user_id
    and member.role = 'owner'
    and member.status = 'active'
    and shop.status = 'active';

  if v_shop_id is null then
    raise exception 'Only an active shop owner can add attendants'
      using errcode = '42501';
  end if;

  return v_shop_id;
end;
$function$;

-- Adds a just-created Auth user to the owner's shop as an active 'staff'
-- member and records the 'created' event, atomically. The shop is derived
-- from the owner again here (not passed in), and the role is always 'staff'.
create function public.create_shop_attendant_membership(
  p_owner_user_id uuid,
  p_member_user_id uuid
)
returns table (
  member_id uuid,
  user_id uuid,
  role text,
  status text,
  created_at timestamptz
)
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_shop_id uuid;
  v_member_id uuid;
begin
  if p_owner_user_id is null or p_member_user_id is null then
    raise exception 'Owner and member are required' using errcode = '22023';
  end if;

  if p_owner_user_id = p_member_user_id then
    raise exception 'An owner cannot add themselves' using errcode = '42501';
  end if;

  -- Re-checks the owner and locks their membership so they can't be
  -- suspended halfway through.
  perform 1
  from public.shop_members as owner_member
  where owner_member.user_id = p_owner_user_id
  for share;

  v_shop_id := public.shop_attendant_owner_shop(p_owner_user_id);

  -- Defence in depth: only an account created moments ago by the Edge
  -- Function can be attached, never an arbitrary existing user.
  perform 1
  from auth.users as account
  where account.id = p_member_user_id
    and account.created_at > now() - interval '15 minutes';

  if not found then
    raise exception 'Only a newly created account can be added'
      using errcode = '42501';
  end if;

  if exists (
    select 1 from public.shop_members as member
    where member.user_id = p_member_user_id
  ) then
    raise exception 'This account already belongs to a shop'
      using errcode = '23505';
  end if;

  insert into public.shop_members (shop_id, user_id, role, status)
  values (v_shop_id, p_member_user_id, 'staff', 'active')
  returning id into v_member_id;

  insert into public.shop_member_events (shop_id, member_user_id, actor_user_id, event_type)
  values (v_shop_id, p_member_user_id, p_owner_user_id, 'created');

  return query
  select member.id, member.user_id, member.role, member.status, member.created_at
  from public.shop_members as member
  where member.id = v_member_id;
end;
$function$;

revoke all on function public.shop_attendant_owner_shop(uuid)
  from public, anon, authenticated;
revoke all on function public.create_shop_attendant_membership(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.shop_attendant_owner_shop(uuid) to service_role;
grant execute on function public.create_shop_attendant_membership(uuid, uuid) to service_role;
