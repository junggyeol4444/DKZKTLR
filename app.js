/* ============================================================
 *  AKASHIC RECORDS / app.js
 *  라우팅 · 렌더링 · 이벤트 (제2부 / 제4부)
 * ============================================================ */

(function () {
'use strict';

const { LANGS, I18N, LEVEL_GREEK } = window.AKASHIC_I18N;
const API = window.AKASHIC_API;
const { ApiError } = API;

/* ============================================================
 *  0. 상태 / 저장소
 *    LocalStorage 에는 언어·정렬·모션 설정만 둔다 (0.3)
 * ============================================================ */
const LS = { lang: 'akashic_lang', sort: 'akashic_sort', motion: 'akashic_motion' };

const SORT_KEYS = ['event_desc', 'event_asc', 'created_desc', 'title_asc', 'level_desc'];

const state = {
  lang: 'ko',
  sort: 'event_desc',
  session: null,
  profile: null,
  planets: [],
  categories: [],
  subcategories: [],
  route: null,
  list: { rows: [], offset: 0, done: false, key: '' },
  modal: { record: null, pushed: false, lastFocus: null, fromCode: null },
  reportTarget: null,
  booting: true,
  renderSeq: 0
};

function lsGet(k, d) { try { return localStorage.getItem(k) ?? d; } catch (_) { return d; } }
function lsSet(k, v) { try { localStorage.setItem(k, v); } catch (_) {} }

/* ============================================================
 *  1. i18n
 * ============================================================ */
function detectLang() {
  const saved = lsGet(LS.lang, null);
  if (saved && LANGS.includes(saved)) return saved;
  const nav = (navigator.language || 'en').slice(0, 2).toLowerCase();
  return LANGS.includes(nav) ? nav : 'en';
}

function t(key, vars) {
  const dict = I18N[state.lang] || I18N.ko;
  let s = dict[key];
  if (s === undefined) s = I18N.ko[key];
  if (s === undefined) s = I18N.en[key];
  if (s === undefined) return key;
  if (vars) for (const k in vars) s = s.replace(new RegExp('\\{' + k + '\\}', 'g'), vars[k]);
  return s;
}

/* 데이터 다국어 필드 폴백: 요청 언어 -> ko -> en -> '—' (4.4-3) */
function pick(obj) {
  if (!obj || typeof obj !== 'object') return '—';
  const order = [state.lang, 'ko', 'en'];
  for (const l of order) {
    const v = obj[l];
    if (typeof v === 'string' && v.trim() !== '') return v;
  }
  return '—';
}

function applyI18n(root) {
  (root || document).querySelectorAll('[data-i18n]').forEach(el => {
    el.textContent = t(el.getAttribute('data-i18n'));
  });
  (root || document).querySelectorAll('[data-i18n-ph]').forEach(el => {
    el.setAttribute('placeholder', t(el.getAttribute('data-i18n-ph')));
  });
}

function setLang(lang) {
  if (!LANGS.includes(lang)) lang = 'ko';
  state.lang = lang;
  lsSet(LS.lang, lang);
  document.documentElement.lang = lang;                       // <html lang> 동기화
  document.body.className = document.body.className
    .replace(/\blang-\w+\b/g, '').trim() + ' lang-' + lang;
  if (isMotionOff()) document.body.classList.add('no-motion');
  applyI18n(document);
  document.querySelectorAll('.lang-btn').forEach(b => {
    b.setAttribute('aria-current', b.dataset.lang === lang ? 'true' : 'false');
  });
  if (state.session && state.session.user) {
    API.auth.syncLang(state.session.user.id, lang);            // 계정 기본 언어도 갱신
  }
  render();                                                   // 현재 화면 다시 그리기
}

/* ============================================================
 *  2. 유틸
 * ============================================================ */
function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

/* 저장은 YYYY-MM-DD, 표시는 로케일. 기원전 등 파싱 불가 값은 원문 그대로 (4.4-5) */
function fmtDate(v) {
  if (!v) return '—';
  const s = String(v);

  // 기원전 표기: Postgres 는 '1754-01-01 BC', 드라이버에 따라 '-001753-01-01' 로도 온다
  const bcText = s.match(/^0*(\d{1,6})-\d{2}-\d{2}\s*BC$/i);
  if (bcText) return t('date.bc', { y: Number(bcText[1]) });
  const bcIso = s.match(/^-0*(\d{1,6})-\d{2}-\d{2}/);
  if (bcIso) return t('date.bc', { y: Number(bcIso[1]) + 1 });   // 천문학적 연도 -> 기원전 연도

  const m = s.match(/^(\d{4}-\d{2}-\d{2})(?:[T\s]|$)/);
  if (!m) return s;                                    // 그 밖의 파싱 불가 값은 원문 유지
  const d = new Date(m[1] + 'T00:00:00Z');
  if (isNaN(d.getTime())) return s;
  try {
    return d.toLocaleDateString(state.lang, { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' });
  } catch (_) { return s; }
}

function fmtDateTime(v) {
  if (!v) return '—';
  const d = new Date(v);
  if (isNaN(d.getTime())) return String(v);
  try { return d.toLocaleDateString(state.lang, { year: 'numeric', month: 'long', day: 'numeric' }); }
  catch (_) { return d.toISOString().slice(0, 10); }
}

function greek(level) { return LEVEL_GREEK[level] || '?'; }

/* 분류 코드 -> 선택 언어 이름 (없으면 코드를 그대로 보여준다) */
function planetName(id) { const x = state.planets.find(p => p.id === id);      return x ? pick(x.name) : id; }
function catName(id)    { const x = state.categories.find(c => c.id === id);   return x ? pick(x.name) : id; }
function subName(id)    { const x = state.subcategories.find(sc => sc.id === id); return x ? pick(x.name) : id; }

function blocks(n) { return '█'.repeat(Math.max(8, Math.min(n || 40, 90))); }

function isMotionOff() { return lsGet(LS.motion, '0') === '1'; }

/* 4.3 등급 상승은 상단 배너로 알린다 */
function levelBanner(msg) {
  const box = document.getElementById('level-banner');
  if (!box) return;
  document.getElementById('level-banner-text').textContent = msg;
  document.getElementById('level-banner-close').textContent = t('banner.close');
  box.hidden = false;
}

function toast(msg, warn) {
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.className = 'toast' + (warn ? ' toast-warn' : '');
  el.hidden = false;
  clearTimeout(toast._t);
  toast._t = setTimeout(() => { el.hidden = true; }, 4200);
}

/* 오류 코드 -> 사용자 문구 (2.16) */
function errText(e) {
  if (!(e instanceof ApiError)) return t('err.unknown');
  if (e.code.startsWith('AKASHIC_')) {
    const k = 'srv.' + e.code;
    const s = t(k);
    return s === k ? t('err.unknown') : s;
  }
  switch (e.code) {
    case 'network':   return t('err.network');
    case 'session':   return t('err.session');
    case 'forbidden': return t('err.forbidden');
    case 'notfound':  return t('err.notfound');
    case 'server':    return t('err.server');
    case 'config':    return t('err.config');
    case 'duplicate': return t('report.dup');
    default:          return t('err.unknown');
  }
}

async function handleError(e, mount) {
  if (e instanceof ApiError && e.code === 'session') {
    state.session = null; state.profile = null;
    location.hash = '#/';
    toast(t('err.session'), true);
    return;
  }
  const msg = errText(e);
  if (mount) {
    mount.innerHTML =
      '<div class="state-box"><p class="state-mark" aria-hidden="true">▓▓▓▓▓▓▓▓</p>' +
      '<p class="state-title">' + esc(msg) + '</p>' +
      '<button type="button" class="btn" id="btn-retry">' + esc(t('err.retry')) + '</button></div>';
    const b = mount.querySelector('#btn-retry');
    if (b) b.addEventListener('click', () => render());
  } else {
    toast(msg, true);
  }
}

/* 화면 전환 세대 표시.
   느린 응답이 뒤늦게 도착해 이미 바뀐 화면을 덮어쓰지 않도록,
   각 화면 함수는 시작할 때 세대를 기억하고 그리기 직전에 아직 유효한지 확인한다. */
function newRender() { return ++state.renderSeq; }
function stale(seq) { return seq !== state.renderSeq; }

function skeleton(n) {
  let h = '<div class="grid">';
  for (let i = 0; i < (n || 4); i++) {
    h += '<div class="skeleton"><div class="line short"></div><div class="line"></div>' +
         '<div class="line mid"></div></div>';
  }
  return h + '</div>';
}

function emptyBox(titleKey, bodyKey) {
  return '<div class="state-box"><p class="state-mark" aria-hidden="true">▓▓▓▓▓▓▓▓</p>' +
         '<p class="state-title">' + esc(t(titleKey || 'empty.title')) + '</p>' +
         '<p class="state-body">' + esc(t(bodyKey || 'empty.body')) + '</p></div>';
}

/* ============================================================
 *  3. 라우팅 (4.2)
 * ============================================================ */
function parseRoute() {
  const raw = location.hash.replace(/^#/, '') || '/';
  const [pathPart, queryPart] = raw.split('?');
  const q = new URLSearchParams(queryPart || '');
  const seg = pathPart.split('/').filter(Boolean);

  if (seg.length === 0) return { name: 'planets' };

  const simple = {
    login: 'login', signup: 'signup', 'signup-done': 'signup-done',
    reset: 'reset', 'reset-confirm': 'reset-confirm',
    bookmarks: 'bookmarks', new: 'new', mine: 'mine', admin: 'admin'
  };
  if (seg.length === 1 && simple[seg[0]]) return { name: simple[seg[0]] };
  if (seg[0] === 'search') return { name: 'search', q: q.get('q') || '' };
  if (seg[0] === 'edit' && seg[1]) return { name: 'edit', code: decodeURIComponent(seg[1]) };

  if (seg[0] === 'p' && seg[1]) {
    const r = { name: 'categories', planet: decodeURIComponent(seg[1]) };
    if (seg[2] === 'c' && seg[3]) {
      r.name = 'subcategories'; r.category = decodeURIComponent(seg[3]);
      if (seg[4] === 's' && seg[5]) {
        r.name = 'records'; r.sub = decodeURIComponent(seg[5]);
        if (seg[6] === 'r' && seg[7]) { r.name = 'record'; r.code = decodeURIComponent(seg[7]); }
      }
    }
    if (r.name === 'categories' && seg.length > 2) return null;
    return r;
  }
  return null;                                  // 잘못된 해시 -> #/ 로 리다이렉트
}

function routePath(r) {
  switch (r.name) {
    case 'categories':    return '#/p/' + r.planet;
    case 'subcategories': return '#/p/' + r.planet + '/c/' + r.category;
    case 'records':
    case 'record':        return '#/p/' + r.planet + '/c/' + r.category + '/s/' + r.sub;
    default:              return '#/';
  }
}

function recordPath(row) {
  return '#/p/' + row.planet_id + '/c/' + row.category_id + '/s/' + row.subcategory_id +
         '/r/' + row.record_code;
}

const PUBLIC_ROUTES = ['login', 'signup', 'signup-done', 'reset', 'reset-confirm'];

/* ============================================================
 *  4. 화면 전환
 * ============================================================ */
const SCREENS = ['screen-boot', 'screen-gate', 'screen-login', 'screen-signup',
                 'screen-signup-done', 'screen-reset', 'screen-reset-confirm'];

function showScreen(id) {
  SCREENS.forEach(s => { const el = document.getElementById(s); if (el) el.hidden = (s !== id); });
  document.getElementById('app').hidden = true;
}

function showApp() {
  SCREENS.forEach(s => { const el = document.getElementById(s); if (el) el.hidden = true; });
  document.getElementById('app').hidden = false;
}

/* ============================================================
 *  5. 사이드바 (2.5)
 * ============================================================ */
async function renderSidebar() {
  const targets = [document.getElementById('sidebar-desktop'),
                   document.getElementById('sidebar-drawer')];
  const shell = (statsHtml, recentHtml) =>
    '<div class="side-box"><h2 class="side-title">' + esc(t('side.stats')) + '</h2>' + statsHtml +
    '<div class="motion-toggle"><input type="checkbox" id="__m" ' +
      (isMotionOff() ? 'checked' : '') + '><label for="__m">' + esc(t('side.motion')) + '</label></div>' +
    '</div>' +
    '<div class="side-box"><h2 class="side-title">' + esc(t('side.recent')) + '</h2>' + recentHtml + '</div>' +
    '<div class="side-box side-actions">' +
      '<a class="btn btn-gold" href="#/new">' + esc(t('side.new')) + '</a>' +
      '<a class="btn" href="#/mine">' + esc(t('side.mine')) + '</a>' +
      '<a class="btn" href="#/bookmarks" id="side-book">' + esc(t('side.bookmarks')) + '</a>' +
      '<a class="btn" href="#/search">' + esc(t('side.search')) + '</a>' +
      (state.profile && state.profile.is_admin
        ? '<a class="btn btn-red" href="#/admin">' + esc(t('side.admin')) + '</a>' : '') +
    '</div>';

  const loading = '<div class="side-row"><span>' + esc(t('gate.checking')) + '</span></div>';
  targets.forEach(el => { if (el) el.innerHTML = shell(loading, loading); });

  let stats, recent, books;
  try {
    [stats, recent, books] = await Promise.all([
      API.counts.stats(), API.views.recent(5), API.bookmarks.list()
    ]);
  } catch (e) {
    targets.forEach(el => { if (el) el.innerHTML = shell(
      '<div class="side-row"><span>' + esc(errText(e)) + '</span></div>', '') ; });
    return;
  }

  const lvl = state.profile ? state.profile.level : 0;
  const statsHtml =
    '<div class="side-row"><span>' + esc(t('side.total'))   + '</span><b>' + stats.total_records + '</b></div>' +
    '<div class="side-row"><span>' + esc(t('side.planets')) + '</span><b>' + stats.total_planets + '</b></div>' +
    '<div class="side-row"><span>' + esc(t('side.mylevel')) + '</span><b>' + greek(lvl) +
      ' / LEVEL-' + lvl + '</b></div>' +
    '<div class="side-row"><span>' + esc(t('side.today'))   + '</span><b>' + stats.today_records + '</b></div>';

  const recentHtml = recent.length
    ? '<ul class="side-list">' + recent.map(r =>
        '<li><a href="' + esc(recordPath(r)) + '">' + esc(pick(r.title)) + '</a></li>').join('') + '</ul>'
    : '<p class="side-empty">' + esc(t('side.none')) + '</p>';

  targets.forEach(el => {
    if (!el) return;
    el.innerHTML = shell(statsHtml, recentHtml);
    const link = el.querySelector('#side-book');
    if (link) link.textContent = t('side.bookmarks') + ' (' + books.length + ')';
    const m = el.querySelector('#__m');
    if (m) m.addEventListener('change', () => {
      lsSet(LS.motion, m.checked ? '1' : '0');
      document.body.classList.toggle('no-motion', m.checked);
      renderSidebar();
    });
  });
}

/* ============================================================
 *  6. 상단 바 / breadcrumb
 * ============================================================ */
function renderTopbar() {
  const p = state.profile;
  document.getElementById('tb-level').textContent = p ? greek(p.level) : '—';
  document.getElementById('tb-keeper').textContent = p ? (p.keeper_code || 'KEEPER-???') : '—';
}

function crumbLink(href, label) { return '<a href="' + esc(href) + '">' + esc(label) + '</a>'; }

function renderCrumbs(r) {
  const box = document.getElementById('crumbs');
  const parts = [crumbLink('#/', t('nav.home'))];
  if (r.planet) parts.push(crumbLink('#/p/' + r.planet, planetName(r.planet)));
  if (r.category) parts.push(crumbLink('#/p/' + r.planet + '/c/' + r.category, catName(r.category)));
  if (r.sub) parts.push(crumbLink(routePath(r), subName(r.sub)));
  const names = { bookmarks: 'book.title', mine: 'mine.title', new: 'form.new',
                  edit: 'form.edit', search: 'search.title', admin: 'admin.title' };
  if (names[r.name]) parts.push('<span>' + esc(t(names[r.name])) + '</span>');
  // 구분자는 장식이므로 보조기술에서 감춘다 (명암비 기준의 장식 예외에 해당)
  box.innerHTML = parts.join('<span class="sep" aria-hidden="true">»</span>');
}

/* ============================================================
 *  7. 카드 렌더링
 * ============================================================ */
function recordCard(row, opts) {
  opts = opts || {};
  const locked = !row.can_view;
  const summary = locked
    ? '<span class="redacted">' + blocks(60) + '</span>'
    : esc(pick(row.summary));
  const badge = '<span class="badge badge-level">LEVEL-' + row.level + '</span>';
  const lockBar = locked
    ? '<p class="badge badge-locked lock-bar">' + esc(t('rec.locked', { n: row.level })) + '</p>' : '';
  const tags = (row.tags || []).map(x => '<span class="tag">#' + esc(x) + '</span>').join('');
  const state_ = opts.state
    ? '<span class="badge badge-state-' + esc(opts.state) + '">' +
      esc(t('mine.state.' + opts.state)) + '</span>' : '';

  return '<article class="card" data-code="' + esc(row.record_code) + '" tabindex="0">' +
    '<div class="card-head"><span class="card-code">' + esc(row.record_code) + '</span>' +
      '<span>' + state_ + ' ' + badge +
      (opts.noBookmark ? '' :
        '<button type="button" class="bookmark-btn" data-bm="' + row.id + '" ' +
        'aria-pressed="' + (row.is_bookmarked ? 'true' : 'false') + '" ' +
        'title="' + esc(t('modal.bookmark')) + '">' + (row.is_bookmarked ? '★' : '☆') + '</button>') +
      '</span></div>' + lockBar +
    '<h3 class="card-title">' + esc(pick(row.title)) + '</h3>' +
    '<p class="card-summary">' + summary + '</p>' +
    '<div class="tags">' + tags + '</div>' +
    '<div class="card-foot"><span>' + esc(fmtDate(row.event_date)) + ' | ' +
      esc(row.author_code || 'KEEPER-???') + '</span>' +
      '<span class="card-open">' + esc(t('rec.detail')) + '</span></div>' +
    '</article>';
}

function wireCards(mount, onOpen) {
  mount.querySelectorAll('.card[data-code]').forEach(card => {
    const open = ev => {
      if (ev.target.closest('.bookmark-btn')) return;
      onOpen(card.dataset.code, card);
    };
    card.addEventListener('click', open);
    card.addEventListener('keydown', ev => {
      if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); open(ev); }
    });
  });
  mount.querySelectorAll('.bookmark-btn[data-bm]').forEach(btn => {
    btn.addEventListener('click', async ev => {
      ev.stopPropagation();
      const id = Number(btn.dataset.bm);
      const on = btn.getAttribute('aria-pressed') === 'true';
      try {
        if (on) await API.bookmarks.remove(id, state.session.user.id);
        else    await API.bookmarks.add(id, state.session.user.id);
        btn.setAttribute('aria-pressed', on ? 'false' : 'true');
        btn.textContent = on ? '☆' : '★';
        renderSidebar();
        if (state.route && state.route.name === 'bookmarks') render();
      } catch (e) { handleError(e); }
    });
  });
}

/* ============================================================
 *  8. 화면: 1단계 행성 (2.6)
 * ============================================================ */
async function viewPlanets(mount) {
  const seq = state.renderSeq;
  mount.innerHTML = '<h2 class="section-title">' + esc(t('planets.title')) + '</h2>' + skeleton(4);
  const [planets, counts] = await Promise.all([API.catalog.planets(), API.counts.byPlanet()]);
  if (stale(seq)) return;
  state.planets = planets;

  const myLevel = state.profile ? state.profile.level : 0;
  const cards = planets.map(p => {
    const locked = p.required_level > myLevel;
    const n = counts[p.id] || 0;
    return '<article class="card' + (locked ? ' card-locked' : '') + '" data-planet="' +
      esc(p.id) + '" tabindex="0">' +
      '<p class="card-code">CLASSIFIED · ' + esc(p.id) + '</p>' +
      '<h3 class="card-title">' + esc(pick(p.name)) + '</h3>' +
      '<p class="card-sub">' + esc(pick(p.location)) + '</p>' +
      '<p class="card-foot"><span>' + esc(t('planets.status')) + ': ' + esc(p.status) +
        ' (' + esc(t('planets.status.' + p.status)) + ')</span>' +
      '<span>' + n + ' ' + esc(t('rec.count')) + '</span></p>' +
      (locked ? '<div class="lock-overlay"><span class="lock-icon">🔒</span><span>' +
        esc(t('planets.locked')) + '</span><span>LEVEL-' + p.required_level + ' REQUIRED</span></div>' : '') +
      '</article>';
  }).join('');

  mount.innerHTML = '<h2 class="section-title">' + esc(t('planets.title')) + '</h2>' +
                    '<div class="grid">' + cards + '</div>';

  mount.querySelectorAll('.card[data-planet]').forEach(card => {
    const go = () => {
      if (card.classList.contains('card-locked')) { toast(t('planets.locked'), true); return; }
      location.hash = '#/p/' + card.dataset.planet;
    };
    card.addEventListener('click', go);
    card.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); go(); }
    });
  });
}

