-- Harden record writes, clearance responses, concurrent moderation, and admin review.

create or replace function public.prepare_record() returns trigger language plpgsql security definer set search_path='' as $$
declare seq_no bigint; user_level int; last_post timestamptz; today_posts int;
begin
 if auth.uid() is not null and new.is_seed then raise exception 'seed records are server managed'; end if;
 if auth.uid() is null then return new; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 if new.author_id <> auth.uid() then raise exception 'author mismatch'; end if;
 select level into user_level from public.profiles where id=auth.uid();
 if new.level>user_level then raise exception 'clearance exceeded'; end if;
 select max(created_at),count(*) filter(where created_at>=date_trunc('day',now())) into last_post,today_posts from public.records where author_id=auth.uid() and deleted_at is null;
 if today_posts>=10 then raise exception 'daily record limit reached'; end if;
 if last_post is not null and last_post>now()-interval '60 seconds' then raise exception 'wait before creating another record'; end if;
 if exists(select 1 from public.records where author_id=auth.uid() and title->>'ko'=new.title->>'ko' and content->>'ko'=new.content->>'ko' and deleted_at is null) then raise exception 'duplicate record'; end if;
 if not exists(select 1 from public.categories where id=new.category_id and domain_id=new.domain_id) then raise exception 'category does not belong to domain'; end if;
 seq_no:=new.id;
 new.record_code='ARC-'||upper(new.domain_id)||'-'||lpad(seq_no::text,greatest(6,length(seq_no::text)),'0'); new.created_at=now();
 return new;
end $$;

create or replace function public.touch_record() returns trigger language plpgsql security definer set search_path='' as $$
declare user_level int;
begin
 if not public.is_admin() then
  if new.author_id<>old.author_id or new.record_code<>old.record_code or new.created_at<>old.created_at or new.search_document<>old.search_document then raise exception 'immutable record identity'; end if;
  if new.status<>old.status and pg_trigger_depth()=1 then raise exception 'moderation fields are server managed'; end if;
  if new.is_seed<>old.is_seed then raise exception 'seed flag is immutable'; end if;
  if old.deleted_at is not null then raise exception 'deleted records cannot be changed by clients'; end if;
  if old.deleted_at is null and new.deleted_at is not null then new.deleted_at=now(); end if;
  select level into user_level from public.profiles where id=auth.uid();
  if new.level>user_level then raise exception 'clearance exceeded'; end if;
 end if;
 if not exists(select 1 from public.categories where id=new.category_id and domain_id=new.domain_id) then raise exception 'category does not belong to domain'; end if;
 new.updated_at=now();return new;
end $$;

create or replace function public.open_moderation_case() returns trigger language plpgsql security definer set search_path='' as $$
declare n int;
begin
 perform pg_advisory_xact_lock(new.record_id);
 select count(*) into n from public.reports where record_id=new.record_id;
 if exists(select 1 from public.moderation_cases where record_id=new.record_id and status='open') then
  update public.moderation_cases set report_count=n where record_id=new.record_id and status='open';
 elsif n>=3 and n%3=0 then
  insert into public.moderation_cases(record_id,report_count) values(new.record_id,n);
  update public.records set status='under_review' where id=new.record_id and status<>'hidden';
 end if;
 return new;
end $$;

create or replace function public.get_record_for_reader(requested_code text)
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,content jsonb,event_date date,tags text[],source text,level int,author_id uuid,created_at timestamptz,keeper_code text,domain_name jsonb,category_name jsonb,content_available boolean)
language plpgsql volatile security definer set search_path='' as $$
declare target_id bigint;
begin
 if auth.uid() is null then return;end if;
 select r.id into target_id from public.records r where r.record_code=requested_code and r.status in('published','under_review') and r.deleted_at is null;
 if target_id is null then return;end if;
 insert into public.record_views(user_id,record_id,viewed_at) values(auth.uid(),target_id,now()) on conflict(user_id,record_id) do update set viewed_at=excluded.viewed_at;
 return query select r.id,r.record_code,r.domain_id,r.category_id,r.title,case when r.level<=p.level then r.summary else null end,case when r.level<=p.level then r.content else null end,r.event_date,r.tags,r.source,r.level,r.author_id,r.created_at,a.keeper_code,d.name,c.name,r.level<=p.level
 from public.records r join public.profiles a on a.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id join public.profiles p on p.id=auth.uid() where r.id=target_id;
end;
$$;

create or replace function public.get_moderation_dossiers()
returns setof jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.is_admin() then raise exception 'administrator access required' using errcode='42501'; end if;
 return query select jsonb_build_object('id',mc.id,'record_id',mc.record_id,'report_count',mc.report_count,'status',mc.status,'decision',mc.decision,'opened_at',mc.opened_at,'resolved_at',mc.resolved_at,
 'records',jsonb_build_object('record_code',r.record_code,'title',r.title,'summary',r.summary,'content',r.content,'source',r.source,'author_id',r.author_id,'status',r.status),
 'reports',coalesce((select jsonb_agg(jsonb_build_object('reason',rp.reason,'detail',rp.detail,'created_at',rp.created_at) order by rp.created_at) from public.reports rp where rp.record_id=mc.record_id),'[]'::jsonb),
 'moderation_votes',coalesce((select jsonb_agg(jsonb_build_object('admin_id',v.admin_id,'decision',v.decision,'note',v.note,'created_at',v.created_at,'profiles',jsonb_build_object('keeper_code',p.keeper_code,'display_name',p.display_name)) order by v.created_at) from public.moderation_votes v join public.profiles p on p.id=v.admin_id where v.case_id=mc.id),'[]'::jsonb))
 from public.moderation_cases mc join public.records r on r.id=mc.record_id order by mc.opened_at desc;
end $$;

revoke insert,update on public.records from authenticated;
grant insert(domain_id,category_id,title,summary,content,event_date,tags,source,level,related_ids,author_id) on public.records to authenticated;
grant update(domain_id,category_id,title,summary,content,event_date,tags,source,level,related_ids,deleted_at) on public.records to authenticated;
revoke all on function public.get_moderation_dossiers() from public;
grant execute on function public.get_moderation_dossiers() to authenticated;
drop trigger if exists prepare_record_before_insert on public.records;
create trigger prepare_record_before_insert before insert on public.records for each row execute procedure public.prepare_record();
drop view if exists public.record_catalog;
create view public.record_catalog with(security_invoker=true) as
select r.id,r.record_code,r.domain_id,r.category_id,r.title,case when r.level<=coalesce((select level from public.profiles where id=auth.uid()),0) then r.summary else null end summary,r.event_date,r.tags,r.level,r.author_id,r.status,r.deleted_at,r.created_at,p.keeper_code,d.name domain_name,c.name category_name,r.level<=coalesce((select level from public.profiles where id=auth.uid()),0) content_available
from public.records r join public.profiles p on p.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id;
grant select on public.record_catalog to authenticated;
