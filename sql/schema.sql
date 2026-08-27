-- Akashic Records: shared, source-based knowledge archive
create extension if not exists pgcrypto;

create type public.record_status as enum ('published','under_review','hidden');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  keeper_code text not null unique,
  display_name text not null check (char_length(display_name) between 1 and 20),
  level int not null default 2 check (level between 1 and 5),
  lang text not null default 'ko' check (lang in ('ko','en','ja')),
  is_admin boolean not null default false,
  created_at timestamptz not null default now()
);

create sequence public.keeper_code_seq minvalue 1;
create table public.domains (
  id text primary key,
  name jsonb not null check (name ? 'ko'),
  description jsonb not null check (description ? 'ko'),
  icon text not null default '◇', sort_order int not null default 0
);
create table public.categories (
  id text primary key,
  domain_id text not null references public.domains(id),
  name jsonb not null check (name ? 'ko'),
  description jsonb not null check (description ? 'ko'),
  sort_order int not null default 0
);
create table public.records (
  id bigint generated always as identity primary key,
  record_code text unique,
  domain_id text not null references public.domains(id),
  category_id text not null references public.categories(id),
  title jsonb not null check (title ? 'ko' and char_length(title->>'ko') between 1 and 100),
  summary jsonb not null check (summary ? 'ko' and char_length(summary->>'ko') between 1 and 300),
  content jsonb not null check (content ? 'ko' and char_length(content->>'ko') >= 1),
  event_date date,
  tags text[] not null check (cardinality(tags) between 1 and 8),
  search_document tsvector not null default ''::tsvector,
  source text not null check (source ~ '^https?://'),
  level int not null default 1 check (level between 1 and 5),
  related_ids bigint[] not null default '{}',
  author_id uuid not null references public.profiles(id),
  is_seed boolean not null default false,
  status public.record_status not null default 'published',
  deleted_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz
);
create table public.bookmarks (user_id uuid references public.profiles(id) on delete cascade,record_id bigint references public.records(id) on delete cascade,created_at timestamptz not null default now(),primary key(user_id,record_id));
create table public.record_views (user_id uuid references public.profiles(id) on delete cascade,record_id bigint references public.records(id) on delete cascade,viewed_at timestamptz not null default now(),primary key(user_id,record_id));
create table public.reports (id bigint generated always as identity primary key,record_id bigint references public.records(id) on delete cascade,user_id uuid references public.profiles(id) on delete cascade,reason text not null check(reason in ('false_information','missing_source','fiction','inappropriate','other')),detail text check(char_length(detail)<=1000),created_at timestamptz not null default now(),unique(record_id,user_id));
create table public.moderation_cases (
  id bigint generated always as identity primary key,
  record_id bigint not null references public.records(id) on delete cascade,
  report_count int not null check(report_count >= 3),
  status text not null default 'open' check(status in ('open','resolved')),
  decision text check(decision in ('keep','hide')),
  opened_at timestamptz not null default now(), resolved_at timestamptz,
  check ((status='open' and decision is null and resolved_at is null) or (status='resolved' and decision is not null and resolved_at is not null))
);
create unique index one_open_case_per_record on public.moderation_cases(record_id) where status='open';
create table public.moderation_votes (
  case_id bigint references public.moderation_cases(id) on delete cascade,
  admin_id uuid references public.profiles(id) on delete cascade,
  decision text not null check(decision in ('keep','hide')),
  note text check(char_length(note) between 1 and 1000),
  created_at timestamptz not null default now(),
  primary key(case_id,admin_id)
);

create index records_location_idx on public.records(domain_id,category_id);
create index records_event_idx on public.records(event_date desc);
create index records_created_idx on public.records(created_at desc);
create index records_public_idx on public.records(status,deleted_at) where deleted_at is null;
create index records_tags_idx on public.records using gin(tags);
create index records_search_idx on public.records using gin(search_document);
create index record_views_recent_idx on public.record_views(user_id,viewed_at desc);

-- array_to_string is STABLE on supported PostgreSQL versions, so this must be a
-- trigger-maintained column rather than an invalid generated column.
create or replace function public.refresh_record_search() returns trigger language plpgsql set search_path='' as $$
begin
 new.search_document:=to_tsvector('simple'::regconfig,
  coalesce(new.title->>'ko','')||' '||coalesce(new.title->>'en','')||' '||coalesce(new.title->>'ja','')||' '||
  coalesce(new.summary->>'ko','')||' '||coalesce(new.summary->>'en','')||' '||coalesce(new.summary->>'ja','')||' '||
  coalesce(new.content->>'ko','')||' '||coalesce(new.content->>'en','')||' '||coalesce(new.content->>'ja','')||' '||
  array_to_string(new.tags,' '));
 return new;
