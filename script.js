'use strict';

// ── 경고 화면 ──────────────────────────────────────────────
const warningScreen = document.getElementById('warning-screen');
const main          = document.getElementById('main');
const enterBtn      = document.getElementById('enter-btn');

function showMain() {
  warningScreen.classList.add('hidden');
  main.classList.remove('hidden');
}

if (localStorage.getItem('akashic-accepted') === '1') {
  showMain();
} else {
  enterBtn.addEventListener('click', () => {
    localStorage.setItem('akashic-accepted', '1');
    showMain();
  });
}

// ── 세션 ID 생성 (순수 장식용) ──────────────────────────────
const archiveSession = document.getElementById('archive-session');
if (archiveSession) {
  archiveSession.textContent = String(Math.floor(Math.random() * 10000)).padStart(4, '0');
}

// ── 유틸리티 ────────────────────────────────────────────────
const _escapeDiv = document.createElement('div');
function escapeHTML(str) {
  _escapeDiv.textContent = str;
  return _escapeDiv.innerHTML;
}

function getLevelClass(level) {
  if (!level) return '';
  return 'level-' + level.replace('LEVEL-', '');
}

function getLevelNum(level) {
  if (!level) return 0;
  return parseInt(level.replace('LEVEL-', ''), 10) || 0;
}

// ── 즐겨찾기 관리 ──────────────────────────────────────────
function getBookmarks() {
  try {
    return JSON.parse(localStorage.getItem('akashic-bookmarks') || '[]');
  } catch (e) {
    return [];
  }
}

function saveBookmarks(arr) {
  localStorage.setItem('akashic-bookmarks', JSON.stringify(arr));
}

function isBookmarked(recordId) {
  return getBookmarks().includes(recordId);
}

function toggleBookmark(recordId) {
  const bm = getBookmarks();
  const idx = bm.indexOf(recordId);
  if (idx >= 0) {
    bm.splice(idx, 1);
  } else {
    bm.push(recordId);
  }
  saveBookmarks(bm);
  return idx < 0; // true if now bookmarked
}

// ── 데이터 로드 ────────────────────────────────────────────
let allData = null;
let allRecordsFlat = [];

fetch('data.json')
  .then(r => r.json())
  .then(data => {
    allData = data;
    // 모든 기록을 flat 배열로
    allRecordsFlat = [];
    data.categories.forEach(cat => {
      cat.records.forEach(rec => {
        allRecordsFlat.push({ ...rec, categoryId: cat.id, categoryName: cat.name });
      });
    });
    initAllPages(data);
  });

// ── 페이지 초기화 ──────────────────────────────────────────
function initAllPages(data) {
  // 데이터베이스 페이지
  buildSidebar(data.categories);
  updateStats(data);
  // 대시보드
  buildDashboard(data);
  // 타임라인
  buildTimeline();
  // 은하 지도
  buildGalaxyMap(data);
  // 즐겨찾기
  renderBookmarks();
}

// ── 네비게이션 ─────────────────────────────────────────────
const navBtns = document.querySelectorAll('.nav-btn');
const pages   = document.querySelectorAll('.page-content');

navBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    const pageId = btn.dataset.page;
    navigateTo(pageId);
  });
});

function navigateTo(pageId) {
  navBtns.forEach(b => b.classList.remove('active'));
  pages.forEach(p => p.classList.add('hidden'));
  const targetBtn = document.querySelector('.nav-btn[data-page="' + pageId + '"]');
  const targetPage = document.getElementById('page-' + pageId);
  if (targetBtn) targetBtn.classList.add('active');
  if (targetPage) targetPage.classList.remove('hidden');

  // 즐겨찾기 페이지 열 때 갱신
  if (pageId === 'bookmarks') renderBookmarks();
  window.scrollTo(0, 0);
}

// ── 검색 ───────────────────────────────────────────────────
const searchInput = document.getElementById('search-input');

