create function public.get_inventory_report()
returns table (
  total_products bigint,
  total_units numeric,
  inventory_cost_value numeric,
  potential_selling_value numeric,
  expected_gross_profit numeric,
  low_stock_count bigint,
  out_of_stock_count bigint,
  units_purchased numeric,
  units_sold numeric
)
language plpgsql
stable
security definer
set search_path = public
as $function$
declare
  v_shop_id uuid := public.current_shop_id();
  v_total_products bigint := 0;
  v_total_units numeric := 0;
  v_inventory_cost_value numeric := 0;
  v_potential_selling_value numeric := 0;
  v_low_stock_count bigint := 0;
  v_out_of_stock_count bigint := 0;
  v_units_purchased numeric := 0;
  v_units_sold numeric := 0;
begin
  if auth.uid() is null then
    raise exception 'Authentication is required';
  end if;

  if v_shop_id is null then
    raise exception 'No active shop for this account';
  end if;

  -- Stock on hand for active products only; deleted products are soft-deleted
  -- with is_active = false, matching the app's product and inventory lists.
  -- Stock and prices are NOT NULL and nonnegative by table constraints, and
  -- valuation uses current product prices.
  select
    count(*),
    coalesce(sum(product.stock_quantity), 0),
    coalesce(sum(product.stock_quantity * product.cost_price), 0),
    coalesce(sum(product.stock_quantity * product.selling_price), 0),
    count(*) filter (
      where product.stock_quantity > 0
        and product.stock_quantity <= product.low_stock_threshold
    ),
    count(*) filter (where product.stock_quantity = 0)
  into
    v_total_products,
    v_total_units,
    v_inventory_cost_value,
    v_potential_selling_value,
    v_low_stock_count,
    v_out_of_stock_count
  from public.products as product
  where product.shop_id = v_shop_id
    and product.is_active = true;

  -- All completed purchases for the shop, across all dates.
  select coalesce(sum(item.quantity), 0)
  into v_units_purchased
  from public.purchase_items as item
  join public.purchases as purchase
    on purchase.id = item.purchase_id
   and purchase.shop_id = v_shop_id
  where item.shop_id = v_shop_id
    and purchase.status = 'completed';

  -- All sales for the shop, across all dates; credit sales count like any
  -- other sale.
  select coalesce(sum(item.quantity), 0)
  into v_units_sold
  from public.sale_items as item
  join public.sales as sale
    on sale.id = item.sale_id
   and sale.shop_id = v_shop_id
  where item.shop_id = v_shop_id;

  return query
    select
      v_total_products,
      v_total_units,
      v_inventory_cost_value,
      v_potential_selling_value,
      v_potential_selling_value - v_inventory_cost_value,
      v_low_stock_count,
      v_out_of_stock_count,
      v_units_purchased,
      v_units_sold;
end;
$function$;

revoke all privileges on function public.get_inventory_report()
  from public, anon, authenticated;
grant execute on function public.get_inventory_report()
  to authenticated;

comment on function public.get_inventory_report() is
  'Read-only stock-on-hand valuation at current product prices plus all-time completed-purchase and sold units for the caller active shop.';
