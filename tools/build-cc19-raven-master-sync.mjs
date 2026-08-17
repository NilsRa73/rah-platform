import fs from 'node:fs';
import assert from 'node:assert/strict';

const ravenPath='RAH-RAVEN-VERSION.json';
const ccPath='RAH-COMMAND-CENTER-VERSION.json';
const releasePath='RAH-CC19-NODE13-STABLE-RELEASE.json';
const raven=JSON.parse(fs.readFileSync(ravenPath,'utf8'));
const cc=JSON.parse(fs.readFileSync(ccPath,'utf8'));
const release=JSON.parse(fs.readFileSync(releasePath,'utf8'));
const before=structuredClone(raven);
const stableCore={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};

assert.equal(raven.product,'RAH Raven');
assert.equal(raven.version,'2.0.32');
assert.equal(raven.release_gate.stage,'temporary-stable');
assert.equal(raven.release_gate.temporary_stable_target,'2.0.32');
assert.equal(raven.release_gate.development_paused,true);
assert.deepEqual(raven.release_gate.stable_components,stableCore);
assert.equal(cc.product,'RAH Raven Command Center');
assert.equal(cc.version,'1.9.0');
assert.equal(cc.stage,'stable');
assert.equal(cc.raven_contract,'2.0.32');
assert.equal(cc.entry,'RAH-COMMAND-CENTER-V1.9.html');
assert.equal(cc.runtime,'rah-command-center-core-v1.9.js');
assert.equal(cc.canonical_package_generation,4);
assert.equal(cc.package_files.length,37);
assert.equal(cc.release_gate.status,'passed');
assert.equal(cc.release_gate.runtime_files_frozen,true);
assert.equal(release.stage,'stable-release');
assert.equal(release.commandCenterVersion,'1.9.0');
assert.equal(release.nodeAgentVersion,'1.3.0');
assert.equal(release.nodeHealthProtocol,'rah-node-health-v2');
assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
assert.equal(release.authProtocol,'rah-node-auth-v2');
assert.equal(release.policyId,'rah-capability-allowlist-v1');
assert.equal(release.nodeRuntimeChange,false);
assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
const intent=release.mutatingIntentBinding;
assert.equal(intent.version,'rah-cc-mutating-intent-v1');
assert.deepEqual(intent.requiredActions,['rustdesk.launch','rustdesk.connect']);
assert.equal(intent.readOnlyStorageRequiresIntentBinding,false);
assert.equal(intent.ttlMs,90000);
assert.equal(intent.maxOutstanding,32);
assert.equal(intent.memoryOnly,true);
assert.equal(intent.persistent,false);
assert.equal(intent.singleUse,true);
assert.equal(intent.consumeBeforeNodeLocalConfirmation,true);
assert.equal(intent.consumeOnMismatch,true);
for(const k of ['bindsDeviceId','bindsEndpointIpv4','bindsNodeSession','bindsPolicyId','bindsNodeHealthProtocol','bindsNodeActionsProtocol','bindsNodeAuthProtocol','bindsActionId','bindsRequiredCapability','bindsCapabilitySnapshot','bindsAdvertisedActionSnapshot','bindsApprovedActionSnapshot','bindsTargetDigest','secureRandomRequired'])assert.equal(intent[k],true,k);
assert.equal(intent.storesRawTarget,false);
assert.equal(intent.mathRandomFallback,false);

