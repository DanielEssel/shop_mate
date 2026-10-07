# RBAC-3A database tests

Checks `supabase/migrations/20261012090000_rbac3a_shop_attendant_accounts.sql`
on a throwaway local Postgres. Nothing here touches the live Supabase project
and no real Auth users are created.

- `setup.sql` recreates what the migration builds on: Supabase's roles,
  `auth.users`, `shops`, `shop_members` (live definition, policies and
  SELECT-only grant) and two history tables with the live foreign-key
  behaviour, plus two shops' worth of owners and attendants.
- `cases.sql` runs every check in one transaction, prints PASS/FAIL per case
  and a total, and rolls back. The Edge Function's database steps are
  exercised as `service_role`, with a new row in `auth.users` standing in for
  Auth Admin `createUser`.

Run: `PG_BIN=<postgres bin dir> test/database/rbac3/run.sh`
(`SKIP_RBAC3A=1` runs the checks without the migration; they cannot pass.)

The Edge Function's request handling is tested separately with Node:
`node --test test/edge_functions/create_shop_attendant_handler.test.ts`
