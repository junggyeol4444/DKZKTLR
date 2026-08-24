-- ============================================================
--  AKASHIC RECORDS  /  sql/schema.sql
--  테이블 · 인덱스 · 함수 · 트리거 · 집계 뷰 · RPC
--  실행 순서: schema.sql -> rls.sql -> seed.sql
--  Supabase SQL Editor 에서 postgres 권한으로 실행합니다.
-- ============================================================

create extension if not exists pgcrypto;

-- ------------------------------------------------------------
-- 0. 정리 (재실행 가능하도록)
-- ------------------------------------------------------------
drop view   if exists public.v_bookmarks        cascade;
drop view   if exists public.v_recent_views     cascade;
drop view   if exists public.v_my_records       cascade;
drop view   if exists public.v_records          cascade;
drop view   if exists public.v_planet_counts    cascade;
drop view   if exists public.v_category_counts  cascade;
drop view   if exists public.v_subcategory_counts cascade;
drop view   if exists public.v_archive_stats    cascade;

-- ============================================================
-- 1. 테이블
-- ============================================================

-- 1.1 profiles ------------------------------------------------
create table if not exists public.profiles (
  id            uuid primary key references auth.users(id) on delete cascade,
  keeper_code   text unique,                       -- KEEPER-007 (이메일 인증 완료 시 발급)
  display_name  text not null default 'KEEPER',
  level         int  not null default 2 check (level between 1 and 5),
  lang          text not null default 'ko' check (lang in ('ko','en','ja')),
  is_admin      boolean not null default false,
  created_at    timestamptz not null default now()
);

create sequence if not exists public.keeper_code_seq start 1;

-- 1.2 planets -------------------------------------------------
create table if not exists public.planets (
  id             text primary key,                 -- TERRA-001
  name           jsonb not null,                   -- {ko,en,ja}
  location       jsonb not null default '{}'::jsonb,
  status         text not null default 'ACTIVE'
                 check (status in ('ACTIVE','DORMANT','RESTRICTED')),
  required_level int  not null default 1 check (required_level between 1 and 5),
  sort_order     int  not null default 0
  -- ※ record_count 컬럼 없음 (4.6 하드코딩 금지)
);

-- 1.3 categories ----------------------------------------------
create table if not exists public.categories (
  id           text primary key,                   -- TECH-004
  name         jsonb not null,
  description  jsonb not null default '{}'::jsonb,
  sort_order   int  not null default 0
  -- ※ record_count 컬럼 없음
);

-- 1.4 subcategories -------------------------------------------
create table if not exists public.subcategories (
  id           text primary key,                   -- ENERGY
  category_id  text not null references public.categories(id) on delete cascade,
  planet_ids   text[] not null default '{}',       -- 빈 배열 = 전 행성 공용
  name         jsonb not null,
  description  jsonb not null default '{}'::jsonb,
  level        int  not null default 1 check (level between 1 and 5),
  sort_order   int  not null default 0
  -- ※ record_count 컬럼 없음
);

-- 1.5 검색 벡터 생성용 IMMUTABLE 헬퍼 --------------------------
create or replace function public.records_tsv(
  p_title jsonb, p_summary jsonb, p_content jsonb, p_tags text[]
) returns tsvector
language sql immutable as $$
  select to_tsvector('simple',
      coalesce(p_title  ->> 'ko','') || ' ' ||
      coalesce(p_title  ->> 'en','') || ' ' ||
      coalesce(p_title  ->> 'ja','') || ' ' ||
      coalesce(p_summary->> 'ko','') || ' ' ||
      coalesce(p_summary->> 'en','') || ' ' ||
      coalesce(p_summary->> 'ja','') || ' ' ||
      coalesce(p_content->> 'ko','') || ' ' ||
      coalesce(p_content->> 'en','') || ' ' ||
      coalesce(p_content->> 'ja','') || ' ' ||
      coalesce(array_to_string(p_tags, ' '), '')
  );
$$;