raven.summary='RAH Raven 2.0.32 remains the temporary stable freeze with nine Stable core components unchanged. Project Brain Cloud Sync v1.1, Voice Control v1.7, Mission Engine v1.6, Raven Care v0.1 and Raven Fristvakt v0.2 remain stable supporting modules. Raven Chronicle v1.7.1 is stable. Raven Insights v0.1 is stable. Raven Daily Brief v0.1 is stable. RAH Raven Command Center v1.9.0 is Stable. Command Center v1.9 keeps the exact four capabilities compute, storage, display and remote-desktop; the exact three fixed actions storage-summary.read, rustdesk.launch and rustdesk.connect; and the exact five business routes /health, /actions, /storage, /launch/rustdesk and /handoff/rustdesk. Node Agent v1.3.0 remains rah-node-health-v2, rah-node-actions-v7 and rah-node-auth-v2 token-proof: the fresh Node token stays local and is not transported as Bearer over LAN. Mutating RustDesk actions retain the 90-second memory-only single-use one-shot approval and v1.9 additionally binds immutable execution intent to endpoint IPv4, Node session, policy/protocol identities, required capability, full sanitized capability/advertised/approved snapshots, action and SHA-256 target digest. Any drift consumes and rejects the ticket before Node-local confirmation; raw RustDesk target is never stored in the ticket. Existing advertised-action, capability, ephemeral Command Center approval, requester-source/context, Node-local human confirmation, fresh action challenge and Node-local approval proof remain independent gates. storage-summary.read remains read-only and outside the mutating-intent ledger. Password persistence, RustDesk peer-ID persistence, caller-controlled executable paths or generic arguments, installation, shell/file/generic process or action endpoints, device commands, discovery, background polling and native Raven remote-control authority remain disabled.';

const fileSet=new Set(raven.files);
for(const f of cc.package_files)fileSet.add(f);
fileSet.add('RAH-COMMAND-CENTER-VERSION.json');
raven.files=[...fileSet];

const p=raven.privacy;
Object.assign(p,{
  command_center_version_synced:true,
  command_center_canonical_version:'1.9.0',
  command_center_runtime_frozen:true,
  command_center_stable:true,
  command_center_canonical_package_generation:4,
  command_center_canonical_package_dependency_count:37,
  command_center_node_agent_version_synced:true,
  command_center_node_agent_version:'1.3.0',
  command_center_node_health_protocol_v2:true,
  command_center_node_action_protocol_v7:true,
  command_center_node_auth_protocol_v2:true,
  command_center_capability_count:4,
  command_center_action_count:3,
  command_center_business_route_count:5,
  command_center_exact_capability_allowlist:true,
  command_center_exact_action_allowlist:true,
  command_center_exact_business_route_allowlist:true,
  command_center_action_execution_requires_bearer_token:false,
  command_center_action_execution_requires_token_proof:true,
  command_center_token_proof_authentication:true,
  command_center_token_network_transport:false,
  command_center_bearer_authorization_transport:false,
  command_center_fresh_node_agent_token_required:true,
  command_center_token_local_only_transient:true,
  command_center_node_agent_token_memory_only:true,
  command_center_auth_nonce_single_use:true,
  command_center_auth_nonce_requester_source_bound:true,
  command_center_auth_nonce_memory_only:true,
  command_center_auth_nonce_persistence:false,
  command_center_auth_proof_hmac_sha256:true,
  command_center_auth_proof_binds_session:true,
  command_center_auth_proof_binds_method:true,
  command_center_auth_proof_binds_fixed_path:true,
  command_center_auth_proof_binds_body_sha256:true,
  command_center_auth_proof_webcrypto_required:true,
  command_center_auth_proof_fallback:false,
  command_center_auth_proof_persistence:false,
  command_center_requester_context_binding:true,
  command_center_requester_context_raw_persistence:false,
  command_center_requester_source_socket_ipv4_binding:true,
  command_center_forwarding_header_identity:false,
  command_center_node_local_human_confirmation:true,
  command_center_ephemeral_command_center_action_approval:true,
  command_center_node_storage_read_requires_bearer_token:false,
  command_center_node_storage_read_requires_token_proof:true,
  command_center_rustdesk_launch_requires_bearer_token:false,
  command_center_rustdesk_launch_requires_token_proof:true,
  command_center_rustdesk_handoff_requires_bearer_token:false,
  command_center_rustdesk_handoff_requires_token_proof:true,
  command_center_one_shot_mutating_approval:true,
  command_center_one_shot_required_rustdesk_launch:true,
  command_center_one_shot_required_rustdesk_connect:true,
  command_center_one_shot_storage_read_required:false,
  command_center_one_shot_ttl_ms:90000,
  command_center_one_shot_max_outstanding:32,
  command_center_one_shot_memory_only:true,
  command_center_one_shot_persistence:false,
  command_center_one_shot_single_use:true,
  command_center_one_shot_consume_before_node_local_confirmation:true,
  command_center_one_shot_consume_on_binding_mismatch:true,
  command_center_one_shot_binds_device_id:true,
  command_center_one_shot_binds_node_session:true,
  command_center_one_shot_binds_action_id:true,
  command_center_one_shot_binds_target_digest:true,
  command_center_one_shot_stores_raw_target:false,
  command_center_one_shot_secure_random_required:true,
  command_center_one_shot_math_random_fallback:false,
  command_center_immutable_mutating_intent_binding:true,
  command_center_mutating_intent_binding_version:'rah-cc-mutating-intent-v1',
  command_center_mutating_intent_required_rustdesk_launch:true,
  command_center_mutating_intent_required_rustdesk_connect:true,
  command_center_mutating_intent_storage_read_required:false,
  command_center_mutating_intent_ttl_ms:90000,
  command_center_mutating_intent_max_outstanding:32,
  command_center_mutating_intent_memory_only:true,
  command_center_mutating_intent_persistence:false,
  command_center_mutating_intent_single_use:true,
  command_center_mutating_intent_consume_before_node_local_confirmation:true,
  command_center_mutating_intent_consume_on_mismatch:true,
  command_center_mutating_intent_binds_device_id:true,
  command_center_mutating_intent_binds_endpoint_ipv4:true,
  command_center_mutating_intent_binds_node_session:true,
  command_center_mutating_intent_binds_policy_id:true,
  command_center_mutating_intent_binds_node_health_protocol:true,
  command_center_mutating_intent_binds_node_actions_protocol:true,
  command_center_mutating_intent_binds_node_auth_protocol:true,
  command_center_mutating_intent_binds_action_id:true,
  command_center_mutating_intent_binds_required_capability:true,
  command_center_mutating_intent_binds_capability_snapshot:true,
  command_center_mutating_intent_binds_advertised_action_snapshot:true,
  command_center_mutating_intent_binds_approved_action_snapshot:true,
  command_center_mutating_intent_binds_target_digest:true,
  command_center_mutating_intent_stores_raw_target:false,
  command_center_mutating_intent_secure_random_required:true,
  command_center_mutating_intent_math_random_fallback:false,
  command_center_rustdesk_handoff_peer_id_transient:true,
  command_center_rustdesk_handoff_peer_id_persistence:false,
  command_center_rustdesk_handoff_password_input:false,
  command_center_rustdesk_handoff_password_transport:false,
  command_center_rustdesk_handoff_password_persistence:false,
  command_center_rustdesk_installation:false,
  command_center_generic_process_launch:false,
  command_center_generic_action_endpoint:false,
  command_center_file_access:false,
  command_center_shell_access:false,
  command_center_remote_control:false,
  command_center_device_commands:false,
  command_center_network_discovery:false,
  command_center_device_background_polling:false,
  command_center_credential_collection:false
});

