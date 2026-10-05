create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete restrict,
  category text not null check (
    category in (
      'rent',
      'utilities',
      'transport',
      'salaries',
      'supplies',
      'maintenance',
      'marketing',
      'communication',
      'other'
    )
  ),
  amount numeric(12, 2) not null check (amount > 0),
  payment_method text not null check (
    payment_method in ('cash', 'mobile_money', 'card', 'bank_transfer')
  ),
  expense_date date not null,
  reference text,
  note text,
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  idempotency_key uuid not null,
  constraint expenses_shop_idempotency_key_key
    unique (shop_id, idempotency_key)
);

create index expenses_shop_expense_date_idx
  on public.expenses (shop_id, expense_date desc, created_at desc);

create index expenses_shop_category_expense_date_idx
  on public.expenses (shop_id, category, expense_date desc);

alter table public.expenses enable row level security;

create policy expenses_select_current_shop
  on public.expenses
  for select
  to authenticated
  using (shop_id = public.current_shop_id());

revoke all privileges on table public.expenses
  from anon, authenticated;
grant select on table public.expenses to authenticated;

comment on table public.expenses is
  'Shop operating expenses; recorded only through record_expense and independent of sales, purchases, inventory, and customer balances.';

create function public.record_expense(
  p_category text,
  p_amount numeric,
  p_payment_method text,
  p_expense_date date,
  p_reference text,
  p_note text,
  p_idempotency_key uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
  v_expense_id uuid;
  v_existing_category text;
  v_existing_amount numeric(12, 2);
  v_existing_method text;
  v_existing_expense_date date;
  v_existing_reference text;
  v_existing_note text;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if p_category is null
     or p_category not in (
       'rent',
       'utilities',
       'transport',
       'salaries',
       'supplies',
       'maintenance',
       'marketing',
       'communication',
       'other'
     ) then
    raise exception 'Invalid expense category: %', p_category;
  end if;

  if p_amount is null
     or p_amount <= 0
     or p_amount >= 10000000000
     or p_amount <> round(p_amount, 2) then
    raise exception 'Expense amount must be positive and have at most two decimal places';
  end if;

  if p_payment_method is null
     or p_payment_method not in ('cash', 'mobile_money', 'card', 'bank_transfer') then
    raise exception 'Invalid payment method: %', p_payment_method;
  end if;

  if p_expense_date is null then
    raise exception 'Expense date is required';
  end if;

  if p_idempotency_key is null then
    raise exception 'Idempotency key is required';
  end if;

  -- Serialize retries for this shop/key so a duplicate request returns the original expense.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(v_shop_id::text),
    pg_catalog.hashtext(p_idempotency_key::text)
  );

  select
    expense.id,
    expense.category,
    expense.amount,
    expense.payment_method,
    expense.expense_date,
    expense.reference,
    expense.note
  into
    v_expense_id,
    v_existing_category,
    v_existing_amount,
    v_existing_method,
    v_existing_expense_date,
    v_existing_reference,
    v_existing_note
  from public.expenses as expense
  where expense.shop_id = v_shop_id
    and expense.idempotency_key = p_idempotency_key;

  if found then
    if v_existing_category is distinct from p_category
       or v_existing_amount is distinct from p_amount
       or v_existing_method is distinct from p_payment_method
       or v_existing_expense_date is distinct from p_expense_date
       or v_existing_reference is distinct from p_reference
       or v_existing_note is distinct from p_note then
      raise exception 'Idempotency key was already used for a different expense';
    end if;

    return v_expense_id;
  end if;

  insert into public.expenses (
    shop_id,
    category,
    amount,
    payment_method,
    expense_date,
    reference,
    note,
    created_by,
    idempotency_key
  )
  values (
    v_shop_id,
    p_category,
    p_amount,
    p_payment_method,
    p_expense_date,
    p_reference,
    p_note,
    auth.uid(),
    p_idempotency_key
  )
  returning id into v_expense_id;

  return v_expense_id;
end;
$function$;

revoke all privileges on function public.record_expense(
  text, numeric, text, date, text, text, uuid
) from public, anon, authenticated;
grant execute on function public.record_expense(
  text, numeric, text, date, text, text, uuid
) to authenticated;

comment on function public.record_expense(
  text, numeric, text, date, text, text, uuid
) is
  'Idempotently records one expense in the caller active shop; does not touch sales, purchases, inventory, or customer payments.';
