/* 아직 실행해 보지 않았던 경로: 오류 코드별 화면 · 모달 접근성 · 잠금 행성 ·
   비로그인 접근 · 가입 유효성 · 모션 토글 */
const L = require('./lib');
const { BASE, sql, newCtx, open, signup, login, confirmEmail: confirm, setLang } = L;
const { check, summary } = L.reporter();
const SHOTS = process.env.SHOTS_DIR || require('os').tmpdir();

(async () => {
const browser = await L.launch();
const ctx = await newCtx(browser);
const page = await open(ctx);

/* ---------- 4.2 비로그인 상태로 내부 해시 접근 ---------- */
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004'; });
await page.waitForTimeout(900);
check('4.2 비로그인 내부 해시 접근 시 경고 화면',
      await page.isVisible('#screen-gate'), await page.evaluate(() => location.hash));

/* ---------- 2.3 회원가입 유효성 ---------- */
await page.evaluate(() => { location.hash = '#/signup'; }); await page.waitForTimeout(500);
const cases = [
  ['형식이 아닌 이메일', { e: 'notanemail', p: 'passphrase1', c: 'passphrase1', n: 'A', a: true }, /이메일|email/i],
  ['8자 미만 암호',      { e: 'v@test.io', p: 'short',       c: 'short',       n: 'A', a: true }, /8/],
  ['확인값 불일치',      { e: 'v@test.io', p: 'passphrase1', c: 'passphrase2', n: 'A', a: true }, /일치|match/i],
  ['규약 미동의',        { e: 'v@test.io', p: 'passphrase1', c: 'passphrase1', n: 'A', a: false }, /동의|terms/i]
];
let allBlocked = true; const seen = [];
for (const [label, v, re] of cases) {
  await page.fill('#su-email', v.e); await page.fill('#su-pw', v.p);
  await page.fill('#su-pw2', v.c);   await page.fill('#su-name', v.n);
  await page.setChecked('#su-agree', v.a);
  await page.click('#form-signup button[type=submit]'); await page.waitForTimeout(400);
  const msg = await page.textContent('#signup-error');
  const onSignup = await page.isVisible('#screen-signup');
  seen.push(label + '=' + (msg || '(없음)'));
  if (!onSignup || !re.test(msg)) allBlocked = false;
}
check('2.3 회원가입 입력 규칙 4종이 모두 차단', allBlocked, seen.join(' / '));

/* 표시 이름 길이: maxlength 로 1차, 그것을 우회해도 스크립트 검증으로 2차 차단 */
const maxlen = await page.getAttribute('#su-name', 'maxlength');
await page.fill('#su-email', 'v@test.io'); await page.fill('#su-pw', 'passphrase1');
await page.fill('#su-pw2', 'passphrase1'); await page.setChecked('#su-agree', true);
await page.evaluate(() => {                       // maxlength 를 우회해 21자를 넣는다
  const el = document.getElementById('su-name');
  el.value = 'x'.repeat(21);
  el.dispatchEvent(new Event('input', { bubbles: true }));
});
await page.click('#form-signup button[type=submit]'); await page.waitForTimeout(600);
check('2.3 표시 이름 21자 차단 (maxlength + 스크립트 검증)',
      maxlen === '20' && await page.isVisible('#screen-signup') &&
      /1.*20|20/.test(await page.textContent('#signup-error')),
      `maxlength=${maxlen} 오류=${await page.textContent('#signup-error')}`);
// 이름 20자는 통과해야 한다 (경계값)
await page.fill('#su-name', 'x'.repeat(20));
await page.fill('#su-email', 'edge@test.io');
await page.fill('#su-pw', 'passphrase1'); await page.fill('#su-pw2', 'passphrase1');
await page.setChecked('#su-agree', true);
await page.click('#form-signup button[type=submit]'); await page.waitForTimeout(1000);
check('2.3 표시 이름 20자는 통과', await page.isVisible('#screen-signup-done'));

await confirm('edge@test.io');
await login(page, 'edge@test.io', 'passphrase1');
await setLang(page, 'ko');

/* ---------- 2.16 404: 없는 기록 코드 ---------- */
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY/r/REC-NOPE-9999'; });
await page.waitForTimeout(1600);
const toast404 = await page.textContent('#toast').catch(() => '');
const modalOff  = !(await page.isVisible('#modal-record'));
const listAlive = await page.locator('.card[data-code]').count();
check('2.16 존재하지 않는 기록 코드에서 404 안내 + 목록 유지',
      /존재하지 않는/.test(toast404) && modalOff && listAlive > 0,
      `toast=${toast404} 목록=${listAlive}`);

/* ---------- 2.16 5xx ---------- */
await ctx.route('**/rest/v1/v_planet_counts*', r =>
  r.fulfill({ status: 500, contentType: 'application/json',
              body: JSON.stringify({ message: 'boom', code: 'XX000' }) }));
await page.evaluate(() => { location.hash = '#/'; }); await page.waitForTimeout(1500);
const err5 = await page.textContent('.state-title').catch(() => '');
check('2.16 5xx 에서 서버 오류 화면 + 재시도 버튼',
      /서버 오류/.test(err5) && await page.isVisible('#btn-retry'), err5);
await ctx.unroute('**/rest/v1/v_planet_counts*');
await page.click('#btn-retry'); await page.waitForTimeout(1500);
check('2.16 재시도 버튼이 화면을 복구', (await page.locator('.card[data-planet]').count()) === 5);

/* ---------- 2.10 모달 접근성: 포커스 이동 · 복귀 · 배경 클릭 ---------- */
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY'; });
await page.waitForTimeout(1400);
const card = page.locator('.card[data-code]').first();
await card.focus();
await page.keyboard.press('Enter'); await page.waitForTimeout(1500);
const focusInModal = await page.evaluate(() =>
  document.getElementById('modal-record').contains(document.activeElement));
await page.click('#modal-record .modal-backdrop', { position: { x: 5, y: 5 } });
await page.waitForTimeout(1200);
const closedByBackdrop = !(await page.isVisible('#modal-record'));
const focusBack = await page.evaluate(() =>
  !!document.activeElement && document.activeElement.classList.contains('card'));
check('2.10 모달 열 때 포커스 이동 / 배경 클릭으로 닫힘 / 원래 카드로 복귀',
      focusInModal && closedByBackdrop && focusBack,
      `모달내=${focusInModal} 배경닫힘=${closedByBackdrop} 복귀=${focusBack}`);

/* Tab 포커스 트랩 */
await page.locator('.card[data-code]').first().click(); await page.waitForTimeout(1500);
let escaped = false;
for (let i = 0; i < 25; i++) {
  await page.keyboard.press('Tab');
  const inside = await page.evaluate(() =>
    document.getElementById('modal-record').contains(document.activeElement));
  if (!inside) { escaped = true; break; }
}
check('2.10 모달 안에서 Tab 이 밖으로 나가지 않음', !escaped);
await page.keyboard.press('Escape'); await page.waitForTimeout(800);

/* ---------- 3.4 모션 감소 수동 토글 ---------- */
await page.check('#sidebar-desktop #__m'); await page.waitForTimeout(700);
const off = await page.evaluate(() => ({
  cls: document.body.classList.contains('no-motion'),
  noise: getComputedStyle(document.getElementById('noise')).opacity,
  saved: localStorage.getItem('akashic_motion')
}));
await page.reload({ waitUntil: 'domcontentloaded' }); await page.waitForTimeout(1600);
const kept = await page.evaluate(() => document.body.classList.contains('no-motion'));
check('3.4 모션 감소 수동 토글이 적용되고 새로고침 후에도 유지',
      off.cls && Number(off.noise) === 0 && off.saved === '1' && kept, JSON.stringify(off));

/* ---------- 2.6 / 4.3 RESTRICTED 행성 ---------- */
sql("update public.planets set status='RESTRICTED', required_level=4 where id='EXOPLANET-PCB'");
await page.evaluate(() => { location.hash = '#/'; }); await page.waitForTimeout(1500);
const locked = page.locator('.card[data-planet="EXOPLANET-PCB"]');
const hasLock = await locked.locator('.lock-overlay').count();
await locked.click(); await page.waitForTimeout(900);
const stayed = await page.evaluate(() => location.hash);
check('2.6 등급 미달이면 행성 카드에 자물쇠 + 진입 차단',
      hasLock === 1 && stayed === '#/', `오버레이=${hasLock} hash=${stayed}`);

/* 잠긴 행성의 기록은 본문이 응답에 담기지 않아야 한다 */
const payload = await page.evaluate(async () => {
  const { data } = await window.AKASHIC_SB.sb.from('v_records').select('*')
    .eq('planet_id', 'EXOPLANET-PCB');
  return data.map(r => ({ can: r.can_view, c: r.content, s: r.summary }));
});
check('4.3 잠긴 행성의 기록 본문·요약이 응답에서 제외',
      payload.length > 0 && payload.every(r => r.can === false && r.c === null && r.s === null),
      JSON.stringify(payload[0]));
await page.screenshot({ path: SHOTS + '/s27-restricted.png' });
sql("update public.planets set status='DORMANT', required_level=1 where id='EXOPLANET-PCB'");

/* ---------- 2.16 403 ---------- */
await ctx.route('**/rest/v1/v_records*', r =>
  r.fulfill({ status: 403, contentType: 'application/json',
              body: JSON.stringify({ message: 'permission denied', code: '42501' }) }));
// 이미 불러온 좌표는 목록이 캐시돼 조회가 일어나지 않으므로 다른 좌표로 이동한다
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/LIFE-005/s/EVOLUTION'; });
await page.waitForTimeout(1600);
const err403 = await page.textContent('.state-title').catch(() => '');
check('2.16 403 에서 권한 없음 화면', /권한/.test(err403), err403);
await ctx.unroute('**/rest/v1/v_records*');

await browser.close();
process.exit(summary() ? 1 : 0);
})().catch(e => { console.error('RUNNER ERROR', e); process.exit(1); });
