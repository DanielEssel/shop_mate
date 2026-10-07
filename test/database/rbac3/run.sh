#!/usr/bin/env bash
# RBAC-3A database tests on a throwaway local Postgres (15+).
# Never point this at the live project: it creates and drops its own cluster.
#
#   PG_BIN=/path/to/postgres/bin test/database/rbac3/run.sh
#   PG_BIN=... SKIP_RBAC3A=1 test/database/rbac3/run.sh   # negative control
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
M="$HERE/../../../supabase/migrations"
PG_BIN="${PG_BIN:?set PG_BIN to a directory containing initdb, pg_ctl and psql}"
DATA="$(mktemp -d)/pgdata"
PORT="${PORT:-54334}"

"$PG_BIN/initdb" -D "$DATA" -U postgres --auth=trust >/dev/null
"$PG_BIN/pg_ctl" -D "$DATA" -o "-p $PORT -k $DATA -c listen_addresses=''" \
  -l "$DATA/log" start -w >/dev/null
trap '"$PG_BIN/pg_ctl" -D "$DATA" stop -m fast >/dev/null 2>&1 || true; rm -rf "$(dirname "$DATA")"' EXIT
PSQL=("$PG_BIN/psql" -h "$DATA" -p "$PORT" -U postgres -d postgres -X -q -v ON_ERROR_STOP=1)

"${PSQL[@]}" -f "$HERE/setup.sql"
if [[ -z "${SKIP_RBAC3A:-}" ]]; then
  echo "== applying 20261012090000_rbac3a_shop_attendant_accounts.sql"
  "${PSQL[@]}" -f "$M/20261012090000_rbac3a_shop_attendant_accounts.sql"
fi
"${PSQL[@]}" -f "$HERE/cases.sql"