-- 1.6 records -------------------------------------------------
create table if not exists public.records (
  id              bigserial primary key,
  record_code     text unique,                     -- REC-TERRA-001-0001 (트리거 발급)
  planet_id       text not null references public.planets(id),
  category_id     text not null references public.categories(id),
  subcategory_id  text not null references public.subcategories(id),
  title           jsonb not null,
  summary         jsonb not null,
  content         jsonb not null,
  event_date      date,
  tags            text[] not null default '{}',
  source          text not null check (length(btrim(source)) > 0),
  level           int  not null default 1 check (level between 1 and 5),
  related_ids     bigint[] not null default '{}',
  author_id       uuid references public.profiles(id) on delete set null,
  is_seed         boolean not null default false,
  status          text not null default 'published' check (status in ('published','hidden')),
  deleted_at      timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz,
  search_vector   tsvector generated always as
                  (public.records_tsv(title, summary, content, tags)) stored
);

-- 1.7 bookmarks -----------------------------------------------
create table if not exists public.bookmarks (
  user_id    uuid   not null references public.profiles(id) on delete cascade,
  record_id  bigint not null references public.records(id)  on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, record_id)
);

-- 1.8 record_views --------------------------------------------
create table if not exists public.record_views (
  user_id    uuid   not null references public.profiles(id) on delete cascade,
  record_id  bigint not null references public.records(id)  on delete cascade,
  viewed_at  timestamptz not null default now(),
  primary key (user_id, record_id)
);

-- 1.9 reports -------------------------------------------------
create table if not exists public.reports (
  id         bigserial primary key,
  record_id  bigint not null references public.records(id)  on delete cascade,
  user_id    uuid   not null references public.profiles(id) on delete cascade,
  reason     text   not null check (reason in ('false_info','no_source','fiction','inappropriate','other')),
  detail     text,
  created_at timestamptz not null default now(),
  unique (record_id, user_id)
);

-- 1.10 record_counters (행성별 일련번호 발급) -------------------
create table if not exists public.record_counters (
  planet_id text primary key references public.planets(id) on delete cascade,
  last_no   int not null default 0
);

-- ============================================================
-- 2. 인덱스
-- ============================================================
create index if not exists idx_records_path
  on public.records (planet_id, category_id, subcategory_id);
create index if not exists idx_records_event_date on public.records (event_date desc);
create index if not exists idx_records_created_at on public.records (created_at desc);
create index if not exists idx_records_live
  on public.records (planet_id, category_id, subcategory_id)
  where status = 'published' and deleted_at is null;
create index if not exists idx_records_tags   on public.records using gin (tags);
create index if not exists idx_records_search on public.records using gin (search_vector);
create index if not exists idx_records_author on public.records (author_id);
create index if not exists idx_views_user     on public.record_views (user_id, viewed_at desc);
create index if not exists idx_bookmarks_user on public.bookmarks (user_id, created_at desc);
create index if not exists idx_subcat_planets on public.subcategories using gin (planet_ids);

-- ============================================================
-- 3. 공통 헬퍼 함수
-- ============================================================

-- 현재 로그인 사용자의 등급 (비로그인 = 0)
create or replace function public.current_level() returns int
language sql stable security definer set search_path = public as $$
  select coalesce((select level from public.profiles where id = auth.uid()), 0);
$$;

-- 현재 로그인 사용자가 관리자인가
create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce((select is_admin from public.profiles where id = auth.uid()), false);
$$;

-- 본인 프로필 전체 (lang, is_admin 포함) — 클라이언트는 이 RPC 로만 조회
create or replace function public.get_my_profile()
returns table (
  id uuid, keeper_code text, display_name text,
  level int, lang text, is_admin boolean, created_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select p.id, p.keeper_code, p.display_name, p.level, p.lang, p.is_admin, p.created_at
    from public.profiles p
   where p.id = auth.uid();
$$;

-- ============================================================
-- 4. 가입 / 등급 트리거
-- ============================================================

-- 4.1 가입 시 profiles 생성 + 이메일 인증 완료 시 keeper_code 발급
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, display_name, lang)
  values (
    new.id,
    left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), 'KEEPER'), 20),
    coalesce(nullif(new.raw_user_meta_data ->> 'lang', ''), 'ko')
  )
  on conflict (id) do nothing;

  if new.email_confirmed_at is not null then
    update public.profiles
       set keeper_code = 'KEEPER-' || lpad(nextval('public.keeper_code_seq')::text, 3, '0')
     where id = new.id and keeper_code is null;
  end if;

  return new;
