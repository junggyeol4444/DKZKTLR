(function () {
  const getClient = () => window.AkashicSupabase.client;
  const visible = query => query.in('status', ['published', 'under_review']).is('deleted_at', null);

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
      let q = visible(getClient().from('record_catalog').select('id,record_code,domain_id,category_id,title,summary,event_date,tags,level,author_id,status,created_at,keeper_code,domain_name,category_name,content_available')).range(page * 20, page * 20 + 19);
      if (filters.domain) q = q.eq('domain_id', filters.domain);
      if (filters.category) q = q.eq('category_id', filters.category);
      if (filters.author) q = q.eq('author_id', filters.author);
      const sort = localStorage.getItem('akashic_sort') || 'created';
      if (sort === 'eventAsc') q = q.order('event_date', { ascending: true, nullsFirst: false });
      else if (sort === 'eventDesc') q = q.order('event_date', { ascending: false, nullsFirst: false });
      else if (sort === 'title') q = q.order(`title->>${localStorage.getItem('akashic_lang') || 'ko'}`, { ascending: true });
      else if (sort === 'levelDesc') q = q.order('level', { ascending: false }).order('event_date',{ascending:false,nullsFirst:false});
      else q = q.order('created_at', { ascending: false });
      const { data, error } = await q; if (error) throw error; return data;
    },
    async myRecords(userId) { const { data, error } = await getClient().from('records').select('id,record_code,domain_id,category_id,title,summary,event_date,tags,source,level,author_id,is_seed,status,deleted_at,created_at,updated_at,profiles!records_author_id_fkey(keeper_code)').eq('author_id', userId).order('created_at', { ascending: false }); if (error) throw error; return data; },
    async ownRecord(code) { const { data, error } = await getClient().rpc('get_own_record',{requested_code:code}); if(error) throw error; if(!data?.length) throw new Error('Record not found'); return data[0]; },
    async record(code) { const { data, error } = await getClient().rpc('get_record_for_reader', { requested_code: code }); if (error) throw error; return data?.[0] || null; },
    async related(recordId) { const { data, error } = await getClient().rpc('get_related_records',{requested_id:recordId}); if(error) throw error; return data || []; },
    async createRecord(record) { const { data, error } = await getClient().from('records').insert(record).select('record_code').single(); if (error) throw error; return data; },
    async updateRecord(id, record) { const { data, error } = await getClient().from('records').update(record).eq('id', id).select('record_code').single(); if (error) throw error; return data; },
    async deleteRecord(id) { const { error } = await getClient().from('records').update({ deleted_at: new Date().toISOString() }).eq('id', id); if (error) throw error; },
    async bookmarks() { const user=(await getClient().auth.getUser()).data.user; const profile=await getClient().from('profiles').select('level').eq('id',user.id).single(); if(profile.error) throw profile.error; const { data, error } = await getClient().from('bookmarks').select('record_id,created_at,records!inner(id,record_code,domain_id,category_id,title,summary,event_date,tags,level,author_id,status,deleted_at,created_at,profiles!records_author_id_fkey(keeper_code),domains(name),categories(name))').is('records.deleted_at',null).in('records.status',['published','under_review']).order('created_at', { ascending: false }); if (error) throw error; return data.map(x => ({...x.records,keeper_code:x.records.profiles?.keeper_code,domain_name:x.records.domains?.name,category_name:x.records.categories?.name,content_available:x.records.level<=profile.data.level})); },
    async bookmarkIds() { const { data } = await getClient().from('bookmarks').select('record_id'); return new Set((data || []).map(x => x.record_id)); },
    async toggleBookmark(userId, recordId, active) { const q = active ? getClient().from('bookmarks').delete().match({ user_id:userId, record_id:recordId }) : getClient().from('bookmarks').insert({ user_id:userId, record_id:recordId }); const { error } = await q; if (error) throw error; },
    async recent() { const { data, error } = await getClient().from('record_views').select('viewed_at,record_catalog(record_code,title)').order('viewed_at', { ascending:false }).limit(5); if (error) throw error; return data.map(x=>x.record_catalog).filter(Boolean); },
    async report(userId, recordId, reason, detail) { const { error } = await getClient().from('reports').insert({ user_id:userId, record_id:recordId, reason, detail }); if (error) throw error; },
    async moderationCases() { const { data, error } = await getClient().rpc('get_moderation_dossiers'); if (error) throw error; return data || []; },
    async moderationVote(caseId, adminId, decision, note) { const { error } = await getClient().from('moderation_votes').insert({case_id:caseId,admin_id:adminId,decision,note}); if (error) throw error; }
  };
}());
