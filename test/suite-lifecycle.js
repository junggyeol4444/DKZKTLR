/* 등급 상승 · 관련 기록 · 검색 · 작성/수정 · 시드 전량 삭제 후 재검증 (7.2 의 17) */
const L = require('./lib');
const { BASE, sql, newCtx, open, signup, login, confirmEmail: confirm, setLang } = L;
const { check, summary } = L.reporter();
const SHOTS = process.env.SHOTS_DIR || require('os').tmpdir();

(async () => {
const browser = await L.launch();
const ctx = await newCtx(browser);
const page = await open(ctx);
await signup(page, 'delta@test.io', 'passphrase4', 'Delta');
await confirm('delta@test.io');
await login(page, 'delta@test.io', 'passphrase4');
await page.click('#app .lang-btn[data-lang="ko"]'); await page.waitForTimeout(500);

/* ---------- 등급 상승 (4.3) ---------- */
const lvl0 = await page.textContent('#tb-level');
const codes = sql("select record_code from public.records where status='published' and deleted_at is null and level<=2 order by id limit 10").split('\n');
for (const c of codes) {
  const row = sql(`select planet_id||'|'||category_id||'|'||subcategory_id from public.records where record_code='${c.trim()}'`).split('|');
  await page.evaluate(h => { location.hash = h; },
    `#/p/${row[0]}/c/${row[1]}/s/${row[2]}/r/${c.trim()}`);
  await page.waitForTimeout(700);
  await page.keyboard.press('Escape'); await page.waitForTimeout(350);
}
await page.waitForTimeout(700);
const lvl1 = await page.textContent('#tb-level');
const dbLvl = sql("select level from public.profiles p join auth.users u on u.id=p.id where u.email='delta@test.io'");
check('4.3 서로 다른 10건 열람 → LEVEL-3(Γ) 자동 상승', lvl0 === 'Β' && lvl1 === 'Γ' && dbLvl === '3',
      `${lvl0} → ${lvl1} (db=${dbLvl})`);

/* 상승 후 이전에 검열되던 LEVEL-3 기록의 본문이 보이는가 */
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY/r/REC-TERRA-001-0016'; });
await page.waitForTimeout(1500);
const bodyText = await page.textContent('#modal-body');
check('4.3 등급 상승 후 이전 검열 문서의 본문이 열림',
      bodyText.includes('맨해튼 공병관구') && !bodyText.includes('█'), bodyText.slice(0, 30));

/* ---------- 관련 기록 (4.10) ---------- */
const relVisible = await page.isVisible('#modal-related');
const relCount = await page.locator('#modal-related .related-list li').count();
check('4.10 관련 기록 섹션 표시', relVisible && relCount > 0 && relCount <= 5, 'count=' + relCount);
await page.screenshot({ path: SHOTS + '/s21-modal-open.png' });
await page.keyboard.press('Escape'); await page.waitForTimeout(500);

/* ---------- 최근 조회 (4.11) ---------- */
const recentCount = await page.locator('#sidebar-desktop .side-list li').count();
const viewRows = sql("select count(*) from public.record_views v join auth.users u on u.id=v.user_id where u.email='delta@test.io'");
check('4.11 최근 조회 5건 표시 / 중복 행 없음', recentCount === 5 && Number(viewRows) === 11,
      `sidebar=${recentCount} rows=${viewRows}`);

/* ---------- 검색 (2.15) ---------- */
await page.evaluate(() => { location.hash = '#/search'; }); await page.waitForTimeout(900);
await page.fill('#q', '체르노빌');
await page.click('#search-form button[type=submit]'); await page.waitForTimeout(1500);
const hits = await page.locator('.card[data-code]').count();
check('2.15 검색 동작 (Postgres 전문검색)', hits >= 1, 'hits=' + hits);

/* ---------- 작성 → 수정 흐름 ---------- */
await page.evaluate(() => { location.hash = '#/new'; }); await page.waitForTimeout(1200);
await page.selectOption('#f-planet', 'MOON-TITAN'); await page.waitForTimeout(400);
await page.selectOption('#f-cat', 'TECH-004'); await page.waitForTimeout(600);
const subOptions = await page.locator('#f-sub option').allTextContents();
check('2.11 행성 선택에 따라 중분류가 연쇄 갱신 (MISSION 은 지구 외 전용)',
      subOptions.some(o => /탐사 미션/.test(o)), subOptions.join('/'));
await page.selectOption('#f-sub', 'MISSION');
await page.fill('#f-title', '델타의 관측 기록');
await page.fill('#f-summary', '요약 문장입니다.');
await page.fill('#f-content', '본문 첫 문단.\n\n본문 둘째 문단.');
await page.fill('#f-tag', '관측'); await page.keyboard.press('Enter');
await page.fill('#f-source', 'ESA 자료');
await page.click('#record-form button[type=submit]'); await page.waitForTimeout(1800);
const newCode = sql("select record_code from public.records where title->>'ko'='델타의 관측 기록'");
check('2.11 기록 작성 성공', newCode.startsWith('REC-MOON-TITAN-'), newCode);

await page.evaluate(c => { location.hash = '#/edit/' + c; }, newCode); await page.waitForTimeout(1500);
await page.fill('#f-title', '델타의 관측 기록 (수정)');
await page.click('#record-form button[type=submit]'); await page.waitForTimeout(1800);
const editedTitle = sql(`select title->>'ko' from public.records where record_code='${newCode}'`);
const updatedAt = sql(`select coalesce(updated_at::text,'null') from public.records where record_code='${newCode}'`);
check('2.11 본인 기록 수정 + updated_at 갱신',
      editedTitle === '델타의 관측 기록 (수정)' && updatedAt !== 'null', editedTitle);

/* ---------- 필수값 검증 ---------- */
await page.evaluate(() => { location.hash = '#/new'; }); await page.waitForTimeout(1200);
await page.fill('#f-title', '출처 없는 기록');
await page.fill('#f-summary', '요약'); await page.fill('#f-content', '본문');
await page.fill('#f-tag', '태그'); await page.keyboard.press('Enter');
await page.click('#record-form button[type=submit]'); await page.waitForTimeout(700);
const srcErr = await page.textContent('#f-error');
check('2.11 출처 미입력 시 등록 차단', /출처/.test(srcErr), srcErr);

/* ---------- 내가 쓴 기록 상태 배지 ---------- */
await page.evaluate(() => { location.hash = '#/mine'; }); await page.waitForTimeout(1300);
const mineBadges = await page.locator('.badge-state-published').count();
check('2.12 내가 쓴 기록 목록 + 상태 배지', mineBadges >= 1, 'published=' + mineBadges);
await page.screenshot({ path: SHOTS + '/s22-mine.png' });

/* ---------- prefers-reduced-motion ---------- */
const ctxRM = await newCtx(browser, { reducedMotion: 'reduce' });
const pageRM = await open(ctxRM);
const anim = await pageRM.evaluate(() => {
  const el = document.querySelector('#screen-gate .blink');
  return { blink: getComputedStyle(el).animationName, noise: getComputedStyle(document.getElementById('noise')).opacity };
});
check('3.4 prefers-reduced-motion 에서 깜빡임·노이즈 정지',
      anim.blink === 'none' && Number(anim.noise) === 0, JSON.stringify(anim));
await ctxRM.close();

/* ============================================================
 *  17. 시드 데이터를 전부 삭제한 뒤 재실행
 * ============================================================ */
console.log('\n--- 시드 기록 전량 삭제 후 재검증 ---');
const seedCount = sql('select count(*) from public.records where is_seed');
sql('delete from public.records where is_seed');
const leftover = sql('select count(*) from public.records where is_seed');
const orphanBm = sql('select count(*) from public.bookmarks b left join public.records r on r.id=b.record_id where r.id is null');
const orphanVw = sql('select count(*) from public.record_views v left join public.records r on r.id=v.record_id where r.id is null');
check('17a. 시드 삭제 시 FK CASCADE 로 북마크·열람 기록 정리',
      leftover === '0' && orphanBm === '0' && orphanVw === '0',
      `deleted=${seedCount} orphanBookmarks=${orphanBm} orphanViews=${orphanVw}`);

const ctxS = await newCtx(browser);
const pageS = await open(ctxS);
await login(pageS, 'delta@test.io', 'passphrase4');
await pageS.click('#app .lang-btn[data-lang="ko"]'); await pageS.waitForTimeout(600);
const planetsShown = await pageS.locator('.card[data-planet]').count();
const totalNow = await pageS.textContent('#sidebar-desktop .side-row b');
check('17b. 시드 없이도 행성 목록과 집계가 정상 렌더링',
      planetsShown === 5 && totalNow.trim() === sql("select total_records::text from public.v_archive_stats"),
      `planets=${planetsShown} total=${totalNow}`);

await pageS.click('.card[data-planet="TERRA-001"]'); await pageS.waitForTimeout(900);
const emptyLabels = await pageS.locator('.card[data-cat]').filter({ hasText: 'NO RECORDS ON FILE' }).count();
check('17c. 기록 0개 카테고리에 NO RECORDS ON FILE 표기', emptyLabels >= 7, 'count=' + emptyLabels);

await pageS.evaluate(() => { location.hash = '#/p/TERRA-001/c/NAT-001/s/VOLCANO'; });
await pageS.waitForTimeout(1200);
const emptyState = await pageS.textContent('.state-title').catch(() => '');
check('17d. 기록 없는 좌표에서 빈 상태 화면', /NO RECORDS/.test(emptyState), emptyState);
await pageS.screenshot({ path: SHOTS + '/s23-empty.png' });

await pageS.evaluate(() => { location.hash = '#/bookmarks'; }); await pageS.waitForTimeout(1200);
const bmNow = await pageS.locator('.card[data-code]').count();
check('17e. 시드 삭제 후 북마크 목록에 빈 카드가 남지 않음', bmNow === 0, 'cards=' + bmNow);

await pageS.evaluate(() => { location.hash = '#/mine'; }); await pageS.waitForTimeout(1300);
const mineNow = await pageS.locator('.card[data-code]').count();
check('17f. 시드 삭제 후에도 사용자 기록은 그대로', mineNow >= 1, 'count=' + mineNow);

/* 시드 삭제 후 새 기록 작성이 계속 동작하는가 (record_code 일련번호 이어짐)
   ※ 60초 연속 작성 제한이 걸리지 않도록 직전 작성 시각을 앞당긴다 */
const deltaId = sql("select p.id from public.profiles p join auth.users u on u.id=p.id where u.email='delta@test.io'");
sql(`update public.records set created_at = created_at - interval '10 minutes' where author_id='${deltaId}'::uuid`);
await pageS.evaluate(() => { location.hash = '#/new'; }); await pageS.waitForTimeout(1300);
await pageS.selectOption('#f-planet', 'TERRA-001');
await pageS.selectOption('#f-cat', 'NAT-001'); await pageS.waitForTimeout(500);
await pageS.selectOption('#f-sub', 'VOLCANO');
await pageS.fill('#f-title', '시드 이후 기록');
await pageS.fill('#f-summary', '요약'); await pageS.fill('#f-content', '본문');
await pageS.fill('#f-tag', '태그'); await pageS.keyboard.press('Enter');
await pageS.fill('#f-source', '출처');
await pageS.click('#record-form button[type=submit]'); await pageS.waitForTimeout(1800);
const postSeedCode = sql("select record_code from public.records where title->>'ko'='시드 이후 기록'");
check('17g. 시드 삭제 후에도 기록 작성·코드 발급 정상', /^REC-TERRA-001-\d{4}$/.test(postSeedCode), postSeedCode);

await browser.close();
process.exit(summary() ? 1 : 0);
})().catch(e => { console.error('RUNNER ERROR', e); process.exit(1); });
