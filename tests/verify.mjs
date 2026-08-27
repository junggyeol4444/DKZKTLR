import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const read = path => fs.readFileSync(path, 'utf8');
const schema = read('sql/schema.sql');
const rls = read('sql/rls.sql');
const api = read('api.js');
const app = read('app.js');
const seed = read('sql/seed.sql');

assert.equal([...seed.matchAll(/'ARC-[A-Z]+-\d{6}'/g)].length, 30, 'seed must contain 30 records');
assert.match(schema, /create table public\.moderation_cases/);
assert.match(schema, /if total>=3/);
assert.match(schema, /hide_votes\*2>total/);
assert.doesNotMatch(schema, /set status='hidden' where id=new\.record_id/);
assert.match(schema, /create or replace function public\.get_related_records/);
assert.match(schema, /search_document tsvector not null/);
assert.match(schema, /create trigger refresh_record_search_before_write/);
assert.doesNotMatch(schema, /search_document[^\n]*generated always/);
assert.match(rls, /r\.author_id<>auth\.uid\(\)/, 'self-reporting and self-voting must be blocked');
assert.match(api, /\['published', 'under_review'\]/, 'reviewed records must stay visible');
assert.doesNotMatch(api, /record_catalog'\)\.select\('\*'\)/, 'search lexemes must not be returned to readers');
assert.doesNotMatch(api, /record_views'\)\.(?:insert|upsert)/, 'view counts must only be written by the reader RPC');
assert.doesNotMatch(api, /content_available:x\.records\.level<=2/, 'bookmark clearance must not be hard-coded');
assert.doesNotMatch(rls, /grant select on public\.records to authenticated/, 'records content must not receive table-wide SELECT');
assert.match(schema, /greatest\(6,length\(seq_no::text\)\)/);
assert.match(schema, /greatest\(3,length\(keeper_no::text\)\)/);
assert.match(app, /#\/edit\//);
assert.match(app, /data-action="translation"/);
assert.match(app, /data-action="load-more"/);
assert.match(app, /state\.session&&\['#\/welcome','#\/login','#\/signup'\]/, 'valid sessions must skip auth screens');
assert.ok(fs.existsSync('test/browser.mjs'), 'browser integration test missing');

const storageKeys = [...`${api}\n${app}`.matchAll(/localStorage\.(?:getItem|setItem)\(['"]([^'"]+)/g)].map(match => match[1]);
assert.deepEqual([...new Set(storageKeys)].sort(), ['akashic_lang', 'akashic_motion', 'akashic_sort']);
assert.doesNotMatch(`${api}\n${app}\n${read('supabase.js')}`, /eyJ[A-Za-z0-9_-]{20,}\.[A-Za-z0-9_-]{20,}/, 'JWT-like secret found in client code');

const context = { window: {} };
vm.runInNewContext(read('i18n.js'), context);
for (const lang of ['ko', 'en', 'ja']) {
  for (const key of ['archive', 'login', 'report', 'moderation', 'related', 'confirmDelete']) {
    assert.ok(context.window.I18N[lang][key], `${lang}.${key} translation missing`);
  }
}

console.log('Akashic structural, security, seed, and i18n checks passed.');
