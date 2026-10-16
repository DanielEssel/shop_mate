# Discount Settings (Batch 1) database tests

Checks `supabase/migrations/20261013090000_discount_settings.sql` on a
throwaway local Postgres. Nothing here touches the live Supabase project.

- `setup.sql` recreates what the migration builds on, from the live export of
  2026-10-15: Supabase's roles, `auth.users`, `shops`, `shop_members`, and
  `customers`, `products`, `sales`, `sale_items`, `stock_movements` with their
  live columns, constraints, indexes, triggers, policies and grants. The live
  bodies of `create_sale`, `get_dashboard_summary`,
  `get_dashboard_summary_internal`, `current_shop_id`, `current_shop_role`
  and `update_updated_at` are copied verbatim, with their live EXECUTE
  grants. Product categories are left out (not used by discounts).
- `run.sh` then applies the deployed payment-ledger and credit-sale
  migrations from the repo, records pre-migration sales with the live
  functions (`history.sql`), applies the discount migration in a single
  transaction (as `supabase db push` does; the migration refuses to run
  otherwise), fingerprints the existing objects (`writes_pre.sql`),
  applies the owner-writes migration (`20261016090000`, also one
  transaction), runs `cases.sql` and `writes.sql`, and finally a
  two-session concurrency check.
- `cases.sql` runs every check in one transaction, prints PASS/FAIL per case
  and a total, and rolls back. It first checks the migration's own
  read-only grants (release gating), then applies the grants of the later
  release-gating migration inside its transaction and checks the owner-only
  policies, pricing, below-cost rules, credit sales, history and dashboard.
- `writes.sql` checks `save_discount_settings`: anon, unauthenticated,
  no-shop, suspended-owner and attendant callers are refused (42501) and
  write nothing; the tables stay read-only even for the owner; the owner
  creates, updates, switches on and off, and changes the selection, all
  read back exactly; sales use what was saved and earlier sales do not
  change; another shop's or an unknown product is refused and each owner
  writes and reads only their own shop; percentage limits, scope, missing
  values, an end date in the past (SMD04), no products (SMD03) and below
  cost (SMD02, computed as `create_sale` does) are refused and a refused
  save changes nothing; function security and grants; and that
  `create_sale`, the credit function, the helpers, triggers, tables,
  policies and grants are unchanged. (The release-gating section of
  `cases.sql` still simulates direct table grants inside its transaction;
  production does not grant them, and those cases show the row policies
  would hold even so.)
- The concurrency check holds a product's row lock in one session while a
  multi-line sale waits on it in another, commits a change to the selected
  products in between, and checks that the sale used the selection it
  started with. If the sale never reaches the lock wait, it reports
  INCONCLUSIVE rather than passing.

Run: `PG_BIN=<postgres bin dir> test/database/discounts/run.sh`
Exit status: 0 when every check passes; non-zero on any failure (2 if the
concurrency check was inconclusive).

Negative controls for `writes.sql` (scratch copies of the owner-writes
migration): without the owner check, 5 checks fail (the attendant can
save); with direct table grants added, the 6 release-gating checks in
`cases.sql` fail; without the SMD02/SMD03 checks, 4 checks fail.

Negative controls used during development (scratch copies, not in the
repo): restoring the live `create_sale` after the migration fails 33 checks
and the concurrency check; restoring the Batch 1.0 `create_sale` (per-line
selection reads, whole-sale below-cost rejection, cost in the message) fails
12 checks and the concurrency check; granting owner writes in the migration
fails the 9 release-gating checks.