searchInput.addEventListener('input', () => {
  const q = searchInput.value.trim().toLowerCase();
  if (!q || !allData) return;

  // 데이터베이스 페이지로 이동
  navigateTo('database');

  const results = [];
  allData.categories.forEach(cat => {
    cat.records.forEach(rec => {
      const matchTitle = rec.title.toLowerCase().includes(q);
      const matchSummary = rec.summary.toLowerCase().includes(q);
      const matchTags = rec.tags && rec.tags.some(t => t.toLowerCase().includes(q));
      const matchBody = rec.body.toLowerCase().includes(q);
      if (matchTitle || matchSummary || matchTags || matchBody) {
        results.push(rec);
      }
    });
  });

  currentCategory = null;
  currentLevelFilter = 'all';
  document.querySelectorAll('#category-list li').forEach(el => el.classList.remove('active'));
  document.querySelectorAll('.filter-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.level === 'all');
  });

  placeholder.classList.add('hidden');
  renderRecords(results);
});

searchInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    e.preventDefault();
    searchInput.dispatchEvent(new Event('input'));
  }
});

// ══════════════════════════════════════════════════════════
// ██ 대시보드 페이지
// ══════════════════════════════════════════════════════════
function buildDashboard(data) {
  const totalRecords = allRecordsFlat.length;
  const totalCategories = data.categories.length;
  const classifiedCount = allRecordsFlat.filter(r => getLevelNum(r.level) >= 4).length;
  const bookmarkCount = getBookmarks().length;

  document.getElementById('dash-total').textContent = totalRecords;
  document.getElementById('dash-categories').textContent = totalCategories;
  document.getElementById('dash-classified').textContent = classifiedCount;
  document.getElementById('dash-bookmarks').textContent = bookmarkCount;

  // 보안등급 분포 차트
  buildLevelChart();

  // 카테고리 요약
  buildCategoryOverview(data);

  // 최고 기밀 기록
  buildTopSecretList();

  // 랜덤 기록
  document.getElementById('random-record-btn').addEventListener('click', showRandomRecord);
}

function buildLevelChart() {
  const chart = document.getElementById('level-chart');
  chart.innerHTML = '';
  const counts = [0, 0, 0, 0, 0];
  allRecordsFlat.forEach(r => {
    const n = getLevelNum(r.level);
    if (n >= 1 && n <= 5) counts[n - 1]++;
  });
  const max = Math.max(...counts, 1);

  for (let i = 0; i < 5; i++) {
    const row = document.createElement('div');
    row.className = 'chart-row';

    const label = document.createElement('span');
    label.className = 'chart-label level-' + (i + 1);
    label.textContent = 'LV-' + (i + 1);

    const barWrap = document.createElement('div');
    barWrap.className = 'chart-bar-wrap';

    const bar = document.createElement('div');
    bar.className = 'chart-bar level-' + (i + 1) + '-bg';
    bar.style.width = (counts[i] / max * 100) + '%';

    const count = document.createElement('span');
    count.className = 'chart-count';
    count.textContent = counts[i] + '건';

    barWrap.appendChild(bar);
    row.appendChild(label);
    row.appendChild(barWrap);
    row.appendChild(count);
    chart.appendChild(row);
  }
}

function buildCategoryOverview(data) {
  const container = document.getElementById('category-overview');
  container.innerHTML = '';
  const icons = {
    planets: '🪐', factions: '⚔', characters: '👤',
    artifacts: '🔮', technology: '⚙', events: '📋',
    theories: '🧪', locations: '📍'
  };
  data.categories.forEach(cat => {
    const card = document.createElement('div');
    card.className = 'cat-overview-card';
    card.innerHTML =
      '<div class="cat-icon">' + (icons[cat.id] || '◈') + '</div>' +
      '<div class="cat-info">' +
        '<h4>' + escapeHTML(cat.name) + '</h4>' +
        '<span>' + cat.records.length + '건</span>' +
      '</div>';
    card.addEventListener('click', () => {
      navigateTo('database');
      const li = document.querySelector('#category-list li[data-id="' + cat.id + '"]');
      if (li) selectCategory(cat, li);
    });
    container.appendChild(card);
  });
}

