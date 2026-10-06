-- Owner-only editing of the shop's business name and phone. Clients still have
-- no UPDATE privilege or policy on public.shops; this RPC is the only write
-- path, so status, logo_path and other columns stay out of reach.

create function public.update_shop_profile(p_name text, p_phone text)
returns void
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
  v_name text := btrim(p_name);
  v_phone text := nullif(btrim(p_phone), '');
  v_phone_digits int;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can change the business profile';
  end if;

  -- Same rule as shop registration: 2 to 80 characters after trimming.
  if v_name is null or char_length(v_name) < 2 or char_length(v_name) > 80 then
    raise exception 'Business name must be 2 to 80 characters';
  end if;

  -- Optional. Stored as typed (trimmed), allowing local and international
  -- formats: digits, spaces and + ( ) - . with 7 to 15 digits in total.
  if v_phone is not null then
    v_phone_digits := char_length(regexp_replace(v_phone, '[^0-9]', '', 'g'));
    if char_length(v_phone) > 40
       or v_phone !~ '^[0-9+() .-]+$'
       or v_phone_digits < 7
       or v_phone_digits > 15 then
      raise exception 'Invalid phone number';
    end if;
  end if;

  update public.shops as shop
  set name = v_name,
      phone = v_phone,
      updated_at = now()
  where shop.id = v_shop_id;

  if not found then
    raise exception 'Shop not found';
  end if;
end;
$function$;

revoke all privileges on function public.update_shop_profile(text, text)
  from public, anon, authenticated;
grant execute on function public.update_shop_profile(text, text)
  to authenticated;

comment on function public.update_shop_profile(text, text) is
  'Owner-only: sets the caller''s shop name (2-80 chars, trimmed) and optional phone (blank clears it). The only client write path for these columns.';
