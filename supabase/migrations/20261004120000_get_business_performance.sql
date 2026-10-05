create function public.get_business_performance(
  p_start_date date,
  p_end_date date
)
returns table (
  total_sales numeric,
  total_cogs numeric,
  gross_profit numeric,
  total_expenses numeric,
  net_profit numeric,
  profit_margin numeric,
  sales_count bigint,
  expense_count bigint
)
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
  -- Business dates are UTC calendar days (the database timezone; Ghana is
  -- UTC+0 with no daylight saving). Half-open window, independent of the
  -- session timezone: [start 00:00 UTC, end + 1 day 00:00 UTC).
  v_window_start timestamptz;
  v_window_end timestamptz;
  v_total_sales numeric := 0;
  v_sales_count bigint := 0;
  v_total_cogs numeric := 0;
  v_total_expenses numeric := 0;
  v_expense_count bigint := 0;
  v_gross_profit numeric;
  v_net_profit numeric;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  if p_start_date is null or p_end_date is null then
    raise exception 'Start and end dates are required';
  end if;

  if p_start_date > p_end_date then
    raise exception 'Start date must be on or before end date';
  end if;

  v_window_start := p_start_date::timestamp at time zone 'UTC';
  v_window_end := (p_end_date + 1)::timestamp at time zone 'UTC';

  -- Net sales: every sale in the window, including credit sales, at the
  -- recorded sale total. Sales have no void/cancel status to exclude.
  select coalesce(sum(sale.total_amount), 0), count(*)
  into v_total_sales, v_sales_count
  from public.sales as sale
  where sale.shop_id = v_shop_id
    and sale.created_at >= v_window_start
    and sale.created_at < v_window_end;

  -- COGS: cost recorded on each sale item at the time of sale, never the
  -- product's current cost.
  select coalesce(sum(item.quantity * item.cost_price), 0)
  into v_total_cogs
  from public.sale_items as item
  join public.sales as sale
    on sale.id = item.sale_id
   and sale.shop_id = v_shop_id
  where item.shop_id = v_shop_id
    and sale.created_at >= v_window_start
    and sale.created_at < v_window_end;

  -- Operating expenses only; purchases and customer payments are excluded.
  select coalesce(sum(expense.amount), 0), count(*)
  into v_total_expenses, v_expense_count
  from public.expenses as expense
  where expense.shop_id = v_shop_id
    and expense.expense_date between p_start_date and p_end_date;

  v_gross_profit := v_total_sales - v_total_cogs;
  v_net_profit := v_gross_profit - v_total_expenses;

  return query
    select
      v_total_sales,
      v_total_cogs,
      v_gross_profit,
      v_total_expenses,
      v_net_profit,
      case
        when v_total_sales > 0 then round(v_net_profit / v_total_sales * 100, 2)
        else 0::numeric
      end,
      v_sales_count,
      v_expense_count;
end;
$function$;

revoke all privileges on function public.get_business_performance(date, date)
  from public, anon, authenticated;
grant execute on function public.get_business_performance(date, date)
  to authenticated;

comment on function public.get_business_performance(date, date) is
  'Read-only profit and loss for the caller active shop over an inclusive range of UTC business dates; purchases are not expensed.';
