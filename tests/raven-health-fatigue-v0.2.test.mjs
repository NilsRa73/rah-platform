import assert from 'node:assert/strict';
import fs from 'node:fs';

const read=path=>fs.readFileSync(path,'utf8');
const html=read('RAH-RAVEN-HEALTH-FATIGUE.html');
const manifest=JSON.parse(read('RAH-RAVEN-HEALTH-FATIGUE-VERSION.json'));
const careHtml=read('RAH-RAVEN-CARE.html');
const care=JSON.parse(read('RAH-RAVEN-CARE-VERSION.json'));
const raven=JSON.parse(read('RAH-RAVEN-VERSION.json'));
const chronicle=JSON.parse(read('RAH-RAVEN-CHRONICLE-VERSION.json'));
const insights=JSON.parse(read('RAH-RAVEN-INSIGHTS-VERSION.json'));
const daily=JSON.parse(read('RAH-RAVEN-DAILY-BRIEF-VERSION.json'));
const cc=JSON.parse(read('RAH-COMMAND-CENTER-VERSION.json'));
const stableCore={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};

assert.equal(manifest.product,'RAH Raven Health & Fatigue');
assert.equal(manifest.parent,'RAH Raven Care');
assert.equal(manifest.version,'0.2.0');
assert.equal(manifest.stage,'candidate');
assert.equal(manifest.entry,'RAH-RAVEN-HEALTH-FATIGUE.html');
assert.equal(manifest.data_policy,'session-memory-only');
assert.equal(manifest.next_milestone,'stable-gate');
assert.equal(manifest.release_gate.status,'candidate');
assert.equal(manifest.release_gate.change_policy,'manual-health-boundary-only');
assert.equal(manifest.release_gate.care_v0_1_stable_runtime_frozen,true);
assert.equal(manifest.release_gate.stable_raven_runtime_frozen,true);
assert.equal(manifest.release_gate.candidate_runtime_files_frozen,false);

for(const [key,value] of Object.entries({
  manual_entry_only:true,
  fatigue_0_10:true,
  function_level_0_10:true,
  sleep_length_manual:true,
  sleep_quality_manual:true,
  resting_pulse_manual:true,
  glucose_manual:true,
  hba1c_manual:true,
  medication_note_manual:true,
  side_effect_note_manual:true,
  activity_manual:true,
  delayed_worsening_manual:true,
  period_summary_7_30_90:true,
  descriptive_correlation:true,
  correlation_noncausal_label_required:true,
  csv_import_explicit_only:true,
  csv_export_explicit_only:true,
  csv_schema_allowlist:true,
  browser_storage:false,
  automatic_persistence:false,
  automatic_import:false,
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
  causality_claims:false,
  fastlege_portal:false,
  synthetic_or_deidentified_demo_default:true,
  care_v0_1_runtime_modified:false,
  stable_raven_runtime_modified:false
})) assert.equal(manifest.features[key],value,key);
assert.equal(manifest.features.minimum_complete_pairs_for_correlation,5);

// Preserve the already-frozen Care v0.1 dashboard and the wider Stable Raven set.
assert.equal(care.version,'0.1.0');
assert.equal(care.stage,'stable');
assert.equal(care.development_paused,true);
assert.equal(care.change_policy,'bugfix-only-until-explicit-reopen');
assert.equal(care.features.health_fatigue_module,false);
assert.equal(care.features.fastlege_view,false);
assert.match(careHtml,/Health &amp; Fatigue/);
assert.match(careHtml,/Ikke bygget ennå/);
assert.doesNotMatch(careHtml,/RAH-RAVEN-HEALTH-FATIGUE\.html/);
assert.deepEqual(raven.release_gate.stable_components,stableCore);
assert.equal(raven.privacy.raven_care_stable,true);
assert.equal(raven.privacy.raven_care_runtime_frozen,true);
assert.equal(chronicle.version,'1.7.1');assert.equal(chronicle.stage,'stable');
assert.equal(insights.version,'0.1.0');assert.equal(insights.stage,'stable');
assert.equal(daily.version,'0.1.0');assert.equal(daily.stage,'stable');
assert.equal(cc.version,'0.7.0');assert.equal(cc.stage,'stable');

// Candidate runtime is stage-neutral, local, manual and non-persistent so it can later be frozen unchanged.
assert.match(html,/<title>RAH Raven Health & Fatigue v0\.2<\/title>/);
assert.match(html,/LOCAL MODULE · SESSION-MEMORY ONLY · NO NETWORK/);
assert.doesNotMatch(html,/\bCANDIDATE\b/i);
assert.match(html,/Modulen er laget for syntetiske eller avidentifiserte testdata først/i);
assert.match(html,/gir ikke diagnose, behandlingsvalg, medisinske terskelvarsler eller årsaksforklaringer/i);
assert.match(html,/Samvariasjon er ikke bevist årsak/);
assert.match(html,/Ingen klokke-, sensor-, mikrofon-, kamera- eller bakgrunnsinnhenting/);
assert.match(html,/Ingen diagnose, behandlingsendring, dosering, terskelalarm/);
assert.match(html,/data forsvinner når økten tømmes\/lukkes/i);
assert.match(html,/id="csvFile"[^>]*type="file"/);
assert.match(html,/id="importCsv"/);
assert.match(html,/id="exportCsv"/);
assert.match(html,/id="clearSession"/);
assert.match(html,/new FileReader\(\)/);
assert.match(html,/new Blob\(/);
assert.match(html,/confirm\('Tømme alle Health & Fatigue-data/);
assert.match(html,/minimum_complete_pairs_for_correlation|Minst fem komplette registreringer/i);
assert.match(html,/r=\$\{p\.r\.toFixed\(2\)\}, n=\$\{p\.n\}/);
assert.match(html,/Dette er samvariasjon, ikke bevist årsak/);
assert.match(html,/const FIELDS=\['date','fatigue','functionLevel','sleepHours','sleepQuality','restingPulse','glucose','hba1c','activityMinutes','delayedWorsening','medicationNote','sideEffectNote','note'\]/);
assert.match(html,/header\.length!==FIELDS\.length/);
assert.match(html,/entries=\[\.\.\.entries,\.\.\.imported\]\.slice\(0,2000\)/);
assert.doesNotMatch(html,/fetch\s*\(|XMLHttpRequest|WebSocket\s*\(|EventSource\s*\(|sendBeacon\s*\(|RTCPeerConnection/);
assert.doesNotMatch(html,/localStorage|sessionStorage|indexedDB|CacheStorage|caches\./);
assert.doesNotMatch(html,/navigator\.mediaDevices|getUserMedia|navigator\.bluetooth|navigator\.usb|navigator\.serial|Geolocation|watchPosition/);
assert.doesNotMatch(html,/setInterval\s*\(/);
assert.doesNotMatch(html,/\/agent\/run|\/command|\/shell|Authorization\s*:/i);
assert.doesNotMatch(html,/<iframe\b|<object\b|<embed\b/i);

const scripts=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
assert.equal(scripts.length,1);
new Function(scripts[0][1]);

console.log('RAH Raven Health & Fatigue v0.2 stage-neutral Candidate boundary passed over frozen Care v0.1 and Raven Stable baseline.');