const beforeLocked=structuredClone(before);delete beforeLocked.summary;delete beforeLocked.files;delete beforeLocked.privacy;
const afterLocked=structuredClone(raven);delete afterLocked.summary;delete afterLocked.files;delete afterLocked.privacy;
assert.deepEqual(afterLocked,beforeLocked,'Only Raven summary/files/privacy may change');
assert.equal(raven.version,'2.0.32');
assert.deepEqual(raven.release_gate.stable_components,before.release_gate.stable_components);
for(const f of cc.package_files)assert.ok(raven.files.includes(f),`Raven files missing canonical CC dependency ${f}`);
for(const f of before.files)assert.ok(raven.files.includes(f),`Existing Raven file removed: ${f}`);
assert.ok(raven.summary.includes('RAH Raven Command Center v1.9.0 is Stable'));
assert.ok(raven.summary.includes('Raven Chronicle v1.7.1 is stable.'));
assert.ok(raven.summary.includes('Raven Insights v0.1 is stable.'));
assert.ok(raven.summary.includes('Raven Daily Brief v0.1 is stable.'));
assert.equal(p.command_center_token_proof_authentication,true);
assert.equal(p.command_center_action_execution_requires_bearer_token,false);
assert.equal(p.command_center_immutable_mutating_intent_binding,true);
fs.writeFileSync(ravenPath,JSON.stringify(raven,null,2)+'\n');
console.log('Raven master metadata synced to canonical CC v1.9 without changing Raven release gate/core map.');
