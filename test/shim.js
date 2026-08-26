/* ============================================================
 *  테스트 전용 Supabase 호환 셔임 (PostgREST + GoTrue 최소 구현)
 *
 *  로컬 PostgreSQL 에 직접 붙어, 프론트엔드가 실제 Supabase 를 쓸 때와
 *  같은 경로로 RLS·트리거·컬럼 권한을 그대로 통과하게 한다.
 *  운영에는 절대 쓰지 않는다. 인증은 흉내만 내며 JWT 서명을 검증하지 않는다.
 *
 *  환경 변수
 *    AKASHIC_ROOT   정적 파일 루트   (기본: 이 파일의 상위 디렉터리)
 *    PGSOCKET       PostgreSQL 소켓 디렉터리
 *    PGPORT_TEST    PostgreSQL 포트
 *    SHIM_PORT      셔임 포트        (기본 5555)
 *    SUPABASE_UMD   supabase-js UMD 번들 경로
 * ============================================================ */
const http = require('http');
const fs   = require('fs');
const path = require('path');
const { Pool } = require(process.env.PG_MODULE || 'pg');

const ROOT = process.env.AKASHIC_ROOT || path.resolve(__dirname, '..');
const ANON = 'ANON-KEY-TEST';
const PORT = Number(process.env.SHIM_PORT || 5555);
const UMD  = process.env.SUPABASE_UMD ||
             path.join(__dirname, 'node_modules/@supabase/supabase-js/dist/umd/supabase.js');
const pool = new Pool({
  host: process.env.PGSOCKET || '/tmp/akashic-pg',
  port: Number(process.env.PGPORT_TEST || 5439),
  user: process.env.PGUSER || 'postgres',
  password: process.env.PGPASSWORD || undefined,
  database: process.env.PGDATABASE || 'postgres'
});

const b64u = o => Buffer.from(JSON.stringify(o)).toString('base64url');
function mkJwt(user, seconds) {
  const now = Math.floor(Date.now() / 1000);
  return b64u({ alg: 'HS256', typ: 'JWT' }) + '.' +
         b64u({ sub: user.id, email: user.email, role: 'authenticated', aud: 'authenticated',
                iat: now, exp: now + (seconds || 3600) }) + '.sig';
}
function decodeSub(tok) {
  try {
    const p = JSON.parse(Buffer.from(tok.split('.')[1], 'base64url').toString());
    return (p.exp && p.exp * 1000 < Date.now()) ? null : p.sub;
  } catch (_) { return null; }
}

const IDENT = /^[a-z_][a-z0-9_]*$/;
/* 배열은 pg 드라이버가 직접 처리하고, 그 밖의 객체만 jsonb 문자열로 넘긴다 */
const toParam = v => (v !== null && typeof v === 'object' && !Array.isArray(v)) ? JSON.stringify(v) : v;
const send = (res, code, obj, hdrs) => {
  res.writeHead(code, Object.assign({
    'content-type': 'application/json',
    'access-control-allow-origin': '*',
    'access-control-allow-headers': '*',
    'access-control-expose-headers': 'content-range'
  }, hdrs || {}));
  res.end(obj === undefined ? '' : JSON.stringify(obj));
};

function pgErr(res, e) {
  const m = String(e.message || e);
  if (/AKASHIC_[A-Z_]+/.test(m)) return send(res, 400, { message: m, code: 'P0001', details: null, hint: null });
  if (e.code === '23505') return send(res, 409, { message: m, code: '23505' });
  if (e.code === '42501') return send(res, 403, { message: m, code: '42501' });
  console.error('[db]', m);
  return send(res, 500, { message: m, code: e.code || 'XX000' });
}

async function withRole(sub, fn) {
  const c = await pool.connect();
  try {
    await c.query('begin');
    if (sub) {
      await c.query("select set_config('role','authenticated',true)");
      await c.query("select set_config('request.jwt.claim.sub',$1,true)", [sub]);
    } else {
      await c.query("select set_config('role','anon',true)");
      await c.query("select set_config('request.jwt.claim.sub','',true)");
    }
    const r = await fn(c);
    await c.query('commit');
    return r;
  } catch (e) { await c.query('rollback').catch(() => {}); throw e; }
  finally { c.release(); }
}

