import { chromium } from 'playwright';
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import assert from 'node:assert/strict';

const root = normalize(join(import.meta.dirname, '..'));
const types = {'.html':'text/html','.js':'text/javascript','.css':'text/css'};
const server = createServer(async (req,res) => {
  try {
    const path = req.url.split('?')[0] === '/' ? '/index.html' : req.url.split('?')[0];
    const file = normalize(join(root,path));
    if (!file.startsWith(root)) throw new Error('invalid path');
    res.setHeader('content-type',types[extname(file)]||'text/plain');res.end(await readFile(file));
  } catch { res.statusCode=404;res.end('not found'); }
});
await new Promise(resolve=>server.listen(4174,'127.0.0.1',resolve));

const browser=await chromium.launch({headless:true});
const page=await browser.newPage({viewport:{width:1280,height:900}});
const browserUser={id:'10000000-0000-4000-a000-000000000001',email:'reader@test.invalid'};
await page.addInitScript(() => {
  try { localStorage.setItem('akashic_lang','ko'); } catch {}
  const user={id:'10000000-0000-4000-a000-000000000001',email:'reader@test.invalid'};
  const profile={id:user.id,keeper_code:'KEEPER-007',display_name:'Reader',level:3,lang:'ko',is_admin:true};
  const domain={id:'SCIENCE',name:{ko:'과학',en:'Science',ja:'科学'},description:{ko:'관찰과 실험으로 이해하는 세계',en:'The observed world',ja:'観察の世界'},icon:'◉',sort_order:1};
  const category={id:'SPACE',domain_id:'SCIENCE',name:{ko:'우주과학',en:'Space science',ja:'宇宙科学'},description:{ko:'천체와 우주 탐사'},sort_order:1};
  const record={id:8,record_code:'ARC-SCIENCE-000008',domain_id:'SCIENCE',category_id:'SPACE',title:{ko:'케플러-442b 발견',en:'Kepler-442b discovery',ja:'ケプラー442bの発見'},summary:{ko:'관측으로 확인된 외계행성 기록이다.',en:'An observed exoplanet record.',ja:'観測で確認された記録。'},content:{ko:'관측된 사실과 출처를 바탕으로 보존된 기록이다.',en:'A sourced observation record.',ja:'観測事実と出典に基づく記録。'},event_date:'2015-01-06',tags:['외계행성','천문학'],source:'https://science.nasa.gov/exoplanet-catalog/kepler-442-b/',level:3,author_id:'00000000-0000-0000-0000-000000000000',created_at:'2026-01-01',keeper_code:'KEEPER-000',domain_name:domain.name,category_name:category.name,status:'published',content_available:true};
  const newer={...record,id:9,record_code:'ARC-SCIENCE-000009',title:{ko:'낮은 등급 최신 기록',en:'New low record'},level:1,event_date:'2020-01-01',created_at:'2026-02-01'};
  class Query {
    constructor(table){this.table=table;this.one=false;this.filters={};}
    select(){return this;} eq(k,v){this.filters[k]=v;return this;} in(){return this;} is(){return this;} order(){return this;} range(){return this;} limit(){return this;} textSearch(){return this;}
    single(){this.one=true;return this;} insert(){return this;} update(){return this;} delete(){return this;} upsert(){return this;} match(){return this;}
    result(){let data=[];if(this.table==='profiles')data=profile;else if(this.table==='domains')data=[domain];else if(this.table==='categories')data=[category];else if(this.table==='archive_statistics')data={record_count:30,today_count:1,keeper_count:7};else if(this.table==='record_catalog')data=[{...record,content:undefined}];else if(this.table==='records')data=this.one?record:[record];else if(this.table==='bookmarks')data=[{record_id:8,records:record},{record_id:9,records:newer}];return {data,error:null};}
    then(resolve,reject){return Promise.resolve(this.result()).then(resolve,reject);}
  }
  window.__mockClient={
    auth:{getSession:async()=>({data:{session:location.search.includes('guest=1')?null:{user}}}),getUser:async()=>({data:{user}}),onAuthStateChange:callback=>{window.__triggerAuth=callback;return {data:{subscription:{unsubscribe(){}}}};},signInWithPassword:async()=>({error:null}),signUp:async()=>({error:null}),resetPasswordForEmail:async()=>({error:null}),updateUser:async({password})=>({error:password==='rejectpass'?new Error('Password rejected'):null}),signOut:async()=>({error:null})},
    from:table=>new Query(table),
    rpc:async(name)=>({data:name==='get_record_for_reader'||name==='get_own_record'?[record]:name==='search_record_catalog'?[record]:name==='get_moderation_cases'?[{id:12,record_id:8,report_count:3,status:'open',decision:null,opened_at:'2026-01-01',records:record,moderation_votes:[],reports:[]}]:name==='get_related_records'?[]:[],error:null})
  };
});
await page.route('**/config.js',route=>route.fulfill({contentType:'text/javascript',body:"window.AKASHIC_CONFIG={supabaseUrl:'https://test.supabase.co',supabaseAnonKey:'public-test-key'};"}));
await page.route('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2',route=>route.fulfill({contentType:'text/javascript',body:'window.supabase={createClient:()=>window.__mockClient};'}));

