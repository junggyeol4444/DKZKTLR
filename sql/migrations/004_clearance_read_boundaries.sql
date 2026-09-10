-- Close remaining summary disclosure paths by routing reads through clearance-aware RPCs.

create or replace function public.get_related_records(requested_id bigint)
returns table(id bigint,record_code text,title jsonb,summary jsonb,event_date date,tags text[],level int,keeper_code text,domain_name jsonb,category_name jsonb,score int)
language sql stable security definer set search_path='' as $$
 with current_record as(select * from public.records where id=requested_id and ((status in('published','under_review') and deleted_at is null) or author_id=auth.uid() or public.is_admin())), candidates as(
  select r.*,p.keeper_code,d.name domain_name,c.name category_name,
   case when r.id=any(cr.related_ids) then 100 else 0 end+
   (select count(*)::int*3 from unnest(r.tags) tag where tag=any(cr.tags))+
   case when r.category_id=cr.category_id then 3 else 0 end+
   case when r.domain_id=cr.domain_id then 1 else 0 end+
   case when r.event_date is not null and cr.event_date is not null and abs(r.event_date-cr.event_date)<=3652 then 1 else 0 end score
  from public.records r cross join current_record cr join public.profiles p on p.id=r.author_id join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id
  where r.id<>cr.id and r.status in('published','under_review') and r.deleted_at is null
 )
 select c.id,c.record_code,c.title,case when c.level<=reader.level then c.summary else null end,c.event_date,c.tags,c.level,c.keeper_code,c.domain_name,c.category_name,c.score from candidates c join public.profiles reader on reader.id=auth.uid() where score>0 order by score desc,event_date desc nulls last limit 5;
$$;
revoke all on function public.get_related_records(bigint) from public;
grant execute on function public.get_related_records(bigint) to authenticated;

create or replace function public.list_record_catalog(requested_domain text default null,requested_category text default null,requested_author uuid default null,sort_key text default 'created',lang_key text default 'ko',page_no int default 0)
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,event_date date,tags text[],level int,author_id uuid,status public.record_status,created_at timestamptz,keeper_code text,domain_name jsonb,category_name jsonb,content_available boolean)
language sql stable security definer set search_path='' as $$
 select r.id,r.record_code,r.domain_id,r.category_id,r.title,case when r.level<=reader.level then r.summary else null end,r.event_date,r.tags,r.level,r.author_id,r.status,r.created_at,p.keeper_code,d.name,c.name,r.level<=reader.level
 from public.records r join public.profiles p on p.id=r.author_id join public.profiles reader on reader.id=auth.uid() join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id
 where r.status in('published','under_review') and r.deleted_at is null and (requested_domain is null or r.domain_id=requested_domain) and (requested_category is null or r.category_id=requested_category) and (requested_author is null or r.author_id=requested_author)
 order by case when sort_key='eventAsc' then r.event_date end asc nulls last,case when sort_key='eventDesc' then r.event_date end desc nulls last,case when sort_key='title' then coalesce(r.title->>lang_key,r.title->>'ko',r.title->>'en') end asc,case when sort_key='levelDesc' then r.level end desc,case when sort_key='levelDesc' then r.event_date end desc nulls last,case when sort_key not in('eventAsc','eventDesc','title','levelDesc') then r.created_at end desc,r.id desc
 offset greatest(page_no,0)*20 limit 20;
$$;
revoke all on function public.list_record_catalog(text,text,uuid,text,text,int) from public;
grant execute on function public.list_record_catalog(text,text,uuid,text,text,int) to authenticated;

create or replace function public.get_my_records()
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,event_date date,tags text[],source text,level int,author_id uuid,is_seed boolean,status public.record_status,deleted_at timestamptz,created_at timestamptz,updated_at timestamptz)
language sql stable security definer set search_path='' as $$
 select r.id,r.record_code,r.domain_id,r.category_id,r.title,r.summary,r.event_date,r.tags,r.source,r.level,r.author_id,r.is_seed,r.status,r.deleted_at,r.created_at,r.updated_at from public.records r where r.author_id=auth.uid() order by r.created_at desc;
$$;
revoke all on function public.get_my_records() from public;
grant execute on function public.get_my_records() to authenticated;

create or replace function public.get_bookmarked_records()
returns table(id bigint,record_code text,domain_id text,category_id text,title jsonb,summary jsonb,event_date date,tags text[],level int,author_id uuid,status public.record_status,created_at timestamptz,keeper_code text,domain_name jsonb,category_name jsonb,content_available boolean)
language sql stable security definer set search_path='' as $$
 select r.id,r.record_code,r.domain_id,r.category_id,r.title,case when r.level<=reader.level then r.summary else null end,r.event_date,r.tags,r.level,r.author_id,r.status,r.created_at,p.keeper_code,d.name,c.name,r.level<=reader.level
 from public.bookmarks b join public.records r on r.id=b.record_id join public.profiles p on p.id=r.author_id join public.profiles reader on reader.id=auth.uid() join public.domains d on d.id=r.domain_id join public.categories c on c.id=r.category_id
 where b.user_id=auth.uid() and r.status in('published','under_review') and r.deleted_at is null order by b.created_at desc,r.id desc;
$$;
revoke all on function public.get_bookmarked_records() from public;
grant execute on function public.get_bookmarked_records() to authenticated;

create or replace function public.get_recent_records()
returns table(record_code text,title jsonb) language sql stable security definer set search_path='' as $$
 select r.record_code,r.title from public.record_views v join public.records r on r.id=v.record_id where v.user_id=auth.uid() and r.status in('published','under_review') and r.deleted_at is null order by v.viewed_at desc limit 5;
$$;
revoke all on function public.get_recent_records() from public;
grant execute on function public.get_recent_records() to authenticated;

revoke select(summary) on public.records from authenticated;
revoke all on public.record_catalog from authenticated;