function buildFilters(params, startIdx) {
  const where = []; const vals = []; let i = startIdx;
  for (const [k, v] of params) {
    if (['select', 'order', 'limit', 'offset', 'columns'].includes(k)) continue;
    if (!IDENT.test(k)) continue;
    const m = String(v).match(/^(eq|neq|gt|gte|lt|lte|like|ilike|is)\.(.*)$/s);
    if (!m) continue;
    const ops = { eq: '=', neq: '<>', gt: '>', gte: '>=', lt: '<', lte: '<=', like: 'like', ilike: 'ilike' };
    if (m[1] === 'is') { where.push(`"${k}" is ${m[2] === 'null' ? 'null' : 'not null'}`); continue; }
    where.push(`"${k}" ${ops[m[1]]} $${i++}`); vals.push(m[2]);
  }
  return { sql: where.length ? ' where ' + where.join(' and ') : '', vals, next: i };
}

function buildOrder(params) {
  const o = params.get('order');
  if (!o) return '';
  const parts = o.split(',').map(seg => {
    const [col, dir, nulls] = seg.split('.');
    if (!IDENT.test(col)) return null;
    return `"${col}" ${dir === 'desc' ? 'desc' : 'asc'} ` +
           (nulls === 'nullsfirst' ? 'nulls first' : nulls === 'nullslast' ? 'nulls last' : '');
  }).filter(Boolean);
  return parts.length ? ' order by ' + parts.join(', ') : '';
}

const readBody = req => new Promise(r => {
  let b = ''; req.on('data', d => b += d); req.on('end', () => { try { r(b ? JSON.parse(b) : null); } catch (_) { r(null); } });
});

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json' };

