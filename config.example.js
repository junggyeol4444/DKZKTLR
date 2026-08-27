// Copy to config.js, fill in the public project values, and load it before supabase.js.
// Never put a service_role key in browser code.
window.AKASHIC_CONFIG = {
  supabaseUrl: 'https://YOUR_PROJECT.supabase.co',
  supabaseAnonKey: 'YOUR_PUBLIC_ANON_KEY'
};
