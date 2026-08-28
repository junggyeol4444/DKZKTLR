\set ON_ERROR_STOP on

insert into auth.users(instance_id,id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
select '00000000-0000-0000-0000-000000000000',id,'authenticated','authenticated',email,now(),'{}',jsonb_build_object('display_name',name,'lang','ko')
from(values
 ('10000000-0000-4000-a000-000000000001'::uuid,'reader@test.invalid','Reader'),
 ('10000000-0000-4000-a000-000000000002'::uuid,'report1@test.invalid','Report1'),
 ('10000000-0000-4000-a000-000000000003'::uuid,'report2@test.invalid','Report2'),
 ('10000000-0000-4000-a000-000000000004'::uuid,'report3@test.invalid','Report3'))v(id,email,name);
insert into auth.users(instance_id,id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
values('00000000-0000-0000-0000-000000000000','10000000-0000-4000-a000-000000000006','authenticated','authenticated','unconfirmed@test.invalid',null,'{}','{"display_name":"Unconfirmed"}');

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-a000-000000000006',false);
do $$begin
 begin insert into public.records(domain_id,category_id,title,summary,content,tags,source,level,author_id) values('HISTORY','MODERN','{"ko":"미인증"}','{"ko":"미인증"}','{"ko":"미인증"}',array['검증'],'https://example.com',1,auth.uid());raise exception 'unconfirmed write unexpectedly succeeded';
 exception when insufficient_privilege then null;end;
end$$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-a000-000000000001',false);

do $$begin
 begin perform content from public.records limit 1;raise exception 'content SELECT unexpectedly succeeded';
 exception when insufficient_privilege then null;end;
 begin perform search_document from public.records limit 1;raise exception 'search_document SELECT unexpectedly succeeded';
 exception when insufficient_privilege then null;end;
 begin insert into public.record_views(user_id,record_id) select auth.uid(),id from public.records limit 1;raise exception 'record_views INSERT unexpectedly succeeded';
 exception when insufficient_privilege then null;end;
end$$;

do $$declare body jsonb;available boolean;begin
 select content,content_available into body,available from public.get_record_for_reader('ARC-SCIENCE-000008');
 if body is not null or available then raise exception 'LEVEL-4 body leaked through reader RPC';end if;
 if(select count(*) from public.record_views where user_id=auth.uid())<>1 then raise exception 'reader RPC did not log exactly one real view';end if;
end$$;

reset role;
select setval(pg_get_serial_sequence('public.records','id'),999999,true);
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-a000-000000000001',false);
insert into public.records(domain_id,category_id,title,summary,content,event_date,tags,source,level,author_id)
values('HISTORY','MODERN','{"ko":"코드 경계 시험"}','{"ko":"설치 검증용 기록"}','{"ko":"본문"}',current_date,array['검증'],'https://example.com/source',1,auth.uid());
do $$begin if not exists(select 1 from public.records where author_id=auth.uid() and record_code='ARC-HISTORY-1000000') then raise exception 'record code truncated at one million';end if;end$$;
reset role;

set role authenticated;select set_config('request.jwt.claim.sub','10000000-0000-4000-a000-000000000002',false);
insert into public.reports(record_id,user_id,reason) values((select id from public.records where record_code='ARC-HISTORY-000002'),auth.uid(),'false_information');
reset role;
set role authenticated;select set_config('request.jwt.claim.sub','10000000-0000-4000-a000-000000000003',false);
insert into public.reports(record_id,user_id,reason) values((select id from public.records where record_code='ARC-HISTORY-000002'),auth.uid(),'missing_source');
reset role;
set role authenticated;select set_config('request.jwt.claim.sub','10000000-0000-4000-a000-000000000004',false);
insert into public.reports(record_id,user_id,reason) values((select id from public.records where record_code='ARC-HISTORY-000002'),auth.uid(),'other');
reset role;

do $$begin
 if(select status::text from public.records where record_code='ARC-HISTORY-000002')<>'under_review' then raise exception 'third report did not open review';end if;
 if(select count(*) from public.moderation_cases mc join public.records r on r.id=mc.record_id where mc.status='open' and r.record_code='ARC-HISTORY-000002')<>1 then raise exception 'moderation case missing';end if;
end$$;

select setval('public.keeper_code_seq',999,true);
insert into auth.users(instance_id,id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
values('00000000-0000-0000-0000-000000000000','10000000-0000-4000-a000-000000000005','authenticated','authenticated','boundary@test.invalid',now(),'{}','{"display_name":"Boundary"}');
do $$begin if not exists(select 1 from public.profiles where id='10000000-0000-4000-a000-000000000005' and keeper_code='KEEPER-1000') then raise exception 'keeper code truncated at 1000';end if;end$$;

select 'database integration checks passed' result;

-- Column grants and triggers must reject forged/server-managed fields.
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-a000-000000000001',false);
do $$declare target bigint; locked_summary jsonb;begin
 select id into target from public.records where record_code='ARC-HISTORY-1000000';
 begin update public.records set author_id='10000000-0000-4000-a000-000000000002' where id=target;raise exception 'author update unexpectedly succeeded'; exception when insufficient_privilege then null;end;
 begin update public.records set record_code='FORGED' where id=target;raise exception 'record code update unexpectedly succeeded'; exception when insufficient_privilege then null;end;
 begin update public.records set status='hidden' where id=target;raise exception 'status update unexpectedly succeeded'; exception when insufficient_privilege then null;end;
 begin update public.records set is_seed=true where id=target;raise exception 'seed update unexpectedly succeeded'; exception when insufficient_privilege then null;end;
 begin update public.records set created_at=now()-interval '1 year' where id=target;raise exception 'created_at update unexpectedly succeeded'; exception when insufficient_privilege then null;end;
 begin update public.records set search_document='forged'::tsvector where id=target;raise exception 'search update unexpectedly succeeded'; exception when insufficient_privilege then null;end;
 begin insert into public.records(domain_id,category_id,title,summary,content,tags,source,level,author_id,is_seed) values('HISTORY','MODERN','{"ko":"위조"}','{"ko":"위조"}','{"ko":"위조"}',array['위조'],'https://example.com',1,auth.uid(),true);raise exception 'seed insert unexpectedly succeeded'; exception when insufficient_privilege then null;end;
 select summary into locked_summary from public.get_record_for_reader('ARC-SCIENCE-000008');
 if locked_summary is not null then raise exception 'LEVEL-4 summary leaked through reader RPC';end if;
 begin perform public.get_moderation_dossiers();raise exception 'non-admin moderation RPC unexpectedly succeeded'; exception when insufficient_privilege then null;end;
end$$;
reset role;
update public.profiles set is_admin=true where id='10000000-0000-4000-a000-000000000005';
set role authenticated;
select set_config('request.jwt.claim.sub','10000000-0000-4000-a000-000000000005',false);
do $$declare dossier jsonb;begin
 select x into dossier from public.get_moderation_dossiers() x where (x->>'record_id')::bigint=(select id from public.records where record_code='ARC-HISTORY-000002');
 if dossier is null or dossier->'records'->'content' is null or jsonb_array_length(dossier->'reports')<>3 then raise exception 'admin dossier omitted original content or reports';end if;
end$$;
reset role;
