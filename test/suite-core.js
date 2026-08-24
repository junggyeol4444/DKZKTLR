/* 핵심 시나리오: 인증 · 탐색 · 검열 · 권한 · 신고 · 오류 (7.2 의 1~20 중 대부분) */
const L = require('./lib');
const { BASE, sql, newCtx, open, signup, login, confirmEmail: confirm, setLang } = L;
const { check, summary } = L.reporter();
const SHOTS = process.env.SHOTS_DIR || require('os').tmpdir();

(async () => {
const browser = await L.launch();

/* ---------- 1. 경고 화면 언어 전환 ---------- */
let ctx = await newCtx(browser);
let page = await open(ctx);
await page.click('.gate-lang .lang-btn[data-lang="ko"]'); await page.waitForTimeout(250);
const koLine = await page.textContent('#screen-gate .gate-line');
await page.click('.gate-lang .lang-btn[data-lang="en"]'); await page.waitForTimeout(250);
const enLine = await page.textContent('#screen-gate .gate-line');
check('1. 경고 화면 KO/EN 전환', koLine.includes('금서 보관소') && enLine.includes('sealed vault'),
      koLine.slice(0, 18) + ' / ' + enLine.slice(0, 18));
await page.screenshot({ path: SHOTS + '/s01-gate.png' });

/* ---------- 3. 미인증 계정 로그인 ---------- */
await signup(page, 'alpha@test.io', 'passphrase1', 'Alpha');
const doneVisible = await page.isVisible('#screen-signup-done');
check('2a. 가입 후 메일 확인 안내 화면', doneVisible);
await login(page, 'alpha@test.io', 'passphrase1');
const loginErr = await page.textContent('#login-error');
const resendShown = await page.isVisible('#login-resend');
check('3. 미인증 계정 로그인 시 안내 + 재발송 버튼', /verified|인증/.test(loginErr) && resendShown, loginErr);

/* 잘못된 비밀번호는 계정 존재 여부를 구분하지 않는다 */
await confirm('alpha@test.io');
await login(page, 'alpha@test.io', 'wrongwrong');
const badErr = await page.textContent('#login-error');
await login(page, 'nosuch@test.io', 'wrongwrong');
const noneErr = await page.textContent('#login-error');
check('2b. 실패 메시지가 계정 존재 여부를 노출하지 않음', badErr === noneErr && badErr.length > 0, badErr);

/* ---------- 2. 인증 후 로그인 ---------- */
await login(page, 'alpha@test.io', 'passphrase1');
const inApp = await page.isVisible('#app');
const keeper = await page.textContent('#tb-keeper');
const clearance = await page.textContent('#tb-level');
check('2. 인증 완료 후 로그인 → 메인 진입', inApp && /^KEEPER-\d{3}$/.test(keeper), keeper + ' / ' + clearance);
check('2c. 가입 기본 등급이 Β(LEVEL-2)', clearance === 'Β', clearance);
await page.screenshot({ path: SHOTS + '/s02-main.png' });

/* ---------- 사이드바 집계 ---------- */
await page.waitForTimeout(600);
const sideTotal = await page.textContent('#sidebar-desktop .side-row b');
check('집계: 사이드바 총 기록 수가 DB 값(30)과 일치', sideTotal.trim() === '30', sideTotal);

/* ---------- 5. 4단계 탐색 ---------- */
await page.click('.card[data-planet="TERRA-001"]'); await page.waitForTimeout(700);
const catCount = await page.locator('.card[data-cat]').count();
await page.click('.card[data-cat="TECH-004"]'); await page.waitForTimeout(700);
const subCount = await page.locator('.card[data-sub]').count();
await page.click('.card[data-sub="ENERGY"]'); await page.waitForTimeout(900);
const recCount = await page.locator('.card[data-code]').count();
check('5. 행성→대분류→중분류→기록 목록', catCount === 9 && subCount >= 3 && recCount === 2,
      `cat=${catCount} sub=${subCount} rec=${recCount}`);
await page.screenshot({ path: SHOTS + '/s05-records.png' });

/* ---------- 13. 등급 미달 기록 본문이 응답에 없는지 ---------- */
let captured = null;
page.on('response', async r => {
  if (r.url().includes('v_records') && r.request().method() === 'GET' && !captured) {
    try { captured = await r.text(); } catch (_) {}
  }
});
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY'; });
await page.reload({ waitUntil: 'domcontentloaded' }); await page.waitForTimeout(1600);
const bodyHasSecret = captured ? captured.includes('맨해튼 공병관구') : true;
const rows = captured ? JSON.parse(captured) : [];
const lockedRow = rows.find(r => r.level > 2);
check('13. 등급 미달 기록의 본문·요약이 응답에 없음',
      !!lockedRow && lockedRow.content === null && lockedRow.summary === null && !bodyHasSecret,
      lockedRow ? `level=${lockedRow.level} content=${lockedRow.content} summary=${lockedRow.summary}` : 'no locked row');

/* 화면에도 검열 표기 */
const lockedBadge = await page.locator('.badge-locked').count();
check('2.9 검열 배지 표시', lockedBadge >= 1, 'count=' + lockedBadge);

/* ---------- 6. 상세 모달 + ESC ---------- */
await page.locator('.card[data-code]').first().click();
await page.waitForTimeout(1200);
const modalOpen = await page.isVisible('#modal-record');
const modalTitle = await page.textContent('#modal-record-title');
await page.screenshot({ path: SHOTS + '/s06-modal.png' });
await page.keyboard.press('Escape'); await page.waitForTimeout(700);
const modalClosed = !(await page.isVisible('#modal-record'));
check('6. 상세 모달 열기 / ESC 로 닫기', modalOpen && modalClosed, modalTitle);

/* ---------- 7. 뒤로가기로 단계 이동 ---------- */
/* ESC 로 모달을 닫을 때 이미 history.back() 이 한 번 일어났으므로 현재 위치는 목록이다 */
const h0 = await page.evaluate(() => location.hash);
await page.goBack(); await page.waitForTimeout(700);
const h1 = await page.evaluate(() => location.hash);
await page.goBack(); await page.waitForTimeout(700);
const h2 = await page.evaluate(() => location.hash);
check('7. 브라우저 뒤로가기가 단계 이동과 일치',
      h0.endsWith('/s/ENERGY') && h1 === '#/p/TERRA-001/c/TECH-004' && h2 === '#/p/TERRA-001',
      h0 + ' -> ' + h1 + ' -> ' + h2);

/* ---------- 8. 새로고침 후 위치·로그인 유지 ---------- */
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY'; });
await page.waitForTimeout(500);
await page.reload({ waitUntil: 'domcontentloaded' }); await page.waitForTimeout(1400);
const stillIn = await page.isVisible('#app');
const hashKept = await page.evaluate(() => location.hash);
const listKept = await page.locator('.card[data-code]').count();
check('8. 새로고침 후 위치와 로그인 상태 유지',
      stillIn && hashKept === '#/p/TERRA-001/c/TECH-004/s/ENERGY' && listKept === 2, hashKept);

/* ---------- 잘못된 해시 리다이렉트 ---------- */
await page.evaluate(() => { location.hash = '#/zzz/nope'; });
await page.waitForTimeout(700);
check('4.2 잘못된 해시는 #/ 로 리다이렉트',
      (await page.evaluate(() => location.hash)) === '#/', await page.evaluate(() => location.hash));

/* ---------- 9. 북마크 (다른 브라우저에서 유지) ---------- */
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY'; });
await page.waitForTimeout(1000);
await page.locator('.bookmark-btn').first().click(); await page.waitForTimeout(800);
const pressed = await page.locator('.bookmark-btn').first().getAttribute('aria-pressed');

const ctx2 = await newCtx(browser);               // 다른 브라우저 프로필
const page2 = await open(ctx2);
await login(page2, 'alpha@test.io', 'passphrase1');
await page2.evaluate(() => { location.hash = '#/bookmarks'; });
await page2.waitForTimeout(1200);
const bmCount = await page2.locator('.card[data-code]').count();
check('9. 북마크가 계정 단위로 저장되어 다른 브라우저에서도 보임',
      pressed === 'true' && bmCount === 1, `pressed=${pressed} other=${bmCount}`);

/* ---------- 10. 기록 작성 ---------- */
const before = Number(sql("select total_records from public.v_archive_stats"));
await page.evaluate(() => { location.hash = '#/new'; });
await page.waitForTimeout(1200);
await page.selectOption('#f-planet', 'TERRA-001');
await page.selectOption('#f-cat', 'ART-007');
await page.waitForTimeout(500);
await page.selectOption('#f-sub', 'LITERATURE');
await page.fill('#f-title', '알파의 시험 기록');
await page.fill('#f-summary', '테스트 계정이 작성한 요약입니다.');
await page.fill('#f-content', '첫 문단입니다.\n\n둘째 문단입니다.');
await page.fill('#f-date', '1999-12-31');
await page.fill('#f-tag', '테스트'); await page.keyboard.press('Enter');
await page.fill('#f-source', '테스트 출처');
await page.click('#record-form button[type=submit]');
await page.waitForTimeout(1800);
const formErr = await page.textContent('#f-error').catch(() => '');
if (formErr) console.log('   [form error] ' + formErr);
const after = Number(sql("select total_records from public.v_archive_stats"));
const mineCount = await page.locator('.card[data-code]').count();
const newCode = sql("select record_code from public.records where title->>'ko'='알파의 시험 기록'");
check('10. 기록 작성 → 집계·목록 반영', after === before + 1 && mineCount === 1 && newCode.startsWith('REC-TERRA-001-'),
      `${before}→${after}, code=${newCode}`);
await page.screenshot({ path: SHOTS + '/s10-mine.png' });

/* ---------- 11. 다른 계정에서 보이는가 ---------- */
const ctx3 = await newCtx(browser);
const page3 = await open(ctx3);
await signup(page3, 'beta@test.io', 'passphrase2', 'Beta');
await confirm('beta@test.io');
await login(page3, 'beta@test.io', 'passphrase2');
await page3.evaluate(() => { location.hash = '#/p/TERRA-001/c/ART-007/s/LITERATURE'; });
await page3.waitForTimeout(1400);
const seenByOther = await page3.locator('.card[data-code]').filter({ hasText: '알파의 시험 기록' }).count();
check('11. A가 쓴 기록이 B 화면에 보임', seenByOther === 1, 'count=' + seenByOther);

/* ---------- 12. 타인 기록 수정·삭제 차단 ---------- */
const targetId = Number(sql("select id from public.records where title->>'ko'='알파의 시험 기록'"));
const attack = await page3.evaluate(async id => {
  const out = {};
  try { await window.AKASHIC_API.records.update(id, { title: { ko: '탈취됨' } }); out.update = 'no-error'; }
  catch (e) { out.update = e.code; }
  try { await window.AKASHIC_API.records.remove(id); out.remove = 'no-error'; }
  catch (e) { out.remove = e.code; }
  return out;
}, targetId);
const titleAfter = sql(`select title->>'ko' from public.records where id=${targetId}`);
const delAfter = sql(`select coalesce(deleted_at::text,'null') from public.records where id=${targetId}`);
check('12. 다른 계정의 기록을 수정·삭제할 수 없음',
      titleAfter === '알파의 시험 기록' && delAfter === 'null',
      `update=${attack.update} remove=${attack.remove} title=${titleAfter}`);

/* ---------- 클라이언트가 자기 등급을 올릴 수 없음 ---------- */
const esc = await page3.evaluate(async () => {
  const sb = window.AKASHIC_SB.sb;
  const { data: u } = await sb.auth.getUser();
  const { error } = await sb.from('profiles').update({ level: 5 }).eq('id', u.user.id);
  return error ? error.message : 'no-error';
});
const betaLevel = sql("select level from public.profiles p join auth.users u on u.id=p.id where u.email='beta@test.io'");
check('7.1 클라이언트가 자기 level 을 올릴 수 없음', betaLevel === '2', `level=${betaLevel}, err=${esc.slice(0,40)}`);

/* ---------- 14. 하루 작성 제한 ---------- */
const alphaId = sql("select p.id from public.profiles p join auth.users u on u.id=p.id where u.email='alpha@test.io'");
sql(`insert into public.records (planet_id,category_id,subcategory_id,title,summary,content,tags,source,level,author_id,created_at)
     select 'TERRA-001','ART-007','LITERATURE',
            jsonb_build_object('ko','대량 '||g), jsonb_build_object('ko','요약'), jsonb_build_object('ko','본문'),
            array['t'],'출처',1,'${alphaId}'::uuid, now() - interval '2 hours'
       from generate_series(1,9) g;`);
const limitErr = await page.evaluate(async () => {
  try {
    await window.AKASHIC_API.records.create({
      planet_id: 'TERRA-001', category_id: 'ART-007', subcategory_id: 'LITERATURE',
      title: { ko: '한도 초과 시도' }, summary: { ko: '요약' }, content: { ko: '본문' },
      event_date: null, tags: ['t'], source: '출처', level: 1
    });
    return 'no-error';
  } catch (e) { return e.code; }
});
check('14. 하루 10건 초과 작성 차단', limitErr === 'AKASHIC_DAILY_LIMIT', limitErr);

/* ---------- 15. 3계정 신고 → hidden ---------- */
const ctx4 = await newCtx(browser); const page4 = await open(ctx4);
await signup(page4, 'gamma@test.io', 'passphrase3', 'Gamma');
await confirm('gamma@test.io');
await login(page4, 'gamma@test.io', 'passphrase3');
const reportAs = async (pg, id) => pg.evaluate(async id => {
  const sb = window.AKASHIC_SB.sb; const { data: u } = await sb.auth.getUser();
  try { await window.AKASHIC_API.reports.add(id, u.user.id, 'no_source', 'test'); return 'ok'; }
  catch (e) { return e.code; }
}, id);
const seedId = Number(sql("select id from public.records where record_code='REC-TERRA-001-0003'"));
const r1 = await reportAs(page, seedId), r2 = await reportAs(page3, seedId), r3 = await reportAs(page4, seedId);
const statusAfter = sql(`select status from public.records where id=${seedId}`);
const dup = await reportAs(page, seedId);
check('15. 서로 다른 3명 신고 → hidden 전환', statusAfter === 'hidden', `${r1}/${r2}/${r3} → ${statusAfter}`);
check('15b. 같은 사용자의 중복 신고 차단', dup === 'duplicate', dup);

/* hidden 은 목록·집계에서 제외 */
await page3.evaluate(() => { location.hash = '#/p/TERRA-001/c/NAT-001/s/VOLCANO'; });
await page3.waitForTimeout(1200);
const volCount = await page3.locator('.card[data-code]').count();
check('4.6 hidden 기록이 목록에서 제외됨', volCount === 1, 'count=' + volCount);

/* ---------- 16. 삭제 후 북마크에 빈 카드가 남지 않음 ---------- */
await page3.evaluate(async () => {
  const sb = window.AKASHIC_SB.sb; const { data: u } = await sb.auth.getUser();
  const { data } = await sb.from('v_records').select('id').limit(3);
  for (const r of data) await window.AKASHIC_API.bookmarks.add(r.id, u.user.id);
});
const bmBefore = await page3.evaluate(async () => (await window.AKASHIC_API.bookmarks.list()).length);
const betaId = sql("select p.id from public.profiles p join auth.users u on u.id=p.id where u.email='beta@test.io'");
const anyBm = Number(sql(`select record_id from public.bookmarks where user_id='${betaId}'::uuid limit 1`));
sql(`update public.records set deleted_at = now() where id = ${anyBm}`);
await page3.evaluate(() => { location.hash = '#/bookmarks'; });
await page3.waitForTimeout(1300);
const bmCards = await page3.locator('.card[data-code]').count();
const bmAfter = await page3.evaluate(async () => (await window.AKASHIC_API.bookmarks.list()).length);
check('16. 기록 삭제 후 북마크 목록에 빈 카드가 남지 않음',
      bmAfter === bmBefore - 1 && bmCards === bmAfter, `${bmBefore} → ${bmAfter}, cards=${bmCards}`);

/* ---------- 18. JA 레이아웃 ---------- */
await page3.click('#app .lang-btn[data-lang="ja"]'); await page3.waitForTimeout(800);
await page3.evaluate(() => { location.hash = '#/p/TERRA-002/c/TECH-004/s/MISSION'; });
await page3.waitForTimeout(1300);
const jaTitle = await page3.locator('.card-title').first().textContent();
const htmlLang = await page3.getAttribute('html', 'lang');
const overflow = await page3.evaluate(() =>
  document.documentElement.scrollWidth - document.documentElement.clientWidth);
check('18. JA 전환 시 데이터·UI 모두 일본어 + 가로 넘침 없음',
      /[ぁ-んァ-ン一-龯]/.test(jaTitle) && htmlLang === 'ja' && overflow <= 1,
      `${jaTitle.slice(0, 20)} lang=${htmlLang} overflow=${overflow}`);
await page3.screenshot({ path: SHOTS + '/s18-ja.png' });

/* ---------- 19. 모바일 햄버거 ---------- */
const ctxM = await newCtx(browser, { viewport: { width: 390, height: 780 } });
const pageM = await open(ctxM);
await login(pageM, 'gamma@test.io', 'passphrase3');
await pageM.waitForTimeout(800);
const burgerVisible = await pageM.isVisible('#btn-drawer');
await pageM.click('#btn-drawer'); await pageM.waitForTimeout(500);
const drawerOpen = await pageM.isVisible('#drawer');
const bodyLocked = await pageM.evaluate(() => getComputedStyle(document.body).overflow);
await pageM.screenshot({ path: SHOTS + '/s19-mobile.png' });
await pageM.keyboard.press('Escape'); await pageM.waitForTimeout(400);
const drawerClosed = !(await pageM.isVisible('#drawer'));
const mOverflow = await pageM.evaluate(() =>
  document.documentElement.scrollWidth - document.documentElement.clientWidth);
check('19. 모바일 폭에서 햄버거 패널 동작', burgerVisible && drawerOpen && drawerClosed && bodyLocked === 'hidden' && mOverflow <= 1,
      `open=${drawerOpen} closed=${drawerClosed} overflow=${mOverflow}`);

/* ---------- 20. 네트워크 차단 시 오류 화면 ---------- */
await page4.evaluate(() => { location.hash = '#/'; });
await page4.waitForTimeout(800);
await ctx4.route('**/rest/v1/**', r => r.abort());
await page4.evaluate(() => { location.hash = '#/p/TERRA-001'; });
await page4.waitForTimeout(1500);
const errTitle = await page4.locator('.state-title').first().textContent().catch(() => '');
const retry = await page4.isVisible('#btn-retry').catch(() => false);
check('20. 네트워크 차단 시 오류 화면 + 재시도 버튼',
      /끊겼|connection|接続/i.test(errTitle) && retry, errTitle);
await page4.screenshot({ path: SHOTS + '/s20-error.png' });
await ctx4.unroute('**/rest/v1/**');

/* ---------- 4. 비밀번호 재설정 안내 ---------- */
const ctx5 = await newCtx(browser); const page5 = await open(ctx5, '#/reset');
await page5.waitForTimeout(400);
await page5.fill('#rs-email', 'alpha@test.io');
await page5.click('#form-reset button[type=submit]'); await page5.waitForTimeout(500);
const note1 = await page5.textContent('#reset-note');
await page5.fill('#rs-email', 'nobody@test.io');
await page5.click('#form-reset button[type=submit]'); await page5.waitForTimeout(500);
const note2 = await page5.textContent('#reset-note');
check('4. 재설정 안내가 계정 존재 여부와 무관하게 동일', note1 === note2 && note1.length > 0, note1);

/* ---------- 정렬 / 페이지네이션 ---------- */
await page3.click('#app .lang-btn[data-lang="ko"]'); await page3.waitForTimeout(500);
await page3.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/INFO'; });
await page3.waitForTimeout(1200);
const firstBefore = await page3.locator('.card-title').first().textContent();
await page3.selectOption('#sort-sel', 'event_asc'); await page3.waitForTimeout(1200);
const firstAfter = await page3.locator('.card-title').first().textContent();
const storedSort = await page3.evaluate(() => localStorage.getItem('akashic_sort'));
check('4.7 정렬 변경이 목록에 반영되고 LocalStorage 에 저장됨',
      firstBefore !== firstAfter && storedSort === 'event_asc', `${firstBefore} → ${firstAfter}`);

/* LocalStorage 에 계정·기록이 저장되지 않는지 (0.3) */
const lsKeys = await page3.evaluate(() => Object.keys(localStorage));
const onlyAllowed = lsKeys.every(k => ['akashic_lang', 'akashic_sort', 'akashic_motion', 'akashic-auth'].includes(k));
check('0.3 LocalStorage 에는 설정과 세션 토큰만 저장', onlyAllowed, lsKeys.join(','));

await browser.close();

process.exit(summary() ? 1 : 0);
})().catch(e => { console.error('RUNNER ERROR', e); process.exit(1); });
