import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';

const read = path => fs.readFileSync(path, 'utf8');
const htmlPath = 'RAH-RAVEN-CARE-HUB-V0.4-STABLE.html';
const manifestPath = 'RAH-RAVEN-CARE-HUB-V0.4-STABLE.json';
const html = read(htmlPath);
const manifest = JSON.parse(read(manifestPath));

assert.equal(manifest.product, 'RAH Raven Care Hub');
assert.equal(manifest.parent, 'RAH Raven Care');
assert.equal(manifest.version, '0.4.0');
assert.equal(manifest.stage, 'stable');
assert.equal(manifest.entry, 'RAH-RAVEN-CARE-HUB.html');
assert.equal(manifest.data_policy, 'navigation-only-no-data');
assert.equal(manifest.release_gate.status, 'passed');
assert.equal(manifest.release_gate.gate_version, '1.0.0');
assert.equal(manifest.release_gate.runtime_feature_change, false);
assert.equal(manifest.release_gate.change_policy, 'bugfix-only-until-explicit-reopen');
assert.equal(manifest.release_gate.runtime_files_frozen, true);
assert.equal(manifest.stable_since, '2026-08-15');
assert.equal(manifest.development_paused, true);
assert.equal(manifest.change_policy, 'bugfix-only-until-explicit-reopen');

for (const [key, value] of Object.entries({
  single_care_entrypoint: true,
  case_center_link: true,
  fristvakt_link: true,
  health_fatigue_link: true,
  fastlege_link: true,
  relative_local_links_only: true,
  external_urls: false,
  scripts: false,
  network_requests: false,
  browser_storage: false,
  automatic_persistence: false,
  data_input: false,
  file_upload: false,
  microphone_capture: false,
  camera_capture: false,
  sensor_sync: false,
  automatic_sending: false,
  ai_execution: false,
  background_polling: false,
  medical_decision_automation: false,
  legal_decision_automation: false,
  care_v0_1_runtime_modified: false,
  case_center_v1_6_runtime_modified: false,
  fristvakt_v0_2_runtime_modified: false,
  health_fatigue_v0_2_runtime_modified: false,
  fastlege_v0_3_runtime_modified: false,
  stable_raven_runtime_modified: false
})) assert.equal(manifest.features[key], value, key);

const bytes = fs.readFileSync(htmlPath);
const gitBlobSha = crypto.createHash('sha1')
  .update(Buffer.from(`blob ${bytes.length}\0`))
  .update(bytes)
  .digest('hex');
assert.equal(gitBlobSha, '7626087d3a8d873885b0e33ca477a76307255a88');

const manifestBytes = fs.readFileSync(manifestPath);
const manifestBlobSha = crypto.createHash('sha1')
  .update(Buffer.from(`blob ${manifestBytes.length}\0`))
  .update(manifestBytes)
  .digest('hex');
assert.equal(manifestBlobSha, '056efc87eb73b3efd9d8409571ef9e9338684bf5');

const requiredTargets = [
  'RAH-RAVEN-CASE-CENTER.html',
  'RAH-RAVEN-FRISTVAKT.html',
  'RAH-RAVEN-HEALTH-FATIGUE.html',
  'RAH-RAVEN-FASTLEGE.html',
  'RAH-RAVEN-START.html'
];
for (const target of requiredTargets) assert.equal(fs.existsSync(target), true, target);

assert.match(html, /<title>RAH Raven Care Hub v0\.4<\/title>/);
assert.match(html, /Én inngang til hele Care-familien/);
assert.match(html, /NAVIGATION ONLY · NO DATA INPUT · NO NETWORK · NO STORAGE/);
assert.doesNotMatch(html, /\bCANDIDATE\b/i);
for (const target of requiredTargets) assert.match(html, new RegExp(target.replaceAll('.', '\\.')));
assert.match(html, /connect-src 'none'/);
assert.match(html, /script-src 'none'/);
assert.match(html, /form-action 'none'/);

const hrefs = [...html.matchAll(/href="([^"]+)"/g)].map(match => match[1]);
assert.deepEqual(new Set(hrefs), new Set(requiredTargets));
assert.equal(hrefs.every(href => !/^[a-z][a-z0-9+.-]*:/i.test(href) && !href.startsWith('//')), true);

assert.doesNotMatch(html, /<script\b/i);
assert.doesNotMatch(html, /<form\b|<input\b|<textarea\b|<select\b|<button\b/i);
assert.doesNotMatch(html, /<iframe\b|<object\b|<embed\b/i);
assert.doesNotMatch(html, /fetch\s*\(|XMLHttpRequest|WebSocket\s*\(|EventSource\s*\(|sendBeacon\s*\(|RTCPeerConnection/i);
assert.doesNotMatch(html, /localStorage|sessionStorage|indexedDB|CacheStorage|caches\./i);
assert.doesNotMatch(html, /navigator\.mediaDevices|getUserMedia|navigator\.bluetooth|navigator\.usb|navigator\.serial|Geolocation|watchPosition/i);
assert.doesNotMatch(html, /setInterval\s*\(|setTimeout\s*\(/i);
assert.doesNotMatch(html, /https?:\/\//i);

console.log('RAH Raven Care Hub v0.4 historical rollback boundary PASS.');
