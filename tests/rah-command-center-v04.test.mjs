import assert from 'node:assert/strict';
import fs from 'node:fs';

const raven = JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const currentCc = JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const html = fs.readFileSync('RAH-COMMAND-CENTER-V0.4.html','utf8');
const expected={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};

// v0.4.1 is now a frozen historical predecessor. Do not require it to remain
// the current Command Center manifest after a newer Stable release exists.
assert.equal(currentCc.version,'0.5.0');
assert.equal(currentCc.previous_stable_version,'0.4.1');
assert.equal(currentCc.stage,'stable');
assert.equal(currentCc.release_gate.status,'passed');
assert.equal(currentCc.release_gate.runtime_files_frozen,true);
assert.equal(currentCc.features.stable_runtime_files_changed,false);

assert.deepEqual(raven.release_gate.stable_components,expected);
assert.match(raven.summary,/Raven Fristvakt v0\.2 and RAH Raven Command Center v0\.5\.0 are stable/);
assert.equal(raven.privacy.raven_care_stable,true);
assert.equal(raven.privacy.raven_fristvakt_stable,true);
assert.equal(raven.privacy.command_center_stable,true);
assert.equal(raven.privacy.command_center_runtime_frozen,true);

// Preserve the actual v0.4 artifact as a read-only historical runtime surface.
assert.match(html,/<title>RAH Raven Command Center v0\.4\.0<\/title>/);
assert.match(html,/DEVICES & NODES/);
assert.match(html,/Local device registry/);
assert.match(html,/Register device/);
assert.match(html,/Mark as this device/);
assert.match(html,/rah\.cc\.devices\.v1/);
assert.match(html,/PACKAGE MODULES/);
assert.match(html,/PACKAGED/);
assert.match(html,/Not checked\. CC v0\.4\.0 never probes the Bridge until you click the button\./);
assert.match(html,/No scanning, ping, SSH, remote desktop or agent execution\./);
assert.doesNotMatch(html,/Stable local supporting module/);
assert.doesNotMatch(html,/core\.EXTRA_COMPONENTS/);
assert.doesNotMatch(html,/\/agent\/run|setInterval\s*\(|navigator\.mediaDevices|getUserMedia|clipboard\.readText/i);
assert.doesNotMatch(html,/WebSocket\s*\(|RTCPeerConnection|navigator\.bluetooth|navigator\.usb|navigator\.serial/i);

console.log('RAH Command Center v0.4.1 historical frozen artifact preserved after v0.5 Stable promotion');
