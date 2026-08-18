import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source = fs.readFileSync('vision-module.js', 'utf8');

const defaultLine = source.match(/const DEFAULT_ENDPOINT = "http:\/\/127\.0\.0\.1:1234\/v1";/)?.[0];
const hostsLine = source.match(/const LOOPBACK_HOSTS = new Set\(\["127\.0\.0\.1", "localhost", "\[::1\]", "::1"\]\);/)?.[0];
assert.ok(defaultLine, 'legacy Vision default loopback endpoint missing');
assert.ok(hostsLine, 'legacy Vision exact loopback host allowlist missing');

const start = source.indexOf('  function normalizeEndpoint(value) {');
const end = source.indexOf('\n\n  function saveSettings()', start);
assert.ok(start >= 0 && end > start, 'normalizeEndpoint function could not be isolated');
const normalizeSource = source.slice(start, end);

const notices = [];
const context = {
  URL,
  Set,
  String,
  notices,
  notifyUser: text => notices.push(String(text)),
  normalize: null
};
vm.createContext(context);
vm.runInContext(`${defaultLine}\n${hostsLine}\n${normalizeSource}\nnormalize = normalizeEndpoint;`, context);
const normalize = context.normalize;
const DEFAULT = 'http://127.0.0.1:1234/v1';

const allowed = new Map([
  ['', DEFAULT],
  ['http://127.0.0.1:1234', DEFAULT],
  ['http://127.0.0.1:1234/v1/', DEFAULT],
  ['http://localhost:1234', 'http://localhost:1234/v1'],
  ['https://localhost:9443/v1/', 'https://localhost:9443/v1'],
  ['http://[::1]:1234', 'http://[::1]:1234/v1']
]);
for (const [input, expected] of allowed) {
  assert.equal(normalize(input), expected, `loopback endpoint should be allowed: ${input || '<empty>'}`);
}

const blocked = [
  'https://example.com/v1',
  'http://192.168.1.10:1234/v1',
  'http://10.0.0.2:1234/v1',
  'http://127.0.0.1.evil.example:1234/v1',
  'http://user:pass@127.0.0.1:1234/v1',
  'http://127.0.0.1:1234/v1?model=evil',
  'http://127.0.0.1:1234/v1#fragment',
  'http://127.0.0.1:1234/other',
  'ws://127.0.0.1:1234/v1',
  'file:///tmp/v1',
  'not a url'
];
for (const input of blocked) {
  assert.equal(normalize(input), DEFAULT, `unsafe endpoint must fail closed to default loopback: ${input}`);
}
assert.ok(notices.length >= blocked.length, 'blocked endpoints must produce a visible user notice');