try {
  await page.goto('http://127.0.0.1:4174/',{waitUntil:'domcontentloaded'});
  await page.waitForURL(/#\/$/);
  await page.waitForSelector('.domain-card');
  assert.match(await page.locator('h1').first().textContent(),/모든 지식/);
  assert.equal(await page.locator('.domain-card').count(),1);

  await page.locator('.domain-card').click();
  await page.waitForURL(/#\/d\/SCIENCE$/);
  await page.waitForSelector('.record-card');
  assert.match(await page.locator('.record-card h3').textContent(),/케플러/);

  await page.locator('.record-card .stretched').click();
  await page.waitForSelector('.modal[role="dialog"]');
  assert.equal(await page.locator('.document-content').count(),1);
  await page.keyboard.press('Escape');
  await page.waitForTimeout(100);
  assert.equal(await page.locator('.modal-layer').count(),0);

  await page.goto('http://127.0.0.1:4174/#/search?q=케플러');
  await page.waitForSelector('.record-card');
  assert.equal(await page.locator('.record-card').count(),1);

  await page.locator('.record-card .stretched').click();
  await page.waitForSelector('[data-action="report"]');
  await page.locator('[data-action="report"]').click();
  await page.waitForSelector('#report-form');
  await page.selectOption('#reason','missing_source');
  await page.fill('#detail','출처 연결을 다시 확인해 주세요.');
  await page.locator('#report-form button[type="submit"]').click();
  await page.waitForTimeout(100);
  assert.equal(await page.locator('#report-form').count(),0);

  await page.goto('http://127.0.0.1:4174/#/moderation');
  await page.waitForSelector('.meeting-card');
  assert.match(await page.locator('.meeting-card h2').textContent(),/케플러/);
  assert.equal(await page.locator('.vote-form').count(),1);
  assert.match(await page.locator('.review-content').textContent(),/관측된 사실/);

  await page.goto('http://127.0.0.1:4174/#/bookmarks');
  await page.waitForSelector('.record-card');
  assert.match(await page.locator('.record-card h3').first().textContent(),/낮은 등급/);
  await page.selectOption('[data-action="sort"]','levelDesc');
  await page.waitForTimeout(100);
  assert.match(await page.locator('.record-card h3').first().textContent(),/케플러/);

  await page.goto('http://127.0.0.1:4174/#/new');
  await page.waitForSelector('#record-form');
  await page.locator('[data-action="translation"][data-lang="en"]').click();
  assert.equal(await page.locator('[data-lang-panel="en"]').isVisible(),true);
  await page.locator('[data-action="translation"][data-lang="ko"]').click();
  await page.fill('#title-ko','새 검증 기록');
  await page.fill('#summary-ko','브라우저 저장 흐름을 확인한다.');
  await page.fill('#content-ko','기록 본문과 출처를 함께 저장한다.');
  await page.fill('#tags','검증, 브라우저');
  await page.fill('#source','https://example.com/browser-check');
  await page.locator('#record-form button[type="submit"]').click();
  await page.waitForURL(/#\/r\/ARC-SCIENCE-000008$/);

  await page.goto('http://127.0.0.1:4174/#/edit/ARC-SCIENCE-000008');
  await page.waitForSelector('#record-form[data-id="8"]');
  await page.fill('#title-ko','수정된 검증 기록');
  await page.locator('#record-form button[type="submit"]').click();
  await page.waitForURL(/#\/r\/ARC-SCIENCE-000008$/);

  await page.setViewportSize({width:390,height:780});
  await page.goto('http://127.0.0.1:4174/#/');
  await page.waitForSelector('.mobile-menu');
  await page.locator('.mobile-menu').click();
  assert.equal(await page.locator('body').evaluate(el=>el.classList.contains('drawer-open')),true);
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=document.documentElement.clientWidth+1),true);

  await page.selectOption('#lang','en');
  await page.waitForTimeout(100);
  assert.equal(await page.getAttribute('html','lang'),'en');

  await page.evaluate(user=>window.__triggerAuth('PASSWORD_RECOVERY',{user}),browserUser);
  await page.waitForURL(/#\/reset\/update$/);
  await page.fill('#password','rejectpass');
  await page.locator('#auth-form button[type="submit"]').click();
  await page.waitForTimeout(100);
  assert.match(await page.locator('.form-message').textContent(),/Authentication failed|인증에 실패/);
  assert.match(page.url(),/#\/reset\/update$/);

  await page.evaluate(()=>window.__triggerAuth('SIGNED_OUT',null));
  await page.waitForURL(/#\/welcome$/);
  await page.evaluate(user=>window.__triggerAuth('SIGNED_IN',{user}),browserUser);
  await page.waitForURL(/#\/$/);
  await page.goto('http://127.0.0.1:4174/#/bookmarks');
  await page.waitForSelector('.bookmark.active');
  assert.equal(await page.locator('.bookmark.active').count(),2);

  await page.goto('http://127.0.0.1:4174/?guest=1#/welcome');
  await page.waitForSelector('.gateway-actions');
  assert.equal(await page.locator('#record-form').count(),0);
  await page.goto('http://127.0.0.1:4174/?guest=1#/login');
  await page.waitForSelector('#auth-form[data-kind="login"]');
  await page.goto('http://127.0.0.1:4174/?guest=1#/signup');
  await page.waitForSelector('#auth-form[data-kind="signup"]');
  await page.goto('http://127.0.0.1:4174/?guest=1#/reset');
  await page.waitForSelector('#auth-form[data-kind="reset"]');
  console.log('Browser auth, navigation, search, report, moderation, editor, mobile, and i18n checks passed.');
} catch(error) {
  await page.screenshot({path:process.env.BROWSER_SHOT||'/tmp/akashic-browser-failure.png',fullPage:true});
  throw error;
} finally { await browser.close();await new Promise(resolve=>server.close(resolve)); }