function buildTopSecretList() {
  const container = document.getElementById('top-secret-list');
  container.innerHTML = '';
  const topSecret = allRecordsFlat
    .filter(r => getLevelNum(r.level) >= 4)
    .sort((a, b) => getLevelNum(b.level) - getLevelNum(a.level))
    .slice(0, 6);
  topSecret.forEach(rec => {
    container.appendChild(createRecordCard(rec));
  });
}

function showRandomRecord() {
  if (!allRecordsFlat.length) return;
  const rand = allRecordsFlat[Math.floor(Math.random() * allRecordsFlat.length)];
  const area = document.getElementById('random-record-area');
  area.innerHTML = '';
  area.appendChild(createRecordCard(rand));
}

// ══════════════════════════════════════════════════════════
// ██ 데이터베이스 페이지
// ══════════════════════════════════════════════════════════

// ── 통계 업데이트 ──────────────────────────────────────────
function updateStats(data) {
  const totalRecords = data.categories.reduce((sum, cat) => sum + cat.records.length, 0);
  const statTotal = document.getElementById('stat-total');
  const statCategories = document.getElementById('stat-categories');
  if (statTotal) statTotal.textContent = totalRecords;
  if (statCategories) statCategories.textContent = data.categories.length;
}

// ── 사이드바 ───────────────────────────────────────────────
const categoryList = document.getElementById('category-list');
const recordList   = document.getElementById('record-list');
const placeholder  = document.getElementById('placeholder');

function buildSidebar(categories) {
  categories.forEach(cat => {
    const li = document.createElement('li');
    li.textContent = cat.name + ' (' + cat.records.length + ')';
    li.dataset.id  = cat.id;
    li.addEventListener('click', () => selectCategory(cat, li));
    categoryList.appendChild(li);
  });
}

let currentCategory = null;
let currentLevelFilter = 'all';

function selectCategory(cat, li) {
  document.querySelectorAll('#category-list li').forEach(el => el.classList.remove('active'));
  li.classList.add('active');
  currentCategory = cat;
  applyFilters();
}

// ── 보안등급 필터 ──────────────────────────────────────────
const filterBtns = document.querySelectorAll('.filter-btn');
filterBtns.forEach(btn => {
  btn.addEventListener('click', () => {
    filterBtns.forEach(b => b.classList.remove('active'));
    btn.classList.add('active');
    currentLevelFilter = btn.dataset.level;
    applyFilters();
  });
});

function applyFilters() {
  if (!currentCategory && currentLevelFilter === 'all') {
    placeholder.classList.remove('hidden');
    recordList.innerHTML = '';
    return;
  }

  let records = currentCategory ? currentCategory.records : allRecordsFlat;

  if (currentLevelFilter !== 'all') {
    records = records.filter(r => getLevelNum(r.level) === parseInt(currentLevelFilter, 10));
  }

  placeholder.classList.add('hidden');
  renderRecords(records);
}

// ── 레코드 카드 생성 ────────────────────────────────────────
function createRecordCard(rec) {
  const card = document.createElement('div');
  card.className = 'record-card';

  const bookmarked = isBookmarked(rec.id);
  const bmClass = bookmarked ? ' bookmarked' : '';

  let headerHTML = '<div class="card-header"><h3>' + escapeHTML(rec.title) + '</h3>';
  if (rec.level) {
    headerHTML += '<span class="card-level ' + getLevelClass(rec.level) + '">' + escapeHTML(rec.level) + '</span>';
  }
  headerHTML += '</div>';

  let tagsHTML = '';
  if (rec.tags && rec.tags.length > 0) {
    tagsHTML = '<div class="card-tags">' + rec.tags.map(t => '<span>#' + escapeHTML(t) + '</span>').join('') + '</div>';
  }

  let dateHTML = '';
  if (rec.date) {
    dateHTML = '<div class="card-date">' + escapeHTML(rec.date) + '</div>';
  }

  const catLabel = rec.categoryName ? '<div class="card-category">' + escapeHTML(rec.categoryName) + '</div>' : '';

  card.innerHTML = headerHTML +
    '<p>' + escapeHTML(rec.summary) + '</p>' +
    tagsHTML + dateHTML + catLabel +
    '<span class="card-bookmark' + bmClass + '" title="즐겨찾기">★</span>';

  // 즐겨찾기 버튼
  const bmBtn = card.querySelector('.card-bookmark');
  if (bmBtn) {
    bmBtn.addEventListener('click', (e) => {
      e.stopPropagation();
      const nowBM = toggleBookmark(rec.id);
      bmBtn.classList.toggle('bookmarked', nowBM);
      updateDashboardBookmarkCount();
    });
  }

  card.addEventListener('click', () => openModal(rec));
  return card;
}

