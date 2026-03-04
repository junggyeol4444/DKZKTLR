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

// ── 데이터 로드 ────────────────────────────────────────────
let allData = null;

fetch('data.json')
  .then(r => r.json())
  .then(data => {
    allData = data;
    buildSidebar(data.categories);
  });

// ── 사이드바 ───────────────────────────────────────────────
const categoryList = document.getElementById('category-list');
const recordList   = document.getElementById('record-list');
const placeholder  = document.getElementById('placeholder');

function buildSidebar(categories) {
  categories.forEach(cat => {
    const li = document.createElement('li');
    li.textContent = cat.name;
    li.dataset.id  = cat.id;
    li.addEventListener('click', () => selectCategory(cat, li));
    categoryList.appendChild(li);
  });
}

function selectCategory(cat, li) {
  document.querySelectorAll('#category-list li').forEach(el => el.classList.remove('active'));
  li.classList.add('active');
  renderRecords(cat.records);
}

// ── 레코드 목록 ────────────────────────────────────────────
function renderRecords(records) {
  placeholder.classList.add('hidden');
  recordList.innerHTML = '';
  records.forEach(rec => {
    const card = document.createElement('div');
    card.className = 'record-card';
    card.innerHTML = `<h3>${rec.title}</h3><p>${rec.summary}</p>`;
    card.addEventListener('click', () => openModal(rec));
    recordList.appendChild(card);
  });
}

// ── 검색 ───────────────────────────────────────────────────
const searchInput = document.getElementById('search-input');

searchInput.addEventListener('input', () => {
  const q = searchInput.value.trim().toLowerCase();
  if (!q || !allData) return;

  const results = [];
  allData.categories.forEach(cat => {
    cat.records.forEach(rec => {
      if (rec.title.toLowerCase().includes(q) || rec.summary.toLowerCase().includes(q)) {
        results.push(rec);
      }
    });
  });

  document.querySelectorAll('#category-list li').forEach(el => el.classList.remove('active'));
  placeholder.classList.add('hidden');
  renderRecords(results);
});

// ── 모달 ───────────────────────────────────────────────────
const modal      = document.getElementById('modal');
const modalTitle = document.getElementById('modal-title');
const modalBody  = document.getElementById('modal-body');
const modalClose = document.getElementById('modal-close');

function openModal(rec) {
  modalTitle.textContent = rec.title;
  modalBody.innerHTML    = `<p>${rec.body}</p>`;
  modal.classList.remove('hidden');
}

modalClose.addEventListener('click', () => modal.classList.add('hidden'));
modal.addEventListener('click', e => { if (e.target === modal) modal.classList.add('hidden'); });
document.addEventListener('keydown', e => { if (e.key === 'Escape') modal.classList.add('hidden'); });
