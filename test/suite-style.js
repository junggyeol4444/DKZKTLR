/* 3.1 색상 사용 제한 · 3.2 CJK 폰트 폴백 · 3.5 반응형 3단계
   화면에 실제로 그려진 값을 재서 확인한다. */
const L = require('./lib');
const { BASE, sql, newCtx, open, signup, login, confirmEmail: confirm, setLang } = L;
const { check, summary } = L.reporter();
const SHOTS = process.env.SHOTS_DIR || require('os').tmpdir();

/* 페이지 안에서 실행할 명암비 감사기 */
const AUDIT = () => {
  const parse = c => {
    const m = c.match(/rgba?\(([^)]+)\)/);
    if (!m) return null;
    const p = m[1].split(',').map(Number);
    return { r: p[0], g: p[1], b: p[2], a: p.length > 3 ? p[3] : 1 };
  };
  const lum = ({ r, g, b }) => {
    const f = v => { v /= 255; return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); };
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
  };
  const ratio = (a, b) => {
    const l1 = lum(a), l2 = lum(b);
    return (Math.max(l1, l2) + 0.05) / (Math.min(l1, l2) + 0.05);
  };
  const bgOf = el => {
    let n = el;
    while (n && n !== document.documentElement) {
      const c = parse(getComputedStyle(n).backgroundColor);
      if (c && c.a > 0.9) return c;
      n = n.parentElement;
    }
    return { r: 13, g: 13, b: 13, a: 1 };            // body 바탕
  };

  const out = [];
  document.querySelectorAll('body *').forEach(el => {
    if (el.offsetParent === null && el.tagName !== 'BODY') return;
    const text = Array.from(el.childNodes)
      .filter(n => n.nodeType === 3).map(n => n.textContent.trim()).join('');
    if (!text) return;
    if (el.closest('.redacted, .gate-redact')) return;   // 검열 블록은 읽는 글이 아니다
    if (el.closest('[aria-hidden="true"]')) return;     // 장식 구분자는 명암비 기준 대상이 아니다
    const st = getComputedStyle(el);
    const fg = parse(st.color); if (!fg) return;
    const size = parseFloat(st.fontSize);
    const bold = Number(st.fontWeight) >= 700;
    const large = size >= 24 || (bold && size >= 18.66);
    const need = large ? 3 : 4.5;
    const r = ratio(fg, bgOf(el));
    if (r < need) {
      out.push({ sel: el.tagName.toLowerCase() + '.' + (el.className || '').toString().split(' ')[0],
                 color: st.color, size, ratio: Math.round(r * 100) / 100, need,
                 text: text.slice(0, 24) });
    }
  });
  return out;
};

