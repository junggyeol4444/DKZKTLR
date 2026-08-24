/* related_ids 참조 무결성과 관련 기록 산출 (4.9(3), 4.10) */
const L = require('./lib');
const { BASE, sql, newCtx, open, signup, login, confirmEmail: confirm, setLang } = L;
const { check, summary } = L.reporter();
const SHOTS = process.env.SHOTS_DIR || require('os').tmpdir();

(async()=>{
// 대상: 맨해튼(0016). 관련으로 삭제된 것 1, 숨김 1, 정상 1 지정
const target = sql("select id from public.records where record_code='REC-TERRA-001-0016'");
const del  = sql("select id from public.records where record_code='REC-TERRA-001-0003'");
const hid  = sql("select id from public.records where record_code='REC-TERRA-001-0004'");
const ok   = sql("select id from public.records where record_code='REC-TERRA-001-0021'");
sql(`update public.records set deleted_at=now() where id=${del}`);
sql(`update public.records set status='hidden' where id=${hid}`);
sql(`update public.records set related_ids = array[${del},${hid},${ok}]::bigint[] where id=${target}`);
console.log(`related_ids = [삭제 ${del}, 숨김 ${hid}, 정상 ${ok}]`);

const b = await L.launch();
const ctx = await newCtx(b, { viewport: { width: 1280, height: 1000 } });
const p = await open(ctx);
await signup(p, 'rel@test.io', 'passphraseA', 'Rel');
await confirm('rel@test.io');
await login(p, 'rel@test.io', 'passphraseA');
await setLang(p, 'ko');
await p.evaluate(()=>{location.hash='#/p/TERRA-001/c/TECH-004/s/ENERGY/r/REC-TERRA-001-0016';});
await p.waitForTimeout(1800);
const items = await p.locator('#modal-related .related-list li a').allTextContents();
console.log('   관련 기록:', items.map(s=>s.trim()).join(' / '));
const hasDeleted = items.some(t=>/ベスビオ|베수비오|Vesuvius/.test(t));
const hasHidden  = items.some(t=>/흑사병|Black Death|黒死病/.test(t));
const hasOk      = items.some(t=>/월드 와이드 웹|World Wide Web/.test(t));
check('4.9(3) 삭제된 기록이 관련 기록에서 제외', !hasDeleted);
check('4.9(3) 숨김 기록이 관련 기록에서 제외', !hasHidden);
check('4.10(1) related_ids 의 유효 항목이 최상단', items.length>0 && /월드 와이드 웹/.test(items[0]), items[0]);
check('4.10(3) 자동 보충으로 최대 5개까지 채움', items.length===5, 'count='+items.length);
check('4.10(2) 자기 자신 제외', !items.some(t=>/맨해튼/.test(t)));

// 후보 0개일 때 섹션 숨김
sql("delete from public.records where record_code <> 'REC-TERRA-001-0016'");
await p.reload({waitUntil:'domcontentloaded'}); await p.waitForTimeout(2000);
const relHidden = await p.locator('#modal-related').isHidden();
check('4.9(3)/4.10(4) 후보 0개면 관련 기록 섹션 자체를 숨김', relHidden);
await p.screenshot({path:SHOTS + '/s26-related.png'});
await b.close();
process.exit(summary() ? 1 : 0);
})().catch(e=>{console.error('RUNNER ERROR',e);process.exit(1);});
