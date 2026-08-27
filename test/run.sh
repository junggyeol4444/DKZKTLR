#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
PG_VERSION=${PG_VERSION:-16}
PORT=${PGPORT_TEST:-55432}
DATA=${TMPDIR:-/tmp}/akashic-pg-$PG_VERSION-$$
cleanup(){ [[ ${EXTERNAL_PG:-0} == 1 ]] || runuser -u postgres -- "$(pg_config --bindir)/pg_ctl" -D "$DATA" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$DATA"; }
trap cleanup EXIT

if [[ ${EXTERNAL_PG:-0} != 1 ]]; then
  install -d -o postgres -g postgres "$DATA"
  runuser -u postgres -- "$(pg_config --bindir)/initdb" -D "$DATA" -A trust -U postgres >/dev/null
  runuser -u postgres -- "$(pg_config --bindir)/pg_ctl" -D "$DATA" -o "-p $PORT -k $DATA" -w start >/dev/null
  export PGHOST=$DATA PGPORT=$PORT PGUSER=postgres
fi

createdb akashic_test
psql -v ON_ERROR_STOP=1 -d akashic_test -f "$ROOT/test/bootstrap.sql" >/dev/null
psql -v ON_ERROR_STOP=1 -d akashic_test -f "$ROOT/sql/schema.sql" >/dev/null
psql -v ON_ERROR_STOP=1 -d akashic_test -f "$ROOT/sql/rls.sql" >/dev/null
psql -v ON_ERROR_STOP=1 -d akashic_test -f "$ROOT/sql/seed.sql" >/dev/null
# 002 must also be safe against a database that already has the completed schema;
# this executes the exact migration that previously failed on array_to_string.
psql -v ON_ERROR_STOP=1 -d akashic_test -f "$ROOT/sql/migrations/002_records_completion.sql" >/dev/null
psql -v ON_ERROR_STOP=1 -d akashic_test -f "$ROOT/test/security.sql"
"$ROOT/test/concurrency.sh"
