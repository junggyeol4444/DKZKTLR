#!/usr/bin/env bash
# ============================================================
#  로컬 검증 실행기
#
#  임시 PostgreSQL 클러스터를 만들어 sql/ 3개를 적재하고,
#  Supabase 호환 셔임을 띄운 뒤 헤드리스 Chromium 으로 시나리오를 실행한다.
#  실제 Supabase 프로젝트 없이 RLS·트리거·컬럼 권한을 그대로 통과시킨다.
#
#  준비물: postgresql (initdb, pg_ctl, psql), node, playwright, Chromium
#  준비:   cd test && npm install
#  실행:   ./run.sh            전체
#          ./run.sh core       한 스위트만 (core|lifecycle|ui|related)
# ============================================================
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(dirname "$HERE")"

WORK="${AKASHIC_TEST_WORK:-${TMPDIR:-/tmp}/akashic-test}"
export PGSOCKET="${PGSOCKET:-$WORK/sock}"
export PGPORT_TEST="${PGPORT_TEST:-5439}"
export SHIM_PORT="${SHIM_PORT:-5555}"
export AKASHIC_BASE="${AKASHIC_BASE:-http://127.0.0.1:$SHIM_PORT}"
export AKASHIC_ROOT="$ROOT"
export SHOTS_DIR="${SHOTS_DIR:-$WORK/shots}"
export CHROMIUM="${CHROMIUM:-/opt/pw-browsers/chromium}"
export PLAYWRIGHT="${PLAYWRIGHT:-playwright}"

PGBIN="${PGBIN:-$(dirname "$(command -v initdb || echo /usr/lib/postgresql/16/bin/initdb)")}"
PGDATA_DIR="$WORK/data"

mkdir -p "$WORK" "$PGSOCKET" "$SHOTS_DIR"

db_reset() {
  "$PGBIN/pg_ctl" -D "$PGDATA_DIR" -m fast stop >/dev/null 2>&1 || true
  rm -rf "$PGDATA_DIR"
  "$PGBIN/initdb" -D "$PGDATA_DIR" -U postgres --auth=trust >/dev/null
  "$PGBIN/pg_ctl" -D "$PGDATA_DIR" \
    -o "-p $PGPORT_TEST -k $PGSOCKET" -l "$WORK/pg.log" start >/dev/null
  sleep 2
  for f in "$HERE/bootstrap.sql" "$ROOT/sql/schema.sql" "$ROOT/sql/rls.sql" "$ROOT/sql/seed.sql"; do
    if ! psql -h "$PGSOCKET" -p "$PGPORT_TEST" -U postgres -v ON_ERROR_STOP=1 -q -f "$f" 2>&1 \
         | grep -Ei '^(ERROR|FATAL)'; then :; else
      echo "적재 실패: $f"; exit 1
    fi
  done
}

shim_start() {
  node "$HERE/shim.js" > "$WORK/shim.log" 2>&1 &
  SHIM_PID=$!
  for _ in $(seq 1 20); do
    curl -sf -o /dev/null "$AKASHIC_BASE/index.html" && return 0
    sleep 0.3
  done
  echo "셔임 기동 실패. $WORK/shim.log 확인"; exit 1
}

cleanup() {
  [ -n "${SHIM_PID:-}" ] && kill "$SHIM_PID" 2>/dev/null || true
  "$PGBIN/pg_ctl" -D "$PGDATA_DIR" -m fast stop >/dev/null 2>&1 || true
}
trap cleanup EXIT

SUITES=("core" "lifecycle" "ui" "related" "edge" "scale")
[ $# -gt 0 ] && SUITES=("$@")

FAILED=0
for s in "${SUITES[@]}"; do
  echo ""
  echo "================ suite: $s ================"
  db_reset                       # 스위트마다 깨끗한 시드 상태에서 시작
  [ -n "${SHIM_PID:-}" ] && kill "$SHIM_PID" 2>/dev/null || true
  shim_start
  node "$HERE/suite-$s.js" || FAILED=1
done

echo ""
[ "$FAILED" -eq 0 ] && echo "전체 통과. 스크린샷: $SHOTS_DIR" || echo "실패한 스위트 있음"
exit "$FAILED"
