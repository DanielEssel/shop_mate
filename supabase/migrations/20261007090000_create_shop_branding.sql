-- Shop branding foundation: a per-shop logo stored in a private bucket and
-- referenced from shops.logo_path. Only the logo column, the bucket, its
-- policies, and two owner-only RPCs are added; existing shop columns, shop
-- RLS, and the product-images bucket are untouched.

-- =============================================================
-- shops.logo_path
-- =============================================================
-- Object path inside the shop-branding bucket, e.g.
-- '<shop id>/logo-1760000000000.png'. The first folder must be this shop's
-- own id, so a row can never reference another shop's object.
alter table public.shops
  add column logo_path text;

alter table public.shops
  add constraint shops_logo_path_check
    check (
      logo_path is null
      or (
        char_length(logo_path) <= 255
        and logo_path ~ '^[0-9a-f-]{36}/logo-[0-9]{1,20}\.(png|jpg|jpeg)$'
        and split_part(logo_path, '/', 1) = id::text
      )
    );

comment on column public.shops.logo_path is
  'Path of the shop logo object in the private shop-branding bucket; null when the shop has no logo. Set only through set_shop_logo/clear_shop_logo.';

-- =============================================================
-- shop-branding bucket
-- =============================================================
-- Private (no public URLs), at most 1 MiB per object, PNG or JPEG only.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'shop-branding',
  'shop-branding',
  false,
  1048576,
  array['image/png', 'image/jpeg']
);

-- =============================================================
-- shop-branding object policies
-- =============================================================
-- Every logo lives under '<shop id>/'. Members read only their own shop's
-- folder; only owners upload or delete. There is no UPDATE policy: each
-- replacement is uploaded to a new versioned path instead of overwriting.

create policy shop_branding_select_current_shop
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'shop-branding'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
  );

create policy shop_branding_insert_owner_current_shop
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'shop-branding'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
    and public.current_shop_role() = 'owner'
    -- Exactly '<shop id>/logo-<digits>.<png|jpg|jpeg>': no nesting,
    -- traversal, or other file names.
    and name ~ (
      '^' || public.current_shop_id()::text
      || '/logo-[0-9]{1,20}\.(png|jpg|jpeg)$'
    )
  );

create policy shop_branding_delete_owner_current_shop
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'shop-branding'
    and (storage.foldername(name))[1] = public.current_shop_id()::text
    and public.current_shop_role() = 'owner'
  );

-- =============================================================
-- set_shop_logo
-- =============================================================
create function public.set_shop_logo(p_path text)
returns text
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
  v_logo_path text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can change the shop logo';
  end if;

  if p_path is null or btrim(p_path) = '' then
    raise exception 'Logo path is required';
  end if;

  -- The path must be exactly '<current shop id>/logo-<digits>.<ext>'.
  if p_path !~ (
    '^' || v_shop_id::text || '/logo-[0-9]{1,20}\.(png|jpg|jpeg)$'
  ) then
    raise exception 'Invalid logo path for this shop';
  end if;

  -- The logo must already be uploaded to the shop-branding bucket, so the
  -- shop never points at a missing object.
  if not exists (
    select 1
    from storage.objects as object
    where object.bucket_id = 'shop-branding'
      and object.name = p_path
  ) then
    raise exception 'Logo file was not found in shop branding storage';
  end if;

  update public.shops as shop
  set logo_path = p_path
  where shop.id = v_shop_id
  returning shop.logo_path into v_logo_path;

  if not found then
    raise exception 'Shop not found';
  end if;

  return v_logo_path;
end;
$function$;

revoke all privileges on function public.set_shop_logo(text)
  from public, anon, authenticated;
grant execute on function public.set_shop_logo(text)
  to authenticated;

comment on function public.set_shop_logo(text) is
  'Owner-only: points the caller''s shop at an uploaded shop-branding object and returns the new logo_path. Does not delete the previous object.';

-- =============================================================
-- clear_shop_logo
-- =============================================================
create function public.clear_shop_logo()
returns text
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
  v_previous_path text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can change the shop logo';
  end if;

  -- Lock the row so the returned previous path is the one being cleared.
  select shop.logo_path
  into v_previous_path
  from public.shops as shop
  where shop.id = v_shop_id
  for update;

  if not found then
    raise exception 'Shop not found';
  end if;

  update public.shops as shop
  set logo_path = null
  where shop.id = v_shop_id;

  return v_previous_path;
end;
$function$;

revoke all privileges on function public.clear_shop_logo()
  from public, anon, authenticated;
grant execute on function public.clear_shop_logo()
  to authenticated;

comment on function public.clear_shop_logo() is
  'Owner-only: clears the caller''s shop logo_path and returns the previous path (null if none) so the client can delete that object. Does not delete storage objects.';
