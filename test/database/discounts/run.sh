#!/usr/bin/env bash
# Discount Settings (Batch 1) database tests on a throwaway local Postgres
# (15+). Never point this at the live project: it creates and drops its own
# cluster.
#
#   PG_BIN=/path/to/postgres/bin test/database/discounts/run.sh
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
M="$HERE/../../../supabase/migrations"
PG_BIN="${PG_BIN:?set PG_BIN to a directory containing initdb, pg_ctl and psql}"
DATA="$(mktemp -d)/pgdata"
PORT="${PORT:-54337}"

"$PG_BIN/initdb" -D "$DATA" -U postgres --auth=trust >/dev/null
# TCP on localhost: the socket path under a long temp directory can exceed
# the 107-byte limit.
"$PG_BIN/pg_ctl" -D "$DATA" -o "-p $PORT -k '' -c listen_addresses=127.0.0.1" \
  -l "$DATA/log" start -w >/dev/null
trap '"$PG_BIN/pg_ctl" -D "$DATA" stop -m fast >/dev/null 2>&1 || true; rm -rf "$(dirname "$DATA")"' EXIT
PSQL=("$PG_BIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -X -q -v ON_ERROR_STOP=1)

"${PSQL[@]}" -f "$HERE/setup.sql"
# The repo migrations the sale functions depend on, as deployed.
for migration in \
  20261003090000_customer_payment_ledger.sql \
  20261003110000_create_credit_sale_with_initial_payment.sql; do
  echo "== applying $migration"
  "${PSQL[@]}" -f "$M/$migration"
done
echo "== recording pre-migration sales"
"${PSQL[@]}" -f "$HERE/history.sql"
# One transaction, as `supabase db push` runs a migration file (the
# migration refuses to run otherwise).
echo "== applying 20261013090000_discount_settings.sql (single transaction)"
"${PSQL[@]}" --single-transaction -f "$M/20261013090000_discount_settings.sql"
"${PSQL[@]}" -f "$HERE/cases.sql"

# ---------------------------------------------------------------------------
# Two-session check: the selected-products list is read once per sale.
#   H holds Oil's row lock; sale S (Rice, then Oil) reads the configuration,
#   prices Rice, then waits on Oil. While S waits, the owner's change
#   (removing Oil from the selection) commits. H releases; S finishes Oil.
#   Oil must still get the discount from the list S started with.
# ---------------------------------------------------------------------------
echo "== concurrency: selection change during a multi-line sale"
OUT="$(dirname "$DATA")"
SHOP_A=aaaaaaaa-0000-0000-0000-000000000000
RICE=a0000000-0000-0000-0000-000000000001
OIL=a0000000-0000-0000-0000-000000000002
"${PSQL[@]}" -c "
  insert into public.shop_discount_settings (shop_id, is_enabled, scope, percentage)
  values ('$SHOP_A', true, 'selected_products', 10);
  insert into public.shop_discount_products (shop_id, product_id)
  values ('$SHOP_A', '$RICE'), ('$SHOP_A', '$OIL');"

"${PSQL[@]}" -c "begin; select 1 from public.products where id = '$OIL' for update;
  select pg_sleep(8); commit;" >/dev/null 2>&1 &
HOLDER=$!
for _ in $(seq 1 50); do
  held=$("${PSQL[@]}" -A -t -c "select count(*) from pg_stat_activity
    where query like '%pg_sleep(8)%' and state = 'active' and pid <> pg_backend_pid()")
  [[ "$held" == 1 ]] && break
  sleep 0.1
done

"${PSQL[@]}" -A -t -c "set role authenticated;
  select set_config('test.uid', '0000000a-0000-0000-0000-000000000001', false);
  select public.create_sale(null, 'cash', 50,
    '[{\"product_id\": \"$RICE\", \"quantity\": 1}, {\"product_id\": \"$OIL\", \"quantity\": 1}]'::jsonb);" \
  >"$OUT/sale.out" 2>&1 &
SALE=$!

waiting=0
for _ in $(seq 1 60); do
  waiting=$("${PSQL[@]}" -A -t -c "select count(*) from pg_stat_activity
    where wait_event_type = 'Lock' and query like '%create_sale%' and pid <> pg_backend_pid()")
  [[ "$waiting" == 1 ]] && break
  sleep 0.1
done

if [[ "$waiting" == 1 ]]; then
  "${PSQL[@]}" -c "delete from public.shop_discount_products where product_id = '$OIL';"
fi
wait "$HOLDER" || true
wait "$SALE" || true

if [[ "$waiting" != 1 ]]; then
  echo "concurrency: INCONCLUSIVE (the sale never waited on Oil's lock)"
  exit 2
fi
SALE_ID=$(grep -Eo '[0-9a-f-]{36}' "$OUT/sale.out" | tail -1 || true)
RESULT=$("${PSQL[@]}" -A -t -c "
  select coalesce(string_agg(p.name || '=' || i.discount_percentage, ',' order by p.name), 'no sale')
  from public.sale_items i join public.products p on p.id = i.product_id
  where i.sale_id = nullif('$SALE_ID', '')::uuid;")
SELECTION=$("${PSQL[@]}" -A -t -c "select string_agg(product_id::text, ',')
  from public.shop_discount_products")
echo "concurrency: sale lines: $RESULT; selection after the change: $SELECTION"
if [[ "$RESULT" == "Oil 1L=10.00,Rice 1kg=10.00" && "$SELECTION" == "$RICE" ]]; then
  echo "concurrency: PASS (both lines used the selection read at the start of the sale)"
else
  echo "concurrency: FAIL"
  exit 1
fi