end $$;
create trigger refresh_record_search_before_write before insert or update of title,summary,content,tags on public.records for each row execute procedure public.refresh_record_search();

create or replace function public.new_profile() returns trigger language plpgsql security definer set search_path='' as $$
declare keeper_no bigint;
begin
 keeper_no:=nextval('public.keeper_code_seq');
 insert into public.profiles(id,keeper_code,display_name,lang)
 values(new.id,'KEEPER-'||lpad(keeper_no::text,greatest(3,length(keeper_no::text)),'0'),coalesce(nullif(new.raw_user_meta_data->>'display_name',''),'Anonymous'),coalesce(new.raw_user_meta_data->>'lang','en'));
 return new;
end $$;
create trigger auth_user_profile after insert on auth.users for each row execute procedure public.new_profile();

create or replace function public.prepare_record() returns trigger language plpgsql security definer set search_path='' as $$
declare seq_no bigint; user_level int; last_post timestamptz; today_posts int;
begin
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
create trigger prepare_record_before_insert before insert on public.records for each row when(new.is_seed=false) execute procedure public.prepare_record();

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path='' as $$select coalesce((select is_admin from public.profiles where id=auth.uid()),false)$$;
create or replace function public.is_email_confirmed() returns boolean language sql stable security definer set search_path='' as $$select exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null)$$;

create or replace function public.touch_record() returns trigger language plpgsql security definer set search_path='' as $$
declare user_level int;
begin
 if not public.is_admin() then
  if new.author_id<>old.author_id or new.record_code<>old.record_code then raise exception 'immutable record identity'; end if;
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
create trigger touch_record_before_update before update on public.records for each row execute procedure public.touch_record();

create or replace function public.update_reader_level() returns trigger language plpgsql security definer set search_path='' as $$
declare n int;
begin select count(*) into n from public.record_views where user_id=new.user_id;
 update public.profiles set level=case when n>=60 then 5 when n>=30 then 4 when n>=10 then 3 else level end where id=new.user_id;
 return new; end $$;
create trigger level_after_view after insert on public.record_views for each row execute procedure public.update_reader_level();

-- Three reports open a review meeting. The record remains readable until moderators decide.
create or replace function public.open_moderation_case() returns trigger language plpgsql security definer set search_path='' as $$
declare n int;
begin
 select count(*) into n from public.reports where record_id=new.record_id;
 if exists(select 1 from public.moderation_cases where record_id=new.record_id and status='open') then
  update public.moderation_cases set report_count=n where record_id=new.record_id and status='open';
 elsif n>=3 and n%3=0 then
  insert into public.moderation_cases(record_id,report_count) values(new.record_id,n);
  update public.records set status='under_review' where id=new.record_id and status<>'hidden';
 end if;
 return new;
end $$;
create trigger open_case_after_report after insert on public.reports for each row execute procedure public.open_moderation_case();

-- A decision requires three different administrators. Majority vote decides keep/hide.
create or replace function public.resolve_moderation_case() returns trigger language plpgsql security definer set search_path='' as $$
declare total int; hide_votes int; target_record bigint;
begin
 select count(*),count(*) filter(where decision='hide') into total,hide_votes from public.moderation_votes where case_id=new.case_id;
 if total>=3 then
  update public.moderation_cases set status='resolved',decision=case when hide_votes*2>total then 'hide' else 'keep' end,resolved_at=now() where id=new.case_id and status='open' returning record_id into target_record;
  if target_record is not null then
   update public.records set status=case when hide_votes*2>total then 'hidden'::public.record_status else 'published'::public.record_status end where id=target_record;
  end if;
 end if;
 return new;
end $$;
create trigger resolve_case_after_vote after insert or update on public.moderation_votes for each row execute procedure public.resolve_moderation_case();