function renderRecords(records) {
  placeholder.classList.add('hidden');
  recordList.innerHTML = '';
  if (records.length === 0) {
    recordList.innerHTML = '<p class="no-results">해당하는 기록이 없습니다.</p>';
    return;
  }
  records.forEach(rec => {
    recordList.appendChild(createRecordCard(rec));
  });
}

function updateDashboardBookmarkCount() {
  const el = document.getElementById('dash-bookmarks');
  if (el) el.textContent = getBookmarks().length;
}

// ══════════════════════════════════════════════════════════
// ██ 타임라인 페이지
// ══════════════════════════════════════════════════════════
function buildTimeline() {
  const container = document.getElementById('timeline-container');
  container.innerHTML = '';

  // 연도 추출 및 정렬
  const dated = allRecordsFlat.map(rec => {
    let year = null;
    const match = rec.date ? rec.date.match(/(\d{4})/) : null;
    if (match) year = parseInt(match[1], 10);
    return { ...rec, year };
  });

  // 연도 있는 기록만 정렬
  const withYear = dated.filter(r => r.year !== null).sort((a, b) => a.year - b.year);
  const withoutYear = dated.filter(r => r.year === null);

  // 타임라인 렌더링
  withYear.forEach((rec, i) => {
    const item = document.createElement('div');
    item.className = 'timeline-item' + (i % 2 === 0 ? ' left' : ' right');

    item.innerHTML =
      '<div class="timeline-dot ' + getLevelClass(rec.level) + '-bg"></div>' +
      '<div class="timeline-card">' +
        '<div class="timeline-year">' + escapeHTML(rec.date) + '</div>' +
        '<h3>' + escapeHTML(rec.title) + '</h3>' +
        '<span class="card-level ' + getLevelClass(rec.level) + '">' + escapeHTML(rec.level) + '</span>' +
        '<p>' + escapeHTML(rec.summary) + '</p>' +
        '<div class="timeline-category">' + escapeHTML(rec.categoryName) + '</div>' +
      '</div>';

    item.addEventListener('click', () => openModal(rec));
    container.appendChild(item);
  });

  // 불명 기록
  if (withoutYear.length > 0) {
    const divider = document.createElement('div');
    divider.className = 'timeline-divider';
    divider.innerHTML = '<span>— 시기 불명 —</span>';
    container.appendChild(divider);

    withoutYear.forEach((rec, i) => {
      const item = document.createElement('div');
      item.className = 'timeline-item' + (i % 2 === 0 ? ' left' : ' right');
      item.innerHTML =
        '<div class="timeline-dot ' + getLevelClass(rec.level) + '-bg"></div>' +
        '<div class="timeline-card">' +
          '<div class="timeline-year">' + escapeHTML(rec.date) + '</div>' +
          '<h3>' + escapeHTML(rec.title) + '</h3>' +
          '<span class="card-level ' + getLevelClass(rec.level) + '">' + escapeHTML(rec.level) + '</span>' +
          '<p>' + escapeHTML(rec.summary) + '</p>' +
          '<div class="timeline-category">' + escapeHTML(rec.categoryName) + '</div>' +
        '</div>';
      item.addEventListener('click', () => openModal(rec));
      container.appendChild(item);
    });
  }
}

