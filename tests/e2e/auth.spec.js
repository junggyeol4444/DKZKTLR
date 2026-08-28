const { test, expect } = require('@playwright/test');

async function mockSupabase(page, { session = null, updateError = null } = {}) {
  await page.route('**/config.js', route => route.fulfill({contentType:'application/javascript',body:"window.AKASHIC_CONFIG={supabaseUrl:'https://test.supabase.co',supabaseAnonKey:'anon'}"}));
  await page.route('https://cdn.jsdelivr.net/**', route => route.fulfill({contentType:'application/javascript',body:`
    window.__authCallback=null;
    const response=(table)=>({data:table==='profiles'?{id:'user-1',keeper_code:'KEEPER-001',display_name:'Reader',level:2,lang:'en',is_admin:false}:table==='archive_statistics'?{record_count:0,today_count:0,keeper_count:1}:[],error:null});
    const query=table=>new Proxy({}, {get(_,key){if(key==='then')return resolve=>resolve(response(table));return ()=>query(table)}});
    window.supabase={createClient:()=>({auth:{
      getSession:async()=>({data:{session:${JSON.stringify(session)}}}),getUser:async()=>({data:{user:${JSON.stringify(session?.user||null)}}}),
      onAuthStateChange:cb=>(window.__authCallback=cb,{data:{subscription:{unsubscribe(){}}}}),signOut:async()=>({error:null}),
      signInWithPassword:async()=>({error:null}),signUp:async()=>({error:null}),resetPasswordForEmail:async()=>({error:null}),
      updateUser:async()=>({error:${updateError?`{message:'failed'}`:'null'}})},from:table=>query(table),rpc:()=>query('rpc')})};
  `}));
}

test('an existing session skips the gateway', async ({page}) => {
  await mockSupabase(page,{session:{user:{id:'user-1'}}});
  await page.goto('/#/welcome');
  await expect(page).toHaveURL(/#\/$/);
  await expect(page.locator('.site-header')).toBeVisible();
});

test('PASSWORD_RECOVERY opens the SPA update route', async ({page}) => {
  await mockSupabase(page,{session:null});
  await page.goto('/#/welcome');
  await page.evaluate(() => window.__authCallback('PASSWORD_RECOVERY',{user:{id:'user-1'}}));
  await expect(page).toHaveURL(/#\/reset\/update$/);
  await expect(page.locator('#auth-form[data-kind="update"]')).toBeVisible();
});

test('failed password update is not shown as success', async ({page}) => {
  await mockSupabase(page,{session:{user:{id:'user-1'}},updateError:true});
  await page.goto('/#/reset/update');
  await page.locator('#password').fill('new-password');
  await page.locator('#auth-form button[type=submit]').click();
  await expect(page.locator('.form-message')).not.toBeEmpty();
  await expect(page).toHaveURL(/#\/reset\/update$/);
});
