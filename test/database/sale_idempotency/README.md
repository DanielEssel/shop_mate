# Sale idempotency (Batch 4) database tests

Checks `supabase/migrations/20261014090000_sale_idempotency.sql` on a
throwaway local Postgres. Nothing here touches the live Supabase project.

- `run.sh` creates its own cluster, loads the live schema shared with the
  discount suite (`../discounts/setup.sql`), applies the deployed
  payment-ledger and credit-sale migrations and the discount migration,
  runs `pre.sql`, then applies the idempotency migration in a single
  transaction (as `supabase db push` does; the migration refuses to run
  otherwise), runs `cases.sql`, and finally `concurrency.sh`.
- `pre.sql` captures fingerprints of `create_sale` and
  `create_credit_sale_with_initial_payment` (definition and EXECUTE grants)
  and of `credit_sale_idempotency`'s columns before the migration, so
  `cases.sql` can prove the migration left them unchanged.
- `cases.sql` runs every check in one transaction, prints PASS/FAIL per case
  and a total, and rolls back. It covers the first request and its replay
  (same sale id, `replayed = true`, no second sale, stock moved once),
  decimal amounts, replays after the price, discount or stock changed, the
  SMI01 conflict for each changed field (customer, method, amount, items,
  quantities, line order), failed sales leaving no key and a corrected
  retry succeeding, a forced rollback after the sale insert, credit and
  null-key refusals, unauthenticated, attendant and cross-shop access, no
  table access for API roles, RLS, function security settings, and the
  lookup (standard and credit keys, other shops, unknown keys).
- `concurrency.sh` runs two checks with separate sessions:
  - A: two identical requests with the same key while a third session holds
    the product row lock. Exactly one sale must be recorded; the second
    request must replay it.
  - B: the lookup for a key whose request is still in flight must wait for
    it and report the sale, not answer early with nothing.
  If a session never reaches the expected lock wait it reports
  INCONCLUSIVE rather than passing.

Run: `PG_BIN=<postgres bin dir> test/database/sale_idempotency/run.sh`
(`MIGRATION=<file>` tests a variant of the migration).
Exit status: 0 when every check passes; non-zero on any failure (2 if a
concurrency check was inconclusive).

Negative controls used during development (scratch copies of the
migration, not in the repo): without the advisory lock in
`create_sale_idempotent`, checks A (duplicate key) and B fail (the lookup
waits on that same lock, so it answers early); without the locks in
`find_sale_by_idempotency_key`, check B fails (it answers early with
nothing); without the fingerprint comparison, the 2 conflict cases fail
(one of them covers all six changed fields). In each control the other
`cases.sql` checks still pass.

Not covered here: two devices ringing up the same purchase use different
keys and are two requests (out of scope by design).