// ══════════════════════════════════════════════════════════
// ██ 은하 지도 페이지
// ══════════════════════════════════════════════════════════
function buildGalaxyMap(data) {
  const mapContainer = document.getElementById('galaxy-map');

  // 행성과 장소 데이터 추출
  const planetsCat = data.categories.find(c => c.id === 'planets');
  const locationsCat = data.categories.find(c => c.id === 'locations');

  const nodes = [];
  if (planetsCat) {
    planetsCat.records.forEach((rec, i) => {
      nodes.push({ ...rec, type: 'planet', categoryName: '행성' });
    });
  }
  if (locationsCat) {
    locationsCat.records.forEach((rec, i) => {
      nodes.push({ ...rec, type: 'location', categoryName: '장소' });
    });
  }

  // 배치: 원형으로 행성들, 안쪽에 장소들 배치
  const mapRect = { width: 600, height: 500 };
  const centerX = mapRect.width / 2;
  const centerY = mapRect.height / 2;

  nodes.forEach((node, i) => {
    const el = document.createElement('div');
    el.className = 'galaxy-node ' + (node.type === 'planet' ? 'node-planet' : 'node-location');
    el.innerHTML = '<span class="node-label">' + escapeHTML(node.title) + '</span>' +
                   '<span class="node-dot ' + getLevelClass(node.level) + '-bg"></span>';

    // 배치 계산
    let angle, radius;
    if (node.type === 'planet') {
      const planetIdx = nodes.filter(n => n.type === 'planet').indexOf(node);
      const planetCount = nodes.filter(n => n.type === 'planet').length;
      angle = (planetIdx / planetCount) * Math.PI * 2 - Math.PI / 2;
      radius = 180;
    } else {
      const locIdx = nodes.filter(n => n.type === 'location').indexOf(node);
      const locCount = nodes.filter(n => n.type === 'location').length;
      angle = (locIdx / locCount) * Math.PI * 2 - Math.PI / 4;
      radius = 100;
    }

    const x = centerX + Math.cos(angle) * radius;
    const y = centerY + Math.sin(angle) * radius;
    el.style.left = x + 'px';
    el.style.top = y + 'px';

    el.addEventListener('click', () => {
      document.querySelectorAll('.galaxy-node').forEach(n => n.classList.remove('selected'));
      el.classList.add('selected');
      showGalaxyInfo(node);
    });

    mapContainer.appendChild(el);
  });
}

function showGalaxyInfo(rec) {
  document.getElementById('galaxy-info-title').textContent = rec.title;

  let html = '';
  html += '<div class="galaxy-detail">';
  html += '<span class="card-level ' + getLevelClass(rec.level) + '">' + escapeHTML(rec.level) + '</span>';
  html += '<span class="galaxy-type">' + (rec.type === 'planet' ? '🪐 행성' : '📍 장소') + '</span>';
  html += '</div>';
  html += '<p class="galaxy-summary">' + escapeHTML(rec.summary) + '</p>';
  html += '<p class="galaxy-body">' + escapeHTML(rec.body) + '</p>';
  if (rec.date) html += '<div class="galaxy-date">기록일: ' + escapeHTML(rec.date) + '</div>';
  if (rec.tags && rec.tags.length) {
    html += '<div class="galaxy-tags">' + rec.tags.map(t => '<span>#' + escapeHTML(t) + '</span>').join('') + '</div>';
  }
  html += '<button class="action-btn galaxy-open-btn" onclick="openModal(window._galaxyCurrentRec)">상세 보기 ▸</button>';

  window._galaxyCurrentRec = rec;
  document.getElementById('galaxy-info-body').innerHTML = html;
}

// ══════════════════════════════════════════════════════════
// ██ 즐겨찾기 페이지
// ══════════════════════════════════════════════════════════
function renderBookmarks() {
  const list = document.getElementById('bookmarks-list');
  const empty = document.getElementById('bookmarks-empty');
  const bm = getBookmarks();

  if (!allRecordsFlat.length) return;

  const bookmarkedRecords = allRecordsFlat.filter(r => bm.includes(r.id));

  if (bookmarkedRecords.length === 0) {
    empty.classList.remove('hidden');
    list.innerHTML = '';
  } else {
    empty.classList.add('hidden');
    list.innerHTML = '';
    bookmarkedRecords.forEach(rec => {
      list.appendChild(createRecordCard(rec));
    });
  }

  updateDashboardBookmarkCount();
}

