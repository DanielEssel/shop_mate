#!/usr/bin/env bash
# RBAC-1 database regression tests on a throwaway local Postgres (15+).
# Never point this at the live project: it creates and drops its own cluster.
#
#   PG_BIN=/path/to/postgres/bin test/database/rbac1/run.sh
#   PG_BIN=... SKIP_RBAC1=1 test/database/rbac1/run.sh   # negative control
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
M="$HERE/../../../supabase/migrations"
PG_BIN="${PG_BIN:?set PG_BIN to a directory containing initdb, pg_ctl and psql}"
DATA="$(mktemp -d)/pgdata"
PORT="${PORT:-54331}"

"$PG_BIN/initdb" -D "$DATA" -U postgres --auth=trust >/dev/null
"$PG_BIN/pg_ctl" -D "$DATA" -o "-p $PORT -k $DATA -c listen_addresses=''" \
  -l "$DATA/log" start -w >/dev/null
trap '"$PG_BIN/pg_ctl" -D "$DATA" stop -m fast >/dev/null 2>&1 || true; rm -rf "$(dirname "$DATA")"' EXIT
PSQL=("$PG_BIN/psql" -h "$DATA" -p "$PORT" -U postgres -d postgres -X -q -v ON_ERROR_STOP=1)

# Stand-in for the live schema, then the repo migrations it depends on.
"${PSQL[@]}" -f "$HERE/setup.sql"
migrations=(
  20261004090000_create_expenses.sql
  20261004120000_get_business_performance.sql
  20261005090000_get_inventory_report.sql
  20261006090000_create_suppliers.sql
)
if [[ -z "${SKIP_RBAC1:-}" ]]; then
  migrations+=(20261011090000_rbac1_enforce_shop_roles.sql)
fi
for f in "${migrations[@]}"; do
  echo "== applying $f"
  "${PSQL[@]}" -f "$M/$f"
done
"${PSQL[@]}" -f "$HERE/cases.sql"