end $$;

drop trigger if exists on_auth_user_created   on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

drop trigger if exists on_auth_user_confirmed on auth.users;
create trigger on_auth_user_confirmed
  after update of email_confirmed_at on auth.users
  for each row
  when (old.email_confirmed_at is null and new.email_confirmed_at is not null)
  execute function public.handle_new_user();

-- 4.2 등급 산정 (서버에서만 수행 / 4.3)
create or replace function public.recalc_level() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_cnt int; v_new int;
begin
  select count(*) into v_cnt from public.record_views where user_id = new.user_id;
  v_new := case
             when v_cnt >= 60 then 5
             when v_cnt >= 30 then 4
             when v_cnt >= 10 then 3
             else 2
           end;
  update public.profiles
     set level = greatest(level, v_new)
   where id = new.user_id and level < v_new;
  return new;
end $$;

drop trigger if exists trg_recalc_level on public.record_views;
create trigger trg_recalc_level
  after insert on public.record_views
  for each row execute function public.recalc_level();

-- ============================================================
-- 5. 기록 쓰기 검증 / 코드 발급 (4.8, 5.4)
-- ============================================================

-- 공통 값 검증 (5.6 템플릿 규칙)
create or replace function public.validate_record_payload(
  p_title jsonb, p_summary jsonb, p_content jsonb, p_tags text[], p_source text, p_level int
) returns void
language plpgsql immutable as $$
begin
  if coalesce(btrim(p_title ->> 'ko'), '') = '' then
    raise exception 'AKASHIC_TITLE_REQUIRED';
  end if;
  if char_length(p_title ->> 'ko') > 100
     or char_length(coalesce(p_title ->> 'en', '')) > 100
     or char_length(coalesce(p_title ->> 'ja', '')) > 100 then
    raise exception 'AKASHIC_TITLE_TOO_LONG';
  end if;
  if coalesce(btrim(p_summary ->> 'ko'), '') = '' then
    raise exception 'AKASHIC_SUMMARY_REQUIRED';
  end if;
  if char_length(p_summary ->> 'ko') > 300
     or char_length(coalesce(p_summary ->> 'en', '')) > 300
     or char_length(coalesce(p_summary ->> 'ja', '')) > 300 then
    raise exception 'AKASHIC_SUMMARY_TOO_LONG';
  end if;
  if coalesce(btrim(p_content ->> 'ko'), '') = '' then
    raise exception 'AKASHIC_CONTENT_REQUIRED';
  end if;
  if coalesce(btrim(p_source), '') = '' then
    raise exception 'AKASHIC_SOURCE_REQUIRED';
  end if;
  if array_length(p_tags, 1) is null or array_length(p_tags, 1) < 1 then
    raise exception 'AKASHIC_TAGS_REQUIRED';
  end if;
  if array_length(p_tags, 1) > 8 then
    raise exception 'AKASHIC_TAGS_TOO_MANY';
  end if;
  if p_level < 1 or p_level > 5 then
    raise exception 'AKASHIC_LEVEL_RANGE';
  end if;
end $$;

-- 5.1 INSERT 트리거
create or replace function public.records_before_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_uid  uuid := auth.uid();
  v_lvl  int;
  v_conf timestamptz;
  v_cnt  int;
  v_last timestamptz;
  v_dup  int;
  v_no   int;