/* ============================================================
 *  9. 화면: 2단계 대분류 (2.7)
 * ============================================================ */
async function viewCategories(mount, r) {
  const seq = state.renderSeq;
  mount.innerHTML = '<h2 class="section-title">' + esc(t('cat.title')) + '</h2>' + skeleton(3);
  const [cats, counts] = await Promise.all([
    API.catalog.categories(), API.counts.byCategory(r.planet)
  ]);
  if (stale(seq)) return;
  state.categories = cats;

  const rows = cats.map(c => {
    const n = counts[c.id] || 0;
    return '<article class="card rowcard" data-cat="' + esc(c.id) + '" tabindex="0">' +
      '<div class="rowcard-main">' +
        '<p class="card-code">' + esc(c.id) + '</p>' +
        '<h3 class="card-title">' + esc(pick(c.name)) + '</h3>' +
        '<p class="card-sub">' + esc(pick(c.description)) + '</p>' +
        '<p class="card-foot"><span>' +
          (n > 0 ? n + ' ' + esc(t('rec.count')) : esc(t('cat.empty'))) + '</span></p>' +
      '</div><span class="rowcard-arrow" aria-hidden="true">›</span></article>';
  }).join('');

  mount.innerHTML = '<h2 class="section-title">' + esc(t('cat.title')) + '</h2>' +
                    '<div class="grid grid-1">' + rows + '</div>';
  mount.querySelectorAll('.card[data-cat]').forEach(card => {
    const go = () => { location.hash = '#/p/' + r.planet + '/c/' + card.dataset.cat; };
    card.addEventListener('click', go);
    card.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); go(); }
    });
  });
}

