/* 세션 수명 · 다중 탭 · 로그아웃 이후 · i18n 폴백 */
const L = require('./lib');
const { BASE, sql, newCtx, open, signup, login, confirmEmail: confirm, setLang } = L;
const { check, summary } = L.reporter();

(async () => {
const browser = await L.launch();
const ctx = await newCtx(browser);
const page = await open(ctx);
await signup(page, 'sess@test.io', 'passphrase1', 'Sess');
await confirm('sess@test.io');
await login(page, 'sess@test.io', 'passphrase1');
await setLang(page, 'ko');

/* ---------- 로그인 상태로 공개 화면 접근 ---------- */
await page.evaluate(() => { location.hash = '#/login'; }); await page.waitForTimeout(900);
check('4.2 로그인 상태에서 로그인 화면으로 가면 메인으로 되돌림',
      (await page.evaluate(() => location.hash)) === '#/' && await page.isVisible('#app'),
      await page.evaluate(() => location.hash));

/* ---------- 만료된 토큰으로 시작하면 자동 갱신 ---------- */
const stored = await page.evaluate(() => localStorage.getItem('akashic-auth'));
const expired = await page.evaluate(raw => {
  const o = JSON.parse(raw);
  o.expires_at = Math.floor(Date.now() / 1000) - 60;      // 이미 만료된 상태로 되돌린다
  o.expires_in = 0;
  localStorage.setItem('akashic-auth', JSON.stringify(o));
  return o.refresh_token;
}, stored);
await page.reload({ waitUntil: 'domcontentloaded' }); await page.waitForTimeout(2200);
const afterRefresh = await page.evaluate(() => ({
  inApp: !document.getElementById('app').hidden,
  keeper: document.getElementById('tb-keeper').textContent,
  fresh: JSON.parse(localStorage.getItem('akashic-auth') || '{}').expires_at
}));
check('만료된 토큰이 refresh_token 으로 자동 갱신되고 화면이 유지됨',
      afterRefresh.inApp && /^KEEPER-\d+$/.test(afterRefresh.keeper) &&
      afterRefresh.fresh > Math.floor(Date.now() / 1000),
      `${afterRefresh.keeper} refresh=${expired ? '있음' : '없음'}`);

/* ---------- 폐기된 refresh_token ---------- */
const ctxBad = await newCtx(browser);
const pageBad = await open(ctxBad);
await login(pageBad, 'sess@test.io', 'passphrase1');
await pageBad.evaluate(() => {
  const o = JSON.parse(localStorage.getItem('akashic-auth'));
  o.expires_at = Math.floor(Date.now() / 1000) - 60;
  o.refresh_token = 'rt:00000000-0000-4000-a000-999999999999';   // 없는 사용자
  localStorage.setItem('akashic-auth', JSON.stringify(o));
});
await pageBad.reload({ waitUntil: 'domcontentloaded' }); await pageBad.waitForTimeout(2200);
check('갱신에 실패하면 경고 화면으로 떨어짐',
      await pageBad.isVisible('#screen-gate'),
      await pageBad.evaluate(() => location.hash));
await ctxBad.close();

/* ---------- 다중 탭 ---------- */
const tab2 = await open(ctx);
await tab2.waitForTimeout(1200);
check('두 번째 탭이 같은 세션을 이어받음', await tab2.isVisible('#app'));

await page.click('#btn-logout'); await page.waitForTimeout(2000);
await tab2.waitForTimeout(1500);
check('한 탭에서 로그아웃하면 다른 탭도 경고 화면으로',
      await tab2.isVisible('#screen-gate'), await tab2.evaluate(() => location.hash));

/* ---------- 로그아웃 후 뒤로가기로 기록 화면 복귀 시도 ---------- */
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY'; });
await page.waitForTimeout(1200);
const afterBack = await page.evaluate(() => ({
  gate: !document.getElementById('screen-gate').hidden,
  cards: document.querySelectorAll('.card[data-code]').length,
  app: !document.getElementById('app').hidden
}));
check('로그아웃 뒤 기록 주소로 돌아가도 데이터가 보이지 않음',
      afterBack.gate && !afterBack.app && afterBack.cards === 0, JSON.stringify(afterBack));

/* 로그아웃 뒤 남은 저장값 */
const leftovers = await page.evaluate(() => {
  const raw = localStorage.getItem('akashic-auth');
  return { keys: Object.keys(localStorage), token: raw ? JSON.parse(raw).access_token : null };
});
check('로그아웃 뒤 접근 토큰이 저장소에 남지 않음',
      !leftovers.token, JSON.stringify(leftovers.keys));

/* ---------- 4.4 사전에 없는 키는 ko 로 폴백 ---------- */
await login(page, 'sess@test.io', 'passphrase1');
const fallback = await page.evaluate(() => {
  const D = window.AKASHIC_I18N.I18N;
  const keep = D.en['side.new'];
  delete D.en['side.new'];                     // en 사전에서 일부러 지운다
  document.querySelector('#app .lang-btn[data-lang="en"]').click();
  return new Promise(r => setTimeout(() => {
    const btn = [...document.querySelectorAll('#sidebar-desktop .btn')]
      .find(b => b.getAttribute('href') === '#/new');
    const text = btn ? btn.textContent : '';
    D.en['side.new'] = keep;                   // 원상 복구
    r(text);
  }, 900));
});
check('4.4 사전에 없는 키는 키 문자열이 아니라 ko 값으로 대체',
      fallback === '기록 작성', JSON.stringify(fallback));
await setLang(page, 'ko');

/* 사전에 아예 없는 키를 넣으면 키 자체가 화면에 남는지 (개발 중 발견 가능해야 함) */
const missing = await page.evaluate(() =>
  document.body.textContent.match(/\b(side|form|modal|rec|err)\.[a-z.]+\b/g) || []);
check('화면에 번역되지 않은 키 문자열이 노출되지 않음',
      missing.length === 0, missing.slice(0, 5).join(','));

await browser.close();
process.exit(summary() ? 1 : 0);
})().catch(e => { console.error('RUNNER ERROR', e); process.exit(1); });
