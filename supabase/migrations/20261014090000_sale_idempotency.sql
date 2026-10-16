-- Batch 4: idempotent non-credit sales, and a read-only lookup for
-- recovering a sale whose outcome the app could not confirm.
--
-- Additive only. create_sale (still used directly by older app builds) and
-- create_credit_sale_with_initial_payment (with credit_sale_idempotency) are
-- NOT changed. A fifth, defaulted parameter on create_sale would make the
-- credit function's four-argument call ambiguous, so the idempotent entry
-- point is a separately named function that wraps create_sale, following
-- the credit function's pattern.
--
-- * sale_idempotency: one row per (shop, request key), written in the same
--   transaction as the sale it recorded. A failed sale leaves no row, so
--   its key can be retried. Rows are kept indefinitely.
-- * create_sale_idempotent(key, customer, method, amount paid, items):
--   returns (sale_id, replayed). The same key with the same request returns
--   the original sale (replayed = true) without repricing or touching stock;
--   the same key with a different request raises SQLSTATE SMI01.
-- * find_sale_by_idempotency_key(key): the sale recorded under a key in the
--   caller's shop (non-credit or credit), or null. It waits for an in-flight
--   request with that key to finish first, but null still cannot prove that
--   a request which has not reached the database will never commit.
--
-- Fingerprint: customer id (null included), payment method, amount paid and
-- the items EXACTLY as sent (jsonb: object key order is irrelevant, array
-- order is significant, numbers compare by value so 20 = 20.00). Prices,
-- discounts and totals are not part of it: a retry is the same request.
-- Clients must store the original payload and resend it unchanged.
--
-- Not deduplicated: separate requests made on different devices for the
-- same real-world purchase have different keys.
--
-- APPLYING: like 20261013090000, apply as one transaction (supabase db push
-- or psql --single-transaction); the guard below refuses otherwise.

-- ===========================================================================
-- Single transaction and lock timeout
-- ===========================================================================
set local lock_timeout = '5s';
set local shopmate.sale_idempotency_migration = 'single-transaction';

do $guard$
begin
  -- SET LOCAL only survives to this statement inside one transaction.
  if current_setting('shopmate.sale_idempotency_migration', true)
     is distinct from 'single-transaction' then
    raise exception
      'Apply 20261014090000_sale_idempotency.sql as one transaction (supabase db push, or psql --single-transaction).';
  end if;
end;
$guard$;

-- ===========================================================================
-- sale_idempotency
-- ===========================================================================
create table public.sale_idempotency (
  shop_id uuid not null references public.shops (id) on delete restrict,
  idempotency_key uuid not null,
  request_fingerprint jsonb not null,
  sale_id uuid not null,
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),

  constraint sale_idempotency_pkey
    primary key (shop_id, idempotency_key),
  -- The recorded sale belongs to the same shop.
  constraint sale_idempotency_sale_shop_fkey
    foreign key (sale_id, shop_id)
    references public.sales (id, shop_id)
    on delete restrict,
  -- One request records one sale.
  constraint sale_idempotency_sale_key
    unique (sale_id)
);

comment on table public.sale_idempotency is
  'Private shop-scoped request keys for non-credit sales (create_sale_idempotent). No API access; kept indefinitely.';

alter table public.sale_idempotency enable row level security;

-- No policies and no grants: only the functions below use it.
revoke all privileges on table public.sale_idempotency
  from public, anon, authenticated;