(async () => {
const browser = await L.launch();
const ctx = await newCtx(browser);
const page = await open(ctx);

/* ---------- 비로그인 화면 ---------- */
await setLangGate(page, 'ko');
const gateBad = await page.evaluate(AUDIT);
check('3.1 경고 화면의 모든 본문 텍스트가 명암비 기준 충족',
      gateBad.length === 0, JSON.stringify(gateBad).slice(0, 300));

await page.evaluate(() => { location.hash = '#/login'; }); await page.waitForTimeout(500);
const loginBad = await page.evaluate(AUDIT);
check('3.1 로그인 화면 명암비 충족', loginBad.length === 0, JSON.stringify(loginBad).slice(0, 300));

/* ---------- 로그인 후 본 화면 ---------- */
await signup(page, 'style@test.io', 'passphrase1', 'Style');
await confirm('style@test.io');
await login(page, 'style@test.io', 'passphrase1');
await setLang(page, 'ko');
await page.waitForTimeout(900);
const homeBad = await page.evaluate(AUDIT);
check('3.1 행성 목록 화면 명암비 충족', homeBad.length === 0, JSON.stringify(homeBad).slice(0, 300));

await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/TECH-004/s/ENERGY'; });
await page.waitForTimeout(1400);
const listBad = await page.evaluate(AUDIT);
check('3.1 기록 목록 화면 명암비 충족 (검열 배지 포함)',
      listBad.length === 0, JSON.stringify(listBad).slice(0, 300));

await page.locator('.card[data-code]').first().click(); await page.waitForTimeout(1500);
const modalBad = await page.evaluate(AUDIT);
check('3.1 상세 모달 명암비 충족', modalBad.length === 0, JSON.stringify(modalBad).slice(0, 300));
await page.keyboard.press('Escape'); await page.waitForTimeout(700);

/* ---------- #8b0000 은 테두리·배경 전용 ---------- */
const redText = await page.evaluate(() => {
  const hits = [];
  document.querySelectorAll('body *').forEach(el => {
    if (el.offsetParent === null) return;
    const txt = Array.from(el.childNodes).filter(n => n.nodeType === 3)
      .map(n => n.textContent.trim()).join('');
    if (!txt) return;
    if (getComputedStyle(el).color === 'rgb(139, 0, 0)') {
      hits.push(el.className + ' :: ' + txt.slice(0, 20));
    }
  });
  return hits;
});
check('3.1 #8b0000 이 텍스트 색으로 쓰인 곳이 없음', redText.length === 0, redText.join(' / '));

/* ---------- 3.2 언어별 CJK 폰트 폴백 체인 ---------- */
const fonts = {};
for (const lang of ['ko', 'ja', 'en']) {
  await setLang(page, lang); await page.waitForTimeout(500);
  fonts[lang] = await page.evaluate(() => ({
    body:  getComputedStyle(document.body).fontFamily,
    title: getComputedStyle(document.querySelector('.mast-title')).fontFamily
  }));
}
check('3.2 KO 에서 본문·제목 모두 한글 폰트로 폴백',
      /Noto Serif KR/.test(fonts.ko.body) && /Noto Serif KR/.test(fonts.ko.title),
      fonts.ko.title);
check('3.2 JA 에서 본문·제목 모두 일본어 폰트로 폴백',
      /Noto Serif JP/.test(fonts.ja.body) && /Noto Serif JP/.test(fonts.ja.title),
      fonts.ja.title);
check('3.2 제목 폰트가 Special Elite 를 먼저 쓰고 CJK 가 뒤를 받침',
      /^["']?Special Elite/.test(fonts.ko.title) && /^["']?Special Elite/.test(fonts.ja.title),
      fonts.en.title);
check('3.2 시스템 폰트 폴백이 체인 끝에 있음',
      /serif$/.test(fonts.ko.body) && /serif$/.test(fonts.en.body), fonts.en.body);
await setLang(page, 'ko');

/* ---------- 3.5 반응형 3단계 ---------- */
const layoutAt = async (w, h) => {
  await page.setViewportSize({ width: w, height: h });
  await page.waitForTimeout(700);
  return page.evaluate(() => {
    const grid = document.querySelector('.grid');
    return {
      sidebar: getComputedStyle(document.getElementById('sidebar-desktop')).display,
      burger:  getComputedStyle(document.getElementById('btn-drawer')).display,
      cols:    grid ? getComputedStyle(grid).gridTemplateColumns.split(' ').length : 0,
      overflow: document.documentElement.scrollWidth - document.documentElement.clientWidth
    };
  });
};
await page.evaluate(() => { location.hash = '#/'; }); await page.waitForTimeout(1200);

const desktop = await layoutAt(1280, 900);
check('3.5 데스크톱 1024px 이상: 사이드바 노출 · 카드 2열 · 가로 넘침 없음',
      desktop.sidebar !== 'none' && desktop.burger === 'none' &&
      desktop.cols === 2 && desktop.overflow <= 1, JSON.stringify(desktop));

const tablet = await layoutAt(900, 900);
check('3.5 태블릿 768~1024px: 사이드바는 햄버거로 · 카드 1열 · 가로 넘침 없음',
      tablet.sidebar === 'none' && tablet.burger !== 'none' &&
      tablet.cols === 1 && tablet.overflow <= 1, JSON.stringify(tablet));

const mobile = await layoutAt(390, 780);
check('3.5 모바일 768px 이하: 1열 · 가로 넘침 없음',
      mobile.sidebar === 'none' && mobile.burger !== 'none' &&
      mobile.cols === 1 && mobile.overflow <= 1, JSON.stringify(mobile));

/* 태블릿 폭에서 드로어가 실제로 열리는가 */
await page.setViewportSize({ width: 900, height: 900 }); await page.waitForTimeout(500);
await page.click('#btn-drawer'); await page.waitForTimeout(500);
const drawerOK = await page.isVisible('#drawer');
const drawerBad = await page.evaluate(AUDIT);
await page.screenshot({ path: SHOTS + '/s28-tablet.png' });
check('3.5 태블릿 폭에서 햄버거 패널이 열리고 그 안도 명암비 충족',
      drawerOK && drawerBad.length === 0, JSON.stringify(drawerBad).slice(0, 200));

/* 터치 영역 44px */
const small = await page.evaluate(() => {
  const bad = [];
  document.querySelectorAll('button, .btn, a.btn').forEach(el => {
    if (el.offsetParent === null) return;
    const r = el.getBoundingClientRect();
    if (r.height < 44 && !el.classList.contains('btn-small') &&
        !el.classList.contains('lang-btn') && !el.classList.contains('langtab')) {
      bad.push(el.className + ' ' + Math.round(r.height));
    }
  });
  return bad;
});
check('2.17 터치 대상 높이 44px 이상', small.length === 0, small.join(' / '));

await browser.close();
process.exit(summary() ? 1 : 0);
})().catch(e => { console.error('RUNNER ERROR', e); process.exit(1); });

async function setLangGate(page, lang) {
  await page.click(`#screen-gate .lang-btn[data-lang="${lang}"]`);
  await page.waitForTimeout(400);
}
