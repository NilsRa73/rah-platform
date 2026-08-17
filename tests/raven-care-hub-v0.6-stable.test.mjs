import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import vm from 'node:vm';

const read=p=>fs.readFileSync(p,'utf8');
const bytes=p=>fs.readFileSync(p);
const json=p=>JSON.parse(read(p));
const blobSha=b=>crypto.createHash('sha1').update(Buffer.from(`blob ${b.length}\0`)).update(b).digest('hex');

const stableHtml=read('RAH-RAVEN-CARE-HUB.html');
const candidateHtml=read('RAH-RAVEN-CARE-HUB-V0.6-CANDIDATE.html');
const stable=json('RAH-RAVEN-CARE-HUB-VERSION.json');
const candidate=json('RAH-RAVEN-CARE-HUB-V0.6-CANDIDATE.json');
const readiness=json('RAH-RAVEN-CARE-HUB-V0.6-STABLE-READINESS.json');
const release=json('RAH-RAVEN-CARE-HUB-V0.6-STABLE-RELEASE.json');
const rollback=json('RAH-RAVEN-CARE-HUB-V0.5-STABLE.json');

assert.equal(stable.product,'RAH Raven Care Hub');
assert.equal(stable.version,'0.6.0');
assert.equal(stable.stage,'stable');
assert.equal(stable.entry,'RAH-RAVEN-CARE-HUB.html');
assert.equal(stable.data_policy,'explicit-local-read-only-handoff-health-summary');
assert.equal(stable.authority_delta,'none');
assert.equal(stable.release_gate.status,'passed');
assert.equal(stable.release_gate.gate_version,'1.2.0');
assert.equal(stable.release_gate.candidate_source,'0.6.0-candidate');
assert.equal(stable.release_gate.readiness_commit,'dc160d7dedc5e9f3979961ca18d24a63e0656b22');
assert.equal(stable.release_gate.rollback_version,'0.5.0');
assert.equal(stable.release_gate.data_migration_required,false);
assert.equal(stable.release_gate.runtime_files_frozen,true);
assert.equal(stable.development_paused,true);
assert.equal(stable.change_policy,'bugfix-only-until-explicit-reopen');

assert.equal(stable.integration.case_center.health_url,'http://127.0.0.1:18765/health');
assert.equal(stable.integration.case_center.explicit_refresh_only,true);
assert.deepEqual(stable.integration.case_center.allowed_network_paths,['/health']);
assert.equal(stable.integration.case_center.case_extract_allowed,false);
assert.equal(stable.integration.case_center.case_analyze_allowed,false);
assert.equal(stable.integration.case_center.capture_allowed,false);
assert.equal(stable.integration.case_center.lm_calls_allowed,false);
assert.equal(stable.integration.fristvakt.stable_version,'0.2.0');
assert.equal(stable.integration.fristvakt.required_product,'RAH Raven Fristvakt');
assert.equal(stable.integration.fristvakt.required_schema_version,1);
assert.equal(stable.integration.fristvakt.session_memory_only,true);

const hf=stable.integration.health_fatigue;
assert.equal(hf.stable_version,'0.2.0');
assert.equal(hf.import_mode,'explicit-user-selected-csv');
assert.deepEqual(hf.exact_csv_fields,['date','fatigue','functionLevel','sleepHours','sleepQuality','restingPulse','glucose','hba1c','activityMinutes','delayedWorsening','medicationNote','sideEffectNote','note']);
assert.equal(hf.max_file_bytes,2097152);
assert.equal(hf.max_rows,2000);
assert.equal(hf.session_memory_only,true);
assert.equal(hf.raw_rows_retained_after_summary,false);
assert.equal(hf.snapshot_contains_raw_health_rows,false);
assert.equal(hf.automatic_persistence,false);
assert.equal(hf.browser_storage,false);

assert.equal(stable.health_summary.descriptive_only,true);
for(const k of ['medical_thresholds','diagnostic_inference','treatment_recommendations','dose_recommendations','causality_claims','alerts','legal_health_cross_inference'])assert.equal(stable.health_summary[k],false,k);
for(const k of ['automatic_network_requests','external_network_requests','browser_storage','automatic_persistence','file_upload_to_network','microphone_capture','camera_capture','sensor_sync','automatic_sending','automatic_calling','ai_execution','background_polling','medical_decision_automation','legal_decision_automation','health_fatigue_v0_2_runtime_modified','case_center_v1_6_runtime_modified','fristvakt_v0_2_runtime_modified','fastlege_v0_3_runtime_modified','raven_care_v0_1_runtime_modified','project_registry_runtime_modified','stable_raven_runtime_modified','command_center_node_authority_modified'])assert.equal(stable.features[k],false,k);
assert.equal(stable.features.health_fatigue_explicit_csv_import,true);
assert.equal(stable.features.health_fatigue_summary_only_export,true);

