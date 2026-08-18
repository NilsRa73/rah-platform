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

console.log('Legacy RAH Vision v1.4: loopback-only endpoint boundary is enforced before model discovery and image analysis.');
