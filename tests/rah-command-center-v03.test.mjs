import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const root = process.cwd();
const require = createRequire(import.meta.url);
const core = require(path.join(root, 'rah-command-center-core.js'));
const raven = JSON.parse(fs.readFileSync(path.join(root, 'RAH-RAVEN-VERSION.json'), 'utf8'));
const cc = JSON.parse(fs.readFileSync(path.join(root, 'RAH-COMMAND-CENTER-VERSION.json'), 'utf8'));
const html = fs.readFileSync(path.join(root, 'RAH-COMMAND-CENTER-V0.3.html'), 'utf8');

const expected = {
  raven_vision: '0.6', raven_council: '0.3', agent_runner: '0.3', memory_sync: '0.2',
  mission_control: '2.9', project_focus: '2.4', raven_core: '1.12', raven_now: '2.17', raven_studio: '2.8'
};

assert.equal(cc.version, '0.3.1');
assert.equal(cc.raven_contract, '2.0.32');
assert.equal(cc.features.stable_runtime_files_changed, false);
assert.equal(cc.features.bridge_health_check_explicit_only, true);
assert.equal(cc.features.automatic_agent_execution, false);
assert.equal(cc.features.automatic_mission_mutation, false);
assert.equal(cc.features.automatic_sending, false);
assert.deepEqual(raven.release_gate.stable_components, expected);

const snapshot = core.buildCoreSnapshot(raven, 'manifest');
assert.equal(snapshot.ravenVersion, '2.0.32');
assert.equal(snapshot.stableCount, 9);
assert.equal(snapshot.totalCount, 9);

assert.match(html, /CONTINUE RAH/);
assert.match(html, /Check local Bridge/);
assert.match(html, /Not checked\. CC v0\.3 never probes the Bridge until you click the button\./);
assert.doesNotMatch(html, /\/agent\/run/);
assert.doesNotMatch(html, /setInterval\s*\(/);
assert.doesNotMatch(html, /navigator\.mediaDevices|getUserMedia|clipboard\.readText/i);

console.log('RAH Command Center v0.3.1 integration gate passed');
