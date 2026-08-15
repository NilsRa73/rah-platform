import fs from 'node:fs';
import assert from 'node:assert/strict';

const ravenPath='RAH-RAVEN-VERSION.json';
const ccPath='RAH-COMMAND-CENTER-VERSION.json';
const raven=JSON.parse(fs.readFileSync(ravenPath,'utf8'));
const cc=JSON.parse(fs.readFileSync(ccPath,'utf8'));
const stableBefore=JSON.stringify(raven.release_gate?.stable_components||{});

assert.equal(raven.product,'RAH Raven');
assert.equal(raven.version,'2.0.32');
assert.equal(cc.version,'0.9.0');
assert.equal(cc.stage,'stable');
assert.equal(cc.release_gate?.status,'passed');
assert.equal(cc.release_gate?.gate_version,'1.5.0');
assert.equal(cc.node_agent?.agent_version,'0.5.0');
assert.match(raven.summary,/RAH Raven Command Center v0\.8\.0 are stable/);
assert.ok(Array.isArray(raven.files));
assert.ok(raven.files.includes('RAH-COMMAND-CENTER-V0.8.html'));
assert.equal(raven.files.includes('RAH-COMMAND-CENTER-V0.9.html'),false);

const oldText='RAH Raven Command Center v0.8.0 are stable. Command Center v0.8 adds an approved-action allowlist: nodes advertise a fixed action catalog and each action requires explicit local per-device approval plus a current bearer token before execution; the Stable catalog contains only storage-summary.read, while generic actions, arbitrary URLs or paths, file listings, writes, shell access, device commands, background polling, discovery and remote control remain disabled.';
const newText='RAH Raven Command Center v0.9.0 are stable. Command Center v0.9 adds one fixed external-app launcher action, rustdesk.launch: the node advertises it only with explicit remote-desktop capability and a locally resolved RustDesk binary, while execution still requires explicit per-device approval plus a current bearer token. The launch route is fixed to POST /launch/rustdesk with an empty body; arbitrary executables, paths, arguments, installation, generic process or action endpoints, shell access, file access, device commands, background polling, discovery and remote control remain disabled.';
assert.ok(raven.summary.includes(oldText),'Expected v0.8 Command Center summary baseline not found');
raven.summary=raven.summary.replace(oldText,newText);

const idx=raven.files.indexOf('RAH-COMMAND-CENTER-V0.8.html');
raven.files.splice(idx+1,0,'RAH-COMMAND-CENTER-V0.9.html');

Object.assign(raven.privacy,{
  command_center_version_synced:true,
  command_center_stable:true,
  command_center_runtime_frozen:true,
  command_center_node_agent_version_synced:true,
  command_center_external_app_launchers:true,
  command_center_external_app_allowlist:true,
  command_center_rustdesk_launch:true,
  command_center_rustdesk_launch_requires_remote_desktop_capability:true,
  command_center_rustdesk_launch_requires_local_approval:true,
  command_center_rustdesk_launch_requires_bearer_token:true,
  command_center_rustdesk_launch_post_only:true,
  command_center_rustdesk_launch_no_request_body:true,
  command_center_rustdesk_launch_fixed_executable_resolution:true,
  command_center_rustdesk_launch_requires_local_binary:true,
  command_center_rustdesk_launch_user_supplied_path:false,
  command_center_rustdesk_launch_user_supplied_arguments:false,
  command_center_rustdesk_installation:false,
  command_center_generic_process_launch:false,
  command_center_generic_action_endpoint:false,
  command_center_node_external_launch_protocol_v1:true,
  command_center_device_background_polling:false,
  command_center_network_discovery:false,
  command_center_remote_control:false,
  command_center_device_commands:false,
  command_center_file_access:false,
  command_center_shell_access:false,
  command_center_credential_collection:false
});

assert.equal(JSON.stringify(raven.release_gate?.stable_components||{}),stableBefore,'Stable core components changed during metadata sync');
assert.match(raven.summary,/Command Center v0\.9 adds one fixed external-app launcher action/);
assert.equal(raven.files.filter(x=>x==='RAH-COMMAND-CENTER-V0.9.html').length,1);
assert.equal(raven.privacy.command_center_external_app_launchers,true);
assert.equal(raven.privacy.command_center_rustdesk_launch,true);
assert.equal(raven.privacy.command_center_rustdesk_launch_user_supplied_path,false);
assert.equal(raven.privacy.command_center_rustdesk_launch_user_supplied_arguments,false);
assert.equal(raven.privacy.command_center_rustdesk_installation,false);
assert.equal(raven.privacy.command_center_generic_process_launch,false);
assert.equal(raven.privacy.command_center_remote_control,false);
assert.equal(raven.privacy.command_center_device_commands,false);

fs.writeFileSync(ravenPath,JSON.stringify(raven,null,2)+'\n');
console.log('RAH Raven master metadata synchronized to Command Center v0.9 Stable.');
