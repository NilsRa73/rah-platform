import assert from 'node:assert/strict';
import fs from 'node:fs';

const page = fs.readFileSync('RAH-RAVEN-AGENT-RUNNER.html', 'utf8');
const runner = fs.readFileSync('desktop-bridge/agent_runner.py', 'utf8');
const localStatus = fs.readFileSync('desktop-bridge/hovedpc_local_status.py', 'utf8');
const bridge = fs.readFileSync('desktop-bridge/raven_bridge.py', 'utf8');

assert.match(page, /Raven Agent Runner v0\.3/);
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

assert.match(runner, /AGENT_RUNNER_VERSION = "0\.3\.0"/);
assert.match(runner, /CAPABILITIES: dict/);
assert.match(runner, /"system-inventory": Capability/);
assert.match(runner, /title="HOVED-PC systeminventar"/);
assert.match(runner, /"hovedpc-local-status": Capability/);
assert.match(runner, /title="HOVED-PC lokalstatus"/);
assert.match(runner, /def _system_inventory\(\)/);
assert.match(runner, /def _hovedpc_local_status\(\)/);
assert.match(runner, /hovedpc_local_status\.collect_status/);
assert.match(runner, /Get-CimInstance Win32_VideoController/);
assert.match(runner, /fixed_script =/);
assert.match(runner, /"mode": "read-only-allowlist"/);
assert.match(runner, /"arbitrary_commands": False/);
assert.match(runner, /"file_writes": False/);
assert.match(runner, /"automatic_execution": False/);
assert.match(runner, /shell=False/);
assert.match(runner, /payload\.get\("confirm"\) is not True/);
assert.match(runner, /Capability er ikke i den lokale allowlisten/);
assert.match(runner, /return sorted\(output, key=str\.casefold\)/);
assert.match(runner, /"read_only": True/);
assert.match(runner, /"files_modified": False/);
assert.match(runner, /"automatic_actions": False/);
assert.doesNotMatch(runner, /shell=True/);
assert.doesNotMatch(runner, /payload\.get\("command"\)/);

assert.match(localStatus, /STATUS_VERSION = "1\.0\.0"/);
assert.match(localStatus, /def collect_status/);
assert.match(localStatus, /socket\.getaddrinfo/);
assert.match(localStatus, /shutil\.disk_usage/);
assert.match(localStatus, /tasklist\.exe/);
assert.match(localStatus, /IMAGENAME eq/);
assert.match(localStatus, /shell=False/);
assert.match(localStatus, /"arbitrary_paths": False/);
assert.match(localStatus, /"file_names_returned": False/);
assert.match(localStatus, /"file_contents_read": False/);
assert.match(localStatus, /"network_scan": False/);
assert.match(localStatus, /"external_network_requests": False/);
assert.match(localStatus, /"foreground_window_read": False/);
assert.doesNotMatch(localStatus, /shell=True/);
assert.doesNotMatch(localStatus, /request\./);
assert.doesNotMatch(localStatus, /urllib|requests\./);

assert.match(bridge, /import agent_runner/);
assert.match(bridge, /"\/agent\/"/);

console.log('Raven Agent Runner v0.3 local-boundary + system inventory + HOVED-PC local-status validation passed.');
