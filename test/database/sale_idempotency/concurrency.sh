#!/usr/bin/env bash
# Two-session checks for create_sale_idempotent and the recovery lookup.
# Called by run.sh with the psql command for the throwaway cluster.
#
#   A. Two identical requests at the same time: session 1 is held inside
#      create_sale (another session holds the product's row lock) while
#      session 2 sends the same key. Exactly one sale may result, and the
#      second response must report replayed = true.
#   B. A lookup while the request is still running waits for it and returns
#      its sale.
# Each check reports INCONCLUSIVE (exit 2) if the sessions never reach the
# intended lock waits, rather than passing.
set -euo pipefail
PSQL=("$@")
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

OWNER=0000000a-0000-0000-0000-000000000001
SHOP_A=aaaaaaaa-0000-0000-0000-000000000000
RICE=a0000000-0000-0000-0000-000000000001
ITEMS="[{\"product_id\": \"$RICE\", \"quantity\": 1}]"

value() { "${PSQL[@]}" -A -t -c "$1"; }

hold_rice() {
  "${PSQL[@]}" -c "begin; select 1 from public.products where id = '$RICE' for update;
    select pg_sleep(6); commit;" >/dev/null 2>&1 &
  HOLDER=$!
  for _ in $(seq 1 50); do
    [[ "$(value "select count(*) from pg_stat_activity where query like '%pg_sleep(6)%'
      and state = 'active' and pid <> pg_backend_pid()")" == 1 ]] && return 0
    sleep 0.1
  done
  return 1
}

as_owner() {
  "${PSQL[@]}" -A -t -c "set role authenticated;
    select set_config('test.uid', '$OWNER', false);
    $1" >"$2" 2>&1 &
}

# Waits until $2 sessions running a query containing $1 wait on a lock.
wait_for_lock_waits() {
  for _ in $(seq 1 60); do
    [[ "$(value "select count(*) from pg_stat_activity where wait_event_type = 'Lock'
      and query like '%$1%' and pid <> pg_backend_pid()")" == "$2" ]] && return 0
    sleep 0.1
  done
  return 1
}

counts() {
  value "select (select count(*) from public.sales where shop_id = '$SHOP_A') || '|' ||
    (select count(*) from public.sale_items where shop_id = '$SHOP_A') || '|' ||
    (select count(*) from public.stock_movements where shop_id = '$SHOP_A') || '|' ||
    (select stock_quantity from public.products where id = '$RICE')"
}

status=0

# ---------------------------------------------------------------- A
KEY_A=33333333-0000-4000-8000-00000000000a
CALL_A="select sale_id::text || '|' || replayed::text from public.create_sale_idempotent('$KEY_A', null, 'cash', 10, '$ITEMS'::jsonb);"
BEFORE="$(counts)"
hold_rice
as_owner "$CALL_A" "$OUT/s1"; S1=$!
waited=0
if wait_for_lock_waits create_sale_idempotent 1; then
  as_owner "$CALL_A" "$OUT/s2"; S2=$!
  wait_for_lock_waits create_sale_idempotent 2 && waited=1
else
  S2=""
fi
wait "$HOLDER" || true
wait "$S1" || true
[[ -n "$S2" ]] && { wait "$S2" || true; }
AFTER="$(counts)"
R1="$(grep -Eo '[0-9a-f-]{36}\|(true|false)' "$OUT/s1" | tail -1 || true)"
R2="$(grep -Eo '[0-9a-f-]{36}\|(true|false)' "$OUT/s2" 2>/dev/null | tail -1 || true)"
IFS='|' read -r b_sales b_items b_moves b_stock <<<"$BEFORE"
EXPECTED="$((b_sales + 1))|$((b_items + 1))|$((b_moves + 1))|$((b_stock - 1))"
KEYS="$(value "select count(*) from public.sale_idempotency where idempotency_key = '$KEY_A'")"
echo "A: session 1: ${R1:-$(tr '\n' ' ' <"$OUT/s1")}"
echo "A: session 2: ${R2:-$(tr '\n' ' ' <"$OUT/s2" 2>/dev/null)}"
echo "A: sales|items|movements|rice stock: before $BEFORE, after $AFTER, expected $EXPECTED; key rows $KEYS"
if [[ "$waited" != 1 ]]; then
  echo "concurrency A: INCONCLUSIVE (the sessions never waited on each other)"
  status=2
elif [[ -n "$R1" && -n "$R2" && "${R1%|*}" == "${R2%|*}" \
        && "$(printf '%s\n%s\n' "${R1#*|}" "${R2#*|}" | sort | tr '\n' ' ')" == "false true " \
        && "$AFTER" == "$EXPECTED" && "$KEYS" == 1 ]]; then
  echo "concurrency A: PASS (one sale, one set of lines, movements and stock change; the second request replayed it)"
else
  echo "concurrency A: FAIL"
  status=1
fi

# ---------------------------------------------------------------- B
KEY_B=33333333-0000-4000-8000-00000000000b
CALL_B="select sale_id::text || '|' || replayed::text from public.create_sale_idempotent('$KEY_B', null, 'cash', 10, '$ITEMS'::jsonb);"
hold_rice
as_owner "$CALL_B" "$OUT/b1"; B1=$!
waited=0
early=""
if wait_for_lock_waits create_sale_idempotent 1; then
  as_owner "select coalesce(public.find_sale_by_idempotency_key('$KEY_B')::text, 'null');" "$OUT/b2"; B2=$!
  if wait_for_lock_waits find_sale_by_idempotency_key 1; then
    waited=1
  elif ! kill -0 "$B2" 2>/dev/null; then
    # The lookup answered while the request was still running: it did not
    # wait for it.
    early="$(grep -Eo '[0-9a-f-]{36}|null' "$OUT/b2" | tail -1 || true)"
  fi
else
  B2=""
fi
wait "$HOLDER" || true
wait "$B1" || true
[[ -n "$B2" ]] && { wait "$B2" || true; }
SALE_B="$(grep -Eo '[0-9a-f-]{36}' "$OUT/b1" | tail -1 || true)"
FOUND_B="$(grep -Eo '[0-9a-f-]{36}|null' "$OUT/b2" 2>/dev/null | tail -1 || true)"
echo "B: in-flight sale $SALE_B; lookup returned $FOUND_B"
if [[ -n "$early" ]]; then
  echo "concurrency B: FAIL (the lookup answered '$early' while the request was still running)"
  status=1
elif [[ "$waited" != 1 ]]; then
  echo "concurrency B: INCONCLUSIVE (the lookup never waited for the request)"
  [[ "$status" == 0 ]] && status=2
elif [[ -n "$SALE_B" && "$FOUND_B" == "$SALE_B" ]]; then
  echo "concurrency B: PASS (the lookup waited for the running request and found its sale)"
else
  echo "concurrency B: FAIL"
  status=1
fi

exit "$status"
