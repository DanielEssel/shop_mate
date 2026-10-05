create table public.credit_sale_idempotency (
  shop_id uuid not null references public.shops(id) on delete restrict,
  idempotency_key uuid not null,
  request_fingerprint jsonb not null,
  sale_id uuid not null,
  created_at timestamptz not null default now(),
  constraint credit_sale_idempotency_pkey
    primary key (shop_id, idempotency_key),
  constraint credit_sale_idempotency_sale_shop_fkey
    foreign key (sale_id, shop_id)
    references public.sales (id, shop_id) on delete restrict
);

alter table public.credit_sale_idempotency enable row level security;

revoke all privileges on table public.credit_sale_idempotency
  from public, anon, authenticated;

comment on table public.credit_sale_idempotency is
  'Private shop-scoped request keys for credit-sale creation, including zero-payment sales.';

create function public.create_credit_sale_with_initial_payment(
  p_customer_id uuid,
  p_initial_payment_amount numeric,
  p_initial_payment_method text,
  p_items jsonb,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_shop_id uuid;
  v_existing_sale_id uuid;
  v_existing_request_fingerprint jsonb;
  v_request_fingerprint jsonb;
  v_sale_id uuid;
  v_sale_customer_id uuid;
  v_total_amount numeric(12, 2);
  v_payment_id uuid;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  v_shop_id := public.current_shop_id();

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if p_idempotency_key is null then
    raise exception 'Idempotency key is required';
  end if;

  v_request_fingerprint := jsonb_build_object(
    'p_customer_id', p_customer_id,
    'p_initial_payment_amount', p_initial_payment_amount,
    'p_initial_payment_method', p_initial_payment_method,
    'p_items', p_items
  );

  -- Serialize same-shop retries, including successful sales with no payment row.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(v_shop_id::text),
    pg_catalog.hashtext(p_idempotency_key::text)
  );

  select request.sale_id, request.request_fingerprint
  into
    v_existing_sale_id,
    v_existing_request_fingerprint
  from public.credit_sale_idempotency as request
  where request.shop_id = v_shop_id
    and request.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_request_fingerprint is distinct from v_request_fingerprint then
      raise exception 'Idempotency key has already been used with a different credit-sale request';
    end if;

    return v_existing_sale_id;
  end if;

  if p_customer_id is null then
    raise exception 'Customer is required for a credit sale';
  end if;

  if p_initial_payment_amount is null
     or p_initial_payment_amount < 0
     or p_initial_payment_amount >= 10000000000
     or p_initial_payment_amount <> round(p_initial_payment_amount, 2) then
    raise exception 'Initial payment must be nonnegative and have at most two decimal places';
  end if;

  if p_initial_payment_amount = 0 then
    if p_initial_payment_method is not null then
      raise exception 'Initial payment method must be null when no payment is made';
    end if;
  elsif p_initial_payment_method is null
     or p_initial_payment_method not in ('cash', 'mobile_money', 'card', 'bank_transfer') then
    raise exception 'A valid tender method is required for an initial payment';
  end if;

  if not exists (
    select 1
    from public.customers as customer
    where customer.id = p_customer_id
      and customer.shop_id = v_shop_id
      and customer.is_active = true
  ) then
    raise exception 'Customer % not found or inactive', p_customer_id;
  end if;

  -- Delegate all sale, item, and inventory work to the existing transaction.
  v_sale_id := public.create_sale(
    p_customer_id,
    'credit',
    p_initial_payment_amount,
    p_items
  );

  select sale.customer_id, sale.total_amount
  into v_sale_customer_id, v_total_amount
  from public.sales as sale
  where sale.id = v_sale_id
    and sale.shop_id = v_shop_id;

  if not found or v_sale_customer_id is distinct from p_customer_id then
    raise exception 'Created sale could not be verified for this customer and shop';
  end if;

  if p_initial_payment_amount > v_total_amount then
    raise exception 'Initial payment (%) exceeds sale total (%)',
      p_initial_payment_amount,
      v_total_amount;
  end if;

  if p_initial_payment_amount > 0 then
    insert into public.customer_payments (
      shop_id,
      customer_id,
      amount,
      payment_method,
      paid_at,
      created_by,
      idempotency_key
    )
    values (
      v_shop_id,
      p_customer_id,
      p_initial_payment_amount,
      p_initial_payment_method,
      now(),
      auth.uid(),
      p_idempotency_key
    )
    returning id into v_payment_id;

    insert into public.customer_payment_allocations (
      shop_id,
      payment_id,
      sale_id,
      amount
    )
    values (
      v_shop_id,
      v_payment_id,
      v_sale_id,
      p_initial_payment_amount
    );
  end if;

  insert into public.credit_sale_idempotency (
    shop_id,
    idempotency_key,
    request_fingerprint,
    sale_id
  )
  values (
    v_shop_id,
    p_idempotency_key,
    v_request_fingerprint,
    v_sale_id
  );

  return v_sale_id;
end;
$function$;

revoke all privileges on function public.create_credit_sale_with_initial_payment(
  uuid, numeric, text, jsonb, uuid
) from public, anon, authenticated;
grant execute on function public.create_credit_sale_with_initial_payment(
  uuid, numeric, text, jsonb, uuid
) to authenticated;

comment on function public.create_credit_sale_with_initial_payment(
  uuid, numeric, text, jsonb, uuid
) is
  'Creates a credit sale through create_sale and atomically records any initial customer payment and allocation.';