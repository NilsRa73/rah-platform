import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const index = readFileSync(new URL('../index.html', import.meta.url), 'utf8');
const sync = readFileSync(new URL('../cloud-sync.js', import.meta.url), 'utf8');
const sql = readFileSync(new URL('../supabase/001_project_brain_sync.sql', import.meta.url), 'utf8');

assert.match(index, /cloud-sync\.js\?v=1\.0/, 'Command Center must load cloud-sync.js');
assert.match(index, /v1\.4 • ONLINE/, 'Command Center must advertise v1.4');

assert.match(sync, /rah_user_state/, 'Cloud module must use the expected table');
assert.match(sync, /lastLocalChange/, 'Cloud module must track local changes');
assert.match(sync, /upsert\(/, 'Cloud module must support first-write and update');
assert.match(sync, /Hent fra skyen/, 'Cloud module must expose manual recovery download');
assert.match(sync, /Bruk denne enheten/, 'Cloud module must expose manual recovery upload');

assert.match(sql, /enable row level security/i, 'RLS must be enabled');
assert.match(sql, /auth\.uid\(\) = user_id/g, 'Policies must scope access to auth.uid()');
assert.match(sql, /revoke all .* from anon/i, 'Anonymous table access must be revoked');
assert.match(sql, /on delete cascade/i, 'User deletion must remove the associated state');

console.log('RAH Project Brain Cloud Sync validation passed.');