begin
  if v_uid is not null then
    -- 클라이언트가 보낸 서버 소유 필드는 모두 무시하고 서버 값으로 덮어씀
    new.author_id  := v_uid;
    new.is_seed    := false;
    new.status     := 'published';
    new.deleted_at := null;
    new.created_at := now();          -- 클라이언트 시각 신뢰 금지 (2.11)
    new.updated_at := null;

    -- 이메일 인증 계정만 작성 가능
    select email_confirmed_at into v_conf from auth.users where id = v_uid;
    if v_conf is null then
      raise exception 'AKASHIC_EMAIL_UNVERIFIED';
    end if;

    select level into v_lvl from public.profiles where id = v_uid;
    if v_lvl is null then
      raise exception 'AKASHIC_NO_PROFILE';
    end if;
    if new.level > v_lvl then
      raise exception 'AKASHIC_LEVEL_EXCEEDED';
    end if;

    -- 하루 10건 제한
    select count(*) into v_cnt
      from public.records
     where author_id = v_uid and created_at >= date_trunc('day', now());
    if v_cnt >= 10 then
      raise exception 'AKASHIC_DAILY_LIMIT';
    end if;

    -- 60초 간격 제한
    select max(created_at) into v_last from public.records where author_id = v_uid;
    if v_last is not null and now() - v_last < interval '60 seconds' then
      raise exception 'AKASHIC_TOO_FAST';
    end if;

    -- 제목+본문 중복 등록 차단
    select count(*) into v_dup
      from public.records
     where author_id = v_uid
       and deleted_at is null
       and btrim(title   ->> 'ko') = btrim(new.title   ->> 'ko')
       and btrim(content ->> 'ko') = btrim(new.content ->> 'ko');
    if v_dup > 0 then
      raise exception 'AKASHIC_DUPLICATE';
    end if;
  end if;

  perform public.validate_record_payload(
    new.title, new.summary, new.content, new.tags, new.source, new.level);

  -- 행성별 일련번호 발급 (동시 등록 충돌 방지)
  insert into public.record_counters (planet_id, last_no)
       values (new.planet_id, 1)
  on conflict (planet_id)
       do update set last_no = public.record_counters.last_no + 1
    returning last_no into v_no;

  new.record_code := 'REC-' || new.planet_id || '-' || lpad(v_no::text, 4, '0');
  return new;
end $$;

drop trigger if exists trg_records_before_insert on public.records;
create trigger trg_records_before_insert
  before insert on public.records
  for each row execute function public.records_before_insert();

-- 5.2 UPDATE 트리거
create or replace function public.records_before_update() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  v_uid    uuid := auth.uid();
  v_lvl    int;
  v_admin  boolean := public.is_admin();
  -- 서버 내부 트리거(신고 누적 처리 등)가 상태를 바꿀 때만 켜지는 트랜잭션 로컬 플래그.
  -- 이 플래그는 트리거 검사만 완화하며 RLS 는 그대로 적용되므로,
  -- 클라이언트가 임의로 켜더라도 남의 기록을 수정할 수 없습니다.
  v_bypass boolean := coalesce(current_setting('akashic.bypass', true), '') = 'on';
begin
  if v_uid is not null then
    -- 불변 필드 고정
    new.id          := old.id;
    new.record_code := old.record_code;
    new.author_id   := old.author_id;
    new.is_seed     := old.is_seed;
    new.created_at  := old.created_at;

    if not v_bypass then
      new.updated_at := now();

      if old.author_id is distinct from v_uid and not v_admin then
        raise exception 'AKASHIC_NOT_OWNER';
      end if;

      -- 상태 변경(hidden 설정/해제)은 관리자 또는 서버 내부 처리만
      if new.status is distinct from old.status and not v_admin then
        new.status := old.status;
      end if;

      if not v_admin then
        select level into v_lvl from public.profiles where id = v_uid;
        if new.level > coalesce(v_lvl, 1) then
          raise exception 'AKASHIC_LEVEL_EXCEEDED';
        end if;
      end if;
    end if;
  end if;

  perform public.validate_record_payload(
    new.title, new.summary, new.content, new.tags, new.source, new.level);
  return new;
end $$;

drop trigger if exists trg_records_before_update on public.records;
create trigger trg_records_before_update
  before update on public.records
  for each row execute function public.records_before_update();

-- 5.3 신고 누적 3명 -> hidden (4.8)
create or replace function public.reports_after_insert() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_cnt int;
begin
  select count(distinct user_id) into v_cnt
    from public.reports where record_id = new.record_id;
  if v_cnt >= 3 then
    -- 이 갱신은 신고자가 아니라 시스템이 수행하는 것이므로
    -- records_before_update 의 소유자 검사를 트랜잭션 범위에서만 우회한다.
    perform set_config('akashic.bypass', 'on', true);
    update public.records
       set status = 'hidden'
     where id = new.record_id and status = 'published';
    perform set_config('akashic.bypass', 'off', true);
  end if;
  return new;
