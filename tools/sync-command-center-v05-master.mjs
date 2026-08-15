import assert from 'node:assert/strict';
import fs from 'node:fs';

const path = 'RAH-RAVEN-VERSION.json';
const raven = JSON.parse(fs.readFileSync(path, 'utf8'));
const expectedCore = {
  raven_vision: '0.6',
  raven_council: '0.3',
  agent_runner: '0.3',
  memory_sync: '0.2',
  mission_control: '2.9',
  project_focus: '2.4',
  raven_core: '1.12',
  raven_now: '2.17',
  raven_studio: '2.8'
};

assert.equal(raven.product, 'RAH Raven');
assert.equal(raven.version, '2.0.32');
assert.deepEqual(raven.release_gate.stable_components, expectedCore);
assert.equal(raven.privacy.raven_care_stable, true);
assert.equal(raven.privacy.raven_fristvakt_stable, true);

raven.summary = 'RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components, Project Brain Cloud Sync v1.1, Voice Control v1.7, Mission Engine v1.6, Raven Care v0.1, Raven Fristvakt v0.2 and RAH Raven Command Center v0.5.0 are stable. Command Center v0.5 adds explicit read-only device enrollment through a separate token-protected Node Agent; discovery, background polling, remote control and device commands remain disabled.';

for (const file of [
  'RAH-COMMAND-CENTER-V0.5.html',
  'rah-node-agent.py',
  'START-RAH-NODE-AGENT.bat',
  'START-RAH-NODE-AGENT.sh'
]) {
  if (!raven.files.includes(file)) raven.files.push(file);
}

Object.assign(raven.privacy, {
  command_center_explicit_device_enrollment: true,
  command_center_enrollment_metadata_local_storage_only: true,
  command_center_node_agent_read_only_health: true,
  command_center_node_agent_fixed_port: 18766,
  command_center_node_agent_default_loopback_bind: true,
  command_center_node_agent_lan_bind_requires_explicit_flag: true,
  command_center_node_agent_token_memory_only: true,
  command_center_node_agent_automatic_start: false,
  command_center_node_agent_automatic_discovery: false,
  command_center_node_agent_command_endpoints: false,
  command_center_node_agent_file_endpoints: false,
  command_center_node_agent_shell_endpoints: false,
  command_center_enrollment_private_ipv4_only: true,
  command_center_enrollment_token_local_storage: false,
  command_center_enrollment_token_url_transport: false,
  command_center_device_health_check_explicit_only: true,
  command_center_device_background_polling: false,
  command_center_network_discovery: false,
  command_center_remote_control: false,
  command_center_device_commands: false,
  command_center_credential_collection: false,
  command_center_stable: true,
  command_center_runtime_frozen: true
});

assert.deepEqual(raven.release_gate.stable_components, expectedCore);
fs.writeFileSync(path, JSON.stringify(raven, null, 2) + '\n');