/* ============================================================
 *  10. 화면: 3단계 중분류 (2.8)
 * ============================================================ */
async function viewSubcategories(mount, r) {
  const seq = state.renderSeq;
  mount.innerHTML = '<h2 class="section-title">' + esc(t('sub.title')) + '</h2>' + skeleton(3);
  const [subs, counts] = await Promise.all([
    API.catalog.subcategories(r.planet, r.category),
    API.counts.bySubcategory(r.planet, r.category)
  ]);
  if (stale(seq)) return;

  if (!subs.length) { mount.innerHTML = emptyBox(); return; }

  const rows = subs.map(s => {
    const c = counts[s.id] || { count: 0, last: null };
    return '<article class="card rowcard" data-sub="' + esc(s.id) + '" tabindex="0">' +
      '<div class="rowcard-main">' +
        '<div class="card-head"><h3 class="card-title">' + esc(pick(s.name)) + '</h3>' +
          '<span class="badge badge-level">LEVEL-' + s.level + '</span></div>' +
        '<p class="card-sub">' + esc(pick(s.description)) + '</p>' +
        '<p class="card-foot"><span>' + c.count + ' ' + esc(t('rec.count')) + ' | ' +
          esc(t('sub.latest')) + ': ' + (c.last ? esc(fmtDateTime(c.last)) : '—') + '</span></p>' +
      '</div><span class="rowcard-arrow" aria-hidden="true">›</span></article>';
  }).join('');

  mount.innerHTML = '<h2 class="section-title">' + esc(t('sub.title')) + '</h2>' +
                    '<div class="grid grid-1">' + rows + '</div>';
  mount.querySelectorAll('.card[data-sub]').forEach(card => {
    const go = () => {
      location.hash = '#/p/' + r.planet + '/c/' + r.category + '/s/' + card.dataset.sub;
    };
    card.addEventListener('click', go);
    card.addEventListener('keydown', e => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); go(); }
    });
  });
}

