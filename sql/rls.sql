-- ============================================================
--  AKASHIC RECORDS  /  sql/rls.sql
--  행 단위 보안 정책 (5.2)
--  기본은 거부. 아래에 명시한 정책만 허용됩니다.
--  실행 순서: schema.sql -> rls.sql -> seed.sql
-- ============================================================

alter table public.profiles      enable row level security;
alter table public.planets       enable row level security;
alter table public.categories    enable row level security;
alter table public.subcategories enable row level security;
alter table public.records       enable row level security;
alter table public.bookmarks     enable row level security;
alter table public.record_views  enable row level security;
alter table public.reports       enable row level security;
alter table public.record_counters enable row level security;
-- record_counters 에는 어떤 정책도 만들지 않습니다.
-- => 클라이언트 롤은 접근 불가. 트리거(SECURITY DEFINER)만 사용합니다.

-- ------------------------------------------------------------
-- 정책 초기화 (재실행 가능하도록)
-- ------------------------------------------------------------
do $$
declare r record;
begin
  for r in
    select schemaname, tablename, policyname
      from pg_policies
     where schemaname = 'public'
       and tablename in ('profiles','planets','categories','subcategories',
                         'records','bookmarks','record_views','reports','record_counters')
  loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

-- ------------------------------------------------------------
-- 1. 분류 테이블 : 읽기 전체 허용 / 쓰기는 관리자만
-- ------------------------------------------------------------
create policy planets_select on public.planets
  for select to anon, authenticated using (true);
create policy planets_write on public.planets
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy categories_select on public.categories
  for select to anon, authenticated using (true);
create policy categories_write on public.categories
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

create policy subcategories_select on public.subcategories
  for select to anon, authenticated using (true);
create policy subcategories_write on public.subcategories
  for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 2. profiles
--    SELECT 는 인증 사용자에게 열되, 노출 컬럼은 schema.sql 의
--    컬럼 단위 GRANT (id, keeper_code, display_name, level) 로 제한됩니다.
--    본인 전체 정보는 get_my_profile() RPC 로만 조회합니다.
--    UPDATE 도 컬럼 GRANT 로 display_name / lang 만 허용되므로
--    클라이언트가 자기 level 을 올릴 수 없습니다. (7.1)
-- ------------------------------------------------------------
create policy profiles_select on public.profiles
  for select to anon, authenticated using (true);

create policy profiles_update_self on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy profiles_admin_all on public.profiles
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ------------------------------------------------------------
-- 3. records
--    ※ 본문(content)·요약(summary) 은 컬럼 GRANT 에서 제외되어 있고,
--      v_records 뷰가 등급을 검사한 뒤에만 값을 채워 내보냅니다. (4.3)
-- ------------------------------------------------------------
create policy records_select on public.records
  for select to authenticated
  using (
    (status = 'published' and deleted_at is null)
    or author_id = auth.uid()
    or public.is_admin()
  );

create policy records_insert on public.records
  for insert to authenticated
  with check (
    author_id = auth.uid()
    and is_seed = false
    and level <= public.current_level()
  );

create policy records_update on public.records
  for update to authenticated
  using (author_id = auth.uid() or public.is_admin())
  with check (author_id = auth.uid() or public.is_admin());

create policy records_delete on public.records
  for delete to authenticated
  using (author_id = auth.uid() or public.is_admin());

-- ------------------------------------------------------------
-- 4. bookmarks / record_views : 본인 행만
-- ------------------------------------------------------------
create policy bookmarks_own on public.bookmarks
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy record_views_own on public.record_views
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ------------------------------------------------------------
-- 5. reports : INSERT 는 본인 명의로만, SELECT 는 관리자만
-- ------------------------------------------------------------
create policy reports_insert on public.reports
  for insert to authenticated
  with check (user_id = auth.uid());

create policy reports_select_admin on public.reports
  for select to authenticated
  using (public.is_admin());

create policy reports_admin_manage on public.reports
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- END OF rls.sql
