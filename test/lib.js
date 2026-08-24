/* ============================================================
 *  테스트 공용 헬퍼
 *  환경 변수
 *    AKASHIC_BASE   셔임 주소        (기본 http://127.0.0.1:5555)
 *    PGSOCKET       PostgreSQL 소켓 디렉터리
 *    PGPORT_TEST    PostgreSQL 포트  (기본 5439)
 *    CHROMIUM       Chromium 실행 파일 경로
 *    PLAYWRIGHT     playwright 모듈 경로
 * ============================================================ */
const { execFileSync } = require('child_process');

const BASE       = process.env.AKASHIC_BASE || 'http://127.0.0.1:5555';
const ANON       = 'ANON-KEY-TEST';
const PGSOCKET   = process.env.PGSOCKET || '/tmp/akashic-pg';
const PGPORT     = process.env.PGPORT_TEST || '5439';
const CHROMIUM   = process.env.CHROMIUM || '/opt/pw-browsers/chromium';
const PLAYWRIGHT = process.env.PLAYWRIGHT || 'playwright';

const { chromium } = require(PLAYWRIGHT);
const CFG = { url: BASE, anonKey: ANON };

/* psql 한 줄 질의 */
const sql = q => execFileSync(
  'psql', ['-h', PGSOCKET, '-p', PGPORT, '-U', 'postgres', '-tAc', q],
  { encoding: 'utf8' }).trim();

/* 결과 집계 */
function reporter() {
  const rows = [];
  const check = (name, ok, extra) => {
    rows.push({ name, ok: !!ok, extra: extra || '' });
    console.log((ok ? '  PASS  ' : '! FAIL  ') + name + (extra ? '   [' + extra + ']' : ''));
  };
  const summary = () => {
    const bad = rows.filter(r => !r.ok);
    console.log('\n=== ' + (rows.length - bad.length) + '/' + rows.length + ' PASS ===');
    bad.forEach(b => console.log(' - ' + b.name + '  ' + b.extra));
    return bad.length;
  };
  return { check, summary, rows };
}

const launch = () => chromium.launch({ executablePath: CHROMIUM });

/* 브라우저 컨텍스트.
   supabase-js CDN 은 로컬 사본으로, 웹폰트는 빈 응답으로 대체한다. */
async function newCtx(browser, opts) {
  const ctx = await browser.newContext(
    Object.assign({ viewport: { width: 1280, height: 900 } }, opts));
  await ctx.addInitScript(c => { window.AKASHIC_CONFIG = c; }, CFG);
  await ctx.route('**/cdn.jsdelivr.net/**',
    r => r.fulfill({ status: 302, headers: { location: BASE + '/__supabase.js' } }));
  await ctx.route('**/fonts.googleapis.com/**',
    r => r.fulfill({ status: 200, body: '', contentType: 'text/css' }));
  return ctx;
}

async function open(ctx, hash) {
  const page = await ctx.newPage();
  page.on('pageerror', e => console.log('   [pageerror] ' + e.message));
  await page.goto(BASE + '/' + (hash || ''), { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(700);
  return page;
}

async function signup(page, email, pw, name) {
  await page.evaluate(() => { location.hash = '#/signup'; });
  await page.waitForTimeout(400);
  await page.fill('#su-email', email); await page.fill('#su-pw', pw);
  await page.fill('#su-pw2', pw);      await page.fill('#su-name', name);
  await page.check('#su-agree');
  await page.click('#form-signup button[type=submit]');
  await page.waitForTimeout(900);
}

async function login(page, email, pw) {
  await page.evaluate(() => { location.hash = '#/login'; });
  await page.waitForTimeout(400);
  await page.fill('#login-email', email); await page.fill('#login-pw', pw);
  await page.click('#form-login button[type=submit]');
  await page.waitForTimeout(1500);
}

/* 셔임의 테스트 전용 경로. 인증 메일 링크 클릭을 대신한다. */
const confirmEmail = email =>
  fetch(BASE + '/test/confirm?email=' + encodeURIComponent(email)).then(r => r.json());

async function setLang(page, lang) {
  await page.click(`#app .lang-btn[data-lang="${lang}"]`);
  await page.waitForTimeout(500);
}

module.exports = { BASE, ANON, CFG, sql, reporter, launch, newCtx, open,
                   signup, login, confirmEmail, setLang };