const normalizedUseCount = (source.match(/const base = normalizeEndpoint\(endpointInput\.value\);/g) || []).length;
assert.equal(normalizedUseCount, 2, 'model discovery and image analysis must both use the boundary normalizer');
assert.match(source, /fetchJson\(`\$\{base\}\/models`\)/);
assert.match(source, /fetchJson\(`\$\{base\}\/chat\/completions`, \{/);
assert.doesNotMatch(normalizeSource, /return\s+raw\s*;/, 'normalizer must never return unchecked raw input');

// Active legacy full-page Vision compatibility surface.
const html = fs.readFileSync('vision.html', 'utf8');
assert.match(html, /id="bridgeUrl" value="http:\/\/127\.0\.0\.1:18765"/);
assert.doesNotMatch(html, /:8765(?:\D|$)/, 'active legacy Vision page must not reference retired Bridge port 8765');
assert.doesNotMatch(html, /normalizeUrl\(/, 'active legacy Vision page must not retain a free-form URL normalizer');

const htmlLmDefault = html.match(/const DEFAULT_LM_URL = 'http:\/\/127\.0\.0\.1:1234';/)?.[0];
const htmlBridgeDefault = html.match(/const DEFAULT_BRIDGE_URL = 'http:\/\/127\.0\.0\.1:18765';/)?.[0];
const htmlHostsLine = html.match(/const LOOPBACK_HOSTS = new Set\(\['127\.0\.0\.1','localhost','\[::1\]','::1'\]\);/)?.[0];
assert.ok(htmlLmDefault, 'vision.html LM default missing');
assert.ok(htmlBridgeDefault, 'vision.html Bridge default missing');
assert.ok(htmlHostsLine, 'vision.html exact loopback allowlist missing');

const htmlNormalizeStart = html.indexOf('  function normalizeLocalBase(value,fallback){');
const htmlNormalizeEnd = html.indexOf('\n  function setStatus(', htmlNormalizeStart);
assert.ok(htmlNormalizeStart >= 0 && htmlNormalizeEnd > htmlNormalizeStart, 'vision.html normalizeLocalBase could not be isolated');
const htmlNormalizeSource = html.slice(htmlNormalizeStart, htmlNormalizeEnd);
const htmlContext = { URL, Set, String, normalizeLocal: null };
vm.createContext(htmlContext);
vm.runInContext(`${htmlLmDefault}\n${htmlBridgeDefault}\n${htmlHostsLine}\n${htmlNormalizeSource}\nnormalizeLocal = normalizeLocalBase;`, htmlContext);
const normalizeLocal = htmlContext.normalizeLocal;

const allowedLocalBases = new Map([
  ['', 'http://127.0.0.1:1234'],
  ['http://127.0.0.1:1234', 'http://127.0.0.1:1234'],
  ['http://localhost:1234/', 'http://localhost:1234'],
  ['https://localhost:9443', 'https://localhost:9443'],
  ['http://[::1]:1234/', 'http://[::1]:1234']
]);
for (const [input, expected] of allowedLocalBases) {
  const result = normalizeLocal(input, 'http://127.0.0.1:1234');
  assert.equal(result.value, expected, `vision.html loopback base should be allowed: ${input || '<empty>'}`);
  assert.equal(result.blocked, false, `allowed loopback base must not be marked blocked: ${input || '<empty>'}`);
}

const blockedLocalBases = [
  'https://example.com',
  'http://192.168.1.10:1234',
  'http://10.0.0.2:1234',
  'http://127.0.0.1.evil.example:1234',
  'http://user:pass@127.0.0.1:1234',
  'http://127.0.0.1:1234?model=evil',
  'http://127.0.0.1:1234#fragment',
  'http://127.0.0.1:1234/v1',
  'http://localhost:18765/capture',
  'ws://127.0.0.1:1234',
  'file:///tmp/vision',
  'not a url'
];
for (const input of blockedLocalBases) {
  const result = normalizeLocal(input, 'http://127.0.0.1:1234');
  assert.equal(result.value, 'http://127.0.0.1:1234', `unsafe vision.html base must fail closed: ${input}`);
  assert.equal(result.blocked, true, `unsafe vision.html base must be marked blocked: ${input}`);
}
const bridgeBlocked = normalizeLocal('https://example.com', 'http://127.0.0.1:18765');
assert.equal(bridgeBlocked.value, 'http://127.0.0.1:18765');
assert.equal(bridgeBlocked.blocked, true);

assert.match(html, /normalizeLocalBase\(\$\('lmUrl'\)\.value,DEFAULT_LM_URL\)/);
assert.match(html, /normalizeLocalBase\(\$\('bridgeUrl'\)\.value,DEFAULT_BRIDGE_URL\)/);
assert.match(html, /Ekstern eller ugyldig adresse blokkert\. Bare lokal loopback er tillatt\./);
assert.match(html, /fetchJson\(`\$\{state\.bridgeUrl\}\/capture\/active-window`/);
assert.match(html, /fetchJson\(`\$\{state\.bridgeUrl\}\/health`/);
assert.match(html, /fetchJson\(`\$\{state\.lmUrl\}\/v1\/models`/);
assert.match(html, /fetchJson\(`\$\{state\.lmUrl\}\/v1\/chat\/completions`/);

for (const name of ['captureBridge','testBridge','discoverModels','analyze']) {
  const functionStart = html.indexOf(`async function ${name}(`);
  assert.ok(functionStart >= 0, `vision.html ${name} function missing`);
  const nextFunction = html.indexOf('\n  async function ', functionStart + 20);
  const block = html.slice(functionStart, nextFunction > functionStart ? nextFunction : html.indexOf('\n  function ', functionStart + 20));
  const persistIndex = block.indexOf('persistSettings();');
  const fetchIndex = block.indexOf('fetchJson(');
  assert.ok(persistIndex >= 0, `${name} must normalize persisted settings before network access`);
  if (fetchIndex >= 0) assert.ok(persistIndex < fetchIndex, `${name} must normalize before fetchJson`);
}

// Frozen compatibility shell and manual setup must follow the same canonical Bridge route.
const shell = fs.readFileSync('index.html', 'utf8');
const readme = fs.readFileSync('README.md', 'utf8');
const bridgeServer = fs.readFileSync('desktop-bridge/server_v16.py', 'utf8');
const canonicalBridge = fs.readFileSync('desktop-bridge/raven_bridge.py', 'utf8');
assert.match(shell, /"http:\/\/127\.0\.0\.1:18765\/capture\/active-window"/);
assert.doesNotMatch(shell, /:8765(?:\D|$)/, 'compatibility shell must not call retired Bridge port 8765');
assert.match(readme, /python raven_bridge\.py/);
assert.match(readme, /http:\/\/127\.0\.0\.1:18765\/health/);
assert.match(readme, /http:\/\/127\.0\.0\.1:18765\/capture\/active-window/);
assert.doesNotMatch(readme, /python server\.py/);
assert.doesNotMatch(readme, /:8765(?:\D|$)/, 'manual Bridge setup must not document retired port 8765');
assert.match(bridgeServer, /@app\.get\("\/capture\/active-window"\)\ndef active_window\(\):/);
assert.match(canonicalBridge, /from server_v17 import APP_VERSION, HOST, PORT, app/);

console.log('Legacy RAH Vision compatibility: module, full-page UI, frozen shell and manual setup are aligned to local-only canonical Bridge endpoints.');
