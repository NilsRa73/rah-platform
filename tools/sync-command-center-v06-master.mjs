import assert from 'node:assert/strict';
import fs from 'node:fs';

const path='RAH-RAVEN-VERSION.json';
const raven=JSON.parse(fs.readFileSync(path,'utf8'));
const expectedCore={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};
assert.equal(raven.product,'RAH Raven');
assert.equal(raven.version,'2.0.32');
assert.deepEqual(raven.release_gate.stable_components,expectedCore);
assert.equal(raven.privacy.command_center_stable,true);
assert.equal(raven.privacy.raven_care_stable,true);
assert.equal(raven.privacy.raven_fristvakt_stable,true);

raven.summary='RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components, Project Brain Cloud Sync v1.1, Voice Control v1.7, Mission Engine v1.6, Raven Care v0.1, Raven Fristvakt v0.2 and RAH Raven Command Center v0.6.0 are stable. Command Center v0.6 adds explicitly declared read-only node capabilities from a fixed allowlist; capability scanning, background polling, file access, shell access, device commands and remote control remain disabled.';
if(!raven.files.includes('RAH-COMMAND-CENTER-V0.6.html'))raven.files.push('RAH-COMMAND-CENTER-V0.6.html');
Object.assign(raven.privacy,{
 command_center_version_synced:true,
 command_center_stable:true,
 command_center_runtime_frozen:true,
 command_center_node_agent_version_synced:true,
 command_center_node_capabilities_declared_only:true,
 command_center_node_capability_source_explicit_cli_only:true,
 command_center_node_capability_scan:false,
 command_center_node_capability_allowlist:true,
 command_center_node_capability_allowlist_compute:true,
 command_center_node_capability_allowlist_storage:true,
 command_center_node_capability_allowlist_display:true,
 command_center_node_capability_allowlist_remote_desktop:true,
 command_center_node_permission_health_read:true,
 command_center_node_permission_capability_read:true,
 command_center_enrollment_capability_metadata_local_storage_only:true,
 command_center_device_background_polling:false,
 command_center_network_discovery:false,
 command_center_remote_control:false,
 command_center_device_commands:false,
 command_center_file_access:false,
 command_center_shell_access:false,
 command_center_credential_collection:false
});
assert.deepEqual(raven.release_gate.stable_components,expectedCore);
fs.writeFileSync(path,JSON.stringify(raven,null,2)+'\n');
