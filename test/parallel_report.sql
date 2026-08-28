\set ON_ERROR_STOP on
set role authenticated;
select set_config('request.jwt.claim.sub', :'reporter', false);
insert into public.reports(record_id,user_id,reason)
select id,auth.uid(),'other' from public.records where record_code='ARC-HISTORY-000003';
