import assert from 'node:assert/strict';
import fs from 'node:fs';

const page = fs.readFileSync('RAH-RAVEN-AGENT-RUNNER.html', 'utf8');
const runner = fs.readFileSync('desktop-bridge/agent_runner.py', 'utf8');
const bridge = fs.readFileSync('desktop-bridge/raven_bridge.py', 'utf8');

assert.match(page, /Raven Agent Runner v0\.2/);
assert.match(page, /http:\/\/127\.0\.0\.1:18765/);
assert.match(page, /\/agent\/capabilities/);
assert.match(page, /\/agent\/run/);
assert.match(page, /confirm\s*:\s*true/);
assert.match(page, /read_only\s*!==\s*true/);
assert.match(page, /files_modified\s*!==\s*false/);
assert.match(page, /automatic_actions\s*!==\s*false/);
assert.match(page, /rah\.command\.center/);
assert.match(page, /markere gjeldende Mission-steg/i);
assert.doesNotMatch(page, /type="text"[^>]*placeholder=".*kommando/i);

assert.match(runner, /AGENT_RUNNER_VERSION = "0\.1\.1"/);
assert.match(runner, /CAPABILITIES: dict/);
assert.match(runner, /shell=False/);
assert.match(runner, /payload\.get\("confirm"\) is not True/);
assert.match(runner, /Capability er ikke i den lokale allowlisten/);
assert.match(runner, /return sorted\(output, key=str\.casefold\)/);
assert.match(runner, /"read_only": True/);
assert.match(runner, /"files_modified": False/);
assert.match(runner, /"automatic_actions": False/);
assert.doesNotMatch(runner, /shell=True/);
assert.doesNotMatch(runner, /payload\.get\("command"\)/);

assert.match(bridge, /import agent_runner/);
assert.match(bridge, /"\/agent\/"/);

console.log('Raven Agent Runner v0.2 UI / runner v0.1.1 validation passed.');
