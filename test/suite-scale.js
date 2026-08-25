/* 규모와 동시성: 코드 발급 경계 · 동시 작성 · 대량 데이터에서의 집계 */
const L = require('./lib');
const { sql } = L;
const { check, summary } = L.reporter();
const { execFileSync } = require('child_process');

const PGSOCKET = process.env.PGSOCKET || '/tmp/akashic-pg';
const PGPORT   = process.env.PGPORT_TEST || '5439';
const run = q => execFileSync('psql',
  ['-h', PGSOCKET, '-p', PGPORT, '-U', 'postgres', '-v', 'ON_ERROR_STOP=1', '-q', '-c', q],
  { encoding: 'utf8' });

(async () => {

/* ---------- 5.4 record_code 4자리 경계 ----------
   lpad 는 인자가 더 길면 잘라내므로, 경계를 넘길 때 자리수를 늘리지 않으면
   10000 번째가 1000 번과 같은 코드가 되어 unique 제약에 걸린다. */
run("update public.record_counters set last_no = 9997 where planet_id = 'TERRA-001'");
run(`insert into public.records
       (planet_id,category_id,subcategory_id,title,summary,content,tags,source,level,is_seed,author_id)
     select 'TERRA-001','NAT-001','VOLCANO',
            jsonb_build_object('ko','경계 '||g), jsonb_build_object('ko','요약'),
            jsonb_build_object('ko','본문'), array['경계'],'출처',1,true,
            (select id from public.profiles where keeper_code='KEEPER-000')
       from generate_series(1,5) g`);
const boundary = sql(`select string_agg(record_code, ',' order by id)
                        from public.records where tags @> array['경계']`);
check('5.4 record_code 가 9999 를 넘어도 충돌하지 않고 자리수를 늘림',
      boundary === 'REC-TERRA-001-9998,REC-TERRA-001-9999,REC-TERRA-001-10000,'
                 + 'REC-TERRA-001-10001,REC-TERRA-001-10002', boundary);
check('5.4 전체 record_code 에 중복 없음',
      sql('select count(*) from (select record_code from public.records group by record_code having count(*)>1) x') === '0');

/* ---------- 5.4 keeper_code 3자리 경계 ---------- */
run("select setval('public.keeper_code_seq', 997, true)");
for (const n of [1, 2, 3]) {
  run(`insert into auth.users (instance_id,id,aud,role,email,email_confirmed_at,
         raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
       values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(),
               'authenticated','authenticated','boundary${n}@t.io', now(), '{}', '{}', now(), now())`);
}
const keepers = sql(`select string_agg(keeper_code, ',' order by keeper_code)
                       from public.profiles p join auth.users u on u.id = p.id
                      where u.email like 'boundary%@t.io'`);
check('5.4 keeper_code 가 999 를 넘어도 충돌하지 않고 자리수를 늘림',
      keepers === 'KEEPER-1000,KEEPER-998,KEEPER-999', keepers);
check('5.4 전체 keeper_code 에 중복 없음',
      sql("select count(*) from (select keeper_code from public.profiles where keeper_code is not null group by keeper_code having count(*)>1) x") === '0');

/* ---------- 동시 작성 시 코드 발급 ---------- */
const before = Number(sql("select count(*) from public.records where tags @> array['동시']"));
const sysId = sql("select id from public.profiles where keeper_code='KEEPER-000'");
await Promise.all(Array.from({ length: 20 }, (_, i) =>
  new Promise((res, rej) => {
    require('child_process').execFile('psql',
      ['-h', PGSOCKET, '-p', PGPORT, '-U', 'postgres', '-q', '-c',
       `insert into public.records
          (planet_id,category_id,subcategory_id,title,summary,content,tags,source,level,is_seed,author_id)
        values ('TERRA-002','NAT-001','VOLCANO',
                jsonb_build_object('ko','동시 ${i}'), jsonb_build_object('ko','요약'),
                jsonb_build_object('ko','본문'), array['동시'],'출처',1,true,'${sysId}'::uuid)`],
      e => e ? rej(e) : res());
  })));
const after = sql("select count(*) || '|' || count(distinct record_code) from public.records where tags @> array['동시']");
check('5.4 동시 작성 20건이 서로 다른 코드를 받음',
      after === `${before + 20}|${before + 20}`, after);

/* ---------- 4.6 대량 데이터에서 집계와 목록 ---------- */
run(`insert into public.records
       (planet_id,category_id,subcategory_id,title,summary,content,event_date,tags,source,level,is_seed,author_id)
     select (array['TERRA-001','TERRA-002','MOON-TITAN'])[1+(g%3)],
            (array['NAT-001','CIV-002','TECH-004','LIFE-005','EVENT-006'])[1+(g%5)],
            (array['VOLCANO','ANCIENT','ENERGY','EVOLUTION','DISASTER'])[1+(g%5)],
            jsonb_build_object('ko','부하 '||g), jsonb_build_object('ko','요약'),
            jsonb_build_object('ko','본문'), make_date(1500+(g%500),1+(g%12),1+(g%28)),
            array['부하'],'출처',1+(g%5),true,
            (select id from public.profiles where keeper_code='KEEPER-000')
       from generate_series(1,20000) g`);
run('analyze public.records');
const total = Number(sql('select count(*) from public.records'));

const timeIt = q => { const t = Date.now(); sql(q); return Date.now() - t; };
const tStats = timeIt('select * from public.v_archive_stats');
const tSub   = timeIt('select count(*) from public.v_subcategory_counts');
check('4.6 2만 건 이상에서도 집계 뷰가 즉시 응답',
      total > 20000 && tStats < 1500 && tSub < 1500,
      `${total}건 stats=${tStats}ms subcategory=${tSub}ms`);

const plan = sql(`explain (costs off) select * from public.records
   where planet_id='TERRA-001' and category_id='TECH-004' and subcategory_id='ENERGY'
     and status='published' and deleted_at is null
   order by event_date desc nulls last limit 20`);
check('4.6 목록 조회가 부분 인덱스를 사용 (순차 스캔 아님)',
      /idx_records_live/.test(plan) && !/Seq Scan on records/.test(plan),
      plan.split('\n').map(x => x.trim()).filter(Boolean).slice(0, 3).join(' / '));

process.exit(summary() ? 1 : 0);
})().catch(e => { console.error('RUNNER ERROR', e); process.exit(1); });
