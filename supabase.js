(function () {
  const config = window.AKASHIC_CONFIG || {};
  const valid = /^https:\/\/.+\.supabase\.co$/.test(config.supabaseUrl || '') && !!config.supabaseAnonKey;
  window.AkashicSupabase = {
    configured: valid,
    client: valid ? window.supabase.createClient(config.supabaseUrl, config.supabaseAnonKey, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    }) : null
  };
}());
