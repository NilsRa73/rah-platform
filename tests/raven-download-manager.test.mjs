import assert from 'node:assert/strict';
import fs from 'node:fs';

const manager = fs.readFileSync('desktop-bridge/download_manager.py', 'utf8');
const bridge = fs.readFileSync('desktop-bridge/raven_bridge.py', 'utf8');
const wheel = fs.readFileSync('RAH-RAVEN-WHEEL.user.js', 'utf8');
const dashboard = fs.readFileSync('RAH-RAVEN-DOWNLOADS.html', 'utf8');

assert.match(manager, /DOWNLOAD_MANAGER_VERSION = "0\.1\.1"/);
assert.match(manager, /"mode": "chatgpt-expected-only"/);
assert.match(manager, /@app\.post\("\/downloads\/expect"\)/);
assert.match(manager, /@app\.post\("\/downloads\/scan"\)/);
assert.match(manager, /@app\.get\("\/downloads\/recent"\)/);
assert.match(manager, /@app\.get\("\/downloads\/search"\)/);
assert.match(manager, /@app\.post\("\/downloads\/open-file"\)/);
assert.match(manager, /if not expectations:/);
assert.match(manager, /_matches_expectation/);
assert.match(manager, /_is_stable/);
assert.match(manager, /shutil\.move/);
assert.match(manager, /confirm=true kreves for manuell skanning/);
assert.doesNotMatch(manager, /rglob\("\*"\)/);
assert.doesNotMatch(manager, /unlink\(/);
assert.doesNotMatch(manager, /rmtree\(/);

assert.match(bridge, /import download_manager/);
assert.match(bridge, /"\/downloads\/"/);
assert.match(bridge, /"download_manager": True/);
assert.match(bridge, /"download_manager_mode": "chatgpt-expected-only"/);

assert.match(wheel, /@name\s+RAH Raven Wheel v1\.1/);
assert.match(wheel, /@version\s+1\.1\.0/);
assert.match(wheel, /@match\s+https:\/\/chatgpt\.com\/\*/);
assert.match(wheel, /@connect\s+127\.0\.0\.1/);
assert.match(wheel, /GM_xmlhttpRequest/);
assert.match(wheel, /\/downloads\/expect/);
assert.match(wheel, /\/downloads\/recent/);
assert.match(wheel, /\/downloads\/open-vault/);
assert.match(wheel, /registerExpectedDownload/);
assert.match(wheel, /data-action="command"/);
assert.match(wheel, /data-action="mission"/);
assert.match(wheel, /data-action="doctor"/);
assert.match(wheel, /\?view=missions/);
assert.match(wheel, /\?view=settings&health=run/);
assert.match(wheel, /document\.addEventListener\('click'/);
assert.doesNotMatch(wheel, /preventDefault\(\)/);

assert.match(dashboard, /RAH RAVEN VAULT/);
assert.match(dashboard, /chatgpt-expected-only|forventet ChatGPT-nedlasting/i);
assert.match(dashboard, /\/downloads\/search/);
assert.match(dashboard, /\/downloads\/open-file/);
assert.match(dashboard, /Pause automatikk/);

console.log('Raven Download Manager + Wheel v1 validation passed.');