/* ============================================================
 *  11. 화면: 4단계 기록 목록 (2.9)
 * ============================================================ */
function sortSelect() {
  return '<label class="sr-only" for="sort-sel"></label><select id="sort-sel" aria-label="' +
    esc(t('sort.label')) + '">' +
    SORT_KEYS.map(k => '<option value="' + k + '"' + (k === state.sort ? ' selected' : '') + '>' +
      esc(t('sort.' + k)) + '</option>').join('') + '</select>';
}

async function viewRecords(mount, r) {
  const seq = state.renderSeq;
  const key = [r.planet, r.category, r.sub, state.sort].join('|');
  if (state.list.key !== key) state.list = { rows: [], offset: 0, done: false, key };

  const head =
    '<div class="list-head"><h2 class="list-title">' + esc(t('rec.title')) + '</h2>' +
    '<div class="list-tools"><a class="btn btn-small" href="' + esc('#/p/' + r.planet + '/c/' + r.category) +
    '">← ' + esc(t('nav.location')) + '</a>' + sortSelect() + '</div></div>';

  if (!state.list.rows.length) mount.innerHTML = head + skeleton(4);

  const rows = state.list.rows.length ? state.list.rows : await API.records.list({
    planetId: r.planet, categoryId: r.category, subcategoryId: r.sub,
    sort: state.sort, lang: state.lang, offset: 0
  });
  if (stale(seq)) return;
  state.list.rows = rows;
  state.list.offset = rows.length;
  state.list.done = rows.length < API.PAGE_SIZE;

  paint();

  function paint() {
    if (stale(seq)) return;
    if (!state.list.rows.length) { mount.innerHTML = head + emptyBox(); bindSort(); return; }
    mount.innerHTML = head + '<div class="grid">' +
      state.list.rows.map(x => recordCard(x)).join('') + '</div>' +
      (state.list.done ? '' :
        '<div style="text-align:center;margin-top:1.2rem">' +
        '<button type="button" class="btn" id="btn-more">' + esc(t('rec.more')) + '</button></div>');
    bindSort();
    wireCards(mount, code => { location.hash = location.hash.split('/r/')[0] + '/r/' + code; });
    const more = mount.querySelector('#btn-more');
    if (more) more.addEventListener('click', async () => {
      more.disabled = true;
      try {
        const next = await API.records.list({
          planetId: r.planet, categoryId: r.category, subcategoryId: r.sub,
          sort: state.sort, lang: state.lang, offset: state.list.offset
        });
        if (stale(seq)) return;
        state.list.rows = state.list.rows.concat(next);
        state.list.offset += next.length;
        state.list.done = next.length < API.PAGE_SIZE;
        paint();
      } catch (e) { handleError(e); more.disabled = false; }
    });
  }

  function bindSort() {
    const sel = mount.querySelector('#sort-sel');
    if (!sel) return;
    sel.addEventListener('change', () => {
      state.sort = sel.value; lsSet(LS.sort, sel.value);
      state.list = { rows: [], offset: 0, done: false, key: '' };
      render();
    });
  }
}

/* ============================================================
 *  12. 화면: 북마크 / 내가 쓴 기록 / 검색
 * ============================================================ */
async function viewBookmarks(mount) {
  const seq = state.renderSeq;
  mount.innerHTML = '<h2 class="section-title">' + esc(t('book.title')) + '</h2>' + skeleton(2);
  const rows = await API.bookmarks.list();
  if (stale(seq)) return;
  if (!rows.length) {
    mount.innerHTML = '<h2 class="section-title">' + esc(t('book.title')) + '</h2>' +
                      emptyBox('book.empty', 'empty.body');
    return;
  }
  mount.innerHTML = '<h2 class="section-title">' + esc(t('book.title')) + '</h2>' +
                    '<div class="grid">' + rows.map(x => recordCard(x)).join('') + '</div>';
  wireCards(mount, code => {
    const row = rows.find(x => x.record_code === code);
    if (row) location.hash = recordPath(row);
  });
}

async function viewMine(mount) {
  const seq = state.renderSeq;
  mount.innerHTML = '<h2 class="section-title">' + esc(t('mine.title')) + '</h2>' + skeleton(2);
  const rows = await API.records.mine();
  if (stale(seq)) return;
  if (!rows.length) {
    mount.innerHTML = '<h2 class="section-title">' + esc(t('mine.title')) + '</h2>' +
                      emptyBox('mine.empty', 'empty.body');
    return;
  }
  mount.innerHTML = '<h2 class="section-title">' + esc(t('mine.title')) + '</h2>' +
    '<div class="grid">' + rows.map(x => {
      const card = recordCard(x, { state: x.state, noBookmark: true });
      const tools = '<div class="card-foot">' +
        (x.state === 'deleted' ? '' :
          '<a class="btn btn-small" href="#/edit/' + esc(x.record_code) + '">' + esc(t('modal.edit')) + '</a>' +
          '<button type="button" class="btn btn-small btn-red" data-del="' + x.id + '">' +
          esc(t('modal.delete')) + '</button>') + '</div>';
      return card.replace('</article>', tools + '</article>');
    }).join('') + '</div>';

  wireCards(mount, code => {
    const row = rows.find(x => x.record_code === code);
    if (row && row.state !== 'deleted') location.hash = recordPath(row);
  });
  mount.querySelectorAll('[data-del]').forEach(b => {
    b.addEventListener('click', async ev => {
      ev.stopPropagation();
      if (!confirm(t('form.confirm.delete'))) return;
      try {
        await API.records.remove(Number(b.dataset.del));
        toast(t('form.deleted'));
        render(); renderSidebar();
      } catch (e) { handleError(e); }
    });
  });
}

async function viewSearch(mount, r) {
  const seq = state.renderSeq;
  const q = r.q || '';
  const head = '<h2 class="section-title">' + esc(t('search.title')) + '</h2>' +
    '<form class="list-head" id="search-form"><div class="field" style="flex:1 1 260px;margin:0">' +
    '<label for="q">' + esc(t('search.title')) + '</label>' +
    '<input id="q" name="q" type="search" value="' + esc(q) + '" placeholder="' +
    esc(t('search.ph')) + '"></div>' +
    '<button type="submit" class="btn btn-gold">' + esc(t('search.submit')) + '</button></form>' +
    '<p class="state-body" style="font-size:.85rem">' + esc(t('search.hint')) + '</p>';

  mount.innerHTML = head;
  const form = mount.querySelector('#search-form');
  form.addEventListener('submit', ev => {
    ev.preventDefault();
    location.hash = '#/search?q=' + encodeURIComponent(form.q.value.trim());
  });
  if (!q) return;

  const box = document.createElement('div');
  box.innerHTML = skeleton(2);
  mount.appendChild(box);
  let rows;
  try { rows = await API.records.search(q); }
  catch (e) { return handleError(e, box); }
  if (stale(seq)) return;

  if (!rows.length) { box.innerHTML = emptyBox('search.empty', 'empty.body'); return; }
  box.innerHTML = '<div class="grid">' + rows.map(x => {
    const where = '<p class="card-sub">' + esc(planetName(x.planet_id)) +
                  ' » ' + esc(catName(x.category_id)) +
                  ' » ' + esc(subName(x.subcategory_id)) + '</p>';
    return recordCard(x).replace('<h3 class="card-title">', where + '<h3 class="card-title">');
  }).join('') + '</div>';
  wireCards(box, code => {
    const row = rows.find(x => x.record_code === code);
    if (row) location.hash = recordPath(row);
  });
}

