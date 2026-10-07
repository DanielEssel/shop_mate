-- RBAC-3A checks. Every action runs in its own statement and is verified in a
-- later one (a single statement may evaluate the check before the action).
-- Everything is rolled back at the end.
\set ON_ERROR_STOP on

create table public.t_results (n serial, name text, ok boolean, detail text);
grant all on public.t_results to anon, authenticated, service_role;
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

\set oa '0000000a-0000-0000-0000-000000000001'
\set sa '0000000a-0000-0000-0000-000000000002'
\set sa2 '0000000a-0000-0000-0000-000000000003'
\set co '0000000a-0000-0000-0000-000000000004'
\set ob '0000000b-0000-0000-0000-000000000001'
\set sb '0000000b-0000-0000-0000-000000000002'
\set op '0000000c-0000-0000-0000-000000000001'
\set nb '0000000d-0000-0000-0000-000000000001'
\set new1 '0000000e-0000-0000-0000-000000000001'
\set new2 '0000000e-0000-0000-0000-000000000002'
\set shop_a 'aaaaaaaa-0000-0000-0000-000000000000'

begin;

create temp table t_saved (k text primary key, v text);
grant all on t_saved to anon, authenticated, service_role;

-- =====================================================================
-- Schema
-- =====================================================================
select public.t_check('shop_members.updated_at exists, not null, filled for existing rows',
  (select is_nullable = 'NO' from information_schema.columns
   where table_schema = 'public' and table_name = 'shop_members' and column_name = 'updated_at')
  and not exists (select 1 from public.shop_members where updated_at is null));
select public.t_check('shop_member_events: RLS on, no policies',
  (select relrowsecurity from pg_class where oid = 'public.shop_member_events'::regclass)
  and not exists (select 1 from pg_policies where tablename = 'shop_member_events'));

-- =====================================================================
-- list_shop_members
-- =====================================================================
insert into t_saved
select 'list_a', public.t_value('authenticated', :'oa',
  'select string_agg(email || ''|'' || role || ''|'' || coalesce(display_name, ''-''), '','') from public.list_shop_members()');
select public.t_check('owner lists only their shop, owners first, with display names',
  (select v from t_saved where k = 'list_a')
    = 'owner.a@test|owner|-,coowner.a@test|owner|-,staff.a@test|staff|Ama Staff,staff2.a@test|staff|Kofi',
  (select v from t_saved where k = 'list_a'));
select public.t_check('owner B sees only shop B (no shop A emails)',
  public.t_value('authenticated', :'ob',
    'select string_agg(email, '','' order by email) from public.list_shop_members()')
    = 'owner.b@test,staff.b@test');
select public.t_check('staff cannot list members',
  public.t_is(public.t_try('authenticated', :'sa', 'select * from public.list_shop_members()'), '42501'));
select public.t_check('a user without a shop cannot list members',
  public.t_is(public.t_try('authenticated', :'nb', 'select * from public.list_shop_members()'), '42501'));
select public.t_check('owner of a pending shop cannot list members',
  public.t_is(public.t_try('authenticated', :'op', 'select * from public.list_shop_members()'), '42501'));
select public.t_check('anon cannot list members',
  public.t_is(public.t_try('anon', null, 'select * from public.list_shop_members()'), '42501'));

-- =====================================================================
-- Who may manage
-- =====================================================================
select public.t_check('staff cannot suspend a colleague',
  public.t_is(public.t_try('authenticated', :'sa', format(
    'select public.set_shop_member_status(%L, ''suspended'')', :'sa2')), '42501'));
select public.t_check('staff cannot remove a colleague',
  public.t_is(public.t_try('authenticated', :'sa', format(
    'select public.remove_shop_member(%L)', :'sa2')), '42501'));
select public.t_check('a user without a shop cannot manage members',
  public.t_is(public.t_try('authenticated', :'nb', format(
    'select public.set_shop_member_status(%L, ''suspended'')', :'sa')), '42501'));
select public.t_check('anon cannot manage members',
  public.t_is(public.t_try('anon', null, format(
    'select public.remove_shop_member(%L)', :'sa')), '42501'));
