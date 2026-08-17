import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import vm from 'node:vm';

const read = path => fs.readFileSync(path, 'utf8');
const bytes = path => fs.readFileSync(path);
const json = path => JSON.parse(read(path));
const blobSha = buffer => crypto.createHash('sha1').update(Buffer.from(`blob ${buffer.length}\0`)).update(buffer).digest('hex');

const stableHtml = read('RAH-RAVEN-CARE-HUB.html');
const candidateHtml = read('RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.html');
const stableManifest = json('RAH-RAVEN-CARE-HUB-VERSION.json');
const candidateManifest = json('RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.json');
const readiness = json('RAH-RAVEN-CARE-HUB-V0.5-STABLE-READINESS.json');
const release = json('RAH-RAVEN-CARE-HUB-V0.5-STABLE-RELEASE.json');
const rollbackManifest = json('RAH-RAVEN-CARE-HUB-V0.4-STABLE.json');

assert.equal(stableManifest.product, 'RAH Raven Care Hub');
assert.equal(stableManifest.parent, 'RAH Raven Care');
assert.equal(stableManifest.version, '0.5.0');
assert.equal(stableManifest.stage, 'stable');
assert.equal(stableManifest.entry, 'RAH-RAVEN-CARE-HUB.html');
assert.equal(stableManifest.data_policy, 'explicit-local-read-only-handoff');
assert.equal(stableManifest.authority_delta, 'none');
assert.equal(stableManifest.release_gate.status, 'passed');
assert.equal(stableManifest.release_gate.gate_version, '1.1.0');
assert.equal(stableManifest.release_gate.runtime_feature_change, true);
assert.equal(stableManifest.release_gate.authority_delta, 'none');
assert.equal(stableManifest.release_gate.candidate_source, '0.5.0-candidate');
assert.equal(stableManifest.release_gate.readiness_commit, '726a7a3f4500d7724c3504b7e1683c513513c472');
assert.equal(stableManifest.release_gate.rollback_version, '0.4.0');
assert.equal(stableManifest.release_gate.data_migration_required, false);
assert.equal(stableManifest.release_gate.runtime_files_frozen, true);
assert.equal(stableManifest.stable_since, '2026-08-17');
assert.equal(stableManifest.development_paused, true);
assert.equal(stableManifest.change_policy, 'bugfix-only-until-explicit-reopen');

assert.equal(stableManifest.integration.case_center.stable_version, '1.6.0');
assert.equal(stableManifest.integration.case_center.health_url, 'http://127.0.0.1:18765/health');
assert.equal(stableManifest.integration.case_center.explicit_refresh_only, true);
assert.deepEqual(stableManifest.integration.case_center.allowed_network_paths, ['/health']);
assert.equal(stableManifest.integration.case_center.case_extract_allowed, false);
assert.equal(stableManifest.integration.case_center.case_analyze_allowed, false);
assert.equal(stableManifest.integration.case_center.capture_allowed, false);
assert.equal(stableManifest.integration.case_center.lm_calls_allowed, false);
assert.equal(stableManifest.integration.fristvakt.stable_version, '0.2.0');
assert.equal(stableManifest.integration.fristvakt.import_mode, 'explicit-user-selected-json');
assert.equal(stableManifest.integration.fristvakt.required_product, 'RAH Raven Fristvakt');
assert.equal(stableManifest.integration.fristvakt.required_schema_version, 1);
assert.equal(stableManifest.integration.fristvakt.session_memory_only, true);
assert.equal(stableManifest.integration.fristvakt.automatic_persistence, false);
assert.equal(stableManifest.integration.fristvakt.browser_storage, false);

for (const key of ['single_care_entrypoint','case_center_link','fristvakt_link','health_fatigue_link','fastlege_link','combined_work_dashboard','source_labels_visible','case_center_explicit_health_check','case_center_health_loopback_only','fristvakt_explicit_json_import','explicit_local_snapshot_export','scripts','network_requests','network_requests_explicit_user_click_only','file_input']) {
  assert.equal(stableManifest.features[key], true, `${key} must be true`);
}
for (const key of ['automatic_network_requests','external_network_requests','browser_storage','automatic_persistence','file_upload_to_network','microphone_capture','camera_capture','sensor_sync','automatic_sending','automatic_calling','ai_execution','background_polling','medical_decision_automation','legal_decision_automation','care_v0_1_runtime_modified','case_center_v1_6_runtime_modified','fristvakt_v0_2_runtime_modified','health_fatigue_v0_2_runtime_modified','fastlege_v0_3_runtime_modified','stable_raven_runtime_modified','command_center_node_authority_modified']) {
  assert.equal(stableManifest.features[key], false, `${key} must be false`);
}

// Stable runtime must be exactly Candidate behavior with only release-label/version substitutions.
const normalizedCandidate = candidateHtml
  .replace('<title>RAH Raven Care Hub v0.5 Candidate</title>', '<title>RAH Raven Care Hub v0.5 Stable</title>')
  .replace('v0.5 Candidate · eksplisitt lokal read-only handoff', 'v0.5 Stable · eksplisitt lokal read-only handoff')
  .replace('CANDIDATE · STABLE v0.4 URØRT', 'STABLE · v0.5')
  .replace("version:'0.5.0-candidate'", "version:'0.5.0'");