end $$;

drop trigger if exists trg_reports_after_insert on public.reports;
create trigger trg_reports_after_insert
  after insert on public.reports
  for each row execute function public.reports_after_insert();

-- ============================================================
-- 6. 조회 뷰
--    ※ 이 뷰들은 소유자(postgres) 권한으로 실행되는 SECURITY DEFINER 뷰입니다.
--      따라서 가시성 조건을 뷰 안에 명시적으로 넣습니다.
--      records 본문(content)·요약(summary) 컬럼은 클라이언트 롤에서 회수하고
--      이 뷰를 통해서만, 등급 조건을 만족할 때만 내보냅니다. (4.3 / 7.1)
-- ============================================================

create view public.v_records as
select
  r.id,
  r.record_code,
  r.planet_id,
  r.category_id,
  r.subcategory_id,
  r.title,
  coalesce(r.title ->> 'ko', '') as title_ko,
  coalesce(r.title ->> 'en', '') as title_en,
  coalesce(r.title ->> 'ja', '') as title_ja,
  case when (r.level <= public.current_level()
             and pl.required_level <= public.current_level())
            or r.author_id = auth.uid()
       then r.summary end as summary,
  case when (r.level <= public.current_level()
             and pl.required_level <= public.current_level())
            or r.author_id = auth.uid()
       then r.content end as content,
  r.event_date,
  r.tags,
  r.source,
  r.level,
  r.related_ids,
  coalesce(p.keeper_code, case when r.is_seed then 'KEEPER-000' else 'KEEPER-???' end)
                                                       as author_code,
  r.is_seed,
  r.status,
  r.created_at,
  r.updated_at,
  ((r.level <= public.current_level()
    and pl.required_level <= public.current_level())
   or r.author_id = auth.uid())                        as can_view,
  (r.author_id is not distinct from auth.uid())        as is_mine,
  exists (select 1 from public.bookmarks b
           where b.record_id = r.id and b.user_id = auth.uid()) as is_bookmarked
from public.records r
join public.planets  pl on pl.id = r.planet_id
left join public.profiles p on p.id = r.author_id
where auth.uid() is not null
  and r.deleted_at is null
  and (r.status = 'published' or r.author_id = auth.uid());

-- 내가 쓴 기록 (삭제·숨김 포함 / 2.12)
create view public.v_my_records as
select
  r.id, r.record_code, r.planet_id, r.category_id, r.subcategory_id,
  r.title, coalesce(r.title ->> 'ko','') as title_ko,
  r.summary, r.content, r.event_date, r.tags, r.source, r.level, r.related_ids,
  coalesce(p.keeper_code, case when r.is_seed then 'KEEPER-000' else 'KEEPER-???' end)
                                                       as author_code,
  r.is_seed,
  case when r.deleted_at is not null then 'deleted' else r.status end as state,
  r.status, r.deleted_at, r.created_at, r.updated_at,
  true as can_view, true as is_mine,
  exists (select 1 from public.bookmarks b
           where b.record_id = r.id and b.user_id = auth.uid()) as is_bookmarked
from public.records r
left join public.profiles p on p.id = r.author_id
where auth.uid() is not null and r.author_id = auth.uid();

-- 북마크 목록 (소프트 삭제·숨김 기록은 자동 제외 / 4.9(2))
create view public.v_bookmarks as
select b.created_at as bookmarked_at, v.*
  from public.bookmarks b
  join public.v_records v on v.id = b.record_id
 where b.user_id = auth.uid()
   and v.status = 'published';

-- 최근 조회 (4.11)
create view public.v_recent_views as
select rv.viewed_at, v.*
  from public.record_views rv
  join public.v_records v on v.id = rv.record_id
 where rv.user_id = auth.uid()
   and v.status = 'published';

-- ============================================================
-- 7. 집계 뷰 (4.6 — 개수 하드코딩 금지)
-- ============================================================

create view public.v_planet_counts as
select planet_id, count(*)::int as record_count
  from public.records
 where status = 'published' and deleted_at is null
 group by planet_id;

