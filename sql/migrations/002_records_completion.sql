-- Complete record integrity rules and related-record recommendations.
alter table public.records add column if not exists search_document tsvector not null default ''::tsvector;
create or replace function public.refresh_record_search() returns trigger language plpgsql set search_path='' as $$
begin new.search_document:=to_tsvector('simple'::regconfig,coalesce(new.title->>'ko','')||' '||coalesce(new.title->>'en','')||' '||coalesce(new.title->>'ja','')||' '||coalesce(new.summary->>'ko','')||' '||coalesce(new.summary->>'en','')||' '||coalesce(new.summary->>'ja','')||' '||coalesce(new.content->>'ko','')||' '||coalesce(new.content->>'en','')||' '||coalesce(new.content->>'ja','')||' '||array_to_string(new.tags,' '));return new;end $$;
drop trigger if exists refresh_record_search_before_write on public.records;
create trigger refresh_record_search_before_write before insert or update of title,summary,content,tags on public.records for each row execute procedure public.refresh_record_search();
alter table public.records disable trigger touch_record_before_update;
update public.records set search_document=to_tsvector('simple'::regconfig,coalesce(title->>'ko','')||' '||coalesce(title->>'en','')||' '||coalesce(title->>'ja','')||' '||coalesce(summary->>'ko','')||' '||coalesce(summary->>'en','')||' '||coalesce(summary->>'ja','')||' '||coalesce(content->>'ko','')||' '||coalesce(content->>'en','')||' '||coalesce(content->>'ja','')||' '||array_to_string(tags,' '));
alter table public.records enable trigger touch_record_before_update;
create index if not exists records_search_idx on public.records using gin(search_document);
drop view if exists public.record_catalog;
create view public.record_catalog with(security_invoker=true) as
select r.id,r.record_code,r.domain_id,r.category_id,r.title,r.summary,r.event_date,r.tags,r.level,r.author_id,r.status,r.deleted_at,r.created_at,p.keeper_code,d.name domain_name,c.name category_name,false content_available
from public.records r join public.profiles p on p.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id;
grant select on public.record_catalog to authenticated;

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
 seq_no:=new.id;new.record_code='ARC-'||upper(new.domain_id)||'-'||lpad(seq_no::text,greatest(6,length(seq_no::text)),'0');new.created_at=now();return new;
end $$;

create or replace function public.touch_record() returns trigger language plpgsql security definer set search_path='' as $$
declare user_level int;
begin
 if not public.is_admin() then
  if new.author_id<>old.author_id or new.record_code<>old.record_code then raise exception 'immutable record identity';end if;
  if new.status<>old.status and pg_trigger_depth()=1 then raise exception 'moderation fields are server managed';end if;
  if new.is_seed<>old.is_seed then raise exception 'seed flag is immutable';end if;
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

create or replace function public.new_profile() returns trigger language plpgsql security definer set search_path='' as $$
declare keeper_no bigint;
begin keeper_no:=nextval('public.keeper_code_seq');insert into public.profiles(id,keeper_code,display_name,lang) values(new.id,'KEEPER-'||lpad(keeper_no::text,greatest(3,length(keeper_no::text)),'0'),coalesce(nullif(new.raw_user_meta_data->>'display_name',''),'Anonymous'),coalesce(new.raw_user_meta_data->>'lang','en'));return new;end $$;
create or replace function public.is_email_confirmed() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null)$$;
grant execute on function public.is_email_confirmed() to authenticated;
drop policy if exists "verified users create records" on public.records;
create policy "verified users create records" on public.records for insert to authenticated with check(author_id=auth.uid() and public.is_email_confirmed());

create or replace function public.get_record_for_reader(requested_code text)
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,content jsonb,event_date date,tags text[],source text,level int,author_id uuid,created_at timestamptz,keeper_code text,domain_name jsonb,category_name jsonb,content_available boolean)
language plpgsql volatile security definer set search_path='' as $$
declare target_id bigint;
begin if auth.uid() is null then return;end if;select r.id into target_id from public.records r where r.record_code=requested_code and r.status::text in('published','under_review') and r.deleted_at is null;if target_id is null then return;end if;insert into public.record_views(user_id,record_id,viewed_at) values(auth.uid(),target_id,now()) on conflict(user_id,record_id) do update set viewed_at=excluded.viewed_at;return query select r.id,r.record_code,r.domain_id,r.category_id,r.title,r.summary,case when r.level<=p.level then r.content else null end,r.event_date,r.tags,r.source,r.level,r.author_id,r.created_at,a.keeper_code,d.name,c.name,r.level<=p.level from public.records r join public.profiles a on a.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id join public.profiles p on p.id=auth.uid() where r.id=target_id;end $$;
revoke all on function public.get_record_for_reader(text) from public;grant execute on function public.get_record_for_reader(text) to authenticated;
create or replace function public.get_own_record(requested_code text)
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,content jsonb,event_date date,tags text[],source text,level int,status public.record_status,deleted_at timestamptz,created_at timestamptz,updated_at timestamptz)
language sql stable security definer set search_path='' as $$select r.id,r.record_code,r.domain_id,r.category_id,r.title,r.summary,r.content,r.event_date,r.tags,r.source,r.level,r.status,r.deleted_at,r.created_at,r.updated_at from public.records r where r.record_code=requested_code and r.author_id=auth.uid()$$;
revoke all on function public.get_own_record(text) from public;grant execute on function public.get_own_record(text) to authenticated;
create or replace function public.search_record_catalog(search_query text,page_no int default 0)
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,event_date date,tags text[],level int,author_id uuid,status public.record_status,created_at timestamptz,keeper_code text,domain_name jsonb,category_name jsonb,content_available boolean)
language sql stable security definer set search_path='' as $$select r.id,r.record_code,r.domain_id,r.category_id,r.title,case when r.level<=reader.level then r.summary else null end,r.event_date,r.tags,r.level,r.author_id,r.status,r.created_at,p.keeper_code,d.name,c.name,r.level<=reader.level from public.records r join public.profiles p on p.id=r.author_id join public.profiles reader on reader.id=auth.uid() join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id where r.status::text in('published','under_review') and r.deleted_at is null and r.search_document@@websearch_to_tsquery('simple'::regconfig,search_query) order by ts_rank(r.search_document,websearch_to_tsquery('simple'::regconfig,search_query)) desc,r.created_at desc offset greatest(page_no,0)*20 limit 20$$;
revoke all on function public.search_record_catalog(text,int) from public;grant execute on function public.search_record_catalog(text,int) to authenticated;

revoke select on public.records from authenticated;
grant select(id,record_code,domain_id,category_id,title,summary,event_date,tags,source,level,author_id,is_seed,status,deleted_at,created_at,updated_at) on public.records to authenticated;
revoke insert,update on public.record_views from authenticated;
