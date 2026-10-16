-- Sales made BEFORE the discount migration, with the live create_sale and the
-- credit-sale function: the "existing production rows" the backfill must
-- keep. Their values are copied into t_history_* for comparison afterwards.
\set ON_ERROR_STOP on

select set_config('test.uid', '0000000a-0000-0000-0000-000000000001', false);

create table public.t_history_ids (name text primary key, sale_id uuid not null);

-- H1: cash, Rice x2 + Oil x1, paid 50.00. Its twin after the migration (no
-- discount configured) must come out identical.
insert into public.t_history_ids
select 'h1_cash', public.create_sale(
  null, 'cash', 50.00,
  '[{"product_id": "a0000000-0000-0000-0000-000000000001", "quantity": 2},
    {"product_id": "a0000000-0000-0000-0000-000000000002", "quantity": 1}]'::jsonb);

-- H2: credit with an initial payment, Soap x4, paid 5.00.
insert into public.t_history_ids
select 'h2_credit', public.create_credit_sale_with_initial_payment(
  'c0000000-0000-0000-0000-00000000000a', 5.00, 'cash',
  '[{"product_id": "a0000000-0000-0000-0000-000000000005", "quantity": 4}]'::jsonb,
  'e0000000-0000-0000-0000-000000000001');

select set_config('test.uid', '', false);

create table public.t_history_sales as
select s.id, s.total_amount, s.amount_paid, s.change_amount, s.payment_method, s.customer_id
from public.sales as s;

create table public.t_history_items as
select i.id, i.sale_id, i.product_id, i.product_name, i.quantity, i.unit_price, i.cost_price, i.subtotal
from public.sale_items as i;

create table public.t_history_movements as
select m.id, m.product_id, m.quantity, m.previous_quantity, m.new_quantity, m.reference_id
from public.stock_movements as m;
