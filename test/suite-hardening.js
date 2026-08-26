/* 주입 · 경계값 · 애니메이션 규격 · 포커스 표시 */
const L = require('./lib');
const { BASE, sql, newCtx, open, signup, login, confirmEmail: confirm, setLang } = L;
const { check, summary } = L.reporter();
const SHOTS = process.env.SHOTS_DIR || require('os').tmpdir();
const { execFileSync } = require('child_process');
const PGSOCKET = process.env.PGSOCKET || '/tmp/akashic-pg';
const PGPORT   = process.env.PGPORT_TEST || '5439';
const run = q => execFileSync('psql',
  ['-h', PGSOCKET, '-p', PGPORT, '-U', 'postgres', '-v', 'ON_ERROR_STOP=1', '-q', '-c', q],
  { encoding: 'utf8' });

(async () => {
const browser = await L.launch();
const ctx = await newCtx(browser);
const page = await open(ctx);
await signup(page, 'hard@test.io', 'passphrase1', 'Hard');
await confirm('hard@test.io');
await login(page, 'hard@test.io', 'passphrase1');
await setLang(page, 'ko');

/* ---------- 저장된 값이 마크업으로 실행되지 않는가 ---------- */
run(`insert into public.records
       (planet_id,category_id,subcategory_id,title,summary,content,event_date,tags,source,level,is_seed,author_id)
     values ('TERRA-001','ART-007','LITERATURE',
       jsonb_build_object('ko','<img src=x onerror="window.__xss=1">주입 시도'),
       jsonb_build_object('ko','"><script>window.__xss=2</script>요약'),
       jsonb_build_object('ko','<svg onload="window.__xss=3"></svg>본문 첫 문단'),
       '2000-01-01',
       array['<b>굵게</b>','" onmouseover="window.__xss=4'],
       '</span><img src=y onerror="window.__xss=5">출처',
       1, true,
       (select id from public.profiles where keeper_code='KEEPER-000'))`);

const code = sql("select record_code from public.records where title->>'ko' like '%주입 시도'");
await page.evaluate(() => { window.__xss = undefined; });
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/ART-007/s/LITERATURE'; });
await page.waitForTimeout(1600);

const listState = await page.evaluate(() => ({
  xss: window.__xss,
  injected: document.querySelectorAll('img[src="x"], img[src="y"], svg').length,
  cardText: (document.querySelector('.card-title') || {}).textContent || ''
}));
check('목록에서 저장된 마크업이 실행되지 않고 글자로 보임',
      listState.xss === undefined && listState.injected === 0 &&
      listState.cardText.includes('<img src=x'),
      `xss=${listState.xss} 주입노드=${listState.injected} 제목=${listState.cardText.slice(0, 30)}`);

await page.evaluate(c => { location.hash = '#/p/TERRA-001/c/ART-007/s/LITERATURE/r/' + c; }, code);
await page.waitForTimeout(1700);
const modalState = await page.evaluate(() => ({
  xss: window.__xss,
  injected: document.querySelectorAll('#modal-record img, #modal-record svg, #modal-record script').length,
  body: document.getElementById('modal-body').textContent,
  meta: document.getElementById('modal-meta').textContent
}));
check('상세 모달의 본문·출처·태그도 글자로만 렌더',
      modalState.xss === undefined && modalState.injected === 0 &&
      modalState.body.includes('<svg onload=') && modalState.meta.includes('<img src=y'),
      `xss=${modalState.xss} 주입노드=${modalState.injected}`);
await page.screenshot({ path: SHOTS + '/s29-injection.png' });
await page.keyboard.press('Escape'); await page.waitForTimeout(700);

/* 검색 결과와 관련 기록 경로에서도 같은지 */
await page.evaluate(() => { location.hash = '#/search?q=' + encodeURIComponent('주입'); });
await page.waitForTimeout(1700);
const searchState = await page.evaluate(() => ({
  xss: window.__xss,
  injected: document.querySelectorAll('#main img, #main svg, #main script').length,
  hit: document.querySelectorAll('.card[data-code]').length
}));
check('검색 결과에서도 실행되지 않음',
      searchState.xss === undefined && searchState.injected === 0,
      `xss=${searchState.xss} 결과=${searchState.hit}`);

/* 표시 이름에 넣은 마크업 */
run(`update public.profiles set display_name = '<img src=z onerror="window.__xss=6">'
      where keeper_code = 'KEEPER-000'`);
await page.evaluate(() => { location.hash = '#/'; }); await page.waitForTimeout(1400);
check('표시 이름에 든 마크업도 실행되지 않음',
      (await page.evaluate(() => window.__xss)) === undefined);

/* ---------- 5.6 길이 경계 ---------- */
/* 제목·본문이 같으면 중복 규칙에 먼저 걸리므로 회차마다 다르게 만든다 */
const tryCreate = (n, tlen, slen) => page.evaluate(async a => {
  try {
    await window.AKASHIC_API.records.create({
      planet_id: 'TERRA-001', category_id: 'ART-007', subcategory_id: 'LITERATURE',
      title: { ko: a.n + '가'.repeat(a.t - String(a.n).length) },
      summary: { ko: '나'.repeat(a.s) },
      content: { ko: '본문 ' + a.n }, event_date: null, tags: ['t'], source: '출처', level: 1
    });
    return 'ok';
  } catch (e) { return e.code; }
}, { n, t: tlen, s: slen });

run("update public.records set created_at = created_at - interval '10 minutes'");
const at100 = await tryCreate(1, 100, 300);
run("update public.records set created_at = created_at - interval '10 minutes'");
const over100 = await tryCreate(2, 101, 300);
run("update public.records set created_at = created_at - interval '10 minutes'");
const over300 = await tryCreate(3, 100, 301);
check('5.6 제목 100자·요약 300자는 통과, 넘으면 서버가 거부',
      at100 === 'ok' && over100 === 'AKASHIC_TITLE_TOO_LONG' && over300 === 'AKASHIC_SUMMARY_TOO_LONG',
      `100=${at100} 101=${over100} 301=${over300}`);

/* ---------- 긴 문자열에서 레이아웃 ---------- */
run(`insert into public.records
       (planet_id,category_id,subcategory_id,title,summary,content,tags,source,level,is_seed,author_id)
     values ('TERRA-001','ART-007','LITERATURE',
       jsonb_build_object('ko',repeat('가나다라',20)),
       jsonb_build_object('ko',repeat('요약',60)),
       jsonb_build_object('ko','본문'),
       array[repeat('x',60)], repeat('https://example.invalid/very/long/path/', 6),
       1, true, (select id from public.profiles where keeper_code='KEEPER-000'))`);
const longCode = sql("select record_code from public.records where tags @> array[repeat('x',60)]");
for (const [w, h, label] of [[1280, 900, '데스크톱'], [390, 780, '모바일']]) {
  await page.setViewportSize({ width: w, height: h });
  await page.evaluate(c => { location.hash = '#/p/TERRA-001/c/ART-007/s/LITERATURE/r/' + c; }, longCode);
  await page.waitForTimeout(1600);
  const of = await page.evaluate(() =>
    document.documentElement.scrollWidth - document.documentElement.clientWidth);
  check(`끊기지 않는 긴 제목·태그·출처에서 ${label} 가로 넘침 없음`, of <= 1, 'overflow=' + of);
  await page.keyboard.press('Escape'); await page.waitForTimeout(600);
}
await page.setViewportSize({ width: 1280, height: 900 });

/* ---------- 3.4 애니메이션 규격 ---------- */
await page.evaluate(() => { location.hash = '#/'; }); await page.waitForTimeout(1300);
const anim = await page.evaluate(() => {
  const b = document.querySelector('.tb-classified');
  const n = document.getElementById('noise');
  return {
    blinkName: getComputedStyle(b).animationName,
    blinkDur:  getComputedStyle(b).animationDuration,
    blinkLoop: getComputedStyle(b).animationIterationCount,
    noiseOpacity: getComputedStyle(n).opacity
  };
});
check('3.4 CLASSIFIED 가 2초 주기로 무한 깜빡임',
      anim.blinkName === 'blink' && anim.blinkDur === '2s' && anim.blinkLoop === 'infinite',
      JSON.stringify(anim));
check('3.4 노이즈 오버레이 불투명도 3%',
      Math.abs(Number(anim.noiseOpacity) - 0.03) < 0.005, anim.noiseOpacity);

const hover = await page.evaluate(async () => {
  const card = document.querySelector('.card[data-planet]');
  const before = getComputedStyle(card);
  const out = { borderBefore: before.borderLeftColor, transformBefore: before.transform };
  card.classList.add('__probe');
  const style = document.createElement('style');
  style.textContent = '.__probe { }';
  document.head.appendChild(style);
  return out;
});
await page.hover('.card[data-planet]'); await page.waitForTimeout(400);
const hoverAfter = await page.evaluate(() => {
  const c = getComputedStyle(document.querySelector('.card[data-planet]'));
  return { border: c.borderLeftColor, transform: c.transform };
});
check('3.4 카드 호버 시 좌측 테두리가 빨강에서 금색으로, 위로 2px',
      hover.borderBefore === 'rgb(139, 0, 0)' &&
      hoverAfter.border === 'rgb(212, 175, 55)' &&
      /matrix\(1, 0, 0, 1, 0, -2\)/.test(hoverAfter.transform),
      `${hover.borderBefore} -> ${hoverAfter.border} / ${hoverAfter.transform}`);

/* ---------- 3.3 포커스 표시 유지 ---------- */
const focusRing = await page.evaluate(() => {
  const btn = document.querySelector('#sidebar-desktop .btn');
  btn.focus();
  const s = getComputedStyle(btn);
  return { style: s.outlineStyle, width: s.outlineWidth, color: s.outlineColor };
});
check('3.3 포커스 아웃라인이 제거되지 않고 보임',
      focusRing.style !== 'none' && parseFloat(focusRing.width) >= 2,
      JSON.stringify(focusRing));

/* 키보드만으로 카드까지 도달 */
await page.evaluate(() => { location.hash = '#/p/TERRA-001/c/ART-007/s/LITERATURE'; });
await page.waitForTimeout(1500);
await page.evaluate(() => document.getElementById('main').focus());
let reached = false;
for (let i = 0; i < 40; i++) {
  await page.keyboard.press('Tab');
  if (await page.evaluate(() => !!document.activeElement.closest('.card[data-code]'))) {
    reached = true; break;
  }
}
check('키보드 Tab 만으로 기록 카드에 도달', reached);
if (reached) {
  await page.keyboard.press('Enter'); await page.waitForTimeout(1500);
  check('도달한 카드에서 Enter 로 모달이 열림', await page.isVisible('#modal-record'));
}

/* ---------- 4.3 / 7.1 등급을 스스로 올릴 수 없는가 ----------
   등급은 record_views 의 행 수로 산정된다. 열지 않은 기록의 id 를 넣어
   등급을 올릴 수 있으면, level 컬럼을 막아 둔 의미가 없어진다. */
const before = Number(sql("select level from public.profiles p join auth.users u on u.id=p.id where u.email='hard@test.io'"));
const loggedBefore = Number(sql("select count(*) from public.record_views v join auth.users u on u.id=v.user_id where u.email='hard@test.io'"));
const attack = await page.evaluate(async () => {
  const sb = window.AKASHIC_SB.sb;
  const { data: u } = await sb.auth.getUser();
  const { data: ids } = await sb.from('records').select('id').limit(60);
  const out = { harvested: (ids || []).length };
  const res = await sb.from('record_views')
    .insert((ids || []).map(r => ({ user_id: u.user.id, record_id: r.id })));
  out.direct = res.error ? (res.error.code || res.error.message) : 'no-error';
  // RPC 경로로 등급 초과 기록을 찍어 보기
  const { data: high } = await sb.from('v_records').select('id,level').gt('level', 2).limit(20);
  for (const r of (high || [])) await window.AKASHIC_API.views.touch(r.id);
  out.highTouched = (high || []).length;
  return out;
});
const after = Number(sql("select level from public.profiles p join auth.users u on u.id=p.id where u.email='hard@test.io'"));
const logged = Number(sql("select count(*) from public.record_views v join auth.users u on u.id=v.user_id where u.email='hard@test.io'"));
check('7.1 record_views 에 직접 쓸 수 없고, 등급 초과 기록은 열람으로 기록되지 않음',
      attack.harvested > 0 && attack.direct !== 'no-error' &&
      after === before && logged === loggedBefore,
      `수집한 id ${attack.harvested} 직접쓰기=${attack.direct} 등급 ${before}->${after} ` +
      `열람기록 ${loggedBefore}->${logged}`);

/* 열람 가능한 기록은 정상적으로 기록되어야 한다 */
const okId = sql("select id from public.records where status='published' and deleted_at is null and level<=2 order by id limit 1");
await page.evaluate(id => window.AKASHIC_API.views.touch(Number(id)), okId);
await page.waitForTimeout(700);
check('열람 가능한 기록은 그대로 열람 기록에 남음',
      Number(sql(`select count(*) from public.record_views v join auth.users u on u.id=v.user_id where u.email='hard@test.io' and v.record_id=${okId}`)) === 1);

await browser.close();
process.exit(summary() ? 1 : 0);
})().catch(e => { console.error('RUNNER ERROR', e); process.exit(1); });
