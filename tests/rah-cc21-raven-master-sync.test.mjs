import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const raven=JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));
const cc=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC21-NODE13-STABLE-RELEASE.json','utf8'));
const stableCore={raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'};
const cc21=['RAH-COMMAND-CENTER-V2.1.html','RAH-COMMAND-CENTER-V2.1-CANDIDATE.html','rah-command-center-core-v2.1-candidate.js','rah-command-center-core-v2.1.js','RAH-CC21-FLEET-SNAPSHOT-CANDIDATE.json','RAH-CC21-NODE13-STABLE-RELEASE.json'];

test('Raven 2.0.32 freeze and nine Stable core versions remain unchanged',()=>{
  assert.equal(raven.product,'RAH Raven');
  assert.equal(raven.version,'2.0.32');
  assert.equal(raven.release_gate.stage,'temporary-stable');
  assert.equal(raven.release_gate.temporary_stable_target,'2.0.32');
  assert.equal(raven.release_gate.development_paused,true);
  assert.deepEqual(raven.release_gate.stable_components,stableCore);
});

test('Raven master now names canonical CC 2.1 Stable generation 6',()=>{
  assert.equal(cc.version,'2.1.0');
  assert.equal(cc.stage,'stable');
  assert.equal(cc.raven_contract,'2.0.32');
  assert.equal(cc.entry,'RAH-COMMAND-CENTER-V2.1.html');
  assert.equal(cc.runtime,'rah-command-center-core-v2.1.js');
  assert.equal(cc.canonical_package_generation,6);
  assert.equal(cc.package_files.length,49);
  assert.match(raven.summary,/RAH Raven Command Center v2\.1\.0 is Stable and canonical/);
  assert.match(raven.summary,/Manual Fleet Snapshot/);
  for(const f of cc.package_files)assert.equal(raven.files.includes(f),true,'Raven package missing '+f);
  for(const f of cc21)assert.equal(raven.files.includes(f),true,'Raven CC2.1 artifact missing '+f);
});

test('authority, Node 1.3 and token-proof remain exact',()=>{
  assert.equal(release.nodeAgentVersion,'1.3.0');
  assert.equal(release.nodeRuntimeChange,false);
  assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
  const p=raven.privacy;
  assert.equal(p.command_center_capability_count,4);
  assert.equal(p.command_center_action_count,3);
  assert.equal(p.command_center_business_route_count,5);
  assert.equal(p.command_center_node_agent_version,'1.3.0');
  assert.equal(p.command_center_node_action_protocol_v7,true);
  assert.equal(p.command_center_node_auth_protocol_v2,true);
  assert.equal(p.command_center_token_network_transport,false);
  assert.equal(p.command_center_bearer_authorization_transport,false);
  assert.equal(p.command_center_action_execution_requires_token_proof,true);
});

test('one-shot, immutable intent and requester-context precommit remain retained',()=>{
  const p=raven.privacy;
  assert.equal(p.command_center_one_shot_mutating_approval,true);
  assert.equal(p.command_center_one_shot_single_use,true);
  assert.equal(p.command_center_one_shot_persistence,false);
  assert.equal(p.command_center_immutable_mutating_intent_binding,true);
  assert.equal(p.command_center_mutating_intent_binding_version,'rah-cc-mutating-intent-v1');
  assert.equal(p.command_center_precommitted_requester_context,true);
  assert.equal(p.command_center_precommitted_requester_context_version,'rah-cc-precommitted-requester-context-v1');
  assert.equal(p.command_center_precommitted_requester_context_raw_memory_only,true);
  assert.equal(p.command_center_precommitted_requester_context_raw_persistence,false);
  assert.equal(p.command_center_precommitted_requester_context_ticket_digest_only,true);
  assert.equal(p.command_center_precommitted_requester_context_same_context_confirmation_execution,true);
});

test('Manual Fleet Snapshot master metadata is explicit, memory-only and authority-neutral',()=>{
  const p=raven.privacy,f=release.fleetSnapshot;
  assert.equal(p.command_center_canonical_version,'2.1.0');
  assert.equal(p.command_center_canonical_package_generation,6);
  assert.equal(p.command_center_canonical_package_dependency_count,49);
  assert.equal(p.command_center_manual_fleet_snapshot,true);
  assert.equal(p.command_center_fleet_snapshot_version,'rah-cc-fleet-snapshot-v1');
  assert.equal(p.command_center_fleet_snapshot_scope,'already-enrolled-devices-only');
  assert.equal(p.command_center_fleet_snapshot_explicit_selected_device_refresh,true);
  assert.equal(p.command_center_fleet_snapshot_fresh_node_token_per_refresh,true);
  assert.equal(p.command_center_fleet_snapshot_token_proof_authentication,true);
  assert.equal(p.command_center_fleet_snapshot_session_match_required,true);
  assert.equal(p.command_center_fleet_snapshot_token_persistence,false);
  assert.equal(p.command_center_fleet_snapshot_memory_only,true);
  assert.equal(p.command_center_fleet_snapshot_persistence,false);
  assert.equal(p.command_center_fleet_snapshot_background_polling,false);
  assert.equal(p.command_center_fleet_snapshot_network_discovery,false);
  assert.equal(p.command_center_fleet_snapshot_automatic_storage_read,false);
  assert.equal(p.command_center_fleet_snapshot_automatic_remote_control,false);
  assert.equal(p.command_center_fleet_snapshot_mutating_actions,false);
  assert.equal(p.command_center_fleet_snapshot_cross_session_refresh_fails_closed,true);
  assert.equal(f.snapshotMemoryOnly,true);
  assert.equal(f.snapshotPersistence,false);
  assert.equal(f.backgroundPolling,false);
  assert.equal(f.networkDiscovery,false);
  assert.equal(f.automaticRemoteControl,false);
});

test('generic authority and secret persistence remain disabled',()=>{
  for(const x of ['new-capabilities','new-actions','new-routes','network-discovery','background-polling','bearer-token-network-transport','shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','native-raven-remote-control-api'])assert.ok(release.forbiddenRuntimeExpansion.includes(x),x);
  for(const x of ['fleet-snapshot','fleet-refresh-token','node-token','auth-nonce','auth-proof','action-challenge','node-local-approval-proof','password','rustdesk-peer-id','raw-requester-context'])assert.ok(release.forbiddenPersistence.includes(x),x);
});