assert.equal(stableHtml, normalizedCandidate, 'Stable HTML may differ from Candidate only by release labels and snapshot version');
assert.doesNotMatch(stableHtml, /\bCANDIDATE\b/i);
assert.match(stableHtml, /<title>RAH Raven Care Hub v0\.5 Stable<\/title>/);
assert.match(stableHtml, /STABLE · v0\.5/);
assert.match(stableHtml, /version:'0\.5\.0'/);

const csp = stableHtml.match(/Content-Security-Policy" content="([^"]+)"/i)?.[1] ?? '';
assert.ok(csp.includes("default-src 'none'"));
assert.ok(csp.includes("script-src 'unsafe-inline'"));
assert.ok(csp.includes('connect-src http://127.0.0.1:18765'));
assert.ok(csp.includes("form-action 'none'"));
assert.ok(csp.includes("object-src 'none'"));
assert.ok(csp.includes("frame-src 'none'"));
const withoutAllowedOrigin = stableHtml.replaceAll('http://127.0.0.1:18765', '');
assert.equal(withoutAllowedOrigin.includes('http://'), false);
assert.equal(withoutAllowedOrigin.includes('https://'), false);
assert.equal((stableHtml.match(/fetch\s*\(/g) ?? []).length, 1);
assert.ok(stableHtml.includes("fetch(CASE_HEALTH_URL,{method:'GET'"));
assert.ok(stableHtml.includes("const CASE_HEALTH_URL='http://127.0.0.1:18765/health'"));
assert.ok(stableHtml.includes("$('caseCheck').addEventListener('click',checkCaseCenter)"));

const lower = stableHtml.toLowerCase();
for (const forbidden of ['/case/extract','/case/analyze','/capture/','/lm/','websocket','eventsource','sendbeacon','localstorage','sessionstorage','indexeddb','setinterval(','settimeout(','getusermedia','mediadevices','clipboard.write','eval(','new function(','xmlhttprequest']) {
  assert.equal(lower.includes(forbidden), false, `forbidden Stable authority: ${forbidden}`);
}
assert.ok(stableHtml.includes('MAX_JSON_BYTES=1024*1024'));
assert.ok(stableHtml.includes("raw.product!=='RAH Raven Fristvakt'"));
assert.ok(stableHtml.includes("raw.version!=='0.2.0'"));
assert.ok(stableHtml.includes('raw.schema_version!==1'));
assert.ok(stableHtml.includes("source:'explicit-json-import'"));

const scripts = [...stableHtml.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(match => match[1]);
assert.equal(scripts.length, 1);
new vm.Script(scripts[0], { filename: 'RAH-RAVEN-CARE-HUB-v0.5-stable.inline.js' });

assert.equal(candidateManifest.version, '0.5.0-candidate');
assert.equal(candidateManifest.stage, 'candidate');
assert.equal(candidateManifest.authority_delta, 'none');
assert.equal(candidateManifest.candidate_gate.stable_promotion_included, false);
assert.equal(readiness.stage, 'stable-readiness');
assert.equal(readiness.targetVersion, '0.5.0');
assert.equal(readiness.authorityDelta, 'none');
assert.equal(readiness.stablePromotionIncluded, false);
assert.equal(rollbackManifest.version, '0.4.0');
assert.equal(rollbackManifest.stage, 'stable');

assert.equal(release.product, 'RAH Raven Care Hub');
assert.equal(release.version, '0.5.0');
assert.equal(release.stage, 'stable-release');
assert.equal(release.sourceCandidateCommit, '755a66797d2c02e97679921000ea550abdf5d62b');
assert.equal(release.readinessCommit, '726a7a3f4500d7724c3504b7e1683c513513c472');
assert.equal(release.authorityDelta, 'none');
assert.equal(release.dataMigrationRequired, false);
assert.deepEqual(release.canonicalRuntimeFiles, ['RAH-RAVEN-CARE-HUB.html','RAH-RAVEN-CARE-HUB-VERSION.json']);

for (const [name, pin] of Object.entries(release.pins)) {
  assert.equal(fs.existsSync(pin.path), true, `${name} path missing`);
  assert.equal(blobSha(bytes(pin.path)), pin.gitBlob, `${name} blob pin mismatch`);
}
assert.equal(release.securityBoundary.caseCenterOrigin, 'http://127.0.0.1:18765');
assert.deepEqual(release.securityBoundary.caseCenterAllowedMethods, ['GET']);
assert.deepEqual(release.securityBoundary.caseCenterAllowedPaths, ['/health']);
assert.equal(release.securityBoundary.caseCenterExplicitUserClickOnly, true);
for (const key of ['browserPersistence','backgroundPolling','automaticNetworkRequests','externalNetworkRequests','medicalDecisionAutomation','legalDecisionAutomation','aiExecution','fileUploadToNetwork','automaticSending','automaticCalling','microphoneCapture','cameraCapture','sensorSync']) {
  assert.equal(release.securityBoundary[key], false, `${key} release boundary`);
}

console.log('Raven Care Hub v0.5 Stable promotion PASS');
