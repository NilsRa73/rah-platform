import assert from 'node:assert/strict';
import fs from 'node:fs';

const html=fs.readFileSync('RAH-RAVEN-DAILY-BRIEF.html','utf8');
const manifest=JSON.parse(fs.readFileSync('RAH-RAVEN-DAILY-BRIEF-VERSION.json','utf8'));
const chronicle=JSON.parse(fs.readFileSync('RAH-RAVEN-CHRONICLE-VERSION.json','utf8'));
const insights=JSON.parse(fs.readFileSync('RAH-RAVEN-INSIGHTS-VERSION.json','utf8'));
const raven=JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const expected={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};

assert.equal(manifest.product,'RAH Raven Daily Brief');
assert.equal(manifest.version,'0.1.0');
assert.equal(manifest.stage,'stable');
assert.equal(manifest.stable_since,'2026-08-15');
assert.equal(manifest.development_paused,true);
assert.equal(manifest.change_policy,'bugfix-only-until-explicit-reopen');
assert.equal(manifest.next_milestone,undefined);
assert.equal(manifest.local_only,true);
assert.equal(manifest.chronicle_dependency,'1.7.x');
for(const [key,value] of Object.entries({
  explicit_refresh_only:true,
  explicit_generate_only:true,
  startup_network_requests:false,
  selection_change_network_requests:false,
  background_polling:false,
  bridge_base_fixed_loopback:true,
  endpoint_allowlist:true,
  local_lm_only:true,
  human_review_required:true,
  server_persists_ai_answer:false,
  download_requires_generated_answer:true,
  automatic_sending:false,
  credentials_sent:false,
  network_discovery:false,
  remote_control:false,
  device_commands:false,
  chronicle_backend_changed:false,
  chronicle_patch_compatible:true
})) assert.equal(manifest.features[key],value,key);
assert.equal(manifest.features.bridge_base,'http://127.0.0.1:18765');
assert.equal(manifest.features.structured_read_endpoint,'/chronicle/brief');
assert.equal(manifest.features.ai_brief_endpoint,'/chronicle/ai-brief');
assert.equal(manifest.release_gate.status,'passed');
assert.equal(manifest.release_gate.gate_version,'1.0.0');
assert.equal(manifest.release_gate.runtime_files_frozen,true);
assert.equal(manifest.release_gate.chronicle_v1_7_runtime_frozen,true);
assert.equal(manifest.release_gate.insights_v0_1_runtime_frozen,true);
assert.equal(manifest.release_gate.stable_raven_runtime_frozen,true);
assert.deepEqual(raven.release_gate.stable_components,expected);
assert.equal(chronicle.version,'1.7.1');
assert.equal(chronicle.stage,'stable');
assert.equal(chronicle.development_paused,true);
assert.equal(chronicle.change_policy,'bugfix-only-until-explicit-reopen');
assert.equal(insights.version,'0.1.0');
assert.equal(insights.stage,'stable');
assert.equal(insights.development_paused,true);
assert.equal(insights.change_policy,'bugfix-only-until-explicit-reopen');
assert.match(raven.summary,/Raven Chronicle v1\.7\.1 is stable/);
assert.match(raven.summary,/Raven Insights v0\.1 is stable/);
assert.match(raven.summary,/Raven Daily Brief v0\.1 is stable/);
for(const file of ['RAH-RAVEN-DAILY-BRIEF.html','RAH-RAVEN-DAILY-BRIEF-VERSION.json']) assert.equal(raven.files.includes(file),true,file);
for(const [key,value] of Object.entries({
  raven_daily_brief_version_synced:true,
  raven_daily_brief_explicit_refresh_only:true,
  raven_daily_brief_explicit_generate_only:true,
  raven_daily_brief_startup_network_requests:false,
  raven_daily_brief_selection_change_network_requests:false,
  raven_daily_brief_background_polling:false,
  raven_daily_brief_bridge_base_loopback_only:true,
  raven_daily_brief_endpoint_allowlist:true,
  raven_daily_brief_local_lm_only:true,
  raven_daily_brief_human_review_required:true,
  raven_daily_brief_server_persists_ai_answer:false,
  raven_daily_brief_automatic_sending:false,
  raven_daily_brief_credentials_sent:false,
  raven_daily_brief_chronicle_backend_changed:false,
  raven_daily_brief_chronicle_patch_compatible:true,
  raven_daily_brief_runtime_frozen:true,
  raven_daily_brief_stable:true
})) assert.equal(raven.privacy[key],value,key);

const scripts=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
assert.equal(scripts.length,1);
const script=scripts[0][1];
new Function(script);
assert.match(html,/<title>RAH Raven Daily Brief v0\.1<\/title>/);
assert.match(html,/href="http:\/\/127\.0\.0\.1:18765\/chronicle\/ui"/);
assert.match(html,/href="http:\/\/127\.0\.0\.1:18765\/chronicle\/insights-ui"/);
assert.match(html,/Ingen lokale Chronicle-data hentes automatisk/);
assert.match(script,/const BASE='http:\/\/127\.0\.0\.1:18765'/);
assert.doesNotMatch(script,/location\.origin/);
assert.match(script,/new Set\(\['\/chronicle\/brief','\/chronicle\/ai-brief'\]\)/);
assert.match(script,/credentials:'omit'/);
assert.match(script,/cache:'no-store'/);
assert.doesNotMatch(script,/setInterval\s*\(|setTimeout\s*\(\s*refresh/);
assert.doesNotMatch(script,/^\s*refresh\(\);\s*$/m);
assert.doesNotMatch(script,/\$\('hours'\)\.onchange\s*=\s*refresh/);
assert.match(script,/\$\('refresh'\)\.onclick=refresh/);
assert.match(script,/\$\('generate'\)\.onclick=async/);
const generateStart=script.indexOf("$('generate').onclick=async");
const refreshWire=script.indexOf("$('refresh').onclick=refresh",generateStart);
const generateBody=script.slice(generateStart,refreshWire);
assert.ok(generateBody.indexOf("api('/chronicle/ai-brief'")>=0);
assert.match(script,/if\(!lastAnswer\)/);
assert.doesNotMatch(script,/WebSocket\s*\(|RTCPeerConnection|navigator\.bluetooth|navigator\.usb|navigator\.serial|navigator\.mediaDevices|getUserMedia/);
assert.doesNotMatch(script,/\/agent\/run|\/command|\/shell/);

console.log('RAH Raven Daily Brief v0.1 Stable explicit-local boundary passed over Chronicle v1.7.1 and Insights v0.1 Stable');
