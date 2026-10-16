-- Discount Settings, owner writes: one owner-only function that saves the
-- shop's discount configuration and its selected products together.
--
-- This replaces the plan in 20261013090000's header (granting authenticated
-- INSERT/UPDATE/DELETE on the discount tables). The tables stay READ-ONLY
-- for every API role: nobody, owners included, can write them directly.
-- The only write path is save_discount_settings, which:
--   * authorizes with the existing helpers: an authenticated, active member
--     (current_shop_id) whose role is 'owner' (current_shop_role); anyone
--     else gets SQLSTATE 42501 and nothing is written;
--   * takes no shop id: it always writes the caller's own shop;
--   * accepts only product ids of that shop;
--   * repeats the app's save rules: a selected-products discount that is
--     switched on needs at least one product (SMD03); a discount that is
--     switched on cannot end in the past (SMD04); no selected active product
--     may go below its current cost (SMD02), computed exactly as
--     create_sale does; the tables' own constraints still apply (23514);
--   * writes the configuration and the selection in ONE transaction, so a
--     sale (create_sale reads both in one statement) sees the old
--     configuration or the new one, never a mix, and a failed save changes
--     nothing. The configuration row is locked first, so two saves for the
--     same shop run one after the other.
--
-- Not changed: create_sale (pricing, and the SMD01 refusal at sale time,
-- which still protects against costs that rise after saving),
-- create_credit_sale_with_initial_payment, the discount tables, their
-- constraints, triggers, row-level security and grants.
--
-- RELEASE: apply only when every device runs the discount-aware app build
-- (discounted checkout prices). Once applied, an owner can switch a discount
-- on, and sales are priced with it on every device. The app's
-- DiscountReleaseGate.writesEnabled is switched on separately.
--
-- APPLYING: like 20261013090000, apply as one transaction (supabase db push
-- or psql --single-transaction); the guard below refuses otherwise.

-- ===========================================================================
-- Single transaction and lock timeout
-- ===========================================================================
set local lock_timeout = '5s';
set local shopmate.discount_writes_migration = 'single-transaction';

do $guard$
begin
  -- SET LOCAL only survives to this statement inside one transaction.
  if current_setting('shopmate.discount_writes_migration', true)
     is distinct from 'single-transaction' then
    raise exception
      'Apply 20261016090000_discount_settings_writes.sql as one transaction (supabase db push, or psql --single-transaction).';
  end if;
end;
$guard$;

-- ===========================================================================
-- save_discount_settings
-- ===========================================================================
create function public.save_discount_settings(
  p_is_enabled boolean,
  p_scope text,
  p_percentage numeric,
  p_ends_at timestamptz,
  p_product_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
declare
  v_shop_id     uuid;
  v_product_ids uuid[];
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  v_shop_id := public.current_shop_id();
  if v_shop_id is null then
    raise exception 'No active shop for this account' using errcode = '42501';
  end if;

  if public.current_shop_role() is distinct from 'owner' then
    raise exception 'Only the shop owner can change discount settings'
      using errcode = '42501';
  end if;

  if p_is_enabled is null
     or p_scope is null
     or p_percentage is null
     or p_product_ids is null
     or array_position(p_product_ids, null) is not null then
    raise exception 'Incomplete discount settings' using errcode = '22023';
  end if;

  -- Each product once.
  select coalesce(array_agg(distinct requested.product_id), '{}'::uuid[])
  into v_product_ids
  from unnest(p_product_ids) as requested(product_id);

  -- Only this shop's products (the same answer for another shop's product
  -- and for one that does not exist).
  if exists (
    select 1
    from unnest(v_product_ids) as requested(product_id)
    where not exists (
      select 1
      from public.products as product
      where product.id = requested.product_id
        and product.shop_id = v_shop_id
    )
  ) then
    raise exception 'One or more products are not in this shop'
      using errcode = '22023';
  end if;

  if p_is_enabled and p_ends_at is not null and p_ends_at <= now() then
    raise exception 'A discount that is switched on cannot end in the past'
      using errcode = 'SMD04';
  end if;

  if p_scope = 'selected_products' then
    if p_is_enabled and cardinality(v_product_ids) = 0 then
      raise exception 'Select at least one product for this discount'
        using errcode = 'SMD03';
    end if;

    -- create_sale's rule: round(price * percentage / 100, 2) off the
    -- current price, never below the current cost. No names, prices or
    -- costs in the message.
    if exists (
      select 1
      from public.products as product
      where product.shop_id = v_shop_id
        and product.is_active = true
        and product.id = any (v_product_ids)
        and round(product.selling_price * p_percentage / 100, 2) > 0
        and product.selling_price
              - round(product.selling_price * p_percentage / 100, 2)
            < product.cost_price
    ) then
      raise exception 'Discount cannot be applied to one or more products.'
        using errcode = 'SMD02';
    end if;
  end if;

  -- The configuration first: this locks the shop's row until commit.
  -- Audit fields are stamped by the table's trigger.
  insert into public.shop_discount_settings (
    shop_id, is_enabled, scope, percentage, ends_at
  )
  values (v_shop_id, p_is_enabled, p_scope, p_percentage, p_ends_at)
  on conflict (shop_id) do update
  set is_enabled = excluded.is_enabled,
      scope      = excluded.scope,
      percentage = excluded.percentage,
      ends_at    = excluded.ends_at;

  -- Then the selection becomes exactly v_product_ids (kept even while the
  -- scope is all products, as the app shows it).
  delete from public.shop_discount_products as selected
  where selected.shop_id = v_shop_id
    and selected.product_id <> all (v_product_ids);

  insert into public.shop_discount_products (shop_id, product_id)
  select v_shop_id, requested.product_id
  from unnest(v_product_ids) as requested(product_id)
  order by requested.product_id
  on conflict (shop_id, product_id) do nothing;
end;
$function$;

revoke all on function public.save_discount_settings(boolean, text, numeric, timestamptz, uuid[])
  from public, anon, service_role;
grant execute on function public.save_discount_settings(boolean, text, numeric, timestamptz, uuid[])
  to authenticated;

comment on function public.save_discount_settings(boolean, text, numeric, timestamptz, uuid[]) is
  'Owner only: saves the caller''s shop discount configuration and selected products in one transaction. 42501 not the owner; 22023 incomplete or another shop''s product; SMD02 below cost; SMD03 no products; SMD04 ends in the past.';