-- ===========================================================================
-- create_sale_idempotent
-- ===========================================================================
create function public.create_sale_idempotent(
  p_idempotency_key uuid,
  p_customer_id uuid,
  p_payment_method text,
  p_amount_paid numeric,
  p_items jsonb
)
returns table (sale_id uuid, replayed boolean)
language plpgsql
security definer
set search_path = public, pg_temp
as $function$
#variable_conflict use_column
declare
  v_shop_id              uuid;
  v_request_fingerprint  jsonb;
  v_existing_sale_id     uuid;
  v_existing_fingerprint jsonb;
  v_sale_id              uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  v_shop_id := public.current_shop_id();
  if v_shop_id is null then
    raise exception 'No active shop for this account' using errcode = '42501';
  end if;

  if p_idempotency_key is null then
    raise exception 'A request key is required' using errcode = '22023';
  end if;

  -- Credit sales record an initial payment; they keep their own function.
  if p_payment_method = 'credit' then
    raise exception 'Credit sales use create_credit_sale_with_initial_payment'
      using errcode = '22023';
  end if;

  v_request_fingerprint := jsonb_build_object(
    'p_customer_id', p_customer_id,
    'p_payment_method', p_payment_method,
    'p_amount_paid', p_amount_paid,
    'p_items', p_items
  );

  -- Serialise requests with this key in this shop (a different namespace
  -- from the credit function's lock). Held until the transaction ends, so
  -- an identical concurrent request waits and then sees the committed row.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('shopmate.sale_idempotency:' || v_shop_id::text),
    pg_catalog.hashtext(p_idempotency_key::text)
  );

  select request.sale_id, request.request_fingerprint
  into v_existing_sale_id, v_existing_fingerprint
  from public.sale_idempotency as request
  where request.shop_id = v_shop_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_fingerprint is distinct from v_request_fingerprint then
      raise exception 'This request key was already used for a different sale'
        using errcode = 'SMI01';
    end if;
    -- The original sale, as recorded: nothing is repriced or re-stocked.
    return query select v_existing_sale_id, true;
    return;
  end if;

  -- All pricing, discount, stock and payment rules stay in create_sale.
  v_sale_id := public.create_sale(
    p_customer_id,
    p_payment_method,
    p_amount_paid,
    p_items
  );

  -- Same transaction: if this insert fails, the sale is rolled back too.
  insert into public.sale_idempotency (
    shop_id, idempotency_key, request_fingerprint, sale_id, created_by
  )
  values (
    v_shop_id, p_idempotency_key, v_request_fingerprint, v_sale_id, auth.uid()
  );

  return query select v_sale_id, false;
end;
$function$;

revoke all on function public.create_sale_idempotent(uuid, uuid, text, numeric, jsonb)
  from public, anon;
grant execute on function public.create_sale_idempotent(uuid, uuid, text, numeric, jsonb)
  to authenticated, service_role;

comment on function public.create_sale_idempotent(uuid, uuid, text, numeric, jsonb) is
  'Records a non-credit sale at most once per (shop, key) through create_sale. Returns (sale_id, replayed). Same key, different request: SQLSTATE SMI01.';

-- ===========================================================================
-- find_sale_by_idempotency_key
-- ===========================================================================
-- Read-only: it creates, reserves and changes nothing. It takes the same
-- transaction-level locks as create_sale_idempotent and the credit function
-- for this key, so a request with the key that is already running in the
-- database finishes first.
create function public.find_sale_by_idempotency_key(p_key uuid)
returns uuid
language plpgsql
volatile
security definer
set search_path = public, pg_temp
as $function$
declare
  v_shop_id uuid;
  v_sale_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required' using errcode = '42501';
  end if;

  v_shop_id := public.current_shop_id();
  if v_shop_id is null then
    raise exception 'No active shop for this account' using errcode = '42501';
  end if;

  if p_key is null then
    return null;
  end if;

  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext('shopmate.sale_idempotency:' || v_shop_id::text),
    pg_catalog.hashtext(p_key::text)
  );
  -- The credit function's lock for the same key.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(v_shop_id::text),
    pg_catalog.hashtext(p_key::text)
  );

  select request.sale_id
  into v_sale_id
  from public.sale_idempotency as request
  where request.shop_id = v_shop_id
    and request.idempotency_key = p_key;

  if v_sale_id is null then
    select request.sale_id
    into v_sale_id
    from public.credit_sale_idempotency as request
    where request.shop_id = v_shop_id
      and request.idempotency_key = p_key;
  end if;

  return v_sale_id;
end;
$function$;

revoke all on function public.find_sale_by_idempotency_key(uuid)
  from public, anon;
grant execute on function public.find_sale_by_idempotency_key(uuid)
  to authenticated, service_role;

comment on function public.find_sale_by_idempotency_key(uuid) is
  'The sale recorded under a request key in the caller''s shop (non-credit or credit), or null. Read-only; null does not prove a request still in transit cannot commit.';