-- Safe reader RPC: inaccessible content is returned as NULL, never sent to the browser.
create or replace function public.get_record_for_reader(requested_code text)
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,content jsonb,event_date date,tags text[],source text,level int,author_id uuid,created_at timestamptz,keeper_code text,domain_name jsonb,category_name jsonb,content_available boolean)
language plpgsql volatile security definer set search_path='' as $$
declare target_id bigint;
begin
 if auth.uid() is null then return;end if;
 select r.id into target_id from public.records r where r.record_code=requested_code and r.status in('published','under_review') and r.deleted_at is null;
 if target_id is null then return;end if;
 insert into public.record_views(user_id,record_id,viewed_at) values(auth.uid(),target_id,now()) on conflict(user_id,record_id) do update set viewed_at=excluded.viewed_at;
 return query select r.id,r.record_code,r.domain_id,r.category_id,r.title,r.summary,case when r.level<=p.level then r.content else null end,r.event_date,r.tags,r.source,r.level,r.author_id,r.created_at,a.keeper_code,d.name,c.name,r.level<=p.level
 from public.records r join public.profiles a on a.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id join public.profiles p on p.id=auth.uid() where r.id=target_id;
end;
$$;
revoke all on function public.get_record_for_reader(text) from public;
grant execute on function public.get_record_for_reader(text) to authenticated;

create or replace function public.get_own_record(requested_code text)
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,content jsonb,event_date date,tags text[],source text,level int,status public.record_status,deleted_at timestamptz,created_at timestamptz,updated_at timestamptz)
language sql stable security definer set search_path='' as $$
 select r.id,r.record_code,r.domain_id,r.category_id,r.title,r.summary,r.content,r.event_date,r.tags,r.source,r.level,r.status,r.deleted_at,r.created_at,r.updated_at
 from public.records r where r.record_code=requested_code and r.author_id=auth.uid();
$$;
revoke all on function public.get_own_record(text) from public;
grant execute on function public.get_own_record(text) to authenticated;

create or replace function public.get_related_records(requested_id bigint)
returns table(id bigint,record_code text,title jsonb,summary jsonb,event_date date,tags text[],level int,keeper_code text,domain_name jsonb,category_name jsonb,score int)
language sql stable security definer set search_path='' as $$
 with current_record as(select * from public.records where id=requested_id), candidates as(
  select r.*,p.keeper_code,d.name domain_name,c.name category_name,
   case when r.id=any(cr.related_ids) then 100 else 0 end+
   (select count(*)::int*3 from unnest(r.tags) tag where tag=any(cr.tags))+
   case when r.category_id=cr.category_id then 3 else 0 end+
   case when r.domain_id=cr.domain_id then 1 else 0 end+
   case when r.event_date is not null and cr.event_date is not null and abs(r.event_date-cr.event_date)<=3652 then 1 else 0 end score
  from public.records r cross join current_record cr join public.profiles p on p.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id
  where r.id<>cr.id and r.status in('published','under_review') and r.deleted_at is null
 )
 select id,record_code,title,summary,event_date,tags,level,keeper_code,domain_name,category_name,score from candidates where score>0 order by score desc,event_date desc nulls last limit 5;
$$;
revoke all on function public.get_related_records(bigint) from public;
grant execute on function public.get_related_records(bigint) to authenticated;

create view public.record_catalog with (security_invoker=true) as
select r.id,r.record_code,r.domain_id,r.category_id,r.title,r.summary,r.event_date,r.tags,r.level,r.author_id,r.status,r.deleted_at,r.created_at,p.keeper_code,d.name domain_name,c.name category_name,
false as content_available
from public.records r join public.profiles p on p.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id;

create or replace function public.search_record_catalog(search_query text,page_no int default 0)
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,event_date date,tags text[],level int,author_id uuid,status public.record_status,created_at timestamptz,keeper_code text,domain_name jsonb,category_name jsonb,content_available boolean)
language sql stable security definer set search_path='' as $$
 select r.id,r.record_code,r.domain_id,r.category_id,r.title,case when r.level<=reader.level then r.summary else null end,r.event_date,r.tags,r.level,r.author_id,r.status,r.created_at,p.keeper_code,d.name,c.name,r.level<=reader.level
 from public.records r join public.profiles p on p.id=r.author_id join public.profiles reader on reader.id=auth.uid() join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id
 where r.status in('published','under_review') and r.deleted_at is null and r.search_document@@websearch_to_tsquery('simple'::regconfig,search_query)
 order by ts_rank(r.search_document,websearch_to_tsquery('simple'::regconfig,search_query)) desc,r.created_at desc offset greatest(page_no,0)*20 limit 20;
$$;
revoke all on function public.search_record_catalog(text,int) from public;
grant execute on function public.search_record_catalog(text,int) to authenticated;

create view public.archive_statistics with (security_invoker=true) as
select count(*) filter(where status in ('published','under_review') and deleted_at is null)::int record_count,count(*) filter(where status in ('published','under_review') and deleted_at is null and created_at>=date_trunc('day',now()))::int today_count,(select count(*)::int from public.profiles) keeper_count from public.records;
