-- 테스트용 Supabase 흉내: 롤과 auth 스키마 스텁.
-- 같은 클러스터에 여러 번 적재될 수 있으므로 전부 재실행 가능해야 한다.
do $$
begin
  create role anon nologin;
exception when duplicate_object then null;
end $$;
do $$
begin
  create role authenticated nologin;
exception when duplicate_object then null;
end $$;
do $$
begin
  create role service_role nologin;
exception when duplicate_object then null;
end $$;

grant usage on schema public to anon, authenticated, service_role;

drop schema if exists auth cascade;
create schema auth;

create table auth.users (
  instance_id uuid,
  id uuid primary key,
  aud text, role text, email text,
  encrypted_password text,
  email_confirmed_at timestamptz,
  raw_app_meta_data jsonb, raw_user_meta_data jsonb,
  created_at timestamptz, updated_at timestamptz
);

create or replace function auth.uid() returns uuid
language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

grant usage on schema auth to anon, authenticated, service_role;
