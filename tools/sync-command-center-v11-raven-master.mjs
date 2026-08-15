import fs from 'node:fs';
const ravenPath='RAH-RAVEN-VERSION.json',ccPath='RAH-COMMAND-CENTER-VERSION.json';
const raven=JSON.parse(fs.readFileSync(ravenPath,'utf8')),cc=JSON.parse(fs.readFileSync(ccPath,'utf8'));
const stableBefore=JSON.stringify(raven.release_gate?.stable_components||{});
if(raven.product!=='RAH Raven'||raven.version!=='2.0.32')throw new Error('Raven baseline mismatch');
if(cc.version!=='1.1.0'||cc.stage!=='stable'||cc.release_gate?.status!=='passed'||cc.release_gate?.gate_version!=='1.7.0'||cc.node_agent?.agent_version!=='0.7.0'||cc.node_agent?.actions_protocol!=='rah-node-actions-v2')throw new Error('CC v1.1 Stable baseline mismatch');
const start='RAH Raven Command Center v1.0.0 is stable.';
const end='The handoff response claims only handoff-started, not a successful remote session.';
const a=raven.summary.indexOf(start),b=raven.summary.indexOf(end,a);
if(a<0||b<0)throw new Error('v1.0 Raven summary baseline not found');
const replacement='RAH Raven Command Center v1.1.0 is stable. Command Center v1.1 keeps the exact fixed action allowlist storage-summary.read, rustdesk.launch and rustdesk.connect, and adds one-time replay challenges without adding new action authority. Every explicit action still requires the node-advertised action, the required capability, local per-device Command Center approval and a current bearer token; in addition, Command Center explicitly refreshes the fixed authenticated /actions route and receives a fresh action-bound 60-second single-use challenge generated in Node Agent memory. The challenge is sent only in the fixed X-RAH-Action-Challenge header and is consumed once; refreshing the catalogue invalidates prior challenges. Challenges are not persisted, stored in browser storage, placed in URLs or request bodies, and are not a second factor: they reduce replay risk but do not protect a compromised current bearer token. Existing password-free RustDesk boundaries remain: peer IDs and passwords are not persisted, passwords are not accepted or transported, and user-supplied executable paths, arbitrary arguments, server/key/URL overrides, installation, generic process or action endpoints, shell access, file access, device commands, background polling, discovery and native Raven remote control remain disabled. RustDesk handoff still claims only handoff-started, not a successful remote session.';
raven.summary=raven.summary.slice(0,a)+replacement+raven.summary.slice(b+end.length);
if(!raven.files.includes('RAH-COMMAND-CENTER-V1.0.html'))throw new Error('v1.0 Raven file baseline missing');
if(raven.files.includes('RAH-COMMAND-CENTER-V1.1.html'))throw new Error('v1.1 Raven file already present');
const idx=raven.files.indexOf('RAH-COMMAND-CENTER-V1.0.html');raven.files.splice(idx+1,0,'RAH-COMMAND-CENTER-V1.1.html');
Object.assign(raven.privacy,{
 command_center_version_synced:true,
 command_center_stable:true,
 command_center_runtime_frozen:true,
 command_center_node_agent_version_synced:true,
 command_center_node_action_protocol_v2:true,
 command_center_action_challenge_required:true,
 command_center_action_challenge_header_fixed:true,
 command_center_action_challenge_ttl_60_seconds:true,
 command_center_action_challenge_action_bound:true,
 command_center_action_challenge_single_use:true,
 command_center_action_challenge_memory_only:true,
 command_center_action_challenge_persistence:false,
 command_center_action_challenge_local_storage:false,
 command_center_action_challenge_url_transport:false,
 command_center_action_challenge_body_transport:false,
 command_center_action_challenge_fresh_catalog_required:true,
 command_center_action_challenge_refresh_invalidates_previous:true,
 command_center_action_challenge_replay_protection:true,
 command_center_action_challenge_bearer_compromise_protection:false,
 command_center_action_token_reentry_each_click:true,
 command_center_action_token_field_cleared_after_click:true,
 command_center_remote_control:false,
 command_center_device_commands:false,
 command_center_file_access:false,
 command_center_shell_access:false,
 command_center_credential_collection:false,
 command_center_generic_process_launch:false,
 command_center_generic_action_endpoint:false,
 command_center_node_native_remote_control_endpoints:false
});
if(JSON.stringify(raven.release_gate?.stable_components||{})!==stableBefore)throw new Error('Stable Raven core components changed');
if(!raven.summary.includes('RAH Raven Command Center v1.1.0 is stable'))throw new Error('v1.1 summary sync failed');
if(raven.files.filter(x=>x==='RAH-COMMAND-CENTER-V1.1.html').length!==1)throw new Error('v1.1 file-list sync failed');
fs.writeFileSync(ravenPath,JSON.stringify(raven,null,2)+'\n');
console.log('Raven master synchronized atomically to Command Center v1.1 Stable; nine Stable core components preserved.');
