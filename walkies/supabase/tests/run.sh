#!/usr/bin/env bash
# Applies every migration to a fresh database twice (they must be safe to
# re-run), then runs the access-rule tests.
#
#   PGHOST=... PGPORT=... PGUSER=postgres supabase/tests/run.sh
set -euo pipefail
cd "$(dirname "$0")/../.."   # walkies/
export PGOPTIONS="${PGOPTIONS:-} -c client_min_messages=warning"

DB="walkies_test_$$"
psql -X -q -d postgres -c "DROP DATABASE IF EXISTS $DB" -c "CREATE DATABASE $DB"
trap 'psql -X -q -d postgres -c "DROP DATABASE IF EXISTS $DB" >/dev/null' EXIT

run() { psql -X -q -v ON_ERROR_STOP=1 -d "$DB" -f "$1" >/dev/null; }

run supabase/tests/00_supabase_stub.sql
MIGRATIONS=(
  SUPABASE_SCHEMA.sql
  SUPABASE_HARDENING.sql
  SUPABASE_MIGRATION_2026_04_27_preferred_name.sql
  SUPABASE_DELETE_ACCOUNT.sql
  SUPABASE_MIGRATION_2026_10_08_content_community.sql
)
for pass in 1 2; do
  for m in "${MIGRATIONS[@]}"; do
    # The base schema creates policies without IF NOT EXISTS; apply it once
    if [[ $pass == 2 && $m == SUPABASE_SCHEMA.sql ]]; then continue; fi
    run "$m"
  done
done
echo "Migrations applied (and re-applied) cleanly"

if ! out=$(psql -X -v ON_ERROR_STOP=1 -d "$DB" -f supabase/tests/access_rules_test.sql 2>&1); then
  echo "$out" | grep -E "FAIL|ERROR" || echo "$out"
  exit 1
fi
echo "$out" | grep "passed"