// ══════════════════════════════════════════════════════════
// ██ 모달
// ══════════════════════════════════════════════════════════
const modal       = document.getElementById('modal');
const modalTitle  = document.getElementById('modal-title');
const modalBody   = document.getElementById('modal-body');
const modalMeta   = document.getElementById('modal-meta');
const modalTags   = document.getElementById('modal-tags');
const modalClose  = document.getElementById('modal-close');
const modalBookmark = document.getElementById('modal-bookmark');
const modalRelatedList = document.getElementById('modal-related-list');

let currentModalRec = null;

function openModal(rec) {
  currentModalRec = rec;
  modalTitle.textContent = rec.title;
  modalBody.innerHTML    = '<p>' + escapeHTML(rec.body) + '</p>';

  // 메타 정보
  modalMeta.innerHTML = '';
  if (rec.level) {
    modalMeta.innerHTML += '<div class="meta-item"><span class="meta-label">보안등급:</span> <span class="' + getLevelClass(rec.level) + '">' + escapeHTML(rec.level) + '</span></div>';
  }
  if (rec.date) {
    modalMeta.innerHTML += '<div class="meta-item"><span class="meta-label">기록일:</span> ' + escapeHTML(rec.date) + '</div>';
  }
  if (rec.categoryName) {
    modalMeta.innerHTML += '<div class="meta-item"><span class="meta-label">분류:</span> ' + escapeHTML(rec.categoryName) + '</div>';
  }

  // 태그
  modalTags.innerHTML = '';
  if (rec.tags && rec.tags.length > 0) {
    rec.tags.forEach(t => {
      const span = document.createElement('span');
      span.textContent = '#' + t;
      modalTags.appendChild(span);
    });
  }

  // 즐겨찾기 상태
  updateModalBookmarkBtn();

  // 연관 기록
  buildRelatedRecords(rec);

  modal.classList.remove('hidden');
}

function updateModalBookmarkBtn() {
  if (!currentModalRec) return;
  const bm = isBookmarked(currentModalRec.id);
  modalBookmark.textContent = bm ? '★' : '☆';
  modalBookmark.classList.toggle('bookmarked', bm);
}

modalBookmark.addEventListener('click', () => {
  if (!currentModalRec) return;
  toggleBookmark(currentModalRec.id);
  updateModalBookmarkBtn();
  updateDashboardBookmarkCount();
});

function buildRelatedRecords(rec) {
  modalRelatedList.innerHTML = '';
  if (!rec.tags || rec.tags.length === 0) {
    modalRelatedList.innerHTML = '<p class="no-related">연관 기록이 없습니다.</p>';
    return;
  }

  const related = allRecordsFlat.filter(r =>
    r.id !== rec.id &&
    r.tags && r.tags.some(t => rec.tags.includes(t))
  ).slice(0, 4);

  if (related.length === 0) {
    modalRelatedList.innerHTML = '<p class="no-related">연관 기록이 없습니다.</p>';
    return;
  }

  related.forEach(r => {
    const item = document.createElement('div');
    item.className = 'related-item';
    item.innerHTML =
      '<span class="card-level ' + getLevelClass(r.level) + '">' + escapeHTML(r.level) + '</span> ' +
      '<span class="related-title">' + escapeHTML(r.title) + '</span>' +
      '<span class="related-cat">' + escapeHTML(r.categoryName || '') + '</span>';
    item.addEventListener('click', () => openModal(r));
    modalRelatedList.appendChild(item);
  });
}

modalClose.addEventListener('click', () => modal.classList.add('hidden'));
modal.addEventListener('click', e => { if (e.target === modal) modal.classList.add('hidden'); });
document.addEventListener('keydown', e => { if (e.key === 'Escape') modal.classList.add('hidden'); });