select public.t_check('owner cannot suspend themselves',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'select public.set_shop_member_status(%L, ''suspended'')', :'oa')), '42501'));
select public.t_check('owner cannot remove themselves',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'select public.remove_shop_member(%L)', :'oa')), '42501'));
select public.t_check('owner cannot suspend another owner',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'select public.set_shop_member_status(%L, ''suspended'')', :'co')), '42501'));
select public.t_check('owner cannot remove another owner',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'select public.remove_shop_member(%L)', :'co')), '42501'));
select public.t_check('invalid status refused',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'select public.set_shop_member_status(%L, ''owner'')', :'sa')), '22023'));
select public.t_check('cross-shop: shop B staff is "not found" for owner A',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'select public.set_shop_member_status(%L, ''suspended'')', :'sb')), 'P0002')
  and public.t_is(public.t_try('authenticated', :'oa', format(
    'select public.remove_shop_member(%L)', :'sb')), 'P0002'));
select public.t_check('cross-shop: shop B staff untouched',
  (select status = 'active' from public.shop_members where user_id = :'sb'));
select public.t_check('both shop A owners still active owners',
  (select count(*) = 2 from public.shop_members
   where shop_id = :'shop_a' and role = 'owner' and status = 'active'));

-- =====================================================================
-- Suspend / restore
-- =====================================================================
update public.shop_members set updated_at = now() - interval '1 day' where user_id = :'sa';
select public.t_check('owner suspends staff (action)',
  public.t_try('authenticated', :'oa', format(
    'select public.set_shop_member_status(%L, ''suspended'')', :'sa')) = 'ok');
select public.t_check('suspended: status, updated_at and suspended event',
  (select status = 'suspended' and updated_at > now() - interval '1 minute'
   from public.shop_members where user_id = :'sa')
  and exists (select 1 from public.shop_member_events
              where member_user_id = :'sa' and actor_user_id = :'oa'
                and shop_id = :'shop_a' and event_type = 'suspended'));
select public.t_check('suspended staff loses shop access',
  public.t_value('authenticated', :'sa', 'select public.current_shop_id()') is null);
select public.t_check('suspending again is refused',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'select public.set_shop_member_status(%L, ''suspended'')', :'sa')), '55000'));
select public.t_check('owner restores staff (action)',
  public.t_try('authenticated', :'oa', format(
    'select public.set_shop_member_status(%L, ''active'')', :'sa')) = 'ok');
select public.t_check('restored: active, access back, restored event',
  (select status = 'active' from public.shop_members where user_id = :'sa')
  and public.t_value('authenticated', :'sa', 'select public.current_shop_id()') = :'shop_a'
  and exists (select 1 from public.shop_member_events
              where member_user_id = :'sa' and event_type = 'restored'));

-- =====================================================================
-- Revoke
-- =====================================================================
select public.t_check('owner revokes staff (action)',
  public.t_try('authenticated', :'oa', format(
    'select public.remove_shop_member(%L)', :'sa')) = 'ok');
select public.t_check('revoked: membership gone, revoked event kept',
  not exists (select 1 from public.shop_members where user_id = :'sa')
  and exists (select 1 from public.shop_member_events
              where member_user_id = :'sa' and actor_user_id = :'oa'
                and shop_id = :'shop_a' and event_type = 'revoked'));
select public.t_check('revoked: Auth user kept',
  exists (select 1 from auth.users where id = :'sa'));
select public.t_check('revoked: sales and purchases still credit them',
  (select count(*) = 1 from public.sales where created_by = :'sa')
  and (select count(*) = 1 from public.purchases where created_by = :'sa'));
select public.t_check('revoked: no shop access, membership slot free',
  public.t_value('authenticated', :'sa', 'select public.current_shop_id()') is null
  and (select count(*) = 0 from public.shop_members where user_id = :'sa'));
select public.t_check('history: a revoked attendant''s Auth user cannot be deleted',
  public.t_try('postgres', null, format('delete from auth.users where id = %L', :'sa')) like '23503%');
