/* ============================================================
 *  AKASHIC RECORDS / supabase.js
 *  Supabase 클라이언트 초기화 (4.5)
 *
 *  ⚠ 여기에는 anon(공개) 키만 넣습니다.
 *    service_role 키는 RLS 를 우회하므로 절대 넣지 마세요.
 *    anon 키는 공개되어도 되는 값이며, 실제 접근 통제는 DB 의 RLS 가 합니다.
 *
 *  설정 방법 (둘 중 하나)
 *   1) 아래 두 상수를 직접 바꿉니다.
 *   2) index.html 보다 먼저 읽히는 스크립트에서
 *      window.AKASHIC_CONFIG = { url: '...', anonKey: '...' } 를 정의합니다.
 * ============================================================ */

const SUPABASE_URL      = (window.AKASHIC_CONFIG && window.AKASHIC_CONFIG.url)
                        || 'https://YOUR-PROJECT-REF.supabase.co';
const SUPABASE_ANON_KEY = (window.AKASHIC_CONFIG && window.AKASHIC_CONFIG.anonKey)
                        || 'YOUR-ANON-KEY';

const AKASHIC_CONFIGURED =
  !SUPABASE_URL.includes('YOUR-PROJECT-REF') && !SUPABASE_ANON_KEY.includes('YOUR-ANON-KEY');

let sb = null;
if (AKASHIC_CONFIGURED && window.supabase && window.supabase.createClient) {
  sb = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: true,
      storageKey: 'akashic-auth'
    }
  });
}

window.AKASHIC_SB = { sb, configured: AKASHIC_CONFIGURED, url: SUPABASE_URL };
