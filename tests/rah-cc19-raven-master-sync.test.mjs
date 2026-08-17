import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const raven=JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const cc=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC19-NODE13-STABLE-RELEASE.json','utf8'));
const stableCore={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};
const v19Artifacts=['RAH-COMMAND-CENTER-V1.9.html','RAH-COMMAND-CENTER-V1.9-CANDIDATE.html','rah-command-center-core-v1.9-candidate.js','rah-command-center-core-v1.9.js','RAH-CC19-IMMUTABLE-MUTATING-INTENT-CANDIDATE.json','RAH-CC19-NODE13-STABLE-RELEASE.json'];

function versionAtLeast19(v){const m=/^(\d+)\.(\d+)\.(\d+)$/.exec(v||'');return !!m&&(Number(m[1])>1||(Number(m[1])===1&&Number(m[2])>=9));}

test('Raven 2.0.32 freeze and nine Stable core versions stay unchanged',()=>{
  assert.equal(raven.product,'RAH Raven');
  assert.equal(raven.version,'2.0.32');
  assert.equal(raven.release_gate.stage,'temporary-stable');
  assert.equal(raven.release_gate.temporary_stable_target,'2.0.32');
  assert.equal(raven.release_gate.development_paused,true);
  assert.deepEqual(raven.release_gate.stable_components,stableCore);
});

test('historical CC 1.9 Stable evidence remains packaged under current canonical',()=>{
  assert.equal(cc.product,'RAH Raven Command Center');
  assert.equal(cc.stage,'stable');
  assert.equal(cc.raven_contract,'2.0.32');
  assert.equal(versionAtLeast19(cc.version),true);
  assert.equal(cc.release_gate.status,'passed');
  assert.equal(cc.release_gate.runtime_files_frozen,true);
  assert.match(raven.summary,/Raven Chronicle v1\.7\.1 is stable/);
  assert.match(raven.summary,/Raven Insights v0\.1 is stable/);
  assert.match(raven.summary,/Raven Daily Brief v0\.1 is stable/);
  assert.equal(raven.files.includes('RAH-COMMAND-CENTER-VERSION.json'),true);
  for(const f of v19Artifacts)assert.equal(raven.files.includes(f),true,`Raven package missing historical v1.9 artifact ${f}`);
});

test('historical v1.9 release authority remains exact 4 capabilities 3 actions 5 routes and Node 1.3',()=>{
  assert.equal(release.commandCenterVersion,'1.9.0');
  assert.equal(release.nodeAgentVersion,'1.3.0');
  assert.equal(release.nodeHealthProtocol,'rah-node-health-v2');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(release.authProtocol,'rah-node-auth-v2');
  assert.equal(release.nodeRuntimeChange,false);
  assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
  assert.equal(raven.privacy.command_center_capability_count,4);
  assert.equal(raven.privacy.command_center_action_count,3);
  assert.equal(raven.privacy.command_center_business_route_count,5);
  assert.equal(raven.privacy.command_center_node_agent_version,'1.3.0');
});

test('token-proof remains no-Bearer and local-secret only',()=>{
  const p=raven.privacy;
  assert.equal(p.command_center_node_action_protocol_v7,true);
  assert.equal(p.command_center_node_auth_protocol_v2,true);
  assert.equal(p.command_center_token_proof_authentication,true);
  assert.equal(p.command_center_token_network_transport,false);
  assert.equal(p.command_center_bearer_authorization_transport,false);
  assert.equal(p.command_center_action_execution_requires_bearer_token,false);
  assert.equal(p.command_center_action_execution_requires_token_proof,true);
  assert.equal(p.command_center_auth_nonce_single_use,true);
  assert.equal(p.command_center_auth_nonce_requester_source_bound,true);
  assert.equal(p.command_center_auth_proof_hmac_sha256,true);
  assert.equal(p.command_center_auth_proof_webcrypto_required,true);
  assert.equal(p.command_center_auth_proof_fallback,false);
});

test('v1.8 one-shot boundary remains active under current canonical',()=>{
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
  assert.equal(p.command_center_one_shot_stores_raw_target,false);
  assert.equal(p.command_center_one_shot_math_random_fallback,false);
});

test('v1.9 immutable mutating-intent boundary remains retained under current canonical',()=>{
  const p=raven.privacy,b=release.mutatingIntentBinding;
  assert.equal(p.command_center_immutable_mutating_intent_binding,true);
  assert.equal(p.command_center_mutating_intent_binding_version,'rah-cc-mutating-intent-v1');
  assert.equal(p.command_center_mutating_intent_required_rustdesk_launch,true);
  assert.equal(p.command_center_mutating_intent_required_rustdesk_connect,true);
  assert.equal(p.command_center_mutating_intent_storage_read_required,false);
  assert.equal(p.command_center_mutating_intent_ttl_ms,90000);
  assert.equal(p.command_center_mutating_intent_max_outstanding,32);
  assert.equal(p.command_center_mutating_intent_memory_only,true);
  assert.equal(p.command_center_mutating_intent_persistence,false);
  assert.equal(p.command_center_mutating_intent_single_use,true);
  assert.equal(p.command_center_mutating_intent_consume_before_node_local_confirmation,true);
  assert.equal(p.command_center_mutating_intent_consume_on_mismatch,true);
  for(const key of ['bindsDeviceId','bindsEndpointIpv4','bindsNodeSession','bindsPolicyId','bindsNodeHealthProtocol','bindsNodeActionsProtocol','bindsNodeAuthProtocol','bindsActionId','bindsRequiredCapability','bindsCapabilitySnapshot','bindsAdvertisedActionSnapshot','bindsApprovedActionSnapshot','bindsTargetDigest']){
    const snake=key.replace(/[A-Z]/g,m=>'_'+m.toLowerCase());
    assert.equal(p['command_center_mutating_intent_'+snake],true,key);
    assert.equal(b[key],true,key);
  }
  assert.equal(p.command_center_mutating_intent_stores_raw_target,false);
  assert.equal(p.command_center_mutating_intent_secure_random_required,true);
  assert.equal(p.command_center_mutating_intent_math_random_fallback,false);
  assert.equal(b.storesRawTarget,false);
  assert.equal(b.mathRandomFallback,false);
});

test('generic authority and credential persistence remain disabled',()=>{
  const p=raven.privacy;
  for(const key of ['command_center_rustdesk_handoff_peer_id_persistence','command_center_rustdesk_handoff_password_input','command_center_rustdesk_handoff_password_transport','command_center_rustdesk_handoff_password_persistence','command_center_rustdesk_installation','command_center_generic_process_launch','command_center_generic_action_endpoint','command_center_file_access','command_center_shell_access','command_center_remote_control','command_center_device_commands','command_center_network_discovery','command_center_device_background_polling','command_center_credential_collection'])assert.equal(p[key],false,key);
});

console.log('RAH CC v1.9 historical Raven evidence contract: PASS');