select public.t_check('revoking an already revoked member: not found',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'select public.remove_shop_member(%L)', :'sa')), 'P0002'));

-- =====================================================================
-- Direct writes stay closed
-- =====================================================================
select public.t_check('owner cannot insert memberships directly',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'insert into public.shop_members (shop_id, user_id, role) values (%L, %L, ''staff'')',
    :'shop_a', :'nb')), '42501'));
select public.t_check('owner cannot update or delete memberships directly',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'update public.shop_members set status = ''suspended'' where user_id = %L', :'sa2')), '42501')
  and public.t_is(public.t_try('authenticated', :'oa', format(
    'delete from public.shop_members where user_id = %L', :'sa2')), '42501'));
select public.t_check('nobody can read or write member events directly',
  public.t_is(public.t_try('authenticated', :'oa', 'select * from public.shop_member_events'), '42501')
  and public.t_is(public.t_try('authenticated', :'oa', format(
    'insert into public.shop_member_events (shop_id, member_user_id, actor_user_id, event_type) values (%L, %L, %L, ''created'')',
    :'shop_a', :'sa2', :'oa')), '42501')
  and public.t_is(public.t_try('authenticated', :'oa', 'delete from public.shop_member_events'), '42501')
  and public.t_is(public.t_try('anon', null, 'select * from public.shop_member_events'), '42501'));

-- =====================================================================
-- Edge Function steps (service_role)
-- =====================================================================
select public.t_check('authenticated users cannot call the Edge Function helpers',
  public.t_is(public.t_try('authenticated', :'oa', format(
    'select public.shop_attendant_owner_shop(%L)', :'oa')), '42501')
  and public.t_is(public.t_try('authenticated', :'oa', format(
    'select * from public.create_shop_attendant_membership(%L, %L)', :'oa', :'nb')), '42501')
  and public.t_is(public.t_try('anon', null, format(
    'select public.shop_attendant_owner_shop(%L)', :'oa')), '42501'));

select public.t_check('helper: an active owner gets their shop',
  public.t_value('service_role', null, format(
    'select public.shop_attendant_owner_shop(%L)', :'oa')) = :'shop_a');
select public.t_check('helper: staff, no-shop users and pending-shop owners are refused',
  public.t_is(public.t_try('service_role', null, format(
    'select public.shop_attendant_owner_shop(%L)', :'sa2')), '42501')
  and public.t_is(public.t_try('service_role', null, format(
    'select public.shop_attendant_owner_shop(%L)', :'nb')), '42501')
  and public.t_is(public.t_try('service_role', null, format(
    'select public.shop_attendant_owner_shop(%L)', :'op')), '42501'));

-- What Auth Admin createUser produces: a brand-new, unconfirmed user.
insert into auth.users (id, email, raw_user_meta_data) values
  (:'new1', 'new.attendant@test', '{"display_name": "Esi", "must_change_password": true}'),
  (:'new2', 'second.new@test', '{}');

select public.t_check('owner adds a new attendant (action)',
  public.t_try('service_role', null, format(
    'insert into t_saved select ''created'', role || ''|'' || status from public.create_shop_attendant_membership(%L, %L)',
    :'oa', :'new1')) = 'ok');
select public.t_check('created: staff, active, in the owner''s shop, with a created event',
  (select v = 'staff|active' from t_saved where k = 'created')
  and (select shop_id = :'shop_a' and role = 'staff' and status = 'active'
       from public.shop_members where user_id = :'new1')
  and exists (select 1 from public.shop_member_events
              where member_user_id = :'new1' and actor_user_id = :'oa'
                and shop_id = :'shop_a' and event_type = 'created'));
select public.t_check('the new attendant has access as staff',
  public.t_value('authenticated', :'new1', 'select public.current_shop_role()') = 'staff'
  and public.t_value('authenticated', :'new1', 'select public.current_shop_id()') = :'shop_a');
select public.t_check('the new attendant appears in the owner''s list with their name',
  public.t_value('authenticated', :'oa',
    'select display_name from public.list_shop_members() where email = ''new.attendant@test''') = 'Esi');
