-- Complete record integrity rules and related-record recommendations.
alter table public.records add column if not exists search_document tsvector generated always as (to_tsvector('simple'::regconfig,coalesce(title->>'ko','')||' '||coalesce(title->>'en','')||' '||coalesce(title->>'ja','')||' '||coalesce(summary->>'ko','')||' '||coalesce(summary->>'en','')||' '||coalesce(summary->>'ja','')||' '||coalesce(content->>'ko','')||' '||coalesce(content->>'en','')||' '||coalesce(content->>'ja','')||' '||array_to_string(tags,' '))) stored;
create index if not exists records_search_idx on public.records using gin(search_document);
create or replace view public.record_catalog with(security_invoker=true) as
select r.id,r.record_code,r.domain_id,r.category_id,r.title,r.summary,r.event_date,r.tags,r.level,r.author_id,r.status,r.deleted_at,r.created_at,p.keeper_code,d.name domain_name,c.name category_name,false content_available,r.search_document
from public.records r join public.profiles p on p.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id;

create or replace function public.prepare_record() returns trigger language plpgsql security definer set search_path='' as $$
declare seq_no bigint;user_level int;last_post timestamptz;today_posts int;
begin
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 if new.author_id<>auth.uid() then raise exception 'author mismatch';end if;
 select level into user_level from public.profiles where id=auth.uid();
 if new.level>user_level then raise exception 'clearance exceeded';end if;
 select max(created_at),count(*) filter(where created_at>=date_trunc('day',now())) into last_post,today_posts from public.records where author_id=auth.uid() and deleted_at is null;
 if today_posts>=10 then raise exception 'daily record limit reached';end if;
 if last_post is not null and last_post>now()-interval '60 seconds' then raise exception 'wait before creating another record';end if;
 if exists(select 1 from public.records where author_id=auth.uid() and title->>'ko'=new.title->>'ko' and content->>'ko'=new.content->>'ko' and deleted_at is null) then raise exception 'duplicate record';end if;
 if not exists(select 1 from public.categories where id=new.category_id and domain_id=new.domain_id) then raise exception 'category does not belong to domain';end if;
 seq_no:=new.id;new.record_code='ARC-'||upper(new.domain_id)||'-'||lpad(seq_no::text,6,'0');new.created_at=now();return new;
end $$;

create or replace function public.touch_record() returns trigger language plpgsql security definer set search_path='' as $$
declare user_level int;
begin
 if not public.is_admin() then
  if new.author_id<>old.author_id or new.record_code<>old.record_code then raise exception 'immutable record identity';end if;
  if new.status<>old.status or new.is_seed<>old.is_seed then raise exception 'moderation fields are server managed';end if;
  if old.deleted_at is not null then raise exception 'deleted records cannot be changed by clients';end if;
  if old.deleted_at is null and new.deleted_at is not null then new.deleted_at=now();end if;
  select level into user_level from public.profiles where id=auth.uid();if new.level>user_level then raise exception 'clearance exceeded';end if;
 end if;
 if not exists(select 1 from public.categories where id=new.category_id and domain_id=new.domain_id) then raise exception 'category does not belong to domain';end if;
 new.updated_at=now();return new;
end $$;

drop policy if exists "submit own report" on public.reports;
create policy "submit own report" on public.reports for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from public.records r where r.id=record_id and r.author_id<>auth.uid()));

create or replace function public.get_related_records(requested_id bigint)
returns table(id bigint,record_code text,title jsonb,summary jsonb,event_date date,tags text[],level int,keeper_code text,domain_name jsonb,category_name jsonb,score int)
language sql stable security definer set search_path='' as $$
 with current_record as(select * from public.records where id=requested_id),candidates as(
  select r.*,p.keeper_code,d.name domain_name,c.name category_name,case when r.id=any(cr.related_ids) then 100 else 0 end+(select count(*)::int*3 from unnest(r.tags) tag where tag=any(cr.tags))+case when r.category_id=cr.category_id then 3 else 0 end+case when r.domain_id=cr.domain_id then 1 else 0 end+case when r.event_date is not null and cr.event_date is not null and abs(r.event_date-cr.event_date)<=3652 then 1 else 0 end score
  from public.records r cross join current_record cr join public.profiles p on p.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id where r.id<>cr.id and r.status::text in('published','under_review') and r.deleted_at is null)
 select id,record_code,title,summary,event_date,tags,level,keeper_code,domain_name,category_name,score from candidates where score>0 order by score desc,event_date desc nulls last limit 5;
$$;
revoke all on function public.get_related_records(bigint) from public;
grant execute on function public.get_related_records(bigint) to authenticated;
