/* 느린 응답에서의 로딩 표시 · 화면 경합 · 이중 제출 */
const L = require('./lib');
const { BASE, sql, newCtx, open, signup, login, confirmEmail: confirm, setLang } = L;
const { check, summary } = L.reporter();

const delay = (ctx, pattern, ms) => ctx.route(pattern, async r => {
  await new Promise(s => setTimeout(s, ms));
  await r.continue();
});

(async () => {
const browser = await L.launch();
const ctx = await newCtx(browser);
const page = await open(ctx);
await signup(page, 'race@test.io', 'passphrase1', 'Race');
await confirm('race@test.io');
await login(page, 'race@test.io', 'passphrase1');
await setLang(page, 'ko');

/* ---------- 2.16 로딩 중 스켈레톤 ---------- */
await delay(ctx, '**/rest/v1/v_records*', 1500);
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY'; });
await page.waitForTimeout(500);
const during = await page.evaluate(() => ({
  skeleton: document.querySelectorAll('#main .skeleton').length,
  emptyMain: document.getElementById('main').textContent.trim().length === 0,
  head: !!document.querySelector('.list-title')
}));
check('2.16 목록 로딩 중 스켈레톤 노출 (빈 화면 아님)',
      during.skeleton > 0 && !during.emptyMain && during.head, JSON.stringify(during));
await page.waitForTimeout(1600);
check('로딩이 끝나면 스켈레톤이 실제 카드로 대체',
      (await page.locator('#main .skeleton').count()) === 0 &&
      (await page.locator('.card[data-code]').count()) === 2);
await ctx.unroute('**/rest/v1/v_records*');

await delay(ctx, '**/rest/v1/planets*', 1500);
await page.evaluate(() => { location.hash = '#/'; });
await page.waitForTimeout(500);
check('2.16 행성 목록 로딩 중에도 스켈레톤 노출',
      (await page.locator('#main .skeleton').count()) > 0);
await page.waitForTimeout(1800);
await ctx.unroute('**/rest/v1/planets*');

/* ---------- 느린 응답 중 언어 전환 ---------- */
await delay(ctx, '**/rest/v1/v_records*', 1200);
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY'; });
await page.waitForTimeout(300);
await page.click('#app .lang-btn[data-lang="en"]');
await page.waitForTimeout(2600);
const afterLang = await page.evaluate(() => ({
  cards: document.querySelectorAll('.card[data-code]').length,
  title: (document.querySelector('.card-title') || {}).textContent || '',
  sort: (document.querySelector('#sort-sel option[selected], #sort-sel') || {}).textContent || '',
  lang: document.documentElement.lang
}));
check('로딩 중 언어를 바꿔도 목록이 중복되지 않고 새 언어로 표시',
      afterLang.cards === 2 && afterLang.lang === 'en' &&
      /Manhattan|Watt/.test(afterLang.title), JSON.stringify(afterLang).slice(0, 160));
await ctx.unroute('**/rest/v1/v_records*');
await setLang(page, 'ko');

/* ---------- 느린 응답 중 다른 화면으로 이동 ----------
   이미 본 좌표는 목록이 캐시돼 조회가 일어나지 않으므로,
   아직 한 번도 열지 않은 좌표를 써야 실제로 경합이 생긴다. */
await delay(ctx, '**/rest/v1/v_records*', 1800);
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/LIFE-005/s/GENETICS'; });
await page.waitForTimeout(250);
await page.evaluate(() => { location.hash = '#/'; });      // 응답이 오기 전에 떠난다
await page.waitForTimeout(2800);
const afterLeave = await page.evaluate(() => ({
  hash: location.hash,
  planets: document.querySelectorAll('.card[data-planet]').length,
  records: document.querySelectorAll('.card[data-code]').length,
  title: (document.querySelector('.section-title') || {}).textContent || ''
}));
check('느린 목록 응답이 나중에 도착해도 지금 화면을 덮어쓰지 않음',
      afterLeave.hash === '#/' && afterLeave.planets === 5 && afterLeave.records === 0,
      JSON.stringify(afterLeave));
await ctx.unroute('**/rest/v1/v_records*');

/* ---------- 빠른 연속 이동 ---------- */
await page.evaluate(() => {
  location.hash = '#/p/TERRA-001';
  location.hash = '#/p/TERRA-001/c/TECH-004';
  location.hash = '#/p/TERRA-002';
});
await page.waitForTimeout(2200);
const rapid = await page.evaluate(() => ({
  hash: location.hash,
  cats: document.querySelectorAll('.card[data-cat]').length,
  crumbs: document.getElementById('crumbs').textContent
}));
check('연속 이동 뒤 마지막 좌표의 화면만 남음',
      rapid.hash === '#/p/TERRA-002' && rapid.cats === 9 && /화성/.test(rapid.crumbs),
      JSON.stringify(rapid));

/* ---------- 작성 폼 이중 제출 ---------- */
sql("update public.records set created_at = created_at - interval '10 minutes'");
await page.evaluate(() => { location.hash = '#/new'; }); await page.waitForTimeout(1400);
await page.selectOption('#f-planet', 'TERRA-001');
await page.selectOption('#f-cat', 'ART-007'); await page.waitForTimeout(500);
await page.selectOption('#f-sub', 'LITERATURE');
await page.fill('#f-title', '이중 제출 시험');
await page.fill('#f-summary', '요약'); await page.fill('#f-content', '본문');
await page.fill('#f-tag', '시험'); await page.keyboard.press('Enter');
await page.fill('#f-source', '출처');
await page.evaluate(() => {                       // 두 번 연속 제출
  const b = document.querySelector('#record-form button[type=submit]');
  b.click(); b.click();
});
await page.waitForTimeout(2500);
check('작성 폼을 두 번 눌러도 기록은 하나만 생성',
      sql("select count(*) from public.records where title->>'ko'='이중 제출 시험'") === '1',
      sql("select count(*) from public.records where title->>'ko'='이중 제출 시험'"));

/* ---------- 더 불러오기 이중 클릭 ---------- */
sql(`insert into public.records
       (planet_id,category_id,subcategory_id,title,summary,content,event_date,tags,source,level,is_seed,author_id)
     select 'TERRA-001','ART-007','LITERATURE',
            jsonb_build_object('ko','더보기 '||lpad(g::text,2,'0')), jsonb_build_object('ko','요약'),
            jsonb_build_object('ko','본문'), make_date(1900+g,1,1), array['더보기'],'출처',1,true,
            (select id from public.profiles where keeper_code='KEEPER-000')
       from generate_series(1,25) g`);
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/ART-007/s/LITERATURE'; });
await page.waitForTimeout(1600);
await page.evaluate(() => {
  const b = document.getElementById('btn-more');
  if (b) { b.click(); b.click(); }
});
await page.waitForTimeout(2500);
const paged = await page.evaluate(() => {
  const codes = [...document.querySelectorAll('.card-code')].map(e => e.textContent.trim());
  return { total: codes.length, dupes: codes.length - new Set(codes).size };
});
check('더 불러오기를 두 번 눌러도 카드가 중복되지 않음',
      paged.dupes === 0, JSON.stringify(paged));

/* ---------- 같은 기록을 두 탭에서 수정 ---------- */
const code = sql("select record_code from public.records where title->>'ko'='이중 제출 시험'");
const tab2 = await open(ctx);
await tab2.waitForTimeout(1200);
for (const [p, t] of [[page, '첫째 탭 수정'], [tab2, '둘째 탭 수정']]) {
  await p.evaluate(c => { location.hash = '#/edit/' + c; }, code);
  await p.waitForTimeout(1600);
  await p.fill('#f-title', t);
}
await page.click('#record-form button[type=submit]'); await page.waitForTimeout(1800);
await tab2.click('#record-form button[type=submit]'); await tab2.waitForTimeout(1800);
const finalTitle = sql(`select title->>'ko' from public.records where record_code='${code}'`);
const revisions = sql(`select count(*) from public.records where record_code='${code}'`);
check('같은 기록을 두 탭에서 수정하면 나중 저장이 남고 행은 하나',
      finalTitle === '둘째 탭 수정' && revisions === '1', `${finalTitle} / 행=${revisions}`);

/* ---------- 회귀: 관련 기록을 기다리는 사이 떠나면 모달이 열리지 않는다 ---------- */
await delay(ctx, '**/rest/v1/rpc/get_related_records', 1800);
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY'; });
await page.waitForTimeout(1400);
await page.locator('.card[data-code]').first().click();
await page.waitForTimeout(600);                  // 관련 기록 응답 전에
await page.keyboard.press('Escape');
await page.waitForTimeout(2600);                 // 응답이 도착하고도 남을 만큼
const late = await page.evaluate(() => ({
  modal: !document.getElementById('modal-record').hidden,
  locked: document.body.classList.contains('drawer-open'),
  hash: location.hash
}));
check('관련 기록이 늦게 도착해도 떠난 뒤에는 모달이 열리지 않음',
      !late.modal && !late.locked, JSON.stringify(late));
await ctx.unroute('**/rest/v1/rpc/get_related_records');

await browser.close();
process.exit(summary() ? 1 : 0);
})().catch(e => { console.error('RUNNER ERROR', e); process.exit(1); });
