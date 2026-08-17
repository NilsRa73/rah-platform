import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const raven=JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const cc=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC17-NODE13-STABLE-RELEASE.json','utf8'));
const stableCore={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};
const requiredFiles=['RAH-COMMAND-CENTER-V1.7.html','RAH-COMMAND-CENTER-V1.7-CANDIDATE.html','rah-command-center-core-v1.7.js','rah-command-center-core-v1.7-candidate.js','rah-node-agent-v1.3.py','rah-node-agent-v1.3-candidate.py','RAH-CC17-NODE13-STABLE-RELEASE.json'];

test('Raven master keeps frozen 2.0.32 core while canonical CC is v1.7 Stable',()=>{
  assert.equal(raven.version,'2.0.32');
  assert.deepEqual(raven.release_gate.stable_components,stableCore);
  assert.equal(cc.version,'1.7.0');assert.equal(cc.stage,'stable');assert.equal(cc.release_gate.status,'passed');
  assert.equal(release.commandCenterVersion,'1.7.0');assert.equal(release.nodeAgentVersion,'1.3.0');assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');assert.equal(release.authProtocol,'rah-node-auth-v2');
});

test('Raven master files include canonical CC 1.7 dependency anchors without removing older history',()=>{
  for(const file of requiredFiles)assert.ok(raven.files.includes(file),file);
  for(const historical of ['RAH-COMMAND-CENTER-V1.2.html','rah-command-center-core.js','rah-node-agent.py'])assert.ok(raven.files.includes(historical),historical);
});

test('Raven master summary identifies v1.7 as canonical and removes stale v1.2-current claim',()=>{
  assert.match(raven.summary,/Command Center v1\.7\.0/i);
  assert.match(raven.summary,/stable and canonical/i);
  assert.match(raven.summary,/token-proof/i);
  assert.match(raven.summary,/HMAC-SHA256/i);
  assert.doesNotMatch(raven.summary,/Command Center v1\.2\.0 is stable/i);
});

test('Raven master privacy reflects no-bearer token proof and independent action gates',()=>{
  const p=raven.privacy;
  for(const [key,value] of Object.entries({
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
    command_center_auth_proof_before_action_or_pair_consumption:true,
    command_center_requester_context_binding:true,
    command_center_requester_context_raw_persistence:false,
    command_center_requester_source_socket_ipv4_binding:true,
    command_center_forwarding_header_identity:false,
    command_center_node_local_human_confirmation:true,
    command_center_ephemeral_approval_session_only:true,
    command_center_approval_persistence:false,
    command_center_remote_control:false,
    command_center_device_commands:false,
    command_center_file_access:false,
    command_center_shell_access:false,
    command_center_generic_process_launch:false,
    command_center_generic_action_endpoint:false
  }))assert.equal(p[key],value,key);
  for(const stale of ['command_center_action_execution_requires_bearer_token','command_center_rustdesk_launch_requires_bearer_token','command_center_rustdesk_handoff_requires_bearer_token','command_center_node_storage_read_requires_bearer_token'])if(Object.hasOwn(p,stale))assert.equal(p[stale],false,stale);
});

test('Raven master exact CC authority remains 4 capabilities / 3 actions / 5 business routes',()=>{
  assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
  assert.equal(release.authoritySurface.newBusinessRoutes.length,0);
});
