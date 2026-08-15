import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-INSIGHTS.html','utf8');
const manifest = JSON.parse(fs.readFileSync('RAH-RAVEN-INSIGHTS-VERSION.json','utf8'));
const chronicle = JSON.parse(fs.readFileSync('RAH-RAVEN-CHRONICLE-VERSION.json','utf8'));
const raven = JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const expected={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};

assert.equal(manifest.product,'RAH Raven Insights');
assert.equal(manifest.version,'0.1.0');
assert.equal(manifest.stage,'stable');
assert.equal(manifest.stable_since,'2026-08-15');
assert.equal(manifest.development_paused,true);
assert.equal(manifest.change_policy,'bugfix-only-until-explicit-reopen');
assert.equal(manifest.next_milestone,undefined);
assert.equal(manifest.local_only,true);
assert.equal(manifest.chronicle_dependency,'1.7.0');
for (const [key,value] of Object.entries({
  explicit_refresh_only:true,
  startup_network_requests:false,
  background_polling:false,
  bridge_base_fixed_loopback:true,
  endpoint_allowlist:true,
  completion_requires_confirmation:true,
  completion_append_only_backend:true,
  automatic_completion:false,
  automatic_sending:false,
  credentials_sent:false,
  network_discovery:false,
  remote_control:false,
  device_commands:false,
  chronicle_backend_changed:false
})) assert.equal(manifest.features[key],value,key);
assert.equal(manifest.features.bridge_base,'http://127.0.0.1:18765');
assert.equal(manifest.release_gate.status,'passed');
assert.equal(manifest.release_gate.gate_version,'1.0.0');
assert.equal(manifest.release_gate.runtime_files_frozen,true);
assert.equal(manifest.release_gate.chronicle_v1_7_runtime_frozen,true);
assert.equal(manifest.release_gate.stable_raven_runtime_frozen,true);
assert.deepEqual(raven.release_gate.stable_components,expected);
assert.equal(chronicle.version,'1.7.0');
assert.equal(chronicle.stage,'stable');
assert.equal(chronicle.development_paused,true);
assert.match(raven.summary,/Raven Insights v0\.1 is stable/);
for (const file of ['RAH-RAVEN-INSIGHTS.html','RAH-RAVEN-INSIGHTS-VERSION.json']) assert.equal(raven.files.includes(file),true,file);
for (const [key,value] of Object.entries({raven_insights_version_synced:true,raven_insights_explicit_refresh_only:true,raven_insights_startup_network_requests:false,raven_insights_background_polling:false,raven_insights_bridge_base_loopback_only:true,raven_insights_endpoint_allowlist:true,raven_insights_completion_requires_confirmation:true,raven_insights_automatic_completion:false,raven_insights_automatic_sending:false,raven_insights_credentials_sent:false,raven_insights_chronicle_backend_changed:false,raven_insights_runtime_frozen:true,raven_insights_stable:true})) assert.equal(raven.privacy[key],value,key);

const scripts=[...html.matchAll(/<script>([\s\S]*?)<\/script>/g)];
assert.equal(scripts.length,1);
const script=scripts[0][1];
new Function(script);
assert.match(html,/<title>RAH Raven Insights v0\.1<\/title>/);
assert.match(html,/href="http:\/\/127\.0\.0\.1:18765\/chronicle\/ui"/);
assert.match(script,/const BASE='http:\/\/127\.0\.0\.1:18765'/);
assert.doesNotMatch(script,/location\.origin/);
assert.match(script,/new Set\(\['\/chronicle\/summary','\/chronicle\/complete'\]\)/);
assert.match(script,/credentials:'omit'/);
assert.match(script,/cache:'no-store'/);
assert.doesNotMatch(script,/setInterval\s*\(|setTimeout\s*\(\s*refresh/);
assert.doesNotMatch(script,/^\s*refresh\(\);\s*$/m);
assert.match(script,/\$\('refresh'\)\.onclick=refresh/);
assert.match(script,/window\.confirm\('Marker denne åpne tråden som ferdig\?/);
const completeStart=script.indexOf('async function complete');
const refreshStart=script.indexOf('async function refresh',completeStart);
const completeBody=script.slice(completeStart,refreshStart);
assert.ok(completeBody.indexOf('window.confirm')>=0);
assert.ok(completeBody.indexOf("api('/chronicle/complete'")>completeBody.indexOf('window.confirm'));
assert.match(completeBody,/if\(!approved\)return/);
assert.doesNotMatch(script,/WebSocket\s*\(|RTCPeerConnection|navigator\.bluetooth|navigator\.usb|navigator\.serial|navigator\.mediaDevices|getUserMedia/);
assert.doesNotMatch(script,/\/agent\/run|\/command|\/shell/);

console.log('RAH Raven Insights v0.1 Stable explicit-local boundary passed');
