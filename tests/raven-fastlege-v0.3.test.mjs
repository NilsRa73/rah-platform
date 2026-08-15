import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=path=>fs.readFileSync(path,'utf8');
const html=read('RAH-RAVEN-FASTLEGE.html');
const manifest=JSON.parse(read('RAH-RAVEN-FASTLEGE-VERSION.json'));
const care=JSON.parse(read('RAH-RAVEN-CARE-VERSION.json'));
const health=JSON.parse(read('RAH-RAVEN-HEALTH-FATIGUE-VERSION.json'));
const chronicle=JSON.parse(read('RAH-RAVEN-CHRONICLE-VERSION.json'));
const insights=JSON.parse(read('RAH-RAVEN-INSIGHTS-VERSION.json'));
const daily=JSON.parse(read('RAH-RAVEN-DAILY-BRIEF-VERSION.json'));
const cc=JSON.parse(read('RAH-COMMAND-CENTER-VERSION.json'));

assert.equal(manifest.product,'RAH Raven Fastlegevisning');
assert.equal(manifest.parent,'RAH Raven Care');
assert.equal(manifest.version,'0.3.0');
assert.equal(manifest.stage,'candidate');
assert.equal(manifest.entry,'RAH-RAVEN-FASTLEGE.html');
assert.equal(manifest.data_policy,'session-memory-only');
assert.equal(manifest.next_milestone,'stable-gate');
assert.equal(manifest.release_gate.status,'candidate');
assert.equal(manifest.release_gate.change_policy,'manual-source-linked-consultation-view-only');
assert.equal(manifest.release_gate.care_v0_1_stable_runtime_frozen,true);
assert.equal(manifest.release_gate.health_fatigue_v0_2_stable_runtime_frozen,true);
assert.equal(manifest.release_gate.stable_raven_runtime_frozen,true);
assert.equal(manifest.release_gate.candidate_runtime_files_frozen,false);

for(const [key,value] of Object.entries({
  manual_entry_only:true,
  consultation_goal:true,
  maximum_three_main_topics:true,
  short_timeline:true,
  measurements_and_labs:true,
  medication_changes:true,
  unresolved_questions:true,
  responsible_person_or_service:true,
  next_deadline:true,
  direct_source_required:true,
  source_classification_required:true,
  print_friendly_view:true,
  browser_print_explicit_only:true,
  browser_storage:false,
  automatic_persistence:false,
  network_requests:false,
  automatic_sending:false,
  hidden_data_collection:false,
  sensor_sync:false,
  wearable_sync:false,
  microphone_capture:false,
  camera_capture:false,
  medical_decision_automation:false,
  diagnostic_inference:false,
  treatment_recommendations:false,
  dose_recommendations:false,
  medical_threshold_alerts:false,
  severity_ranking:false,
  professional_approval_automation:false,
  fastlege_portal:false,
  external_health_integration:false,
  synthetic_or_deidentified_demo_default:true,
  care_v0_1_runtime_modified:false,
  health_fatigue_v0_2_runtime_modified:false,
  stable_raven_runtime_modified:false
})) assert.equal(manifest.features[key],value,key);
assert.deepEqual(manifest.features.source_classes,['documented','patient','professional','disputed','unknown']);

// Preserve frozen parent/previous child and current Stable release baselines.
assert.equal(care.version,'0.1.0');
assert.equal(care.stage,'stable');
assert.equal(care.development_paused,true);
assert.equal(care.change_policy,'bugfix-only-until-explicit-reopen');
assert.equal(care.features.fastlege_view,false);
assert.equal(health.version,'0.2.0');
assert.equal(health.stage,'stable');
assert.equal(health.development_paused,true);
assert.equal(health.release_gate.runtime_files_frozen,true);
assert.equal(health.features.fastlege_portal,false);
assert.equal(chronicle.version,'1.7.1');assert.equal(chronicle.stage,'stable');
assert.equal(insights.version,'0.1.0');assert.equal(insights.stage,'stable');
assert.equal(daily.version,'0.1.0');assert.equal(daily.stage,'stable');
assert.equal(cc.version,'0.8.0');assert.equal(cc.stage,'stable');

// Candidate runtime is stage-neutral, local, source-linked, printable and non-persistent.
assert.match(html,/<title>RAH Raven Fastlegevisning v0\.3<\/title>/);
assert.match(html,/LOCAL MODULE · SESSION-MEMORY ONLY · NO NETWORK · PRINT LOCALLY/);
assert.doesNotMatch(html,/\bCANDIDATE\b/i);
assert.match(html,/maks tre hovedtemaer/i);
assert.match(html,/syntetiske eller avidentifiserte testdata først/i);
assert.match(html,/stiller ikke diagnose, vurderer ikke behandling og sender ingenting/i);
assert.match(html,/Hva pasienten ønsker av konsultasjonen/);
assert.match(html,/Tre viktigste temaer/);
assert.match(html,/Kort tidslinje/);
assert.match(html,/Siste prøver og egenmålinger/);
assert.match(html,/Medisiner og endringer/);
assert.match(html,/Uavklarte spørsmål · ansvar · neste frist/);
assert.match(html,/Direkte kilde/);
assert.match(html,/Kildeklasse/);
assert.match(html,/Dokumentert/);
assert.match(html,/Pasientopplysning/);
assert.match(html,/Faglig tolkning/);
assert.match(html,/Omstridt/);
assert.match(html,/Uavklart/);
assert.match(html,/if\(state\.topics\.length>=3\)/);
assert.match(html,/sourceStatus\('topic'\)/);
assert.match(html,/sourceStatus\('timeline'\)/);
assert.match(html,/sourceStatus\('measure'\)/);
assert.match(html,/sourceStatus\('med'\)/);
assert.match(html,/sourceStatus\('question'\)/);
assert.match(html,/window\.print\(\)/);
assert.match(html,/@media print/);
assert.match(html,/confirm\('Tømme alle Fastlegevisning-data/);
assert.match(html,/Ingen diagnose, behandlingsvalg, dosering, terskelalarm eller rangering av medisinsk alvorlighet/);
assert.match(html,/Ingen nettverkskall, automatisk sending, sensorer, mikrofon, kamera eller bakgrunnsoppdatering/);
assert.match(html,/data finnes bare i denne fanens minne/i);
assert.match(html,/connect-src 'none'/);
assert.match(html,/form-action 'none'/);
assert.doesNotMatch(html,/fetch\s*\(|XMLHttpRequest|WebSocket\s*\(|EventSource\s*\(|sendBeacon\s*\(|RTCPeerConnection/);
assert.doesNotMatch(html,/localStorage|sessionStorage|indexedDB|CacheStorage|caches\./);
assert.doesNotMatch(html,/navigator\.mediaDevices|getUserMedia|navigator\.bluetooth|navigator\.usb|navigator\.serial|Geolocation|watchPosition/);
assert.doesNotMatch(html,/setInterval\s*\(/);
assert.doesNotMatch(html,/\/agent\/run|\/command|\/shell|Authorization\s*:/i);
assert.doesNotMatch(html,/<iframe\b|<object\b|<embed\b/i);

const scripts=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
assert.equal(scripts.length,1);
new Function(scripts[0][1]);

console.log('RAH Raven Fastlegevisning v0.3 stage-neutral Candidate boundary passed over frozen Care v0.1, Health & Fatigue v0.2 and Raven Stable baseline.');
