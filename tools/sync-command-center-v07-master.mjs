import assert from 'node:assert/strict';
import fs from 'node:fs';
const path='RAH-RAVEN-VERSION.json';const raven=JSON.parse(fs.readFileSync(path,'utf8'));
const expectedCore={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};
assert.equal(raven.product,'RAH Raven');assert.equal(raven.version,'2.0.32');assert.deepEqual(raven.release_gate.stable_components,expectedCore);assert.equal(raven.privacy.command_center_stable,true);assert.equal(raven.privacy.command_center_runtime_frozen,true);
const old='RAH Raven Command Center v0.6.0 are stable. Command Center v0.6 adds explicitly declared read-only node capabilities from a fixed allowlist; capability scanning, background polling, file access, shell access, device commands and remote control remain disabled.';
const next='RAH Raven Command Center v0.7.0 are stable. Command Center v0.7 adds one explicit authenticated read-only device action: a fixed system-volume storage summary; arbitrary paths, file listings, result persistence, writes, shell access, device commands, background polling, discovery and remote control remain disabled.';
assert.ok(raven.summary.includes(old),'Expected current Command Center v0.6 summary boundary');raven.summary=raven.summary.replace(old,next);
if(!raven.files.includes('RAH-COMMAND-CENTER-V0.7.html'))raven.files.push('RAH-COMMAND-CENTER-V0.7.html');
Object.assign(raven.privacy,{
 command_center_version_synced:true,
 command_center_stable:true,
 command_center_runtime_frozen:true,
 command_center_node_agent_version_synced:true,
 command_center_explicit_device_actions:true,
 command_center_node_storage_summary_read:true,
 command_center_node_storage_protocol_v1:true,
 command_center_node_storage_read_requires_capability:true,
 command_center_node_storage_read_requires_bearer_token:true,
 command_center_node_storage_read_get_only:true,
 command_center_storage_summary_fixed_system_volume:true,
 command_center_storage_summary_arbitrary_path:false,
 command_center_storage_summary_file_listing:false,
 command_center_storage_summary_result_persistence:false,
 command_center_device_background_polling:false,
 command_center_network_discovery:false,
 command_center_remote_control:false,
 command_center_device_commands:false,
 command_center_file_access:false,
 command_center_shell_access:false,
 command_center_credential_collection:false
});
assert.deepEqual(raven.release_gate.stable_components,expectedCore);fs.writeFileSync(path,JSON.stringify(raven,null,2)+'\n');
