import fs from'node:fs';import assert from'node:assert/strict';
const ravenPath='RAH-RAVEN-VERSION.json',ccPath='RAH-COMMAND-CENTER-VERSION.json',releasePath='RAH-CC17-NODE13-STABLE-RELEASE.json';
const raven=JSON.parse(fs.readFileSync(ravenPath,'utf8')),before=structuredClone(raven),cc=JSON.parse(fs.readFileSync(ccPath,'utf8')),release=JSON.parse(fs.readFileSync(releasePath,'utf8'));
assert.equal(raven.version,'2.0.32');assert.equal(cc.version,'1.7.0');assert.equal(cc.stage,'stable');assert.equal(cc.release_gate.status,'passed');assert.equal(cc.release_gate.runtime_files_frozen,true);assert.equal(release.stage,'stable-release');assert.equal(release.commandCenterVersion,'1.7.0');assert.equal(release.nodeAgentVersion,'1.3.0');assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');assert.equal(release.authProtocol,'rah-node-auth-v2');assert.equal(release.policyId,'rah-capability-allowlist-v1');assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);assert.deepEqual(release.authoritySurface.newBusinessRoutes,[]);

const old=String(raven.summary||'');
const ccMarker='and RAH Raven Command Center';
const ccPos=old.indexOf(ccMarker);
let prefix='RAH Raven 2.0.32 remains the temporary stable freeze. Nine core components and RAH Raven Command Center v1.7.0 are stable.';
let suffix='';
if(ccPos>=0){
  prefix=old.slice(0,ccPos)+'and RAH Raven Command Center v1.7.0 is stable and canonical.';
  const suffixMarkers=['Raven Chronicle','Raven Insights','Raven Daily Brief','Raven Fastlegevisning','Raven Health','Raven Project Registry','Raven Case Center'];
  const positions=suffixMarkers.map(marker=>old.indexOf(marker,ccPos)).filter(pos=>pos>ccPos);
  if(positions.length)suffix=old.slice(Math.min(...positions)).trim();
}
const ccDetails='Command Center v1.7 keeps the exact fixed authority of four capabilities (compute, storage, display, remote-desktop), three actions (storage-summary.read, rustdesk.launch, rustdesk.connect) and five business routes (/health, /actions, /storage, /launch/rustdesk, /handoff/rustdesk). Node Agent v1.3 replaces reusable bearer-token LAN transport with token-proof authentication: a challenge-only mode on the existing GET /health route issues a short-lived source-bound single-use nonce, while Command Center keeps the fresh Node token local and computes HMAC-SHA256 over the Node session, nonce, exact HTTP method/path, exact body hash and fixed Raven security fields. Authorization/Bearer fallback is rejected. Proof verification occurs before action-challenge or Node-local approval-pair consumption. Existing session/policy checks, advertised action, capability, ephemeral Command Center approval, actual socket requester-source binding, requester-context binding, Node-local human confirmation, fresh action challenge and fresh Node-local approval proof remain independent gates. Handoff hashes and parses the same cached request-body bytes. Tokens, auth nonces/proofs, requester context, approval proofs, passwords, RustDesk peer IDs and action results are not persisted. Shell access, generic commands/processes/actions/files, caller-controlled executable paths/arguments, discovery and native Raven remote control remain disabled. Direct rollback remains CC v1.6 / Node v1.2 without data, secret or registry migration.';
raven.summary=(prefix+' '+ccDetails+(suffix?' '+suffix:'')).replace(/\s+/g,' ').trim();

const requiredFiles=['RAH-COMMAND-CENTER-V1.7.html','RAH-COMMAND-CENTER-V1.7-CANDIDATE.html','rah-command-center-core-v1.7.js','rah-command-center-core-v1.7-candidate.js','rah-node-agent-v1.3.py','rah-node-agent-v1.3-candidate.py','RAH-CC17-NODE13-STABLE-RELEASE.json'];
const fileSet=new Set(Array.isArray(raven.files)?raven.files:[]);for(const file of requiredFiles)fileSet.add(file);raven.files=[...fileSet];

raven.privacy=raven.privacy&&typeof raven.privacy==='object'&&!Array.isArray(raven.privacy)?raven.privacy:{};
Object.assign(raven.privacy,{
  command_center_canonical_v17_stable:true,
  command_center_token_proof_authentication:true,
  command_center_token_network_transport:false,
  command_center_bearer_authorization_transport:false,
  command_center_auth_protocol_v2:true,
  command_center_auth_bootstrap_existing_health_route:true,
  command_center_auth_bootstrap_new_route:false,
  command_center_auth_nonce_single_use:true,
  command_center_auth_nonce_requester_source_bound:true,
  command_center_auth_nonce_memory_only:true,
  command_center_auth_nonce_persistence:false,
  command_center_auth_proof_hmac_sha256:true,
  command_center_auth_proof_binds_exact_method_path_body_security_fields:true,
  command_center_auth_proof_before_action_or_pair_consumption:true,
  command_center_requester_context_binding:true,
  command_center_requester_context_raw_persistence:false,
  command_center_requester_source_socket_ipv4_binding:true,
  command_center_forwarding_header_identity:false,
  command_center_node_local_human_confirmation:true,
  command_center_ephemeral_approval_session_only:true,
  command_center_approval_persistence:false,
  command_center_node_health_protocol_v2:true,
  command_center_node_action_protocol_v7:true,
  command_center_exact_capability_allowlist:true,
  command_center_exact_action_allowlist:true,
  command_center_exact_business_route_allowlist:true,
  command_center_action_execution_requires_bearer_token:false,
  command_center_rustdesk_launch_requires_bearer_token:false,
  command_center_rustdesk_handoff_requires_bearer_token:false,
  command_center_node_storage_read_requires_bearer_token:false,
  command_center_action_challenge_bearer_compromise_protection:true,
  command_center_remote_control:false,
  command_center_device_commands:false,
  command_center_file_access:false,
  command_center_shell_access:false,
  command_center_generic_process_launch:false,
  command_center_generic_action_endpoint:false
});
for(const key of Object.keys(before))if(!['summary','files','privacy'].includes(key))assert.deepEqual(raven[key],before[key],`unexpected Raven master mutation: ${key}`);
fs.writeFileSync(ravenPath,JSON.stringify(raven,null,2)+'\n');
console.log('RAH Raven master synced to canonical CC v1.7 using summary/files/privacy only.');
