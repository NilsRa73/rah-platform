import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const manifest = JSON.parse(fs.readFileSync('RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.json', 'utf8'));
const html = fs.readFileSync('RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.html', 'utf8');
const lower = html.toLowerCase();

assert.equal(manifest.product, 'RAH Raven Care Hub');
assert.equal(manifest.version, '0.5.0-candidate');
assert.equal(manifest.stage, 'candidate');
assert.equal(manifest.released_from_stable, '0.4.0');
assert.equal(manifest.entry, 'RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.html');
assert.equal(manifest.stable_runtime_modified, false);
assert.equal(manifest.authority_delta, 'none');
assert.equal(manifest.integration.case_center.stable_version, '1.6.0');
assert.equal(manifest.integration.case_center.health_url, 'http://127.0.0.1:18765/health');
assert.deepEqual(manifest.integration.case_center.allowed_network_paths, ['/health']);
assert.equal(manifest.integration.case_center.explicit_refresh_only, true);
assert.equal(manifest.integration.case_center.case_extract_allowed, false);
assert.equal(manifest.integration.case_center.case_analyze_allowed, false);
assert.equal(manifest.integration.case_center.capture_allowed, false);
assert.equal(manifest.integration.case_center.lm_calls_allowed, false);
assert.equal(manifest.integration.fristvakt.stable_version, '0.2.0');
assert.equal(manifest.integration.fristvakt.required_product, 'RAH Raven Fristvakt');
assert.equal(manifest.integration.fristvakt.required_schema_version, 1);
assert.equal(manifest.integration.fristvakt.session_memory_only, true);
assert.equal(manifest.integration.fristvakt.automatic_persistence, false);
assert.equal(manifest.integration.fristvakt.browser_storage, false);
assert.equal(manifest.candidate_gate.stable_promotion_included, false);

for (const key of [
  'automatic_network_requests','background_polling','automatic_sending','automatic_calling',
  'medical_decision_automation','legal_decision_automation','ai_execution','file_upload_to_network',
  'microphone_capture','camera_capture','sensor_sync','stable_care_v0_1_modified',
  'stable_care_hub_v0_4_modified','stable_case_center_v1_6_modified','stable_fristvakt_v0_2_modified',
  'stable_health_fatigue_v0_2_modified','stable_fastlege_v0_3_modified','stable_raven_runtime_modified'
]) assert.equal(manifest.features[key], false, `${key} must remain false`);

const csp = html.match(/Content-Security-Policy" content="([^"]+)"/i)?.[1] ?? '';
assert.ok(csp.includes("default-src 'none'"));
assert.ok(csp.includes("script-src 'unsafe-inline'"));
assert.ok(csp.includes('connect-src http://127.0.0.1:18765'));
assert.ok(csp.includes("form-action 'none'"));
assert.ok(csp.includes("object-src 'none'"));
assert.ok(csp.includes("frame-src 'none'"));

const withoutAllowedOrigin = html.replaceAll('http://127.0.0.1:18765', '');
assert.equal(withoutAllowedOrigin.includes('http://'), false, 'foreign/insecure HTTP origin added');
assert.equal(withoutAllowedOrigin.includes('https://'), false, 'external HTTPS origin added');
assert.equal((html.match(/fetch\s*\(/g) ?? []).length, 1, 'exactly one explicit fetch call is allowed');
assert.ok(html.includes("fetch(CASE_HEALTH_URL,{method:'GET'"));
assert.ok(html.includes("const CASE_HEALTH_URL='http://127.0.0.1:18765/health'"));
assert.ok(html.includes("$('caseCheck').addEventListener('click',checkCaseCenter)"));
assert.equal(/checkCaseCenter\s*\(\s*\)\s*;/.test(html), false, 'Case Center health check must not auto-run');

for (const forbidden of [
  '/case/extract','/case/analyze','/capture/','/lm/','websocket','eventsource','sendbeacon',
  'localstorage','sessionstorage','indexeddb','setinterval(','settimeout(','getusermedia',
  'mediadevices','clipboard.write','eval(','new function(','xmlhttprequest'
]) assert.equal(lower.includes(forbidden), false, `forbidden browser/runtime authority: ${forbidden}`);

assert.ok(html.includes('id="fristFile" type="file"'));
assert.ok(html.includes("raw.product!=='RAH Raven Fristvakt'"));
assert.ok(html.includes("raw.version!=='0.2.0'"));
assert.ok(html.includes('raw.schema_version!==1'));
assert.ok(html.includes('MAX_JSON_BYTES=1024*1024'));
assert.ok(html.includes("const FRIST_FIELDS=['refDate','receivedDate','area','hasReply','hasRight','deadline','appointment','notified','note']"));
assert.ok(html.includes("source:'explicit-json-import'"));
assert.ok(html.includes("product:'RAH Raven Care Hub',version:'0.5.0-candidate'"));
assert.ok(html.includes("$('exportSnapshot').addEventListener('click',exportSnapshot)"));
assert.ok(html.includes("$('fristClear').addEventListener('click',clearFrist)"));

for (const localHref of [
  'RAH-RAVEN-CASE-CENTER.html','RAH-RAVEN-FRISTVAKT.html','RAH-RAVEN-HEALTH-FATIGUE.html','RAH-RAVEN-FASTLEGE.html'
]) assert.ok(html.includes(`href="${localHref}"`), `missing stable local navigation: ${localHref}`);

const scripts = [...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(m => m[1]);
assert.equal(scripts.length, 1, 'Candidate must have one auditable inline script');
new vm.Script(scripts[0], { filename: 'RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.inline.js' });

console.log('Raven Care Hub v0.5 Candidate boundary PASS');