/* ============================================================
 *  12-1. 관리자: 숨김 기록 대기열 (4.8)
 *     신고 3건이 쌓여 자동으로 숨겨진 기록을 관리자가 검토한다.
 *     숨김 해제 또는 삭제 확정이 가능하며, 두 동작 모두 RLS 와
 *     트리거가 관리자 여부를 서버에서 다시 확인한다.
 * ============================================================ */
async function viewAdmin(mount) {
  const seq = state.renderSeq;
  if (!state.profile || !state.profile.is_admin) {
    mount.innerHTML = emptyBox('err.forbidden', 'err.forbidden');
    return;
  }
  mount.innerHTML = '<h2 class="section-title">' + esc(t('admin.title')) + '</h2>' + skeleton(2);
  const rows = await API.records.hidden();
  if (stale(seq)) return;

  if (!rows.length) {
    mount.innerHTML = '<h2 class="section-title">' + esc(t('admin.title')) + '</h2>' +
                      emptyBox('admin.empty', 'empty.body');
    return;
  }

  mount.innerHTML = '<h2 class="section-title">' + esc(t('admin.title')) + '</h2>' +
    '<div class="grid grid-1">' + rows.map(r =>
      '<article class="card">' +
        '<div class="card-head"><span class="card-code">' + esc(r.record_code) + '</span>' +
          '<span class="badge badge-locked">' + esc(t('admin.reports')) + ' ' + r.report_count +
          '</span></div>' +
        '<h3 class="card-title">' + esc(pick(r.title)) + '</h3>' +
        '<p class="card-summary">' + esc(pick(r.summary)) + '</p>' +
        '<div class="card-foot"><span>' + esc(fmtDate(r.event_date)) + ' | ' +
          esc(r.author_code) + ' | ' + esc(t('modal.source')) + ': ' + esc(r.source) + '</span></div>' +
        '<div class="admin-row">' +
          '<button type="button" class="btn btn-small" data-unhide="' + r.id + '">' +
            esc(t('admin.unhide')) + '</button>' +
          '<button type="button" class="btn btn-small btn-red" data-purge="' + r.id + '">' +
            esc(t('admin.delete')) + '</button>' +
        '</div>' +
      '</article>').join('') + '</div>';

  mount.querySelectorAll('[data-unhide]').forEach(b => b.addEventListener('click', async () => {
    try {
      await API.records.setStatus(Number(b.dataset.unhide), 'published');
      toast(t('admin.unhidden'));
      render(); renderSidebar();
    } catch (e) { handleError(e); }
  }));
  mount.querySelectorAll('[data-purge]').forEach(b => b.addEventListener('click', async () => {
    if (!confirm(t('form.confirm.delete'))) return;
    try {
      await API.records.remove(Number(b.dataset.purge));
      toast(t('form.deleted'));
      render(); renderSidebar();
    } catch (e) { handleError(e); }
  }));
}

/* ============================================================
 *  13. 상세 모달 (2.10)
 * ============================================================ */
const modalEl = () => document.getElementById('modal-record');

async function openRecordModal(code, r) {
  const box = modalEl();
  state.modal.lastFocus = document.activeElement;
  state.modal.fromCode = code;      // 목록이 다시 그려져도 카드를 찾아갈 수 있도록

  const seq = state.renderSeq;
  let row;
  try { row = await API.records.byCode(code); }
  catch (e) { handleError(e); closeRecordModal(); return; }
  if (stale(seq)) return;               // 이미 다른 화면으로 떠났다
  state.modal.record = row;

  document.getElementById('modal-record-title').textContent = pick(row.title);

  const meta = [
    [t('modal.id'), row.record_code],
    [t('modal.path'), planetName(row.planet_id) + ' / ' + catName(row.category_id) +
                      ' » ' + subName(row.subcategory_id)],
    [t('modal.event'), fmtDate(row.event_date)],
    [t('modal.created'), fmtDateTime(row.created_at)]
  ];
  if (row.updated_at) meta.push([t('modal.updated'), fmtDateTime(row.updated_at)]);
  meta.push([t('modal.author'), row.author_code || 'KEEPER-???']);
  meta.push([t('modal.level'), 'LEVEL-' + row.level]);
  meta.push([t('modal.source'), row.source]);
  if (row.tags && row.tags.length) {
    meta.push([t('form.tags'), row.tags.map(x => '#' + x).join('  ')]);
  }
  document.getElementById('modal-meta').innerHTML = meta.map(
    m => '<div class="meta-row"><span class="k">' + esc(m[0]) + '</span>' +
         '<span class="v">' + esc(m[1]) + '</span></div>').join('');

  const bodyEl = document.getElementById('modal-body');
  if (!row.can_view) {
    bodyEl.innerHTML = '<p class="badge badge-locked">' +
      esc(t('rec.locked', { n: row.level })) + '</p><p>' + esc(t('modal.censored')) + '</p>' +
      '<p class="redacted">' + blocks(90) + '<br>' + blocks(90) + '<br>' + blocks(70) + '</p>';
  } else {
    bodyEl.innerHTML = pick(row.content).split(/\n{2,}/)
      .map(p => '<p>' + esc(p).replace(/\n/g, '<br>') + '</p>').join('');
  }

  // 북마크 버튼
  const bm = document.getElementById('modal-bookmark');
  const paintBm = on => {
    bm.setAttribute('aria-pressed', on ? 'true' : 'false');
    bm.textContent = on ? '★' : '☆';
  };
  paintBm(row.is_bookmarked);
  bm.onclick = async () => {
    const on = bm.getAttribute('aria-pressed') === 'true';
    try {
      if (on) await API.bookmarks.remove(row.id, state.session.user.id);
      else    await API.bookmarks.add(row.id, state.session.user.id);
      paintBm(!on);
      renderSidebar();
    } catch (e) { handleError(e); }
  };

  // ⋮ 메뉴
  const menuBtn = document.getElementById('modal-menu');
  const menu = document.getElementById('modal-menu-list');
  menu.innerHTML = row.is_mine
    ? '<li><button type="button" data-act="edit">'   + esc(t('modal.edit'))   + '</button></li>' +
      '<li><button type="button" data-act="delete">' + esc(t('modal.delete')) + '</button></li>'
    : '<li><button type="button" data-act="report">' + esc(t('modal.report')) + '</button></li>';
  menu.hidden = true;
  menuBtn.setAttribute('aria-expanded', 'false');
  menuBtn.onclick = () => {
    const open = menu.hidden;
    menu.hidden = !open;
    menuBtn.setAttribute('aria-expanded', String(open));
  };
  menu.querySelectorAll('button[data-act]').forEach(b => {
    b.addEventListener('click', async () => {
      menu.hidden = true;
      if (b.dataset.act === 'edit') { location.hash = '#/edit/' + row.record_code; return; }
      if (b.dataset.act === 'delete') {
        if (!confirm(t('form.confirm.delete'))) return;
        try {
          await API.records.remove(row.id);
          toast(t('form.deleted'));
          closeRecordModal(); renderSidebar();
        } catch (e) { handleError(e); }
        return;
      }
      if (b.dataset.act === 'report') openReportModal(row);
    });
  });

  // 관련 기록 (4.10) — 후보 0개면 섹션 자체를 숨긴다 (4.9(3))
  const rel = document.getElementById('modal-related');
  rel.hidden = true; rel.innerHTML = '';
  try {
    const list = await API.records.related(row.id, 5);
    if (list && list.length) {
      rel.hidden = false;
      rel.innerHTML = '<h3 class="side-title">' + esc(t('modal.related')) + '</h3>' +
        '<ul class="related-list">' + list.map(x =>
          '<li><a href="' + esc(recordPath(x)) + '">' + esc(pick(x.title)) + '</a>' +
          ' <span class="badge">LEVEL-' + x.level + '</span></li>').join('') + '</ul>';
    }
  } catch (_) { /* 관련 기록 실패는 본문 열람을 막지 않는다 */ }

  box.hidden = false;
  document.body.classList.add('drawer-open');
  box.querySelector('.modal-box').focus({ preventScroll: true });

  // 열람 기록 저장 + 등급 상승 확인 (4.3 / 4.11)
  try {
    await API.views.touch(row.id);
    const before = state.profile ? state.profile.level : 0;
    const p = await API.auth.myProfile();
    if (p) {
      state.profile = p;
      renderTopbar();
      if (p.level > before) levelBanner(t('level.up', { code: greek(p.level) }));
    }
    renderSidebar();
  } catch (_) {}
}