select public.t_check('a user cannot be added to a second shop',
  public.t_is(public.t_try('service_role', null, format(
    'select * from public.create_shop_attendant_membership(%L, %L)', :'ob', :'new1')), '23505')
  and (select shop_id = :'shop_a' from public.shop_members where user_id = :'new1'));
select public.t_check('staff cannot add attendants through the helper',
  public.t_is(public.t_try('service_role', null, format(
    'select * from public.create_shop_attendant_membership(%L, %L)', :'sa2', :'new2')), '42501'));
select public.t_check('pending-shop owner cannot add attendants',
  public.t_is(public.t_try('service_role', null, format(
    'select * from public.create_shop_attendant_membership(%L, %L)', :'op', :'new2')), '42501'));
select public.t_check('an owner cannot add themselves',
  public.t_is(public.t_try('service_role', null, format(
    'select * from public.create_shop_attendant_membership(%L, %L)', :'oa', :'oa')), '42501'));
select public.t_check('an existing (not newly created) account cannot be attached',
  public.t_is(public.t_try('service_role', null, format(
    'select * from public.create_shop_attendant_membership(%L, %L)', :'oa', :'nb')), '42501')
  and not exists (select 1 from public.shop_members where user_id = :'nb'));
update public.shop_members set status = 'suspended' where user_id = :'oa';
select public.t_check('a suspended owner cannot add attendants',
  public.t_is(public.t_try('service_role', null, format(
    'select * from public.create_shop_attendant_membership(%L, %L)', :'oa', :'new2')), '42501')
  and not exists (select 1 from public.shop_members where user_id = :'new2'));
update public.shop_members set status = 'active' where user_id = :'oa';
select public.t_check('no membership or event left behind by refused attempts',
  not exists (select 1 from public.shop_members where user_id = :'new2')
  and not exists (select 1 from public.shop_member_events where member_user_id = :'new2'));

-- =====================================================================
-- Hardening
-- =====================================================================
select public.t_check('all RBAC-3A functions: SECURITY DEFINER, search_path public, pg_temp',
  (select bool_and(p.prosecdef and p.proconfig = array['search_path=public, pg_temp'])
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('list_shop_members', 'set_shop_member_status', 'remove_shop_member',
                       'shop_attendant_owner_shop', 'create_shop_attendant_membership')
   having count(*) = 5));
select public.t_check('PUBLIC and anon have no EXECUTE on any of them',
  (select bool_and(not has_function_privilege('public', p.oid, 'execute')
                   and not has_function_privilege('anon', p.oid, 'execute'))
   from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public'
     and p.proname in ('list_shop_members', 'set_shop_member_status', 'remove_shop_member',
                       'shop_attendant_owner_shop', 'create_shop_attendant_membership')));
select public.t_check('helpers: service_role only; owner RPCs: authenticated',
  not has_function_privilege('authenticated', 'public.shop_attendant_owner_shop(uuid)', 'execute')
  and not has_function_privilege('authenticated', 'public.create_shop_attendant_membership(uuid, uuid)', 'execute')
  and has_function_privilege('service_role', 'public.create_shop_attendant_membership(uuid, uuid)', 'execute')
  and has_function_privilege('authenticated', 'public.list_shop_members()', 'execute')
  and has_function_privilege('authenticated', 'public.set_shop_member_status(uuid, text)', 'execute')
  and has_function_privilege('authenticated', 'public.remove_shop_member(uuid)', 'execute'));
select public.t_check('role check unchanged: owner|staff only',
  (select pg_get_constraintdef(oid) like '%owner%staff%' and pg_get_constraintdef(oid) not like '%attendant%'
   from pg_constraint where conname = 'shop_members_role_check'));

\pset format aligned
select n, case when ok then 'PASS' else 'FAIL' end as result, name, coalesce(detail, '') as detail
from public.t_results order by n;
select count(*) filter (where ok) as passed, count(*) filter (where not ok) as failed
from public.t_results;

rollback;
