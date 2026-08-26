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
# SKIP_PG_SETUP=1 이면 이미 떠 있는 데이터베이스에 붙는다 (PGSOCKET 에 호스트명도 가능)
PGDATA_DIR="$WORK/data"

mkdir -p "$WORK" "$SHOTS_DIR"
# 외부 데이터베이스에 붙을 때는 PGSOCKET 이 소켓 디렉터리가 아니라 호스트명이다
[ "${SKIP_PG_SETUP:-0}" = "1" ] || mkdir -p "$PGSOCKET"

load_sql() {
  # psql 은 오류를 'psql:<파일>:<줄>: ERROR: ...' 로 찍는다.
  # 줄머리를 기준으로 찾으면 아무것도 걸리지 않아 실패가 성공으로 보고된다.
  # 종료 상태를 먼저 보고, 출력에 남은 오류도 함께 확인한다.
  local out
  for f in "$HERE/bootstrap.sql" "$ROOT/sql/schema.sql" "$ROOT/sql/rls.sql" "$ROOT/sql/seed.sql"; do
    if ! out=$(psql -h "$PGSOCKET" -p "$PGPORT_TEST" -U postgres \
                    -v ON_ERROR_STOP=1 -q -f "$f" 2>&1); then
      echo "적재 실패: $f"
      printf '%s\n' "$out" | tail -20
      exit 1
    fi
    if printf '%s' "$out" | grep -Eqi '(ERROR|FATAL):'; then
      echo "적재 중 오류: $f"
      printf '%s\n' "$out" | grep -Ei '(ERROR|FATAL):' | head -10
      exit 1
    fi
  done
}

db_reset() {
  if [ "${SKIP_PG_SETUP:-0}" = "1" ]; then
    # 이미 떠 있는 데이터베이스를 쓴다 (CI 의 서비스 컨테이너 등).
    # 클러스터를 새로 만드는 대신 스키마만 비운다.
    psql -h "$PGSOCKET" -p "$PGPORT_TEST" -U postgres -v ON_ERROR_STOP=1 -q -c \
      'drop schema if exists public cascade; create schema public;' >/dev/null
    load_sql
    return
  fi
  "$PGBIN/pg_ctl" -D "$PGDATA_DIR" -m fast stop >/dev/null 2>&1 || true
  rm -rf "$PGDATA_DIR"
  "$PGBIN/initdb" -D "$PGDATA_DIR" -U postgres --auth=trust >/dev/null
  "$PGBIN/pg_ctl" -D "$PGDATA_DIR" \
    -o "-p $PGPORT_TEST -k $PGSOCKET" -l "$WORK/pg.log" start >/dev/null
  sleep 2
  load_sql
}

shim_start() {
  # 앞선 셔임이 포트를 놓을 때까지 기다린다.
  # 기다리지 않으면 죽어 가는 쪽이 준비 확인에 응답해 EADDRINUSE 를 가린다.
  for _ in $(seq 1 20); do
    curl -sf -o /dev/null "$AKASHIC_BASE/index.html" || break
    sleep 0.3
  done
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
  [ "${SKIP_PG_SETUP:-0}" = "1" ] || \
    "$PGBIN/pg_ctl" -D "$PGDATA_DIR" -m fast stop >/dev/null 2>&1 || true
}
trap cleanup EXIT

SUITES=("core" "lifecycle" "ui" "related" "edge" "scale" "style" "hardening" "session" "race")
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
