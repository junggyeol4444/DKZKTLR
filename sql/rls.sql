alter table public.profiles enable row level security;
alter table public.domains enable row level security;
alter table public.categories enable row level security;
alter table public.records enable row level security;
alter table public.bookmarks enable row level security;
alter table public.record_views enable row level security;
alter table public.reports enable row level security;
alter table public.moderation_cases enable row level security;
alter table public.moderation_votes enable row level security;

grant execute on function public.is_admin() to authenticated;

create policy "taxonomy readable" on public.domains for select to authenticated using(true);
create policy "taxonomy admin write" on public.domains for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "categories readable" on public.categories for select to authenticated using(true);
create policy "categories admin write" on public.categories for all to authenticated using(public.is_admin()) with check(public.is_admin());

create policy "public profiles readable" on public.profiles for select to authenticated using(true);
-- Column grants are as important as row policies: users cannot write level/is_admin/keeper_code.
revoke update on public.profiles from authenticated;
grant update(display_name,lang) on public.profiles to authenticated;
create policy "own profile editable" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());

create policy "published or own records readable" on public.records for select to authenticated using((status in ('published','under_review') and deleted_at is null) or author_id=auth.uid() or public.is_admin());
create policy "verified users create records" on public.records for insert to authenticated with check(author_id=auth.uid() and (select email_confirmed_at is not null from auth.users where id=auth.uid()));
create policy "authors edit records" on public.records for update to authenticated using(author_id=auth.uid() or public.is_admin()) with check(author_id=auth.uid() or public.is_admin());
create policy "admin hard delete" on public.records for delete to authenticated using(public.is_admin());

create policy "own bookmarks" on public.bookmarks for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "own views" on public.record_views for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "submit own report" on public.reports for insert to authenticated with check(user_id=auth.uid() and exists(select 1 from public.records r where r.id=record_id and r.author_id<>auth.uid()));
create policy "admins read reports" on public.reports for select to authenticated using(public.is_admin());
create policy "admins read cases" on public.moderation_cases for select to authenticated using(public.is_admin());
create policy "admins read votes" on public.moderation_votes for select to authenticated using(public.is_admin());
create policy "admins vote once" on public.moderation_votes for insert to authenticated with check(public.is_admin() and admin_id=auth.uid() and exists(select 1 from public.moderation_cases c join public.records r on r.id=c.record_id where c.id=case_id and c.status='open' and r.author_id<>auth.uid()));

revoke all on public.profiles,public.domains,public.categories,public.records,public.bookmarks,public.record_views,public.reports,public.moderation_cases,public.moderation_votes from anon;
grant select on public.domains,public.categories,public.record_catalog,public.archive_statistics to authenticated;
grant select(id,keeper_code,display_name,level,lang,is_admin) on public.profiles to authenticated;
grant select on public.records to authenticated;
grant insert,update on public.records to authenticated;
grant select,insert,delete on public.bookmarks to authenticated;
grant select,insert,update on public.record_views to authenticated;
grant insert on public.reports to authenticated;
grant select on public.moderation_cases,public.moderation_votes to authenticated;
grant insert on public.moderation_votes to authenticated;
grant usage,select on all sequences in schema public to authenticated;
