#!/usr/bin/env bash
# Batch 4 (sale idempotency) database tests on a throwaway local Postgres
# (15+). Never point this at the live project: it creates and drops its own
# cluster.
#
#   PG_BIN=/path/to/postgres/bin test/database/sale_idempotency/run.sh
#   MIGRATION=/path/to/variant.sql ...   # test a variant (negative controls)
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
M="$HERE/../../../supabase/migrations"
SETUP="$HERE/../discounts/setup.sql"
PG_BIN="${PG_BIN:?set PG_BIN to a directory containing initdb, pg_ctl and psql}"
MIGRATION="${MIGRATION:-$M/20261014090000_sale_idempotency.sql}"
DATA="$(mktemp -d)/pgdata"
PORT="${PORT:-54338}"

"$PG_BIN/initdb" -D "$DATA" -U postgres --auth=trust >/dev/null
# TCP on localhost: the socket path under a long temp directory can exceed
# the 107-byte limit.
"$PG_BIN/pg_ctl" -D "$DATA" -o "-p $PORT -k '' -c listen_addresses=127.0.0.1" \
  -l "$DATA/log" start -w >/dev/null
trap '"$PG_BIN/pg_ctl" -D "$DATA" stop -m fast >/dev/null 2>&1 || true; rm -rf "$(dirname "$DATA")"' EXIT
PSQL=("$PG_BIN/psql" -h 127.0.0.1 -p "$PORT" -U postgres -d postgres -X -q -v ON_ERROR_STOP=1)

# The live schema (shared with the discount suite) and the deployed
# migrations the sale functions depend on.
"${PSQL[@]}" -f "$SETUP"
for migration in \
  20261003090000_customer_payment_ledger.sql \
  20261003110000_create_credit_sale_with_initial_payment.sql; do
  "${PSQL[@]}" -f "$M/$migration"
done
"${PSQL[@]}" --single-transaction -f "$M/20261013090000_discount_settings.sql"
"${PSQL[@]}" -f "$HERE/pre.sql"
echo "== applying $(basename "$MIGRATION") (single transaction)"
"${PSQL[@]}" --single-transaction -f "$MIGRATION"
"${PSQL[@]}" -f "$HERE/cases.sql"
"$HERE/concurrency.sh" "${PSQL[@]}"
