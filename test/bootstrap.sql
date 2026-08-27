create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users(
 instance_id uuid,id uuid primary key,aud text,role text,email text,encrypted_password text,
 email_confirmed_at timestamptz,raw_app_meta_data jsonb default '{}',raw_user_meta_data jsonb default '{}',
 created_at timestamptz default now(),updated_at timestamptz default now()
);
create or replace function auth.uid() returns uuid language sql stable as $$
 select nullif(current_setting('request.jwt.claim.sub',true),'')::uuid
$$;
grant usage on schema auth to anon,authenticated;
grant execute on function auth.uid() to anon,authenticated;
