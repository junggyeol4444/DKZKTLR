\set ON_ERROR_STOP on
do $$begin
 if (select count(*) from public.moderation_cases mc join public.records r on r.id=mc.record_id where r.record_code='ARC-HISTORY-000003' and mc.status='open') <> 1 then raise exception 'parallel reports created missing or duplicate review cases'; end if;
 if (select status::text from public.records where record_code='ARC-HISTORY-000003') <> 'under_review' then raise exception 'parallel third report did not mark record under review'; end if;
end$$;
select 'parallel report checks passed' result;
