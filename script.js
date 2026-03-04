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

// ── 데이터 로드 ────────────────────────────────────────────
let allData = null;

fetch('data.json')
  .then(r => r.json())
  .then(data => {
    allData = data;
    buildSidebar(data.categories);
    updateStats(data);
  });

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
const toolbar = document.getElementById('toolbar');
const sortSelect = document.getElementById('sort-select');
const filterLevel = document.getElementById('filter-level');

function selectCategory(cat, li) {
  document.querySelectorAll('#category-list li').forEach(el => el.classList.remove('active'));
  li.classList.add('active');
  currentCategory = cat;
  updateBreadcrumb(cat.name);
  sortSelect.value = 'default';
  filterLevel.value = 'all';
  toolbar.classList.remove('hidden');
  renderRecords(cat.records);
}

// ── 브레드크럼 ─────────────────────────────────────────────
const breadcrumb = document.getElementById('breadcrumb');

function updateBreadcrumb(categoryName) {
  breadcrumb.innerHTML = '';

  const homeSpan = document.createElement('span');
  homeSpan.className = 'crumb';
  homeSpan.textContent = 'HOME';
  homeSpan.addEventListener('click', () => {
    currentCategory = null;
    document.querySelectorAll('#category-list li').forEach(el => el.classList.remove('active'));
    placeholder.classList.remove('hidden');
    recordList.innerHTML = '';
    breadcrumb.innerHTML = '';
    breadcrumb.appendChild(homeSpan);
  });
  breadcrumb.appendChild(homeSpan);

  if (categoryName) {
    const sep = document.createElement('span');
    sep.className = 'crumb-separator';
    sep.textContent = '»';
    breadcrumb.appendChild(sep);

    const catSpan = document.createElement('span');
    catSpan.className = 'crumb-current';
    catSpan.textContent = categoryName;
    breadcrumb.appendChild(catSpan);
  }
}

// ── 레코드 목록 ────────────────────────────────────────────
function getLevelClass(level) {
  if (!level) return '';
  const num = level.replace('LEVEL-', '');
  return 'level-' + num;
}

function renderRecords(records) {
  placeholder.classList.add('hidden');
  recordList.innerHTML = '';
  records.forEach(rec => {
    const card = document.createElement('div');
    card.className = 'record-card';

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

    card.innerHTML = headerHTML + '<p>' + escapeHTML(rec.summary) + '</p>' + tagsHTML + dateHTML;
    card.addEventListener('click', () => openModal(rec));
    recordList.appendChild(card);
  });
}

const _escapeDiv = document.createElement('div');
function escapeHTML(str) {
  _escapeDiv.textContent = str;
  return _escapeDiv.innerHTML;
}

// ── 검색 ───────────────────────────────────────────────────
const searchInput = document.getElementById('search-input');

searchInput.addEventListener('input', () => {
  const q = searchInput.value.trim().toLowerCase();
  if (!q || !allData) return;

  const results = [];
  allData.categories.forEach(cat => {
    cat.records.forEach(rec => {
      const matchTitle = rec.title.toLowerCase().includes(q);
      const matchSummary = rec.summary.toLowerCase().includes(q);
      const matchTags = rec.tags && rec.tags.some(t => t.toLowerCase().includes(q));
      if (matchTitle || matchSummary || matchTags) {
        results.push(rec);
      }
    });
  });

  currentCategory = null;
  document.querySelectorAll('#category-list li').forEach(el => el.classList.remove('active'));

  breadcrumb.innerHTML = '';
  const homeSpan = document.createElement('span');
  homeSpan.className = 'crumb';
  homeSpan.textContent = 'HOME';
  breadcrumb.appendChild(homeSpan);
  const sep = document.createElement('span');
  sep.className = 'crumb-separator';
  sep.textContent = '»';
  breadcrumb.appendChild(sep);
  const searchSpan = document.createElement('span');
  searchSpan.className = 'crumb-current';
  searchSpan.textContent = '검색: "' + q + '" (' + results.length + '건)';
  breadcrumb.appendChild(searchSpan);

  placeholder.classList.add('hidden');
  renderRecords(results);
});

// ── 모달 ───────────────────────────────────────────────────
const modal      = document.getElementById('modal');
const modalTitle = document.getElementById('modal-title');
const modalBody  = document.getElementById('modal-body');
const modalMeta  = document.getElementById('modal-meta');
const modalTags  = document.getElementById('modal-tags');
const modalClose = document.getElementById('modal-close');

function openModal(rec) {
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

  // 태그
  modalTags.innerHTML = '';
  if (rec.tags && rec.tags.length > 0) {
    rec.tags.forEach(t => {
      const span = document.createElement('span');
      span.textContent = '#' + t;
      modalTags.appendChild(span);
    });
  }

  // 관련 기록
  const modalRelated = document.getElementById('modal-related');
  modalRelated.innerHTML = '';
  if (rec.related && rec.related.length > 0) {
    const heading = document.createElement('h4');
    heading.textContent = '관련 기록';
    modalRelated.appendChild(heading);
    const list = document.createElement('div');
    list.className = 'related-list';
    rec.related.forEach(id => {
      const found = findRecordById(id);
      if (found) {
        const link = document.createElement('span');
        link.className = 'related-link';
        link.textContent = found.title;
        link.addEventListener('click', () => openModal(found));
        list.appendChild(link);
      }
    });
    modalRelated.appendChild(list);
  }

  modal.classList.remove('hidden');
}

modalClose.addEventListener('click', () => modal.classList.add('hidden'));
modal.addEventListener('click', e => { if (e.target === modal) modal.classList.add('hidden'); });
document.addEventListener('keydown', e => { if (e.key === 'Escape') modal.classList.add('hidden'); });

// ── 레코드 검색 함수 ───────────────────────────────────────
function findRecordById(id) {
  if (!allData) return null;
  for (const cat of allData.categories) {
    for (const rec of cat.records) {
      if (rec.id === id) return rec;
    }
  }
  return null;
}

// ── 정렬/필터 ──────────────────────────────────────────────
function getFilteredSortedRecords(records) {
  let result = records.slice();
  const levelFilter = filterLevel.value;
  if (levelFilter !== 'all') {
    result = result.filter(r => r.level === levelFilter);
  }
  const sortBy = sortSelect.value;
  if (sortBy === 'title') {
    result.sort((a, b) => a.title.localeCompare(b.title, 'ko'));
  } else if (sortBy === 'level') {
    result.sort((a, b) => {
      const la = a.level ? parseInt(a.level.replace('LEVEL-', ''), 10) : 0;
      const lb = b.level ? parseInt(b.level.replace('LEVEL-', ''), 10) : 0;
      return la - lb;
    });
  } else if (sortBy === 'date') {
    result.sort((a, b) => {
      const da = a.date || '';
      const db = b.date || '';
      return da.localeCompare(db, 'ko');
    });
  }
  return result;
}

sortSelect.addEventListener('change', () => {
  if (currentCategory) renderRecords(getFilteredSortedRecords(currentCategory.records));
});

filterLevel.addEventListener('change', () => {
  if (currentCategory) renderRecords(getFilteredSortedRecords(currentCategory.records));
});

// ── 무작위 기록 ────────────────────────────────────────────
const randomBtn = document.getElementById('random-btn');
randomBtn.addEventListener('click', () => {
  if (!allData) return;
  const allRecords = [];
  allData.categories.forEach(cat => {
    cat.records.forEach(rec => allRecords.push(rec));
  });
  if (allRecords.length === 0) return;
  const idx = Math.floor(Math.random() * allRecords.length);
  openModal(allRecords[idx]);
});
