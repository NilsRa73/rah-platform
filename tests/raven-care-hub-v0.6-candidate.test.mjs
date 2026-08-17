import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const manifest=JSON.parse(fs.readFileSync('RAH-RAVEN-CARE-HUB-V0.6-CANDIDATE.json','utf8'));
const html=fs.readFileSync('RAH-RAVEN-CARE-HUB-V0.6-CANDIDATE.html','utf8');
const lower=html.toLowerCase();

assert.equal(manifest.product,'RAH Raven Care Hub');
assert.equal(manifest.version,'0.6.0-candidate');
assert.equal(manifest.stage,'candidate');
assert.equal(manifest.released_from_stable,'0.5.0');
assert.equal(manifest.stable_runtime_modified,false);
assert.equal(manifest.authority_delta,'none');
assert.equal(manifest.integration.health_fatigue.stable_version,'0.2.0');
assert.equal(manifest.integration.health_fatigue.import_mode,'explicit-user-selected-csv');
assert.equal(manifest.integration.health_fatigue.max_file_bytes,2097152);
assert.equal(manifest.integration.health_fatigue.max_rows,2000);
assert.equal(manifest.integration.health_fatigue.session_memory_only,true);
assert.equal(manifest.integration.health_fatigue.raw_rows_retained_after_summary,false);
assert.equal(manifest.integration.health_fatigue.snapshot_contains_raw_health_rows,false);
assert.deepEqual(manifest.integration.health_fatigue.exact_csv_fields,['date','fatigue','functionLevel','sleepHours','sleepQuality','restingPulse','glucose','hba1c','activityMinutes','delayedWorsening','medicationNote','sideEffectNote','note']);
for(const key of ['medical_thresholds','diagnostic_inference','treatment_recommendations','dose_recommendations','causality_claims','alerts','legal_health_cross_inference'])assert.equal(manifest.health_summary[key],false,key);
for(const key of ['automatic_network_requests','external_network_requests','background_polling','automatic_sending','automatic_calling','medical_decision_automation','legal_decision_automation','ai_execution','file_upload_to_network','microphone_capture','camera_capture','sensor_sync','stable_care_hub_v0_5_modified','stable_health_fatigue_v0_2_modified','stable_case_center_v1_6_modified','stable_fristvakt_v0_2_modified','stable_fastlege_v0_3_modified','stable_raven_runtime_modified','command_center_node_authority_modified'])assert.equal(manifest.features[key],false,key);
assert.equal(manifest.candidate_gate.stable_promotion_included,false);

const csp=html.match(/Content-Security-Policy" content="([^"]+)"/i)?.[1]??'';
assert.ok(csp.includes("default-src 'none'"));
assert.ok(csp.includes('connect-src http://127.0.0.1:18765'));
assert.equal((html.match(/fetch\s*\(/g)??[]).length,1);
assert.ok(html.includes("fetch(CASE_HEALTH_URL,{method:'GET'"));
assert.ok(html.includes("const CASE_HEALTH_URL='http://127.0.0.1:18765/health'"));
const withoutAllowedOrigin=html.replaceAll('http://127.0.0.1:18765','');
assert.equal(withoutAllowedOrigin.includes('http://'),false);
assert.equal(withoutAllowedOrigin.includes('https://'),false);
for(const forbidden of ['/case/extract','/case/analyze','/capture/','/lm/','websocket','eventsource','sendbeacon','localstorage','sessionstorage','indexeddb','setinterval(','settimeout(','getusermedia','mediadevices','xmlhttprequest'])assert.equal(lower.includes(forbidden),false,forbidden);

assert.ok(html.includes("const HEALTH_FIELDS=['date','fatigue','functionLevel','sleepHours','sleepQuality','restingPulse','glucose','hba1c','activityMinutes','delayedWorsening','medicationNote','sideEffectNote','note']"));
assert.ok(html.includes('MAX_HEALTH_BYTES=2*1024*1024'));
assert.ok(html.includes('MAX_HEALTH_ROWS=2000'));
assert.ok(html.includes("if(header.length!==HEALTH_FIELDS.length||header.some((v,i)=>v!==HEALTH_FIELDS[i]))throw new Error('CSV-header matcher ikke Health & Fatigue v0.2')"));
assert.ok(html.includes("health_fatigue:healthState?{source:'explicit-csv-import-summary-only',summary:{...healthState}}:null"));
assert.doesNotMatch(html,/health_fatigue:\s*healthState\?\{[^}]*rows/i);
assert.doesNotMatch(html,/rawHealth|healthRows|rawRows/);
assert.match(html,/Rå rad- og notatdata beholdes ikke etter/);
assert.match(html,/ingen terskler, diagnose, behandling, dosering, årsakspåstand eller varsling/i);
assert.match(html,/klassifiseres ikke som normale\/unormale/i);

const script=[...html.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
assert.equal(script.length,1);
new vm.Script(script[0],{filename:'care-hub-v0.6.inline.js'});

function element(){return {textContent:'',className:'',value:'',files:[],hidden:false,disabled:false,addEventListener(){},click(){},append(){},querySelector(){return {textContent:''}}};}
const elements=new Map();
const sandbox={console,document:{getElementById(id){if(!elements.has(id))elements.set(id,element());return elements.get(id);},createElement(){return element();}},URL:{createObjectURL(){return 'blob:test';},revokeObjectURL(){}},Blob:class{},fetch:async()=>{throw new Error('network must not run during test')}};
vm.createContext(sandbox);vm.runInContext(script[0],sandbox);
assert.equal(vm.runInContext("HEALTH_FIELDS.join(',')",sandbox),'date,fatigue,functionLevel,sleepHours,sleepQuality,restingPulse,glucose,hba1c,activityMinutes,delayedWorsening,medicationNote,sideEffectNote,note');

const csv='date,fatigue,functionLevel,sleepHours,sleepQuality,restingPulse,glucose,hba1c,activityMinutes,delayedWorsening,medicationNote,sideEffectNote,note\n2026-08-16,5,7,8,6,70,7.2,,30,2,"same, dose",,ok\n2026-08-17,7,6,7,5,72,8.1,,20,3,,,fine\n';
sandbox.__csv=csv;
const summary=vm.runInContext("(()=>{const rows=parseCsv(__csv);rows.shift();return summarizeHealth(rows)})()",sandbox);
assert.equal(summary.rowCount,2);
assert.equal(summary.firstDate,'2026-08-16');
assert.equal(summary.lastDate,'2026-08-17');
assert.equal(summary.averageFatigue,6);
assert.equal(summary.averageSleepHours,7.5);
assert.equal(summary.averageActivityMinutes,25);
assert.equal(summary.latestDate,'2026-08-17');
assert.equal(summary.latestGlucose,8.1);
assert.equal(summary.latestHba1c,null);

sandbox.__bad=[['2026-08-17','99','6','7','5','72','8.1','','20','3','','','']];
assert.throws(()=>vm.runInContext('summarizeHealth(__bad)',sandbox),/Ugyldig verdi i fatigue/);
assert.equal(vm.runInContext("parseCsv('a,\"b,c\",d\\n')[0][1]",sandbox),'b,c');

for(const target of ['RAH-RAVEN-CASE-CENTER.html','RAH-RAVEN-FRISTVAKT.html','RAH-RAVEN-HEALTH-FATIGUE.html','RAH-RAVEN-FASTLEGE.html'])assert.ok(html.includes(`href="${target}"`));
console.log('Raven Care Hub v0.6 Health CSV Candidate boundary PASS');
