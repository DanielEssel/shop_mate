create table public.customer_payments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete restrict,
  customer_id uuid not null references public.customers(id) on delete restrict,
  amount numeric(12, 2) not null check (amount > 0),
  payment_method text not null check (
    payment_method in ('cash', 'mobile_money', 'card', 'bank_transfer')
  ),
  reference text,
  note text,
  paid_at timestamptz not null default now(),
  created_by uuid,
  created_at timestamptz not null default now(),
  idempotency_key uuid not null,
  constraint customer_payments_shop_idempotency_key_key
    unique (shop_id, idempotency_key)
);

create table public.customer_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete restrict,
  payment_id uuid not null
    references public.customer_payments(id) on delete restrict,
  sale_id uuid not null references public.sales(id) on delete restrict,
  amount numeric(12, 2) not null check (amount > 0),
  created_at timestamptz not null default now(),
  constraint customer_payment_allocations_payment_sale_key
    unique (payment_id, sale_id)
);

create index customer_payments_shop_customer_paid_at_idx
  on public.customer_payments (shop_id, customer_id, paid_at desc);

create index customer_payment_allocations_shop_sale_idx
  on public.customer_payment_allocations (shop_id, sale_id);

create index customer_payment_allocations_payment_idx
  on public.customer_payment_allocations (payment_id);

alter table public.customer_payments enable row level security;
alter table public.customer_payment_allocations enable row level security;

create policy customer_payments_select_current_shop
  on public.customer_payments
  for select
  to authenticated
  using (shop_id = public.current_shop_id());

create policy customer_payment_allocations_select_current_shop
  on public.customer_payment_allocations
  for select
  to authenticated
  using (shop_id = public.current_shop_id());

revoke all privileges on table public.customer_payments
  from anon, authenticated;
revoke all privileges on table public.customer_payment_allocations
  from anon, authenticated;
grant select on table public.customer_payments to authenticated;
grant select on table public.customer_payment_allocations to authenticated;

comment on table public.customer_payments is
  'Immutable customer payment receipts; ledger begins with newly recorded payments and does not backfill historical sales.';
comment on table public.customer_payment_allocations is
  'Allocations of customer payment receipts to sales; authoritative for ledger-based sale outstanding amounts.';