create view public.v_category_counts as
select planet_id, category_id, count(*)::int as record_count
  from public.records
 where status = 'published' and deleted_at is null
 group by planet_id, category_id;

create view public.v_subcategory_counts as
select planet_id, category_id, subcategory_id,
       count(*)::int as record_count,
       max(created_at) as last_created_at
  from public.records
 where status = 'published' and deleted_at is null
 group by planet_id, category_id, subcategory_id;

create view public.v_archive_stats as
select
  (select count(*)::int from public.records
    where status = 'published' and deleted_at is null)                    as total_records,
  (select count(*)::int from public.planets)                              as total_planets,
  (select count(*)::int from public.records
    where status = 'published' and deleted_at is null
      and created_at >= date_trunc('day', now()))                         as today_records;

-- ============================================================
-- 8. RPC
-- ============================================================

-- 8.1 관련 기록 산출 (4.10)
create or replace function public.get_related_records(p_record_id bigint, p_limit int default 5)
returns setof public.v_records
language plpgsql stable security definer set search_path = public as $$
declare
  v_rec public.records%rowtype;
begin
  select * into v_rec from public.records where id = p_record_id;
  if not found then return; end if;

  return query
  with base as (
    select v.*,
           case when v.id = any(v_rec.related_ids) then 1000 else 0 end
           + (select count(*) from unnest(v.tags) t where t = any(v_rec.tags))::int * 3
           + case when v.subcategory_id = v_rec.subcategory_id then 2 else 0 end
           + case when v.category_id    = v_rec.category_id    then 1 else 0 end
           + case when v.planet_id      = v_rec.planet_id      then 1 else 0 end
           + case when v.event_date is not null and v_rec.event_date is not null
                   and abs(extract(year from v.event_date) - extract(year from v_rec.event_date)) <= 10
                  then 1 else 0 end as score,
           case when v.event_date is not null and v_rec.event_date is not null
                then abs(extract(year from v.event_date) - extract(year from v_rec.event_date))
                else 99999 end as year_gap
      from public.v_records v
     where v.id <> p_record_id
       and v.status = 'published'
  )
  select id, record_code, planet_id, category_id, subcategory_id,
         title, title_ko, title_en, title_ja, summary, content,
         event_date, tags, source, level, related_ids, author_code,
         is_seed, status, created_at, updated_at,
         can_view, is_mine, is_bookmarked
    from base
   where score > 0
   order by score desc, year_gap asc, created_at desc
   limit greatest(coalesce(p_limit, 5), 0);
end $$;

-- 8.2 검색 (2.15 / Postgres 전문검색)
create or replace function public.search_records(
  p_q text, p_limit int default 20, p_offset int default 0
) returns setof public.v_records
language sql stable security definer set search_path = public as $$
  select v.*
    from public.v_records v
    join public.records r on r.id = v.id
   where v.status = 'published'
     and coalesce(btrim(p_q), '') <> ''
     and r.search_vector @@ websearch_to_tsquery('simple', p_q)
   order by ts_rank(r.search_vector, websearch_to_tsquery('simple', p_q)) desc,
            r.created_at desc
   limit greatest(coalesce(p_limit, 20), 0)
  offset greatest(coalesce(p_offset, 0), 0);
$$;

-- 8.3 신고 누적으로 숨겨진 기록 목록 (관리자 전용 / 4.8)
--     v_records 는 숨김 기록을 내보내지 않으므로 별도 RPC 로 제공한다.
create or replace function public.list_hidden_records()
returns table (
  id bigint, record_code text, planet_id text, category_id text, subcategory_id text,
  title jsonb, summary jsonb, content jsonb, event_date date, tags text[],
  source text, level int, author_code text, report_count int,
  created_at timestamptz, updated_at timestamptz
)
language sql stable security definer set search_path = public as $$
  select r.id, r.record_code, r.planet_id, r.category_id, r.subcategory_id,
         r.title, r.summary, r.content, r.event_date, r.tags,
         r.source, r.level,
         coalesce(p.keeper_code, case when r.is_seed then 'KEEPER-000' else 'KEEPER-???' end),
         (select count(*)::int from public.reports rp where rp.record_id = r.id),
         r.created_at, r.updated_at
    from public.records r
    left join public.profiles p on p.id = r.author_id
   where public.is_admin()
     and r.status = 'hidden'
     and r.deleted_at is null
   order by r.created_at desc;
