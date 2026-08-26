/* 페이지네이션 · 언어 탭 · 폼 상한 · 신고 UI · 세션 만료 · 드로어 */
const L = require('./lib');
const { BASE, sql, newCtx, open, signup, login, confirmEmail: confirm, setLang } = L;
const { check, summary } = L.reporter();

(async()=>{
const browser=await L.launch();
const ctx=await newCtx(browser); const page=await open(ctx);
await signup(page,'pg@test.io','passphrase5','Pager'); await confirm('pg@test.io');
await login(page,'pg@test.io','passphrase5');
await page.click('#app .lang-btn[data-lang="ko"]'); await page.waitForTimeout(500);

/* 페이지네이션을 보려면 한 중분류에 20건을 넘겨야 한다.
   시드에는 그런 중분류가 없으므로 여기서 25건을 채운다. */
sql(`insert into public.records
       (planet_id,category_id,subcategory_id,title,summary,content,
        event_date,tags,source,level,is_seed,author_id)
     select 'TERRA-001','ART-007','LITERATURE',
            jsonb_build_object('ko','대량 기록 '||lpad(g::text,2,'0'),'en','Bulk '||lpad(g::text,2,'0')),
            jsonb_build_object('ko','요약 '||g), jsonb_build_object('ko','본문 '||g),
            make_date(1900+g,1,1), array['벌크'],'테스트 출처',1,true,
            (select id from public.profiles where keeper_code='KEEPER-000')
       from generate_series(1,25) g
      where not exists (select 1 from public.records where tags @> array['벌크'])`);

/* ---------- 페이지네이션 (2.9) ---------- */
await page.evaluate(()=>{location.hash='#/p/TERRA-001/c/ART-007/s/LITERATURE';});
await page.waitForTimeout(1600);
const first = await page.locator('.card[data-code]').count();
const moreShown = await page.isVisible('#btn-more');
await page.click('#btn-more'); await page.waitForTimeout(1500);
const second = await page.locator('.card[data-code]').count();
const moreGone = !(await page.isVisible('#btn-more').catch(()=>false));
const codes = await page.locator('.card-code').allTextContents();
const dupes = codes.length - new Set(codes.map(c=>c.trim())).size;
check('2.9 20건 단위 페이지네이션', first===20 && moreShown && second===25 && moreGone && dupes===0,
      `1차=${first} 2차=${second} 중복=${dupes} 버튼사라짐=${moreGone}`);

/* 정렬 바꾸면 목록 처음부터 다시 (누적 아님) */
await page.selectOption('#sort-sel','event_asc'); await page.waitForTimeout(1600);
const afterSort = await page.locator('.card[data-code]').count();
const firstTitle = await page.locator('.card-title').first().textContent();
check('4.7 정렬 변경 시 목록 초기화 + 오래된순 선두', afterSort===20 && /대량 기록 01/.test(firstTitle),
      `개수=${afterSort} 선두=${firstTitle}`);

/* 더 불러오기 후에도 정렬 유지 */
await page.click('#btn-more'); await page.waitForTimeout(1500);
const lastTitle = await page.locator('.card-title').last().textContent();
check('4.7 추가 로드 후에도 정렬 순서 유지', /대량 기록 25/.test(lastTitle), lastTitle);

/* ---------- 언어 탭 왕복 (2.11) ---------- */
sql("update public.records set created_at = created_at - interval '10 minutes' where author_id is not null");
await page.evaluate(()=>{location.hash='#/new';}); await page.waitForTimeout(1300);
await page.selectOption('#f-planet','TERRA-001');
await page.selectOption('#f-cat','LANG-008'); await page.waitForTimeout(500);
await page.selectOption('#f-sub','WRITING');
await page.fill('#f-title','한국어 제목'); await page.fill('#f-summary','한국어 요약'); await page.fill('#f-content','한국어 본문');
await page.click('.langtab[data-l="en"]'); await page.waitForTimeout(300);
const enBlank = await page.inputValue('#f-title');
await page.fill('#f-title','English title'); await page.fill('#f-summary','English summary'); await page.fill('#f-content','English body');
await page.click('.langtab[data-l="ja"]'); await page.waitForTimeout(300);
await page.fill('#f-title','日本語タイトル'); await page.fill('#f-summary','日本語要約'); await page.fill('#f-content','日本語本文');
await page.click('.langtab[data-l="ko"]'); await page.waitForTimeout(300);
const koBack = await page.inputValue('#f-title');
check('2.11 언어 탭 전환 시 입력값 보존', enBlank==='' && koBack==='한국어 제목', `en탭=${JSON.stringify(enBlank)} ko복귀=${koBack}`);

await page.fill('#f-tag','문자'); await page.keyboard.press('Enter');
await page.fill('#f-source','테스트 출처');
await page.click('#record-form button[type=submit]'); await page.waitForTimeout(1800);
const saved = sql("select title->>'en' || '|' || (title->>'ja') || '|' || (content->>'ja') from public.records where title->>'ko'='한국어 제목'");
check('2.11 세 언어가 모두 저장됨', saved==='English title|日本語タイトル|日本語本文', saved);

/* 저장된 기록이 각 언어로 표시되는가 */
const code = sql("select record_code from public.records where title->>'ko'='한국어 제목'");
for (const [lang, expect] of [['en','English title'],['ja','日本語タイトル']]) {
  await page.click(`#app .lang-btn[data-lang="${lang}"]`); await page.waitForTimeout(500);
  await page.evaluate(c=>{location.hash='#/p/TERRA-001/c/LANG-008/s/WRITING/r/'+c;}, code);
  await page.waitForTimeout(1500);
  const title = await page.textContent('#modal-record-title');
  check(`4.4 ${lang.toUpperCase()} 화면에서 기록 데이터가 ${lang} 로 표시`, title===expect, title);
  await page.keyboard.press('Escape'); await page.waitForTimeout(600);
}
await page.click('#app .lang-btn[data-lang="ko"]'); await page.waitForTimeout(500);

/* ---------- 태그 8개 상한 ---------- */
await page.evaluate(()=>{location.hash='#/new';}); await page.waitForTimeout(1300);
for (let i=1;i<=10;i++){ await page.fill('#f-tag','태그'+i); await page.keyboard.press('Enter'); }
const chips = await page.locator('.tagchip').count();
check('2.11 태그 8개 상한', chips===8, 'chips='+chips);

/* ---------- 보안등급 선택지가 본인 등급 이하 ---------- */
const levelOpts = await page.locator('#f-level option').allTextContents();
const myLevel = Number(sql("select level from public.profiles p join auth.users u on u.id=p.id where u.email='pg@test.io'"));
check('2.11 보안등급 선택지는 본인 등급 이하만', levelOpts.length===myLevel,
      `등급=${myLevel} 선택지=${levelOpts.join(',')}`);

/* ---------- 신고 UI 전체 흐름 (2.14) ---------- */
const ctx2=await newCtx(browser); const p2=await open(ctx2);
await signup(p2,'rep@test.io','passphrase6','Rep'); await confirm('rep@test.io');
await login(p2,'rep@test.io','passphrase6');
await p2.click('#app .lang-btn[data-lang="ko"]'); await p2.waitForTimeout(500);
await p2.evaluate(()=>{location.hash='#/p/TERRA-001/c/NAT-001/s/VOLCANO/r/REC-TERRA-001-0003';});
await p2.waitForTimeout(1600);
await p2.click('#modal-menu'); await p2.waitForTimeout(400);
const menuItems = await p2.locator('#modal-menu-list button').allTextContents();
await p2.locator('#modal-menu-list button[data-act="report"]').click(); await p2.waitForTimeout(600);
const reportOpen = await p2.isVisible('#modal-report');
await p2.selectOption('#rp-reason','no_source');
await p2.fill('#rp-detail','출처가 없습니다');
await p2.click('#form-report button[type=submit]'); await p2.waitForTimeout(1200);
const reportClosed = !(await p2.isVisible('#modal-report'));
const rows = sql("select count(*) from public.reports r join auth.users u on u.id=r.user_id where u.email='rep@test.io'");
check('2.14 신고 UI 흐름 (⋮ 메뉴 → 사유 선택 → 접수)',
      menuItems.length===1 && reportOpen && reportClosed && rows==='1',
      `메뉴=${menuItems.join(',')} rows=${rows}`);

/* 같은 기록 재신고 시 안내 */
await p2.click('#modal-menu'); await p2.waitForTimeout(300);
await p2.locator('#modal-menu-list button[data-act="report"]').click(); await p2.waitForTimeout(500);
await p2.click('#form-report button[type=submit]'); await p2.waitForTimeout(1200);
const dupMsg = await p2.textContent('#rp-error');
check('2.14 중복 신고 시 안내 문구', /이미 신고/.test(dupMsg), dupMsg);
await p2.click('#modal-report .modal-tools [data-close]'); await p2.waitForTimeout(400);

/* 본인 기록에는 수정·삭제 메뉴 */
await page.evaluate(c=>{location.hash='#/p/TERRA-001/c/LANG-008/s/WRITING/r/'+c;}, code);
await page.waitForTimeout(1500);
await page.click('#modal-menu'); await page.waitForTimeout(400);
const ownMenu = await page.locator('#modal-menu-list button').allTextContents();
check('2.10 본인 기록은 [수정][삭제], 타인 기록은 [신고]',
      ownMenu.length===2 && ownMenu.join(',')==='수정,삭제', ownMenu.join(','));

/* ---------- 세션 만료 처리 (2.16) ---------- */
await p2.keyboard.press('Escape'); await p2.waitForTimeout(500);
await ctx2.route('**/rest/v1/v_records*', r =>
  r.fulfill({status:401, contentType:'application/json',
             body: JSON.stringify({message:'JWT expired', code:'PGRST301'})}));
await p2.evaluate(()=>{location.hash='#/p/TERRA-001/c/TECH-004/s/INFO';});
await p2.waitForTimeout(1600);
const gateShown = await p2.isVisible('#screen-gate');
const toastTxt = await p2.textContent('#toast').catch(()=> '');
check('2.16 401/세션 만료 시 경고 화면 복귀 + 안내',
      gateShown && /세션/.test(toastTxt), `gate=${gateShown} toast=${toastTxt}`);

/* ---------- 모바일 드로어 안 링크 동작 ---------- */
const ctxM=await newCtx(browser,{viewport:{width:390,height:780}});
const pm=await open(ctxM); await login(pm,'pg@test.io','passphrase5'); await pm.waitForTimeout(900);
await pm.click('#btn-drawer'); await pm.waitForTimeout(500);
await pm.locator('#drawer a[href="#/mine"]').click(); await pm.waitForTimeout(1400);
const drawerClosed = !(await pm.isVisible('#drawer'));
const onMine = await pm.evaluate(()=>location.hash);
check('2.17 드로어 안 링크 클릭 시 이동 + 패널 닫힘',
      drawerClosed && onMine==='#/mine', `hash=${onMine} closed=${drawerClosed}`);

/* ---------- 회귀: 공유 링크로 직접 연 탭에서 모달 닫기 ----------
   history.back() 만 쓰면 뒤로 갈 항목이 없어 사이트 밖으로 나가 버렸다. */
const pDirect = await ctx.newPage();
await pDirect.goto(BASE + '/#/p/TERRA-001/c/TECH-004/s/ENERGY/r/REC-TERRA-001-0008',
                   { waitUntil: 'domcontentloaded' });
await pDirect.waitForTimeout(2000);
const directOpen = await pDirect.isVisible('#modal-record');
await pDirect.keyboard.press('Escape');
await pDirect.waitForTimeout(1200);
const afterUrl = await pDirect.evaluate(() => location.href);
check('4.2 공유 링크로 직접 연 기록에서 ESC 시 사이트 안에 남는다',
      directOpen && afterUrl.endsWith('#/p/TERRA-001/c/TECH-004/s/ENERGY'), afterUrl);

/* ---------- 회귀: 60초 연속 작성 제한 (4.8) ----------
   앞선 작성이 아직 60초 안이면 1번째부터 막혀 검사가 무뎌지므로
   직전 작성 시각을 앞당겨 두고 시작한다. */
sql("update public.records set created_at = created_at - interval '10 minutes'"
    + " where author_id is not null");
const fast = await page.evaluate(async () => {
  const mk = n => ({
    planet_id: 'TERRA-001', category_id: 'LANG-008', subcategory_id: 'WRITING',
    title: { ko: '연속 ' + n }, summary: { ko: '요약' }, content: { ko: '본문' },
    event_date: null, tags: ['t'], source: '출처', level: 1
  });
  const out = {};
  try { await window.AKASHIC_API.records.create(mk(1)); out.first = 'ok'; }
  catch (e) { out.first = e.code; }
  try { await window.AKASHIC_API.records.create(mk(2)); out.second = 'no-error'; }
  catch (e) { out.second = e.code; }
  return out;
});
check('4.8 60초 이내 연속 작성 차단',
      fast.first === 'ok' && fast.second === 'AKASHIC_TOO_FAST',
      `1번째=${fast.first} 2번째=${fast.second}`);

/* ---------- 4.3 등급 상승 상단 배너 ---------- */
const viewCodes = sql("select record_code || '|' || planet_id || '|' || category_id || '|' || subcategory_id"
  + " from public.records where status='published' and deleted_at is null and level<=2 order by id limit 10").split('\n');
/* 기록 주소로 차례차례 이동해 10건을 열람한다.
   중간에 ESC 를 쓰면 history.back() 이 직전 기록으로 되돌아가므로 쓰지 않는다. */
for (const line of viewCodes) {
  const [c, pl, ca, su] = line.trim().split('|');
  await page.evaluate(h => { location.hash = h; }, `#/p/${pl}/c/${ca}/s/${su}/r/${c}`);
  await page.waitForTimeout(700);
}
await page.evaluate(() => { location.hash = '#/'; });
await page.waitForTimeout(1200);
const bannerShown = await page.isVisible('#level-banner');
const bannerText  = await page.textContent('#level-banner-text');
const bannerTop   = await page.evaluate(() => {
  const b = document.getElementById('level-banner');
  const m = document.querySelector('.masthead');
  return b.getBoundingClientRect().top < m.getBoundingClientRect().top;
});
check('4.3 등급 상승을 상단 배너로 알림',
      bannerShown && /CLEARANCE/.test(bannerText) && bannerTop, bannerText);
await page.click('#level-banner-close'); await page.waitForTimeout(300);
check('4.3 배너를 닫을 수 있음', !(await page.isVisible('#level-banner')));

/* ---------- 4.4 언어 선택이 계정에도 반영 (5.2) ---------- */
await setLang(page, 'ja'); await page.waitForTimeout(900);
const dbLang = sql("select lang from public.profiles p join auth.users u on u.id=p.id where u.email='pg@test.io'");
await setLang(page, 'ko'); await page.waitForTimeout(900);
const dbLang2 = sql("select lang from public.profiles p join auth.users u on u.id=p.id where u.email='pg@test.io'");
check('4.4 언어 전환이 profiles.lang 에 반영', dbLang === 'ja' && dbLang2 === 'ko', `${dbLang} -> ${dbLang2}`);

/* ---------- 4.3 행성 STATUS 를 뜻이 드러나게 표기 ---------- */
await page.evaluate(() => { location.hash = '#/'; }); await page.waitForTimeout(1300);
const statusLine = await page.locator('.card[data-planet="EXOPLANET-442"] .card-foot span').first().textContent();
check('4.3 DORMANT 를 뜻과 함께 표기', /DORMANT/.test(statusLine) && /기록 적음/.test(statusLine), statusLine.trim());

/* ---------- 4.8 관리자: 숨김 기록 대기열 ---------- */
const nonAdminLink = await page.locator('#sidebar-desktop a[href="#/admin"]').count();
await page.evaluate(() => { location.hash = '#/admin'; }); await page.waitForTimeout(1200);
const blocked = await page.textContent('.state-title').catch(() => '');
check('4.8 관리자가 아니면 대기열 접근 차단', nonAdminLink === 0 && /권한/.test(blocked),
      `링크=${nonAdminLink} 문구=${blocked}`);

// 신고 3건으로 기록 하나를 숨김 상태로 만든다
const victim = sql("select id from public.records where record_code='REC-TERRA-001-0005'");
for (const em of ['a1@test.io', 'a2@test.io', 'a3@test.io']) {
  sql(`insert into auth.users (instance_id,id,aud,role,email,email_confirmed_at,
        raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
       values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(),'authenticated','authenticated',
               '${em}', now(), '{}', '{}', now(), now())`);
  sql(`insert into public.reports (record_id,user_id,reason)
       select ${victim}, p.id, 'no_source' from public.profiles p
        join auth.users u on u.id = p.id where u.email = '${em}'`);
}
check('4.8 신고 3건으로 hidden 전환',
      sql(`select status from public.records where id=${victim}`) === 'hidden');

// 이 계정을 관리자로 올린 뒤 대기열 확인
sql("update public.profiles set is_admin = true where id = (select id from auth.users where email='pg@test.io')");
await page.reload({ waitUntil: 'domcontentloaded' }); await page.waitForTimeout(1800);
await setLang(page, 'ko');
const adminLink = await page.locator('#sidebar-desktop a[href="#/admin"]').count();
await page.evaluate(() => { location.hash = '#/admin'; }); await page.waitForTimeout(1400);
const queued = await page.locator('[data-unhide]').count();
check('4.8 관리자에게 대기열 링크와 목록이 보임', adminLink === 1 && queued === 1,
      `링크=${adminLink} 대기=${queued}`);

await page.click('[data-unhide]'); await page.waitForTimeout(1500);
const statusNow = sql(`select status from public.records where id=${victim}`);
check('4.8 관리자가 숨김을 해제할 수 있음', statusNow === 'published', statusNow);

/* ---------- 회귀: 언어를 바꾸면 사이드바도 따라간다 ----------
   사이드바는 t() 로 만들어져 data-i18n 치환 대상이 아니다. */
await page.evaluate(() => { location.hash = '#/'; }); await page.waitForTimeout(1200);
await setLang(page, 'en'); await page.waitForTimeout(1200);
const sideEn = await page.textContent('#sidebar-desktop .side-title');
const newBtnEn = await page.textContent('#sidebar-desktop a[href="#/new"]');
await setLang(page, 'ko'); await page.waitForTimeout(1200);
const newBtnKo = await page.textContent('#sidebar-desktop a[href="#/new"]');
check('4.4 언어 전환이 사이드바에도 즉시 반영',
      /ARCHIVE STATUS/.test(sideEn) && /NEW RECORD/.test(newBtnEn) && /기록 작성/.test(newBtnKo),
      `${newBtnEn.trim()} / ${newBtnKo.trim()}`);

/* ---------- 회귀: 내가 쓴 기록의 수정 링크가 두 번 이동하지 않는다 ---------- */
await page.evaluate(() => { location.hash = '#/mine'; }); await page.waitForTimeout(1500);
const editLink = page.locator('.card[data-code] a[href^="#/edit/"]').first();
if (await editLink.count()) {
  await editLink.click(); await page.waitForTimeout(1500);
  const landed = await page.evaluate(() => location.hash);
  await page.goBack(); await page.waitForTimeout(1200);
  const back = await page.evaluate(() => location.hash);
  check('2.12 수정 링크는 한 번만 이동 (뒤로가기가 목록으로 돌아옴)',
        landed.startsWith('#/edit/') && back === '#/mine', `${landed} -> ${back}`);
} else {
  check('2.12 수정 링크는 한 번만 이동 (뒤로가기가 목록으로 돌아옴)', false, '수정 링크 없음');
}

/* ---------- 회귀: 진입할 수 없는 행성에는 작성할 수 없다 ---------- */
sql("update public.planets set status='RESTRICTED', required_level=4 where id='EXOPLANET-PCB'");
await page.evaluate(() => { location.hash = '#/new'; }); await page.waitForTimeout(1500);
const options = await page.locator('#f-planet option').evaluateAll(o => o.map(x => x.value));
const serverSide = await page.evaluate(async () => {
  try {
    await window.AKASHIC_API.records.create({
      planet_id: 'EXOPLANET-PCB', category_id: 'EVENT-006', subcategory_id: 'DISCOVERY',
      title: { ko: '잠긴 행성 시도' }, summary: { ko: '요약' }, content: { ko: '본문' },
      event_date: null, tags: ['t'], source: '출처', level: 1
    });
    return 'no-error';
  } catch (e) { return e.code; }
});
check('4.3 잠긴 행성은 작성 목록에서 빠지고 요청도 서버가 거부',
      !options.includes('EXOPLANET-PCB') && serverSide === 'AKASHIC_PLANET_LOCKED',
      `목록=${options.join(',')} 서버=${serverSide}`);
sql("update public.planets set status='DORMANT', required_level=1 where id='EXOPLANET-PCB'");

await browser.close();
process.exit(summary() ? 1 : 0);
})().catch(e=>{console.error('RUNNER ERROR',e);process.exit(1);});