/* 모달에서 나가기.
   앱 안에서 카드를 눌러 들어온 경우에만 history.back() 을 쓴다.
   공유 링크로 곧바로 들어온 탭에서는 뒤로 갈 항목이 없어
   사이트 밖으로 나가 버리므로, 그때는 목록 주소로 직접 이동한다. */
function leaveModal() {
  if (state.route && state.route.name === 'record') {
    if (state.modal.pushed) { history.back(); return; }
    location.hash = routePath(state.route);
    return;
  }
  closeRecordModal();
}

function closeRecordModal() {
  const box = modalEl();
  if (box.hidden) return;
  box.hidden = true;
  document.getElementById('modal-menu-list').hidden = true;
  document.body.classList.remove('drawer-open');
  state.modal.record = null;

  // 원래 눌렀던 카드로 포커스를 되돌린다.
  // 목록이 다시 그려져 원래 노드가 사라졌으면 같은 기록 코드의 카드를 찾고,
  // 그것도 없으면 본문 영역으로 보낸다.
  let back = state.modal.lastFocus;
  if (!back || !document.contains(back) || !back.classList.contains('card')) {
    back = state.modal.fromCode
      ? document.querySelector('.card[data-code="' + CSS.escape(state.modal.fromCode) + '"]')
      : null;
  }
  (back && document.contains(back) ? back : document.getElementById('main')).focus();
}

/* 신고 모달 (2.14) */
function openReportModal(row) {
  state.reportTarget = row;
  const m = document.getElementById('modal-report');
  document.getElementById('rp-error').textContent = '';
  document.getElementById('form-report').reset();
  m.hidden = false;
  document.getElementById('rp-reason').focus();
}
function closeReportModal() {
  document.getElementById('modal-report').hidden = true;
  state.reportTarget = null;
}

/* ============================================================
 *  14. 기록 작성 / 수정 (2.11)
 * ============================================================ */
const FORM = { tags: [], activeLang: 'ko', text: {} };

function formFieldSet(id, labelKey, type, note) {
  return '<div class="field"><label for="' + id + '">' + esc(t(labelKey)) + ' ' +
    esc(t(note || 'form.required')) + '</label>' +
    (type === 'textarea'
      ? '<textarea id="' + id + '" rows="10"></textarea>'
      : '<input id="' + id + '" type="text">') + '</div>';
}

