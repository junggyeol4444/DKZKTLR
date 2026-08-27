#!/usr/bin/env bash
set -euo pipefail
for n in 7 8 9; do
  psql -v ON_ERROR_STOP=1 -d akashic_test -qAt <<SQL &
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-a000-00000000000$n',false);
insert into public.reports(record_id,user_id,reason)
values((select id from public.records where record_code='ARC-HISTORY-000003'),auth.uid(),'other');
SQL
done
wait
result=$(psql -v ON_ERROR_STOP=1 -d akashic_test -qAt -c "select r.status::text||'|'||count(mc.id) from public.records r left join public.moderation_cases mc on mc.record_id=r.id and mc.status='open' where r.record_code='ARC-HISTORY-000003' group by r.status")
[[ "$result" == 'under_review|1' ]] || { echo "concurrent moderation failed: $result" >&2;exit 1; }
echo 'concurrent third-report check passed'
