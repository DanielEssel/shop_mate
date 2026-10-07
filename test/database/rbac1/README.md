# RBAC-1 database tests

Checks `supabase/migrations/20261011090000_rbac1_enforce_shop_roles.sql` on a
throwaway local Postgres. Nothing here touches the live Supabase project.

- `setup.sql` recreates the live schema the migration depends on (columns,
  constraints, RLS policies and Supabase's broad default grants, as read from
  the live database), plus test accounts for two shops and a suspended shop.
  `create_sale`, `adjust_stock` and `get_dashboard_summary` are stand-ins that
  follow the reviewed live behaviour; their real bodies live only in the live
  database.
- `cases.sql` runs every check inside one transaction, prints PASS/FAIL per
  case and a total, and rolls back.

Run: `PG_BIN=<postgres bin dir> test/database/rbac1/run.sh`
(`SKIP_RBAC1=1` runs the same checks without the migration; the enforcement
checks should then fail.)