$$;

-- 8.4 최근 조회 기록 (upsert / 4.11)
create or replace function public.touch_record_view(p_record_id bigint)
returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  insert into public.record_views (user_id, record_id, viewed_at)
       values (auth.uid(), p_record_id, now())
  on conflict (user_id, record_id) do update set viewed_at = now();
end $$;

-- 8.5 소프트 삭제 (4.9(1))
create or replace function public.soft_delete_record(p_record_id bigint)
returns void
language plpgsql security definer set search_path = public as $$
declare v_author uuid;
begin
  select author_id into v_author from public.records where id = p_record_id;
  if v_author is null and not public.is_admin() then
    raise exception 'AKASHIC_NOT_OWNER';
  end if;
  if v_author is distinct from auth.uid() and not public.is_admin() then
    raise exception 'AKASHIC_NOT_OWNER';
  end if;
  update public.records set deleted_at = now() where id = p_record_id;
end $$;

-- ============================================================
-- 9. 권한 (컬럼 단위 회수 — 등급 미달 본문이 응답에 담기지 않도록)
-- ============================================================
revoke all on public.records      from anon, authenticated;
revoke all on public.profiles     from anon, authenticated;
revoke all on public.record_counters from anon, authenticated;

-- records: summary / content / search_vector 는 SELECT 권한을 주지 않는다.
grant select (id, record_code, planet_id, category_id, subcategory_id,
              title, event_date, tags, source, level, related_ids,
              author_id, is_seed, status, deleted_at, created_at, updated_at)
  on public.records to authenticated;
grant insert on public.records to authenticated;
grant update (planet_id, category_id, subcategory_id, title, summary, content,
              event_date, tags, source, level, related_ids, status, deleted_at, updated_at)
  on public.records to authenticated;

-- profiles: 공개 컬럼만 (5.2)
grant select (id, keeper_code, display_name, level) on public.profiles to anon, authenticated;
grant update (display_name, lang) on public.profiles to authenticated;

grant select, insert, delete on public.bookmarks    to authenticated;
grant select, insert, update on public.record_views to authenticated;
grant insert on public.reports to authenticated;
grant select on public.reports to authenticated;   -- 실제 노출은 RLS(관리자)로 차단
grant usage, select on sequence public.reports_id_seq to authenticated;
grant usage, select on sequence public.records_id_seq to authenticated;

grant select on public.planets, public.categories, public.subcategories to anon, authenticated;

grant select on public.v_records, public.v_my_records, public.v_bookmarks,
                public.v_recent_views to authenticated;
grant select on public.v_planet_counts, public.v_category_counts,
                public.v_subcategory_counts, public.v_archive_stats to anon, authenticated;

grant execute on function public.get_my_profile()                     to authenticated;
grant execute on function public.get_related_records(bigint, int)     to authenticated;
grant execute on function public.search_records(text, int, int)       to authenticated;
grant execute on function public.touch_record_view(bigint)            to authenticated;
grant execute on function public.soft_delete_record(bigint)           to authenticated;
grant execute on function public.list_hidden_records()                to authenticated;
grant execute on function public.current_level()                      to anon, authenticated;
grant execute on function public.is_admin()                           to anon, authenticated;

-- 뷰가 정의자(소유자) 권한으로 동작하도록 명시.
-- PostgreSQL 15 미만에는 security_invoker 옵션이 없으므로 예외를 무시한다.
do $$
declare v text;
begin
  foreach v in array array['v_records','v_my_records','v_bookmarks','v_recent_views',
                           'v_planet_counts','v_category_counts','v_subcategory_counts',
                           'v_archive_stats']
  loop
    begin
      execute format('alter view public.%I set (security_invoker = false)', v);
    exception when others then
      raise notice 'security_invoker option not supported, skipped for %', v;
    end;
  end loop;
end $$;

-- END OF schema.sql