async function viewForm(mount, editing) {
  const seq = state.renderSeq;
  const isEdit = !!editing;
  mount.innerHTML = skeleton(1);

  const [planets, cats] = await Promise.all([API.catalog.planets(), API.catalog.categories()]);
  if (stale(seq)) return;
  state.planets = planets; state.categories = cats;

  let rec = null;
  if (isEdit) {
    rec = await API.records.byCode(editing);
    if (!rec.is_mine) { mount.innerHTML = emptyBox('err.forbidden', 'err.forbidden'); return; }
  }

  FORM.tags = rec ? (rec.tags || []).slice() : [];
  FORM.activeLang = 'ko';
  FORM.text = { ko: {}, en: {}, ja: {} };
  LANGS.forEach(l => {
    FORM.text[l] = {
      title:   rec && rec.title   ? (rec.title[l]   || '') : '',
      summary: rec && rec.summary ? (rec.summary[l] || '') : '',
      content: rec && rec.content ? (rec.content[l] || '') : ''
    };
  });

  const myLevel = state.profile ? state.profile.level : 1;
  const levelOpts = [1, 2, 3, 4, 5].filter(n => n <= myLevel)
    .map(n => '<option value="' + n + '"' + (rec && rec.level === n ? ' selected' : '') + '>LEVEL-' + n + '</option>')
    .join('');

  mount.innerHTML =
    '<form class="panel form-wide" id="record-form" novalidate>' +
    '<h2 class="panel-title">' + esc(t(isEdit ? 'form.edit' : 'form.new')) + '</h2>' +
    '<div class="form-row">' +
      '<div class="field"><label for="f-planet">' + esc(t('form.planet')) + '</label>' +
        '<select id="f-planet">' + planets.map(p =>
          '<option value="' + esc(p.id) + '"' + (rec && rec.planet_id === p.id ? ' selected' : '') +
          '>' + esc(pick(p.name)) + '</option>').join('') + '</select></div>' +
      '<div class="field"><label for="f-cat">' + esc(t('form.category')) + '</label>' +
        '<select id="f-cat">' + cats.map(c =>
          '<option value="' + esc(c.id) + '"' + (rec && rec.category_id === c.id ? ' selected' : '') +
          '>' + esc(pick(c.name)) + '</option>').join('') + '</select></div>' +
      '<div class="field"><label for="f-sub">' + esc(t('form.subcategory')) + '</label>' +
        '<select id="f-sub"></select></div>' +
    '</div>' +
    '<div class="field"><span class="langtabs" role="tablist" aria-label="' + esc(t('form.langtab')) + '">' +
      LANGS.map(l => '<button type="button" class="langtab" role="tab" data-l="' + l + '" ' +
        'aria-selected="' + (l === 'ko') + '">' + l.toUpperCase() +
        (l === 'ko' ? ' *' : '') + '</button>').join('') + '</span></div>' +
    formFieldSet('f-title', 'form.title', 'text') +
    formFieldSet('f-summary', 'form.summary', 'textarea') +
    formFieldSet('f-content', 'form.content', 'textarea') +
    '<div class="form-row-2">' +
      '<div class="field"><label for="f-date">' + esc(t('form.event')) + '</label>' +
        '<input id="f-date" type="date" value="' +
        esc(rec && /^\d{4}-\d{2}-\d{2}$/.test(rec.event_date || '') ? rec.event_date : '') + '"></div>' +
      '<div class="field"><label for="f-level">' + esc(t('form.level')) + '</label>' +
        '<select id="f-level">' + levelOpts + '</select></div>' +
    '</div>' +
    '<div class="field"><label for="f-tag">' + esc(t('form.tags')) + ' ' + esc(t('form.required')) +
      '</label><input id="f-tag" type="text" placeholder="' + esc(t('form.tags.ph')) + '">' +
      '<div class="taglist" id="f-taglist"></div></div>' +
    '<div class="field"><label for="f-source">' + esc(t('form.source')) + ' ' + esc(t('form.required')) +
      '</label><input id="f-source" type="text" value="' + esc(rec ? rec.source : '') + '"></div>' +
    '<p class="form-error" id="f-error" role="alert" aria-live="polite"></p>' +
    '<div class="panel-actions">' +
      '<button type="submit" class="btn btn-gold">' + esc(t(isEdit ? 'form.update' : 'form.submit')) + '</button>' +
      '<a class="btn btn-red" href="#/mine">' + esc(t('form.cancel')) + '</a>' +
    '</div></form>';

  const $ = id => mount.querySelector(id);
  const planetSel = $('#f-planet'), catSel = $('#f-cat'), subSel = $('#f-sub');

  async function refreshSubs(selected) {
    subSel.innerHTML = '';
    const subs = await API.catalog.subcategories(planetSel.value, catSel.value);
    if (!subs.length) {
      subSel.innerHTML = '<option value="">—</option>';
      return;
    }
    subSel.innerHTML = subs.map(s =>
      '<option value="' + esc(s.id) + '"' + (s.id === selected ? ' selected' : '') + '>' +
      esc(pick(s.name)) + '</option>').join('');
  }
  await refreshSubs(rec ? rec.subcategory_id : null);
  planetSel.addEventListener('change', () => refreshSubs());
  catSel.addEventListener('change', () => refreshSubs());

  /* 언어 탭 */
  const fields = { title: $('#f-title'), summary: $('#f-summary'), content: $('#f-content') };
  function loadLang(l) {
    FORM.activeLang = l;
    Object.keys(fields).forEach(k => { fields[k].value = FORM.text[l][k] || ''; });
    mount.querySelectorAll('.langtab').forEach(b =>
      b.setAttribute('aria-selected', String(b.dataset.l === l)));
  }
  function stashLang() {
    Object.keys(fields).forEach(k => { FORM.text[FORM.activeLang][k] = fields[k].value; });
  }
  mount.querySelectorAll('.langtab').forEach(b => {
    b.addEventListener('click', () => { stashLang(); loadLang(b.dataset.l); });
  });
  loadLang('ko');

  /* 태그 */
  const tagInput = $('#f-tag'), tagList = $('#f-taglist');
  function paintTags() {
    tagList.innerHTML = FORM.tags.map((x, i) =>
      '<span class="tagchip">#' + esc(x) +
      '<button type="button" data-i="' + i + '" aria-label="remove">✕</button></span>').join('');
    tagList.querySelectorAll('button[data-i]').forEach(b =>
      b.addEventListener('click', () => { FORM.tags.splice(Number(b.dataset.i), 1); paintTags(); }));
  }
  paintTags();
  tagInput.addEventListener('keydown', ev => {
    if (ev.key !== 'Enter') return;
    ev.preventDefault();
    const v = tagInput.value.trim().replace(/^#/, '');
    if (v && FORM.tags.length < 8 && !FORM.tags.includes(v)) FORM.tags.push(v);
    tagInput.value = '';
    paintTags();
  });

  /* 제출 */
  $('#record-form').addEventListener('submit', async ev => {
    ev.preventDefault();
    stashLang();
    const err = $('#f-error');
    err.textContent = '';

    const jsonOf = f => {
      const o = {};
      LANGS.forEach(l => { const v = (FORM.text[l][f] || '').trim(); if (v) o[l] = v; });
      return o;
    };
    const title = jsonOf('title'), summary = jsonOf('summary'), content = jsonOf('content');
    const date = $('#f-date').value.trim();
    const source = $('#f-source').value.trim();
    const level = Number($('#f-level').value);

    const fail = k => { err.textContent = t(k); return false; };
    if (!planetSel.value || !catSel.value || !subSel.value) return fail('form.err.path');
    if (!title.ko || title.ko.length > 100) return fail('form.err.title');
    if (!summary.ko || summary.ko.length > 300) return fail('form.err.summary');
    if (!content.ko) return fail('form.err.content');
    if (date && !/^\d{4}-\d{2}-\d{2}$/.test(date)) return fail('form.err.date');
    if (FORM.tags.length < 1 || FORM.tags.length > 8) return fail('form.err.tags');
    if (!source) return fail('form.err.source');
    if (level > (state.profile ? state.profile.level : 1)) return fail('form.err.level');

    const payload = {
      planet_id: planetSel.value, category_id: catSel.value, subcategory_id: subSel.value,
      title, summary, content,
      event_date: date || null, tags: FORM.tags, source, level
    };

    const btn = ev.target.querySelector('button[type="submit"]');
    btn.disabled = true;
    try {
      if (isEdit) await API.records.update(rec.id, payload);
      else        await API.records.create(payload);
      toast(t('form.saved'));
      state.list = { rows: [], offset: 0, done: false, key: '' };
      location.hash = '#/mine';
      renderSidebar();
    } catch (e) {
      err.textContent = errText(e);
      btn.disabled = false;
    }
  });
}

/* ============================================================
 *  15. 메인 렌더 루프
 * ============================================================ */
async function render() {
  const r = state.route;
  if (!r) return;
  newRender();

  if (PUBLIC_ROUTES.includes(r.name)) { showScreen('screen-' + r.name); return; }

  if (!state.session) { showScreen('screen-gate'); return; }

  showApp();
  renderTopbar();
  renderCrumbs(r);

  const mount = document.getElementById('main');
  mount.classList.remove('fade-in');
  void mount.offsetWidth;
  mount.classList.add('fade-in');

  try {
    if (!state.planets.length)      state.planets      = await API.catalog.planets();
    if (!state.categories.length)   state.categories   = await API.catalog.categories();
    if (!state.subcategories.length) state.subcategories = await API.catalog.subcategories();
    renderCrumbs(r);

    switch (r.name) {
      case 'planets':       await viewPlanets(mount); break;
      case 'categories':    await viewCategories(mount, r); break;
      case 'subcategories': await viewSubcategories(mount, r); break;
      case 'records':       await viewRecords(mount, r); break;
      case 'record':
        await viewRecords(mount, r);
        await openRecordModal(r.code, r);
        return;
      case 'bookmarks':     await viewBookmarks(mount); break;
      case 'mine':          await viewMine(mount); break;
      case 'new':           await viewForm(mount, null); break;
      case 'edit':          await viewForm(mount, r.code); break;
      case 'search':        await viewSearch(mount, r); break;
      case 'admin':         await viewAdmin(mount); break;
      default:              await viewPlanets(mount);
    }
    closeRecordModal();
  } catch (e) {
    await handleError(e, mount);
  }
}

/* ============================================================
 *  16. 라우팅 진입
 * ============================================================ */
async function onRouteChange() {
  const r = parseRoute();
  if (!r) { location.hash = '#/'; return; }               // 잘못된 해시 -> #/
  const prev = state.route;
  state.route = r;

  // 앱 안에서 이동해 들어온 기록 화면인지 기억한다 (leaveModal 이 사용)
  if (r.name === 'record') state.modal.pushed = !!prev;

  // 비로그인 상태로 내부 화면 접근 시 경고 화면으로 (실제 차단은 RLS)
  if (!state.session && !PUBLIC_ROUTES.includes(r.name)) {
    showScreen('screen-gate');
    return;
  }
  if (state.session && PUBLIC_ROUTES.includes(r.name) && r.name !== 'reset-confirm') {
    location.hash = '#/';
    return;
  }

  const samePath = prev && prev.planet === r.planet &&
                   prev.category === r.category && prev.sub === r.sub;

  // 모달만 닫히는 이동이면 목록을 다시 그리지 않는다
  if (prev && prev.name === 'record' && r.name === 'records' && samePath) {
    closeRecordModal();
    return;
  }

  // 이미 그려진 목록 위에서 모달만 여는 이동도 마찬가지.
  // 목록을 다시 그리면 방금 누른 카드가 사라져 포커스를 되돌릴 곳이 없어진다.
  if (prev && prev.name === 'records' && r.name === 'record' && samePath) {
    newRender();
    renderCrumbs(r);
    await openRecordModal(r.code, r);
    return;
  }
  await render();
}

/* ============================================================
 *  17. 인증 화면 이벤트
 * ============================================================ */
function bindAuthForms() {
  /* 로그인 */
  const lf = document.getElementById('form-login');
  lf.addEventListener('submit', async ev => {
    ev.preventDefault();
    const err = document.getElementById('login-error');
    const resendWrap = document.getElementById('login-resend-wrap');
    err.textContent = ''; resendWrap.hidden = true;
    const btn = lf.querySelector('button[type="submit"]');
    btn.disabled = true;
    try {
      await API.auth.signIn(lf.email.value.trim(), lf.password.value);
      // onAuthStateChange 가 이후를 처리
    } catch (e) {
      if (e.code === 'unverified') {
        err.textContent = t('login.unverified');
        resendWrap.hidden = false;
      } else if (e.code === 'network' || e.code === 'server' || e.code === 'config') {
        err.textContent = errText(e);
      } else {
        err.textContent = t('login.failed');       // 계정 존재 여부를 구분하지 않는다
      }
    } finally { btn.disabled = false; }
  });

  document.getElementById('login-resend').addEventListener('click', async () => {
    try {
      await API.auth.resend(lf.email.value.trim());
      toast(t('login.resent'));
    } catch (e) { toast(errText(e), true); }
  });

  /* 회원가입 */
  const sf = document.getElementById('form-signup');
  document.getElementById('su-lang').value = state.lang;
  sf.addEventListener('submit', async ev => {
    ev.preventDefault();
    const err = document.getElementById('signup-error');
    err.textContent = '';
    const email = sf.email.value.trim();
    const pw = sf.password.value, pw2 = sf.confirm.value;
    const name = sf.displayName.value.trim();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { err.textContent = t('signup.err.email'); return; }
    if (pw.length < 8)      { err.textContent = t('signup.err.password'); return; }
    if (pw !== pw2)         { err.textContent = t('signup.err.match'); return; }
    if (!name || name.length > 20) { err.textContent = t('signup.err.name'); return; }
    if (!sf.agree.checked)  { err.textContent = t('signup.err.agree'); return; }

    const btn = sf.querySelector('button[type="submit"]');
    btn.disabled = true;
    try {
      await API.auth.signUp({ email, password: pw, displayName: name, lang: sf.lang.value });
      location.hash = '#/signup-done';
    } catch (e) { err.textContent = errText(e); }
    finally { btn.disabled = false; }
  });

  /* 비밀번호 재설정 요청 */
  const rf = document.getElementById('form-reset');
  rf.addEventListener('submit', async ev => {
    ev.preventDefault();
    await API.auth.sendReset(rf.email.value.trim());
    document.getElementById('reset-note').textContent = t('reset.sent');   // 항상 같은 안내
  });

  /* 새 비밀번호 설정 */
  const rcf = document.getElementById('form-reset-confirm');
  rcf.addEventListener('submit', async ev => {
    ev.preventDefault();
    const err = document.getElementById('rc-error');
    err.textContent = '';
    if (rcf.password.value.length < 8) { err.textContent = t('signup.err.password'); return; }
    try {
      await API.auth.updatePassword(rcf.password.value);
      await API.auth.signOut();
      state.session = null; state.profile = null;
      toast(t('reset.new.done'));
      location.hash = '#/login';
    } catch (e) { err.textContent = errText(e); }
  });

  /* 신고 제출 */
  document.getElementById('form-report').addEventListener('submit', async ev => {
    ev.preventDefault();
    const row = state.reportTarget;
    if (!row) return;
    const err = document.getElementById('rp-error');
    err.textContent = '';
    try {
      await API.reports.add(row.id, state.session.user.id,
        document.getElementById('rp-reason').value,
        document.getElementById('rp-detail').value.trim());
      closeReportModal();
      toast(t('report.done'));
    } catch (e) {
      err.textContent = e.code === 'duplicate' ? t('report.dup') : errText(e);
    }
  });
}

/* ============================================================
 *  18. 전역 이벤트
 * ============================================================ */
function bindGlobal() {
  /* 언어 선택기 */
  document.querySelectorAll('[data-langpicker]').forEach(host => {
    host.appendChild(document.getElementById('tpl-langpicker').content.cloneNode(true));
  });
  document.addEventListener('click', ev => {
    const b = ev.target.closest('.lang-btn');
    if (b) setLang(b.dataset.lang);
  });

  /* 등급 상승 배너 닫기 */
  document.getElementById('level-banner-close').addEventListener('click', () => {
    document.getElementById('level-banner').hidden = true;
  });

  /* 로그아웃 */
  document.getElementById('btn-logout').addEventListener('click', async () => {
    await API.auth.signOut();
    state.session = null; state.profile = null;
    state.list = { rows: [], offset: 0, done: false, key: '' };
    document.getElementById('level-banner').hidden = true;
    location.hash = '#/';
    showScreen('screen-gate');
  });

  /* 햄버거 패널 (2.17) */
  const drawer = document.getElementById('drawer');
  const backdrop = document.getElementById('drawer-backdrop');
  const openDrawer = () => {
    drawer.hidden = false; backdrop.hidden = false;
    drawer.setAttribute('aria-hidden', 'false');
    document.getElementById('btn-drawer').setAttribute('aria-expanded', 'true');
    document.body.classList.add('drawer-open');
    document.getElementById('drawer-close').focus();
  };
  const closeDrawer = () => {
    drawer.hidden = true; backdrop.hidden = true;
    drawer.setAttribute('aria-hidden', 'true');
    document.getElementById('btn-drawer').setAttribute('aria-expanded', 'false');
    document.body.classList.remove('drawer-open');
  };
  document.getElementById('btn-drawer').addEventListener('click', openDrawer);
  document.getElementById('drawer-close').addEventListener('click', closeDrawer);
  backdrop.addEventListener('click', closeDrawer);
  drawer.addEventListener('click', ev => { if (ev.target.closest('a')) closeDrawer(); });

  /* 모달 닫기: X / 배경 클릭 */
  document.querySelectorAll('[data-close]').forEach(el => {
    el.addEventListener('click', () => {
      if (el.closest('#modal-report')) { closeReportModal(); return; }
      leaveModal();
    });
  });

  /* ESC: 모달 -> 신고 -> 드로어 순 */
  document.addEventListener('keydown', ev => {
    if (ev.key !== 'Escape') return;
    if (!document.getElementById('modal-report').hidden) { closeReportModal(); return; }
    if (!modalEl().hidden) { leaveModal(); return; }
    if (!drawer.hidden) closeDrawer();
  });

  /* 모달 포커스 트랩 */
  document.addEventListener('keydown', ev => {
    if (ev.key !== 'Tab') return;
    const open = [document.getElementById('modal-report'), modalEl()].find(m => !m.hidden);
    if (!open) return;
    const f = open.querySelectorAll(
      'a[href], button:not([disabled]), input, select, textarea, [tabindex]:not([tabindex="-1"])');
    const items = Array.from(f).filter(el => el.offsetParent !== null);
    if (!items.length) return;
    const first = items[0], last = items[items.length - 1];
    if (ev.shiftKey && document.activeElement === first) { ev.preventDefault(); last.focus(); }
    else if (!ev.shiftKey && document.activeElement === last) { ev.preventDefault(); first.focus(); }
  });

  window.addEventListener('hashchange', onRouteChange);
}

/* ============================================================
 *  19. 부팅
 * ============================================================ */
async function boot() {
  setLang(detectLang());
  const s = lsGet(LS.sort, 'event_desc');
  state.sort = SORT_KEYS.includes(s) ? s : 'event_desc';
  if (isMotionOff()) document.body.classList.add('no-motion');

  bindGlobal();
  bindAuthForms();
  applyI18n(document);
  setLang(state.lang);

  if (!window.AKASHIC_SB.configured) {
    showScreen('screen-gate');
    toast(t('err.config'), true);
    state.booting = false;
    return;
  }

  API.auth.onChange(async (event, session) => {
    if (event === 'PASSWORD_RECOVERY') {
      state.session = session;
      location.hash = '#/reset-confirm';
      showScreen('screen-reset-confirm');
      return;
    }
    const had = !!state.session;
    state.session = session || null;
    state.profile = session ? await API.auth.myProfile().catch(() => null) : null;
    if (state.booting) return;
    if (!had && session) {
      renderSidebar();
      if (location.hash.startsWith('#/login')) location.hash = '#/';
      else await render();
    } else if (had && !session) {
      showScreen('screen-gate');
    }
  });

  try {
    state.session = await API.auth.getSession();
    if (state.session) state.profile = await API.auth.myProfile().catch(() => null);
  } catch (_) { state.session = null; }

  state.booting = false;
  // state.route 는 onRouteChange 가 정한다.
  // 여기서 미리 채우면 첫 라우팅에서 prev 가 채워져,
  // 공유 링크로 곧바로 연 기록 화면을 "앱 안에서 이동해 들어온 것"으로 잘못 판단한다.
  if (state.session) renderSidebar();
  await onRouteChange();
}

document.addEventListener('DOMContentLoaded', boot);
})();
