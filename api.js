(function () {
  const getClient = () => window.AkashicSupabase.client;

  window.ArchiveAPI = {
    async session() { return (await getClient().auth.getSession()).data.session; },
    async profile(userId) { return (await getClient().from('profiles').select('id,keeper_code,display_name,level,lang,is_admin').eq('id', userId).single()).data; },
    signIn(email, password) { return getClient().auth.signInWithPassword({ email, password }); },
    signUp(email, password, metadata) { return getClient().auth.signUp({ email, password, options: { data: metadata, emailRedirectTo: `${location.origin}${location.pathname}` } }); },
    signOut() { return getClient().auth.signOut(); },
    resetPassword(email) { const redirect=new URL(location.pathname,location.origin);redirect.searchParams.set('recovery','1');return getClient().auth.resetPasswordForEmail(email, { redirectTo: redirect.href }); },
    updatePassword(password) { return getClient().auth.updateUser({ password }); },
    onAuth(callback) { return getClient().auth.onAuthStateChange(callback); },
    async domains() { const { data, error } = await getClient().from('domains').select('*').order('sort_order'); if (error) throw error; return data; },
    async categories(domainId) { const { data, error } = await getClient().from('categories').select('*').eq('domain_id', domainId).order('sort_order'); if (error) throw error; return data; },
    async counts() { const { data, error } = await getClient().from('archive_statistics').select('*').single(); if (error) throw error; return data; },
    async records(filters = {}, page = 0) {
      if (filters.search) { const { data, error } = await getClient().rpc('search_record_catalog',{search_query:filters.search,page_no:page}); if(error) throw error; return data || []; }
      const sort = localStorage.getItem('akashic_sort') || 'created';
      const { data, error } = await getClient().rpc('list_record_catalog',{requested_domain:filters.domain||null,requested_category:filters.category||null,requested_author:filters.author||null,sort_key:sort,lang_key:localStorage.getItem('akashic_lang')||'ko',page_no:page});
      if (error) throw error; return data || [];
    },
    async myRecords() { const { data, error } = await getClient().rpc('get_my_records'); if (error) throw error; return data || []; },
    async ownRecord(code) { const { data, error } = await getClient().rpc('get_own_record',{requested_code:code}); if(error) throw error; if(!data?.length) throw new Error('Record not found'); return data[0]; },
    async record(code) { const { data, error } = await getClient().rpc('get_record_for_reader', { requested_code: code }); if (error) throw error; return data?.[0] || null; },
    async related(recordId) { const { data, error } = await getClient().rpc('get_related_records',{requested_id:recordId}); if(error) throw error; return data || []; },
    async createRecord(record) { const { data, error } = await getClient().from('records').insert(record).select('record_code').single(); if (error) throw error; return data; },
    async updateRecord(id, record) { const { data, error } = await getClient().from('records').update(record).eq('id', id).select('record_code').single(); if (error) throw error; return data; },
    async deleteRecord(id) { const { error } = await getClient().from('records').update({ deleted_at: new Date().toISOString() }).eq('id', id); if (error) throw error; },
    async bookmarks() { const { data, error } = await getClient().rpc('get_bookmarked_records'); if (error) throw error; return data || []; },
    async bookmarkIds() { const { data } = await getClient().from('bookmarks').select('record_id'); return new Set((data || []).map(x => x.record_id)); },
    async toggleBookmark(userId, recordId, active) { const q = active ? getClient().from('bookmarks').delete().match({ user_id:userId, record_id:recordId }) : getClient().from('bookmarks').insert({ user_id:userId, record_id:recordId }); const { error } = await q; if (error) throw error; },
    async recent() { const { data, error } = await getClient().rpc('get_recent_records'); if (error) throw error; return data || []; },
    async report(userId, recordId, reason, detail) { const { error } = await getClient().from('reports').insert({ user_id:userId, record_id:recordId, reason, detail }); if (error) throw error; },
    async moderationCases() { const { data, error } = await getClient().rpc('get_moderation_dossiers'); if (error) throw error; return data || []; },
    async moderationVote(caseId, adminId, decision, note) { const { error } = await getClient().from('moderation_votes').insert({case_id:caseId,admin_id:adminId,decision,note}); if (error) throw error; }
  };
}());
