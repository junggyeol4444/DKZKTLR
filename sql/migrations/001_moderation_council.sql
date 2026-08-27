-- Upgrade installations from the original three-report auto-hide behavior.
alter type public.record_status add value if not exists 'under_review';

create table if not exists public.moderation_cases (
  id bigint generated always as identity primary key,
  record_id bigint not null references public.records(id) on delete cascade,
  report_count int not null check(report_count>=3),
  status text not null default 'open' check(status in('open','resolved')),
  decision text check(decision in('keep','hide')),
  opened_at timestamptz not null default now(),resolved_at timestamptz,
  check((status='open' and decision is null and resolved_at is null) or(status='resolved' and decision is not null and resolved_at is not null))
);
create unique index if not exists one_open_case_per_record on public.moderation_cases(record_id) where status='open';
create table if not exists public.moderation_votes (
  case_id bigint references public.moderation_cases(id) on delete cascade,
  admin_id uuid references public.profiles(id) on delete cascade,
  decision text not null check(decision in('keep','hide')),
  note text check(char_length(note) between 1 and 1000),
  created_at timestamptz not null default now(),primary key(case_id,admin_id)
);

drop trigger if exists hide_after_report on public.reports;
drop function if exists public.hide_reported_record();
create or replace function public.open_moderation_case() returns trigger language plpgsql security definer set search_path='' as $$
declare n int;
begin
 select count(*) into n from public.reports where record_id=new.record_id;
 if exists(select 1 from public.moderation_cases where record_id=new.record_id and status='open') then
  update public.moderation_cases set report_count=n where record_id=new.record_id and status='open';
 elsif n>=3 and n%3=0 then
  insert into public.moderation_cases(record_id,report_count) values(new.record_id,n);
  execute 'update public.records set status=''under_review'' where id=$1 and status::text<>''hidden''' using new.record_id;
 end if;
 return new;
end $$;
create trigger open_case_after_report after insert on public.reports for each row execute procedure public.open_moderation_case();

create or replace function public.resolve_moderation_case() returns trigger language plpgsql security definer set search_path='' as $$
declare total int;hide_votes int;target_record bigint;
begin
 select count(*),count(*) filter(where decision='hide') into total,hide_votes from public.moderation_votes where case_id=new.case_id;
 if total>=3 then
  update public.moderation_cases set status='resolved',decision=case when hide_votes*2>total then 'hide' else 'keep' end,resolved_at=now() where id=new.case_id and status='open' returning record_id into target_record;
  if target_record is not null then execute format('update public.records set status=%L where id=$1',case when hide_votes*2>total then 'hidden' else 'published' end) using target_record;end if;
 end if;return new;
end $$;
drop trigger if exists resolve_case_after_vote on public.moderation_votes;
create trigger resolve_case_after_vote after insert or update on public.moderation_votes for each row execute procedure public.resolve_moderation_case();

alter table public.moderation_cases enable row level security;
alter table public.moderation_votes enable row level security;
drop policy if exists "published or own records readable" on public.records;
create policy "published or own records readable" on public.records for select to authenticated using((status::text in('published','under_review') and deleted_at is null) or author_id=auth.uid() or public.is_admin());
create policy "admins read cases" on public.moderation_cases for select to authenticated using(public.is_admin());
create policy "admins read votes" on public.moderation_votes for select to authenticated using(public.is_admin());
create policy "admins vote once" on public.moderation_votes for insert to authenticated with check(public.is_admin() and admin_id=auth.uid() and exists(select 1 from public.moderation_cases c join public.records r on r.id=c.record_id where c.id=case_id and c.status='open' and r.author_id<>auth.uid()));
revoke all on public.moderation_cases,public.moderation_votes from anon;
grant select on public.moderation_cases,public.moderation_votes to authenticated;
grant insert on public.moderation_votes to authenticated;
grant select(is_admin) on public.profiles to authenticated;

create or replace function public.get_record_for_reader(requested_code text)
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,content jsonb,event_date date,tags text[],source text,level int,author_id uuid,created_at timestamptz,keeper_code text,domain_name jsonb,category_name jsonb,content_available boolean)
language sql stable security definer set search_path='' as $$
 select r.id,r.record_code,r.domain_id,r.category_id,r.title,r.summary,case when r.level<=coalesce(p.level,0) then r.content else null end,r.event_date,r.tags,r.source,r.level,r.author_id,r.created_at,a.keeper_code,d.name,c.name,r.level<=coalesce(p.level,0)
 from public.records r join public.profiles a on a.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id left join public.profiles p on p.id=auth.uid()
 where r.record_code=requested_code and r.status::text in('published','under_review') and r.deleted_at is null;
$$;
create or replace view public.archive_statistics with(security_invoker=true) as
select count(*) filter(where status::text in('published','under_review') and deleted_at is null)::int record_count,count(*) filter(where status::text in('published','under_review') and deleted_at is null and created_at>=date_trunc('day',now()))::int today_count,(select count(*)::int from public.profiles) keeper_count from public.records;