const normalized=candidateHtml
  .replace('<title>RAH Raven Care Hub v0.6 Candidate</title>','<title>RAH Raven Care Hub v0.6 Stable</title>')
  .replace('v0.6 Candidate · eksplisitte lokale handoffs','v0.6 Stable · eksplisitte lokale handoffs')
  .replace('CANDIDATE · STABLE v0.5 URØRT','STABLE · v0.6')
  .replace("version:'0.6.0-candidate'","version:'0.6.0'");
assert.equal(stableHtml,normalized,'Stable HTML may differ from Candidate only by four release substitutions');
assert.doesNotMatch(stableHtml,/\bCANDIDATE\b/i);
assert.match(stableHtml,/STABLE · v0\.6/);
assert.equal((stableHtml.match(/fetch\s*\(/g)??[]).length,1);
assert.ok(stableHtml.includes("fetch(CASE_HEALTH_URL,{method:'GET'"));
assert.ok(stableHtml.includes("const HEALTH_FIELDS=['date','fatigue','functionLevel','sleepHours','sleepQuality','restingPulse','glucose','hba1c','activityMinutes','delayedWorsening','medicationNote','sideEffectNote','note']"));
assert.ok(stableHtml.includes('MAX_HEALTH_BYTES=2*1024*1024'));
assert.ok(stableHtml.includes('MAX_HEALTH_ROWS=2000'));
assert.ok(stableHtml.includes("health_fatigue:healthState?{source:'explicit-csv-import-summary-only',summary:{...healthState}}:null"));
for(const forbidden of ['/case/extract','/case/analyze','/capture/','/lm/','websocket','eventsource','sendbeacon','localstorage','sessionstorage','indexeddb','setinterval(','settimeout(','getusermedia','mediadevices','xmlhttprequest'])assert.equal(stableHtml.toLowerCase().includes(forbidden),false,forbidden);

const scripts=[...stableHtml.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
assert.equal(scripts.length,1);new vm.Script(scripts[0],{filename:'care-hub-v0.6-stable.inline.js'});

assert.equal(candidate.version,'0.6.0-candidate');
assert.equal(candidate.stage,'candidate');
assert.equal(candidate.authority_delta,'none');
assert.equal(readiness.stage,'stable-readiness');
assert.equal(readiness.authorityDelta,'none');
assert.equal(readiness.stablePromotionIncluded,false);
assert.equal(rollback.version,'0.5.0');
assert.equal(rollback.stage,'stable');

assert.equal(release.product,'RAH Raven Care Hub');
assert.equal(release.version,'0.6.0');
assert.equal(release.stage,'stable-release');
assert.equal(release.sourceCandidateCommit,'5bee67344faa15b1f70cf066c66a61c536963a22');
assert.equal(release.readinessCommit,'dc160d7dedc5e9f3979961ca18d24a63e0656b22');
assert.equal(release.authorityDelta,'none');
assert.equal(release.dataMigrationRequired,false);
assert.deepEqual(release.canonicalRuntimeFiles,['RAH-RAVEN-CARE-HUB.html','RAH-RAVEN-CARE-HUB-VERSION.json']);
for(const [name,pin] of Object.entries(release.pins)){
  assert.equal(fs.existsSync(pin.path),true,`${name} missing`);
  assert.equal(blobSha(bytes(pin.path)),pin.gitBlob,`${name} blob pin mismatch`);
}
assert.equal(release.rollback.version,'0.5.0');
assert.equal(release.rollback.dataMigrationRequired,false);
const b=release.securityBoundary;
assert.equal(b.caseCenterOrigin,'http://127.0.0.1:18765');
assert.deepEqual(b.caseCenterAllowedMethods,['GET']);
assert.deepEqual(b.caseCenterAllowedPaths,['/health']);
assert.equal(b.healthFatigueMaxFileBytes,2097152);
assert.equal(b.healthFatigueMaxRows,2000);
assert.equal(b.rawHealthRowsRetained,false);
assert.equal(b.snapshotContainsRawHealthRows,false);
assert.equal(b.healthSummaryDescriptiveOnly,true);
for(const k of ['medicalThresholds','diagnosticInference','treatmentRecommendations','doseRecommendations','causalityClaims','alerts','legalHealthCrossInference','browserPersistence','backgroundPolling','automaticNetworkRequests','externalNetworkRequests','medicalDecisionAutomation','legalDecisionAutomation','aiExecution','fileUploadToNetwork','automaticSending','automaticCalling','microphoneCapture','cameraCapture','sensorSync'])assert.equal(b[k],false,k);

console.log('Raven Care Hub v0.6 Stable promotion PASS');
