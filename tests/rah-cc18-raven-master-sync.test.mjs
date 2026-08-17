import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const raven=JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const cc=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC18-NODE13-STABLE-RELEASE.json','utf8'));
const stableCore={
  raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'
};

test('Raven 2.0.32 freeze and nine Stable core versions stay unchanged',()=>{
  assert.equal(raven.product,'RAH Raven');
  assert.equal(raven.version,'2.0.32');
  assert.equal(raven.release_gate.stage,'temporary-stable');
  assert.equal(raven.release_gate.temporary_stable_target,'2.0.32');
  assert.equal(raven.release_gate.development_paused,true);
  assert.equal(raven.release_gate.change_policy,'bugfix-only-until-explicit-reopen');
  assert.deepEqual(raven.release_gate.stable_components,stableCore);
});

test('v1.8 Stable evidence remains packaged after later canonical releases',()=>{
  assert.equal(release.stage,'stable-release');
  assert.equal(release.commandCenterVersion,'1.8.0');
  assert.equal(release.nodeAgentVersion,'1.3.0');
  assert.equal(release.nodeRuntimeChange,false);
  assert.equal(cc.product,'RAH Raven Command Center');
  assert.equal(cc.stage,'stable');
  assert.equal(cc.raven_contract,'2.0.32');
  assert.equal(cc.node_agent.agent_version,'1.3.0');
  assert.equal(cc.node_agent.actions_protocol,'rah-node-actions-v7');
  assert.equal(cc.node_agent.auth_protocol,'rah-node-auth-v2');
  const evidence=[
    'RAH-CC18-NODE13-STABLE-RELEASE.json',
    release.runtime.commandCenterCore.path,
    release.runtime.commandCenterHtml.path,
    release.runtime.nodeAgent.path,
    release.pinnedCandidate.manifest.path,
    release.pinnedCandidate.commandCenterCore.path,
    release.pinnedCandidate.commandCenterHtml.path,
    release.directRollback.previousStableRelease.path,
    release.directRollback.commandCenterCore.path,
    release.directRollback.commandCenterHtml.path
  ];
  for(const f of evidence){
    assert.equal(fs.existsSync(f),true,`historical v1.8 evidence missing: ${f}`);
    assert.equal(cc.package_files.includes(f),true,`current canonical package dropped v1.8 evidence: ${f}`);
    assert.equal(raven.files.includes(f),true,`Raven package dropped v1.8 evidence: ${f}`);
  }
  assert.equal(raven.files.includes('RAH-COMMAND-CENTER-VERSION.json'),true);
});

test('v1.8 authority evidence remains exact 4 capabilities 3 actions and 5 business routes',()=>{
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(release.authProtocol,'rah-node-auth-v2');
  assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
  assert.equal(raven.privacy.command_center_capability_count,4);
  assert.equal(raven.privacy.command_center_action_count,3);
  assert.equal(raven.privacy.command_center_business_route_count,5);
});

test('token-proof no-bearer boundary remains truthful after later releases',()=>{
  const p=raven.privacy;
  assert.equal(p.command_center_node_agent_version,'1.3.0');
  assert.equal(p.command_center_node_action_protocol_v7,true);
  assert.equal(p.command_center_node_auth_protocol_v2,true);
  assert.equal(p.command_center_token_proof_authentication,true);
  assert.equal(p.command_center_token_network_transport,false);
  assert.equal(p.command_center_bearer_authorization_transport,false);
  assert.equal(p.command_center_action_execution_requires_bearer_token,false);
  assert.equal(p.command_center_node_storage_read_requires_bearer_token,false);
  assert.equal(p.command_center_rustdesk_launch_requires_bearer_token,false);
  assert.equal(p.command_center_rustdesk_handoff_requires_bearer_token,false);
  assert.equal(p.command_center_action_execution_requires_token_proof,true);
  assert.equal(p.command_center_node_storage_read_requires_token_proof,true);
  assert.equal(p.command_center_rustdesk_launch_requires_token_proof,true);
  assert.equal(p.command_center_rustdesk_handoff_requires_token_proof,true);
  assert.equal(p.command_center_auth_nonce_single_use,true);
  assert.equal(p.command_center_auth_nonce_requester_source_bound,true);
  assert.equal(p.command_center_auth_proof_hmac_sha256,true);
  assert.equal(p.command_center_auth_proof_webcrypto_required,true);
  assert.equal(p.command_center_auth_proof_fallback,false);
});

test('v1.8 one-shot boundary remains active and persistence-free',()=>{
  const p=raven.privacy;
  assert.equal(p.command_center_one_shot_mutating_approval,true);
  assert.equal(p.command_center_one_shot_required_rustdesk_launch,true);
  assert.equal(p.command_center_one_shot_required_rustdesk_connect,true);
  assert.equal(p.command_center_one_shot_storage_read_required,false);
  assert.equal(p.command_center_one_shot_ttl_ms,90000);
  assert.equal(p.command_center_one_shot_max_outstanding,32);
  assert.equal(p.command_center_one_shot_memory_only,true);
  assert.equal(p.command_center_one_shot_persistence,false);
  assert.equal(p.command_center_one_shot_single_use,true);
  assert.equal(p.command_center_one_shot_consume_before_node_local_confirmation,true);
  assert.equal(p.command_center_one_shot_consume_on_binding_mismatch,true);
  assert.equal(p.command_center_one_shot_stores_raw_target,false);
  assert.equal(p.command_center_one_shot_math_random_fallback,false);
});

test('forbidden generic authority and credential persistence remain disabled',()=>{
  const p=raven.privacy;
  for(const key of [
    'command_center_rustdesk_handoff_peer_id_persistence',
    'command_center_rustdesk_handoff_password_input',
    'command_center_rustdesk_handoff_password_transport',
    'command_center_rustdesk_handoff_password_persistence',
    'command_center_rustdesk_installation',
    'command_center_generic_process_launch',
    'command_center_generic_action_endpoint',
    'command_center_file_access',
    'command_center_shell_access',
    'command_center_remote_control',
    'command_center_device_commands',
    'command_center_network_discovery',
    'command_center_device_background_polling',
    'command_center_credential_collection'
  ])assert.equal(p[key],false,key);
});

console.log('RAH CC v1.8 historical Raven master evidence: PASS');
