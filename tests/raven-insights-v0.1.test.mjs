import assert from 'node:assert/strict';
import fs from 'node:fs';

const html = fs.readFileSync('RAH-RAVEN-INSIGHTS.html','utf8');
const manifest = JSON.parse(fs.readFileSync('RAH-RAVEN-INSIGHTS-VERSION.json','utf8'));
const chronicle = JSON.parse(fs.readFileSync('RAH-RAVEN-CHRONICLE-VERSION.json','utf8'));
const raven = JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const expected={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};

assert.equal(manifest.product,'RAH Raven Insights');
assert.equal(manifest.version,'0.1.0');
assert.equal(manifest.stage,'candidate');
assert.equal(manifest.local_only,true);
assert.equal(manifest.chronicle_dependency,'1.7.x');
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
  chronicle_backend_changed:false,
  chronicle_patch_compatible:true
})) assert.equal(manifest.features[key],value,key);
assert.equal(manifest.features.bridge_base,'http://127.0.0.1:18765');
assert.equal(manifest.release_gate.status,'candidate');
assert.equal(manifest.release_gate.chronicle_v1_7_runtime_frozen,true);
assert.equal(manifest.release_gate.stable_raven_runtime_frozen,true);
assert.deepEqual(raven.release_gate.stable_components,expected);
assert.match(chronicle.version,/^1\.7\./);
if (chronicle.version === '1.7.0') {
  assert.equal(chronicle.stage,'stable');
  assert.equal(chronicle.development_paused,true);
} else {
  assert.equal(chronicle.version,'1.7.1');
  assert.equal(chronicle.previous_stable_version,'1.7.0');
  assert.ok(['stable-bugfix-candidate','stable'].includes(chronicle.stage));
  if (chronicle.stage === 'stable-bugfix-candidate') {
    assert.equal(chronicle.stable_release_gate?.status,'candidate');
    assert.equal(raven.privacy.raven_chronicle_stable,true);
    assert.equal(raven.privacy.raven_chronicle_bugfix_candidate,true);
  } else {
    assert.equal(chronicle.development_paused,true);
  }
}

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

console.log('RAH Raven Insights v0.1 candidate explicit-local boundary passed across Chronicle 1.7.x patches');
