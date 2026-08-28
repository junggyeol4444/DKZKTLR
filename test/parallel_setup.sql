insert into auth.users(instance_id,id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data)
select '00000000-0000-0000-0000-000000000000',id,'authenticated','authenticated',email,now(),'{}',jsonb_build_object('display_name','Parallel')
from(values
 ('20000000-0000-4000-a000-000000000001'::uuid,'parallel1@test.invalid'),
 ('20000000-0000-4000-a000-000000000002'::uuid,'parallel2@test.invalid'),
 ('20000000-0000-4000-a000-000000000003'::uuid,'parallel3@test.invalid'))v(id,email);