create function public.record_customer_payment(
  p_customer_id uuid,
  p_amount numeric,
  p_payment_method text,
  p_paid_at timestamptz,
  p_reference text,
  p_note text,
  p_idempotency_key uuid,
  p_allocations jsonb
)
returns table (
  payment_id uuid,
  customer_id uuid,
  amount numeric(12, 2),
  total_allocated numeric(12, 2)
)
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
  v_verified_customer_id uuid;
  v_sale_ids uuid[];
  v_allocation_amounts numeric[];
  v_allocation_total numeric;
  v_input_count bigint;
  v_unique_sale_count bigint;
  v_sale_id uuid;
  v_sale_customer_id uuid;
  v_sale_payment_method text;
  v_sale_tender_amount numeric(12, 2);
  v_sale_total numeric(12, 2);
  v_previously_allocated numeric;
  v_payment_id uuid;
  v_existing_customer_id uuid;
  v_existing_amount numeric(12, 2);
  v_existing_method text;
  v_existing_paid_at timestamptz;
  v_existing_reference text;
  v_existing_note text;
  v_existing_allocation_count bigint;
  v_existing_allocation_amount numeric(12, 2);
  v_total_allocated numeric(12, 2);
  v_index integer;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if p_customer_id is null then
    raise exception 'Customer is required';
  end if;

  if p_amount is null
     or p_amount <= 0
     or p_amount >= 10000000000
     or p_amount <> round(p_amount, 2) then
    raise exception 'Payment amount must be positive and have at most two decimal places';
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'mobile_money', 'card', 'bank_transfer') then
    raise exception 'Invalid payment method: %', p_payment_method;
  end if;

  if p_idempotency_key is null then
    raise exception 'Idempotency key is required';
  end if;

  if p_allocations is null
     or jsonb_typeof(p_allocations) is distinct from 'array'
     or jsonb_array_length(p_allocations) = 0 then
    raise exception 'At least one sale allocation is required';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_allocations) as item(value)
    where jsonb_typeof(item.value) is distinct from 'object'
       or jsonb_typeof(item.value -> 'sale_id') is distinct from 'string'
       or coalesce(item.value ->> 'sale_id', '') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
       or jsonb_typeof(item.value -> 'amount') is distinct from 'number'
  ) then
    raise exception 'Each allocation must contain a UUID sale_id and numeric amount';
  end if;

  if exists (
    select 1
    from jsonb_to_recordset(p_allocations) as allocation(sale_id uuid, amount numeric)
    where allocation.amount is null
       or allocation.amount <= 0
       or allocation.amount >= 10000000000
       or allocation.amount <> round(allocation.amount, 2)
  ) then
    raise exception 'Allocation amounts must be positive and have at most two decimal places';
  end if;

  select
    array_agg(allocation.sale_id order by allocation.sale_id),
    array_agg(allocation.amount order by allocation.sale_id),
    sum(allocation.amount),
    count(*),
    count(distinct allocation.sale_id)
  into
    v_sale_ids,
    v_allocation_amounts,
    v_allocation_total,
    v_input_count,
    v_unique_sale_count
  from jsonb_to_recordset(p_allocations) as allocation(sale_id uuid, amount numeric);

  if v_input_count <> v_unique_sale_count then
    raise exception 'A sale may appear only once in a payment request';
  end if;

  if v_allocation_total <> p_amount then
    raise exception 'Allocation total must equal payment amount';
  end if;

  -- Inactive customers may settle existing debt; new credit sales enforce active status separately.
  select customer.id
  into v_verified_customer_id
  from public.customers as customer
  where customer.id = p_customer_id
    and customer.shop_id = v_shop_id
  for key share;

  if not found then
    raise exception 'Customer not found for this shop';
  end if;

  -- Serialize retries for this shop/key, including requests with different sale locks.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(v_shop_id::text),
    pg_catalog.hashtext(p_idempotency_key::text)
  );

  select
    payment.id,
    payment.customer_id,
    payment.amount,
    payment.payment_method,
    payment.paid_at,
    payment.reference,
    payment.note
  into
    v_payment_id,
    v_existing_customer_id,
    v_existing_amount,
    v_existing_method,
    v_existing_paid_at,
    v_existing_reference,
    v_existing_note
  from public.customer_payments as payment
  where payment.shop_id = v_shop_id
    and payment.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_customer_id is distinct from p_customer_id
       or v_existing_amount is distinct from p_amount
       or v_existing_method is distinct from p_payment_method
       or (p_paid_at is not null and v_existing_paid_at is distinct from p_paid_at)
       or v_existing_reference is distinct from p_reference
       or v_existing_note is distinct from p_note then
      raise exception 'Idempotency key was already used for a different payment';
    end if;

    select count(*)
    into v_existing_allocation_count
    from public.customer_payment_allocations as allocation
    where allocation.payment_id = v_payment_id
      and allocation.shop_id = v_shop_id;

    if v_existing_allocation_count <> v_input_count then
      raise exception 'Idempotency key was already used with different allocations';
    end if;

    for v_index in 1..cardinality(v_sale_ids)
    loop
      select allocation.amount
      into v_existing_allocation_amount
      from public.customer_payment_allocations as allocation
      where allocation.payment_id = v_payment_id
        and allocation.shop_id = v_shop_id
        and allocation.sale_id = v_sale_ids[v_index];

      if not found
         or v_existing_allocation_amount is distinct from v_allocation_amounts[v_index] then
        raise exception 'Idempotency key was already used with different allocations';
      end if;
    end loop;

    select coalesce(sum(allocation.amount), 0)::numeric(12, 2)
    into v_total_allocated
    from public.customer_payment_allocations as allocation
    where allocation.payment_id = v_payment_id
      and allocation.shop_id = v_shop_id;

    return query
      select v_payment_id, v_existing_customer_id, v_existing_amount, v_total_allocated;
    return;
  end if;

  -- Lock every requested sale in deterministic UUID order before reading its ledger balance.
  for v_sale_id in
    select requested.sale_id
    from unnest(v_sale_ids) as requested(sale_id)
    order by requested.sale_id
  loop
    select sale.customer_id, sale.payment_method, sale.amount_paid, sale.total_amount
    into v_sale_customer_id, v_sale_payment_method, v_sale_tender_amount, v_sale_total
    from public.sales as sale
    where sale.id = v_sale_id
      and sale.shop_id = v_shop_id
    for update;

    if not found then
      raise exception 'Sale % not found for this shop', v_sale_id;
    end if;

    if v_sale_customer_id is distinct from p_customer_id then
      raise exception 'Sale % does not belong to the specified customer', v_sale_id;
    end if;

    if v_sale_payment_method <> 'credit' then
      raise exception 'Sale % is not classified as credit', v_sale_id;
    end if;

    if v_sale_total <= 0 then
      raise exception 'Sale % is not eligible for payment', v_sale_id;
    end if;

    select coalesce(sum(allocation.amount), 0)
    into v_previously_allocated
    from public.customer_payment_allocations as allocation
    where allocation.shop_id = v_shop_id
      and allocation.sale_id = v_sale_id;

    if v_previously_allocated = 0 and v_sale_tender_amount > 0 then
      raise exception 'Sale % has tender that is not represented in the payment ledger', v_sale_id;
    end if;
  end loop;

  for v_index in 1..cardinality(v_sale_ids)
  loop
    select sale.total_amount
    into v_sale_total
    from public.sales as sale
    where sale.id = v_sale_ids[v_index]
      and sale.shop_id = v_shop_id;

    select coalesce(sum(allocation.amount), 0)
    into v_previously_allocated
    from public.customer_payment_allocations as allocation
    where allocation.shop_id = v_shop_id
      and allocation.sale_id = v_sale_ids[v_index];

    if v_allocation_amounts[v_index] > v_sale_total - v_previously_allocated then
      raise exception 'Allocation exceeds outstanding amount for sale %', v_sale_ids[v_index];
    end if;
  end loop;

  insert into public.customer_payments (
    shop_id,
    customer_id,
    amount,
    payment_method,
    reference,
    note,
    paid_at,
    created_by,
    idempotency_key
  )
  values (
    v_shop_id,
    p_customer_id,
    p_amount,
    p_payment_method,
    p_reference,
    p_note,
    coalesce(p_paid_at, now()),
    auth.uid(),
    p_idempotency_key
  )
  returning id into v_payment_id;

  for v_index in 1..cardinality(v_sale_ids)
  loop
    insert into public.customer_payment_allocations (
      shop_id,
      payment_id,
      sale_id,
      amount
    )
    values (
      v_shop_id,
      v_payment_id,
      v_sale_ids[v_index],
      v_allocation_amounts[v_index]
    );
  end loop;

  return query
    select v_payment_id, p_customer_id, p_amount::numeric(12, 2), v_allocation_total::numeric(12, 2);
end;
$function$;

revoke all privileges on function public.record_customer_payment(
  uuid, numeric, text, timestamptz, text, text, uuid, jsonb
) from public, anon, authenticated;
grant execute on function public.record_customer_payment(
  uuid, numeric, text, timestamptz, text, text, uuid, jsonb
) to authenticated;

comment on function public.record_customer_payment(
  uuid, numeric, text, timestamptz, text, text, uuid, jsonb
) is
  'Atomically records and allocates a customer payment within the caller active shop; does not modify sales tender fields or inventory.';