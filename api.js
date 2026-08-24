/* ============================================================
 *  AKASHIC RECORDS / api.js
 *  Supabase 질의 함수 모음 (4.5)
 *
 *  원칙
 *   - 읽기는 항상 뷰(v_records / v_my_records / v_bookmarks / v_recent_views)를 통합니다.
 *     records 테이블의 summary·content 컬럼은 클라이언트 롤에서 회수되어 있어,
 *     등급이 부족하면 값 자체가 응답에 담기지 않습니다. (7.1)
 *   - 개수는 모두 집계 뷰에서 받아옵니다. 하드코딩하지 않습니다. (4.6)
 *   - 클라이언트 검증은 편의를 위한 1차 방어이며, 최종 판정은 DB 트리거·RLS 가 합니다.
 * ============================================================ */

(function () {
  const { sb, configured } = window.AKASHIC_SB;

  const PAGE_SIZE = 20;

  /* ---------- 오류 정규화 (2.16) ---------- */
  class ApiError extends Error {
    constructor(code, raw) {
      super(code);
      this.code = code;      // network | session | forbidden | notfound | server | AKASHIC_* | unknown
      this.raw = raw || null;
    }
  }

  function normalize(error) {
    if (!error) return null;
    if (error instanceof ApiError) return error;

    const msg = String(error.message || error || '');
    const status = error.status || (error.originalError && error.originalError.status) || 0;
    const pgCode = error.code || '';

    // DB 트리거가 올린 업무 규칙 오류
    const m = msg.match(/AKASHIC_[A-Z_]+/);
    if (m) return new ApiError(m[0], error);

    if (msg.includes('Failed to fetch') || msg.includes('NetworkError') ||
        msg.includes('Load failed') || error.name === 'TypeError') {
      return new ApiError('network', error);
    }
    if (status === 401 || pgCode === 'PGRST301' || msg.toLowerCase().includes('jwt')) {
      return new ApiError('session', error);
    }
    if (status === 403 || pgCode === '42501') return new ApiError('forbidden', error);
    if (status === 404 || pgCode === 'PGRST116') return new ApiError('notfound', error);
    if (status >= 500) return new ApiError('server', error);
    if (pgCode === '23505') return new ApiError('duplicate', error);
    return new ApiError('unknown', error);
  }

  function guard() {
    if (!configured || !sb) throw new ApiError('config', null);
  }

  async function run(promise) {
    guard();
    let res;
    try {
      res = await promise;
    } catch (e) {
      throw normalize(e);
    }
    if (res.error) throw normalize(res.error);
    return res.data;
  }

  /* ============================================================
   *  인증
   * ============================================================ */
  const auth = {
    async getSession() {
      guard();
      const { data } = await sb.auth.getSession();
      return data.session || null;
    },

    onChange(cb) {
      guard();
      return sb.auth.onAuthStateChange((event, session) => cb(event, session));
    },

    async signIn(email, password) {
      guard();
      const { data, error } = await sb.auth.signInWithPassword({ email, password });
      if (error) {
        // 계정 존재 여부를 구분해 알려주지 않는다 (2.2)
        const unverified = /confirm|verif/i.test(error.message || '');
        throw new ApiError(unverified ? 'unverified' : 'badcredentials', error);
      }
      return data.session;
    },

    async signUp({ email, password, displayName, lang }) {
      guard();
      const { data, error } = await sb.auth.signUp({
        email,
        password,
        options: {
          data: { display_name: displayName, lang },
          emailRedirectTo: window.location.origin + window.location.pathname
        }
      });
      if (error) throw normalize(error);
      return data;
    },

    async resend(email) {
      guard();
      const { error } = await sb.auth.resend({
        type: 'signup',
        email,
        options: { emailRedirectTo: window.location.origin + window.location.pathname }
      });
      if (error) throw normalize(error);
    },

    async sendReset(email) {
      guard();
      // 결과와 무관하게 같은 안내를 보여주므로 오류는 삼킨다 (2.4)
      await sb.auth.resetPasswordForEmail(email, {
        redirectTo: window.location.origin + window.location.pathname + '#/reset-confirm'
      }).catch(() => {});
    },

    async updatePassword(password) {
      guard();
      const { error } = await sb.auth.updateUser({ password });
      if (error) throw normalize(error);
    },

    async signOut() {
      guard();
      await sb.auth.signOut().catch(() => {});
    },

    async myProfile() {
      const rows = await run(sb.rpc('get_my_profile'));
      return (rows && rows[0]) || null;
    }
  };

  /* ============================================================
   *  분류 체계
   * ============================================================ */
  const catalog = {
    planets() {
      return run(sb.from('planets').select('*').order('sort_order'));
    },
    categories() {
      return run(sb.from('categories').select('*').order('sort_order'));
    },
    async subcategories(planetId, categoryId) {
      let q = sb.from('subcategories').select('*').order('sort_order');
      if (categoryId) q = q.eq('category_id', categoryId);
      const rows = await run(q);
      if (!planetId) return rows;
      // planet_ids 가 빈 배열이면 전 행성 공용 (2.8)
      return rows.filter(r => !r.planet_ids || r.planet_ids.length === 0
                              || r.planet_ids.includes(planetId));
    }
  };

  /* ============================================================
   *  집계 (4.6) — 모두 DB 집계 뷰
   * ============================================================ */
  const counts = {
    async stats() {
      const rows = await run(sb.from('v_archive_stats').select('*'));
      return rows[0] || { total_records: 0, total_planets: 0, today_records: 0 };
    },
    async byPlanet() {
      const rows = await run(sb.from('v_planet_counts').select('*'));
      return Object.fromEntries(rows.map(r => [r.planet_id, r.record_count]));
    },
    async byCategory(planetId) {
      const rows = await run(
        sb.from('v_category_counts').select('*').eq('planet_id', planetId));
      return Object.fromEntries(rows.map(r => [r.category_id, r.record_count]));
    },
    async bySubcategory(planetId, categoryId) {
      const rows = await run(
        sb.from('v_subcategory_counts').select('*')
          .eq('planet_id', planetId).eq('category_id', categoryId));
      return Object.fromEntries(rows.map(
        r => [r.subcategory_id, { count: r.record_count, last: r.last_created_at }]));
    }
  };

  /* ============================================================
   *  기록
   * ============================================================ */
  const SORTS = {
    event_desc:   q => q.order('event_date', { ascending: false, nullsFirst: false })
                        .order('created_at', { ascending: false }),
    event_asc:    q => q.order('event_date', { ascending: true, nullsFirst: false })
                        .order('created_at', { ascending: true }),
    created_desc: q => q.order('created_at', { ascending: false }),
    level_desc:   q => q.order('level', { ascending: false })
                        .order('event_date', { ascending: false, nullsFirst: false }),
    title_asc:    (q, lang) => q.order('title_' + (['ko', 'en', 'ja'].includes(lang) ? lang : 'ko'),
                                       { ascending: true })
  };

  const records = {
    PAGE_SIZE,

    async list({ planetId, categoryId, subcategoryId, sort = 'event_desc', lang = 'ko',
                 offset = 0, limit = PAGE_SIZE }) {
      let q = sb.from('v_records').select('*').eq('status', 'published');
      if (planetId)      q = q.eq('planet_id', planetId);
      if (categoryId)    q = q.eq('category_id', categoryId);
      if (subcategoryId) q = q.eq('subcategory_id', subcategoryId);
      q = (SORTS[sort] || SORTS.event_desc)(q, lang);
      q = q.range(offset, offset + limit - 1);
      return run(q);
    },

    async byCode(code) {
      const rows = await run(
        sb.from('v_records').select('*').eq('record_code', code).limit(1));
      if (!rows || !rows.length) throw new ApiError('notfound', null);
      return rows[0];
    },

    async byId(id) {
      const rows = await run(sb.from('v_records').select('*').eq('id', id).limit(1));
      if (!rows || !rows.length) throw new ApiError('notfound', null);
      return rows[0];
    },

    /* 관련 기록: 존재·상태 필터와 자동 보충은 DB 함수가 담당 (4.9(3), 4.10) */
    related(id, limit = 5) {
      return run(sb.rpc('get_related_records', { p_record_id: id, p_limit: limit }));
    },

    mine() {
      return run(sb.from('v_my_records').select('*').order('created_at', { ascending: false }));
    },

    search(q, offset = 0, limit = PAGE_SIZE) {
      return run(sb.rpc('search_records', { p_q: q, p_limit: limit, p_offset: offset }));
    },

    /* 등록: record_code / author_id / created_at 은 서버가 정합니다 (2.11) */
    async create(payload) {
      guard();
      const { error } = await sb.from('records').insert(payload);
      if (error) throw normalize(error);
    },

    async update(id, payload) {
      guard();
      const { error } = await sb.from('records').update(payload).eq('id', id);
      if (error) throw normalize(error);
    },

    /* 소프트 삭제 (4.9(1)) */
    async remove(id) {
      return run(sb.rpc('soft_delete_record', { p_record_id: id }));
    }
  };

  /* ============================================================
   *  북마크 / 최근 조회 / 신고
   * ============================================================ */
  const bookmarks = {
    list() {
      return run(sb.from('v_bookmarks').select('*').order('bookmarked_at', { ascending: false }));
    },
    async add(recordId, userId) {
      guard();
      const { error } = await sb.from('bookmarks')
        .insert({ user_id: userId, record_id: recordId });
      if (error && error.code !== '23505') throw normalize(error);
    },
    async remove(recordId, userId) {
      guard();
      const { error } = await sb.from('bookmarks').delete()
        .eq('user_id', userId).eq('record_id', recordId);
      if (error) throw normalize(error);
    }
  };

  const views = {
    touch(recordId) {
      return run(sb.rpc('touch_record_view', { p_record_id: recordId }));
    },
    recent(limit = 5) {
      return run(sb.from('v_recent_views').select('*')
                   .order('viewed_at', { ascending: false }).limit(limit));
    }
  };

  const reports = {
    async add(recordId, userId, reason, detail) {
      guard();
      const { error } = await sb.from('reports').insert({
        record_id: recordId, user_id: userId, reason, detail: detail || null
      });
      if (error) throw normalize(error);
    }
  };

  window.AKASHIC_API = { ApiError, auth, catalog, counts, records, bookmarks, views, reports, PAGE_SIZE };
})();
