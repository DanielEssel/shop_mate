-- Shop-owned product categories.
--
-- * product_categories: one row per category, owned by exactly one shop.
-- * products.category_id: optional link, tenant-safe via a composite FK.
-- * products.category (text, NOT NULL) is kept as a compatibility mirror for
--   app versions that still read/write it; triggers keep it in sync.
-- Categories are archived (is_active = false), never deleted by clients.

-- =============================================================
-- product_categories
-- =============================================================
create table public.product_categories (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null default public.current_shop_id()
    references public.shops(id) on delete restrict,
  name text not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  -- Stored trimmed, 1 to 60 characters.
  constraint product_categories_name_check
    check (
      name = btrim(name)
      and char_length(name) between 1 and 60
    ),
  -- Target for the tenant-safe composite FK from products.
  constraint product_categories_id_shop_id_key
    unique (id, shop_id)
);

-- One ACTIVE category per case-insensitive name per shop. Archived
-- categories do not block a new active category with the same name;
-- restoring an archived duplicate is rejected by this same index.
create unique index product_categories_shop_active_name_uidx
  on public.product_categories (shop_id, lower(name))
  where is_active = true;

create index product_categories_shop_name_idx
  on public.product_categories (shop_id, name);

create trigger product_categories_updated_at
  before update on public.product_categories
  for each row execute function public.update_updated_at();

alter table public.product_categories enable row level security;

-- All active members of the shop can read its categories.
create policy product_categories_select_current_shop
  on public.product_categories
  for select
  to authenticated
  using (shop_id = public.current_shop_id());

-- Only the shop owner creates, renames, archives or restores categories.
create policy product_categories_insert_owner_current_shop
  on public.product_categories
  for insert
  to authenticated
  with check (
    shop_id = public.current_shop_id()
    and public.current_shop_role() = 'owner'
  );

create policy product_categories_update_owner_current_shop
  on public.product_categories
  for update
  to authenticated
  using (
    shop_id = public.current_shop_id()
    and public.current_shop_role() = 'owner'
  )
  with check (
    shop_id = public.current_shop_id()
    and public.current_shop_role() = 'owner'
  );

-- No DELETE policy or privilege: categories are archived, not deleted.
revoke all privileges on table public.product_categories
  from anon, authenticated;
grant select, insert, update on table public.product_categories
  to authenticated;

comment on table public.product_categories is
  'Shop-owned product categories. Owner-managed; archived (is_active = false) instead of deleted.';

-- =============================================================
-- products.category_id
-- =============================================================
alter table public.products
  add column category_id uuid;

-- The category must belong to the product's own shop.
alter table public.products
  add constraint products_category_shop_fkey
    foreign key (category_id, shop_id)
    references public.product_categories (id, shop_id)
    on delete restrict;

create index products_shop_category_idx
  on public.products (shop_id, category_id);

-- =============================================================
-- Backfill existing text categories
-- =============================================================
-- One category per shop per distinct trimmed, case-insensitive value,
-- named with the most common existing spelling (ties: alphabetical).
-- Runs before the sync triggers exist, and with products_updated_at
-- paused, so existing category text and updated_at stay untouched.
insert into public.product_categories (shop_id, name)
select grouped.shop_id, grouped.spellings[1]
from (
  select
    spelling.shop_id,
    spelling.normalized,
    array_agg(spelling.name order by spelling.uses desc, spelling.name) as spellings
  from (
    select
      product.shop_id,
      btrim(product.category) as name,
      lower(btrim(product.category)) as normalized,
      count(*) as uses
    from public.products as product
    where btrim(product.category) <> ''
    group by product.shop_id, btrim(product.category), lower(btrim(product.category))
  ) as spelling
  group by spelling.shop_id, spelling.normalized
) as grouped;

alter table public.products disable trigger products_updated_at;

update public.products as product
set category_id = category.id
from public.product_categories as category
where category.shop_id = product.shop_id
  and lower(category.name) = lower(btrim(product.category));

alter table public.products enable trigger products_updated_at;

-- =============================================================
-- Keep products.category (compatibility mirror) in sync
-- =============================================================
-- * category_id set   -> category = that category's name. A product may
--                        only be linked to an ARCHIVED category if it was
--                        already linked to it.
-- * category_id null  -> category = '' (current app) ...
-- * ... or, when an older app writes category text without category_id,
--   that text is matched to an active category of the same name
--   (case-insensitive); unmatched text is kept as-is, unlinked.
create function public.sync_product_category()
returns trigger
language plpgsql
set search_path = public
as $function$
declare
  v_name text;
  v_active boolean;
  v_category_changed boolean := tg_op = 'INSERT'
    or new.category_id is distinct from old.category_id;
begin
  -- Older app changed only the text: re-link by name (or unlink).
  if tg_op = 'UPDATE'
     and not v_category_changed
     and new.category is distinct from old.category then
    if new.category_id is not null then
      select category.name into v_name
      from public.product_categories as category
      where category.id = new.category_id
        and category.shop_id = new.shop_id;

      -- Text already matches the linked category (e.g. a rename update).
      if v_name is not distinct from new.category then
        return new;
      end if;
    end if;

    new.category := btrim(coalesce(new.category, ''));
    select category.id into new.category_id
    from public.product_categories as category
    where category.shop_id = new.shop_id
      and category.is_active = true
      and lower(category.name) = lower(new.category);
    return new;
  end if;

  if new.category_id is not null then
    select category.name, category.is_active
    into v_name, v_active
    from public.product_categories as category
    where category.id = new.category_id
      and category.shop_id = new.shop_id;

    -- Unknown or other-shop ids are left for the composite FK to reject;
    -- keep the text non-null so that FK error is the one raised.
    if found then
      if v_category_changed and not v_active then
        raise exception 'Category is archived';
      end if;
      new.category := v_name;
    else
      new.category := coalesce(new.category, '');
    end if;
    return new;
  end if;

  -- No category_id.
  if tg_op = 'INSERT'
     and new.category is not null
     and btrim(new.category) <> '' then
    -- Older app inserting with category text only.
    new.category := btrim(new.category);
    select category.id into new.category_id
    from public.product_categories as category
    where category.shop_id = new.shop_id
      and category.is_active = true
      and lower(category.name) = lower(new.category);
  elsif v_category_changed or new.category is null then
    new.category := '';
  end if;

  return new;
end;
$function$;

create trigger products_sync_category
  before insert or update on public.products
  for each row execute function public.sync_product_category();

-- Renaming a category updates the mirror text of its products.
create function public.sync_product_category_name()
returns trigger
language plpgsql
set search_path = public
as $function$
begin
  update public.products as product
  set category = new.name
  where product.category_id = new.id
    and product.shop_id = new.shop_id
    and product.category is distinct from new.name;
  return null;
end;
$function$;

create trigger product_categories_sync_name
  after update of name on public.product_categories
  for each row
  when (old.name is distinct from new.name)
  execute function public.sync_product_category_name();

revoke all privileges on function public.sync_product_category()
  from public, anon, authenticated;
revoke all privileges on function public.sync_product_category_name()
  from public, anon, authenticated;