http.createServer(async (req, res) => {
  const u = new URL(req.url, 'http://x');
  const p = u.pathname;
  if (req.method === 'OPTIONS') return send(res, 204);

  const authz = (req.headers.authorization || '').replace(/^Bearer\s+/i, '');
  const sub = (authz && authz !== ANON) ? decodeSub(authz) : null;

  try {
    /* ---------- GoTrue ---------- */
    if (p === '/auth/v1/signup' && req.method === 'POST') {
      const b = await readBody(req);
      const meta = (b.data || {});
      const r = await pool.query(
        `insert into auth.users (instance_id,id,aud,role,email,encrypted_password,
           raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
         values ('00000000-0000-0000-0000-000000000000', gen_random_uuid(),'authenticated','authenticated',
                 $1, crypt($2, gen_salt('bf')), '{}', $3::jsonb, now(), now())
         returning id, email`, [b.email, b.password, JSON.stringify(meta)]);
      return send(res, 200, { user: { id: r.rows[0].id, email: r.rows[0].email }, session: null });
    }

    if (p === '/auth/v1/token' && req.method === 'POST') {
      const b = await readBody(req);
      if (u.searchParams.get('grant_type') === 'refresh_token') {
        // refresh_token 에 사용자 id 를 담아 두고 그 사용자로만 재발급한다.
        // 아무 사용자나 돌려주면 갱신 경로를 검사하는 의미가 없어진다.
        const id = String(b && b.refresh_token || '').replace(/^rt:/, '');
        const r = await pool.query('select id, email from auth.users where id = $1', [id]);
        if (!r.rows.length) {
          return send(res, 400, { error: 'invalid_grant', message: 'Invalid Refresh Token' });
        }
        const user = { id: r.rows[0].id, email: r.rows[0].email,
                       aud: 'authenticated', role: 'authenticated' };
        return send(res, 200, { access_token: mkJwt(user), token_type: 'bearer', expires_in: 3600,
                                refresh_token: 'rt:' + user.id, user });
      }
      const r = await pool.query(
        `select id, email, email_confirmed_at,
                (encrypted_password = crypt($2, encrypted_password)) as ok
           from auth.users where email = $1`, [b.email, b.password]);
      if (!r.rows.length || !r.rows[0].ok) {
        return send(res, 400, { error: 'invalid_grant', error_description: 'Invalid login credentials',
                                message: 'Invalid login credentials', code: 'invalid_credentials' });
      }
      if (!r.rows[0].email_confirmed_at) {
        return send(res, 400, { error: 'invalid_grant', error_description: 'Email not confirmed',
                                message: 'Email not confirmed', error_code: 'email_not_confirmed' });
      }
      const user = { id: r.rows[0].id, email: r.rows[0].email, aud: 'authenticated', role: 'authenticated' };
      return send(res, 200, { access_token: mkJwt(user), token_type: 'bearer', expires_in: 3600,
                              refresh_token: 'rt:' + user.id, user });
    }

    if (p === '/auth/v1/user') {
      if (req.method === 'PUT') {
        const b = await readBody(req);
        if (b.password) await pool.query(
          'update auth.users set encrypted_password = crypt($1, gen_salt($2)) where id = $3',
          [b.password, 'bf', sub]);
        const r = await pool.query('select id, email from auth.users where id = $1', [sub]);
        return send(res, 200, r.rows[0] || {});
      }
      const r = await pool.query('select id, email from auth.users where id = $1', [sub]);
      if (!r.rows.length) return send(res, 401, { message: 'invalid claim' });
      return send(res, 200, r.rows[0]);
    }

    if (p === '/auth/v1/logout') return send(res, 204);
    if (p === '/auth/v1/recover' || p === '/auth/v1/resend') return send(res, 200, {});

    /* 테스트 편의: 이메일 인증 완료 시뮬레이션 */
    if (p === '/test/confirm') {
      await pool.query('update auth.users set email_confirmed_at = now() where email = $1',
                       [u.searchParams.get('email')]);
      return send(res, 200, { ok: true });
    }

    /* ---------- PostgREST ---------- */
    if (p.startsWith('/rest/v1/')) {
      const rest = p.slice('/rest/v1/'.length);

      if (rest.startsWith('rpc/')) {
        const fn = rest.slice(4);
        if (!IDENT.test(fn)) return send(res, 404, { message: 'not found' });
        const args = (await readBody(req)) || {};
        const keys = Object.keys(args).filter(k => IDENT.test(k));
        const sql = `select * from public."${fn}"(` +
          keys.map((k, i) => `"${k}" => $${i + 1}`).join(', ') + ')';
        const out = await withRole(sub, c => c.query(sql, keys.map(k => args[k])));
        return send(res, 200, out.rows);
      }

      if (!IDENT.test(rest)) return send(res, 404, { message: 'not found' });
      const params = Array.from(u.searchParams.entries());

      if (req.method === 'GET') {
        const f = buildFilters(params, 1);
        // select= 를 그대로 반영한다. 모든 컬럼을 읽어 버리면
        // 컬럼 단위로 회수한 권한이 검사에 걸리지 않아, 실제로는 되는 조회가 여기서만 막힌다.
        const sel = u.searchParams.get('select');
        let cols = '*';
        if (sel && sel !== '*') {
          const names = sel.split(',').map(x => x.split(':').pop().trim())
                           .filter(x => IDENT.test(x));
          if (names.length) cols = names.map(x => `"${x}"`).join(', ');
        }
        let sql = `select ${cols} from public."${rest}"` + f.sql + buildOrder(u.searchParams);
        const lim = u.searchParams.get('limit'), off = u.searchParams.get('offset');
        if (lim && /^\d+$/.test(lim)) sql += ' limit ' + lim;
        if (off && /^\d+$/.test(off)) sql += ' offset ' + off;
        const out = await withRole(sub, c => c.query(sql, f.vals));
        return send(res, 200, out.rows);
      }

      if (req.method === 'POST') {
        const b = await readBody(req);
        const rows = Array.isArray(b) ? b : [b];
        await withRole(sub, async c => {
          for (const row of rows) {
            const cols = Object.keys(row).filter(k => IDENT.test(k));
            await c.query(
              `insert into public."${rest}" (${cols.map(k => `"${k}"`).join(',')}) values (` +
              cols.map((_, i) => `$${i + 1}`).join(',') + ')',
              cols.map(k => toParam(row[k])));
          }
        });
        return send(res, 201, undefined);
      }

      if (req.method === 'PATCH') {
        const b = await readBody(req);
        const cols = Object.keys(b).filter(k => IDENT.test(k));
        const setSql = cols.map((k, i) => `"${k}" = $${i + 1}`).join(', ');
        const f = buildFilters(params, cols.length + 1);
        await withRole(sub, c => c.query(
          `update public."${rest}" set ${setSql}` + f.sql,
          cols.map(k => toParam(b[k])).concat(f.vals)));
        return send(res, 204, undefined);
      }

      if (req.method === 'DELETE') {
        const f = buildFilters(params, 1);
        await withRole(sub, c => c.query(`delete from public."${rest}"` + f.sql, f.vals));
        return send(res, 204, undefined);
      }
      return send(res, 405, { message: 'method not allowed' });
    }

    /* ---------- 정적 파일 ---------- */
    let file = p === '/' ? '/index.html' : p;
    if (file === '/__supabase.js') file = null;
    const abs = file ? path.join(ROOT, path.normalize(file).replace(/^(\.\.[/\\])+/, '')) : null;
    if (p === '/__supabase.js') {
      const js = fs.readFileSync(UMD);
      res.writeHead(200, { 'content-type': 'text/javascript' }); return res.end(js);
    }
    if (abs && fs.existsSync(abs) && fs.statSync(abs).isFile()) {
      res.writeHead(200, { 'content-type': MIME[path.extname(abs)] || 'text/plain' });
      return res.end(fs.readFileSync(abs));
    }
    return send(res, 404, { message: 'not found' });
  } catch (e) { return pgErr(res, e); }
}).listen(PORT, '127.0.0.1', () => console.log('shim on ' + PORT));
