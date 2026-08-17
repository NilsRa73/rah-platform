import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

const sourceCommit='1354f5166e473ed0128af78e6eca717344e37467';
const readJson=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const raven=readJson('RAH-RAVEN-VERSION.json');
const cc=readJson('RAH-COMMAND-CENTER-VERSION.json');
const release=readJson('RAH-CC22-NODE13-STABLE-RELEASE.json');
const sync=readJson('RAH-CC22-RAVEN-MASTER-SYNC.json');
const oldRaven=JSON.parse(execFileSync('git',['show',`${sourceCommit}:RAH-RAVEN-VERSION.json`],{encoding:'utf8'}));
const blob=p=>execFileSync('git',['hash-object',p],{encoding:'utf8'}).trim();
const revBlob=(commit,path)=>execFileSync('git',['rev-parse',`${commit}:${path}`],{encoding:'utf8'}).trim();
const added=[
  'RAH-COMMAND-CENTER-V2.2.html',
  'RAH-COMMAND-CENTER-V2.2-CANDIDATE.html',
  'rah-command-center-core-v2.2-candidate.js',
  'rah-command-center-core-v2.2.js',
  'RAH-CC22-FLEET-SNAPSHOT-INVALIDATION-CANDIDATE.json',
  'RAH-CC22-NODE13-STABLE-RELEASE.json'
];
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('sync evidence pins exact before/after Raven manifest and no Raven version bump',()=>{
  assert.equal(sync.stage,'raven-master-sync');
  assert.equal(sync.authorityDelta,'none');
  assert.equal(sync.ravenVersion,'2.0.32');
  assert.equal(sync.ravenRuntimeFeatureChange,false);
  assert.equal(revBlob(sourceCommit,'RAH-RAVEN-VERSION.json'),sync.sourceRavenManifest.gitBlobSha);
  assert.equal(blob('RAH-RAVEN-VERSION.json'),sync.syncedRavenManifest.gitBlobSha);
  assert.equal(sync.sourceRavenManifest.commandCenterVersion,'2.1.0');
  assert.equal(sync.syncedRavenManifest.commandCenterVersion,'2.2.0');
  assert.equal(raven.version,'2.0.32');
  assert.equal(raven.launcher,'3.0');
  assert.equal(raven.release_gate.stage,'temporary-stable');
  assert.equal(raven.release_gate.temporary_stable_target,'2.0.32');
  assert.equal(raven.release_gate.runtime_feature_change,false);
  assert.equal(raven.release_gate.development_paused,true);
  assert.equal(raven.release_gate.change_policy,'bugfix-only-until-explicit-reopen');
});

test('only the explicitly allowed Command Center Raven metadata changed',()=>{
  const normalized=structuredClone(raven);
  normalized.summary=oldRaven.summary;
  normalized.files=oldRaven.files;
  normalized.privacy.command_center_canonical_version=oldRaven.privacy.command_center_canonical_version;
  normalized.privacy.command_center_canonical_package_generation=oldRaven.privacy.command_center_canonical_package_generation;
  normalized.privacy.command_center_canonical_package_dependency_count=oldRaven.privacy.command_center_canonical_package_dependency_count;
  for(const key of [
    'command_center_fleet_snapshot_fail_closed_invalidation',
    'command_center_fleet_snapshot_invalidation_version',
    'command_center_fleet_snapshot_failure_policy',
    'command_center_fleet_snapshot_failed_refresh_invalidates_selected_row'
  ]) delete normalized.privacy[key];
  assert.deepEqual(normalized,oldRaven);
});

test('Raven file manifest appends exactly the six versioned CC2.2 files',()=>{
  assert.deepEqual(raven.files.slice(0,oldRaven.files.length),oldRaven.files);
  assert.deepEqual(raven.files.slice(oldRaven.files.length),added);
  assert.deepEqual(sync.ravenFilesAdded,added);
  for(const p of added)assert.ok(fs.existsSync(p),p);
});

test('Raven master and canonical CC agree on 2.2 generation 7 with exact Node1.3 4/3/5 authority',()=>{
  const q=raven.privacy;
  assert.equal(cc.version,'2.2.0');
  assert.equal(cc.stage,'stable');
  assert.equal(cc.canonical_package_generation,7);
  assert.equal(cc.features.canonical_package_dependency_count,55);
  assert.equal(q.command_center_version_synced,true);
  assert.equal(q.command_center_canonical_version,'2.2.0');
  assert.equal(q.command_center_canonical_package_generation,7);
  assert.equal(q.command_center_canonical_package_dependency_count,55);
  assert.equal(q.command_center_node_agent_version,'1.3.0');
  assert.equal(q.command_center_node_action_protocol_v7,true);
  assert.equal(q.command_center_node_auth_protocol_v2,true);
  assert.equal(q.command_center_capability_count,4);
  assert.equal(q.command_center_action_count,3);
  assert.equal(q.command_center_business_route_count,5);
  assert.equal(q.command_center_exact_capability_allowlist,true);
  assert.equal(q.command_center_exact_action_allowlist,true);
  assert.equal(q.command_center_exact_business_route_allowlist,true);
  assert.deepEqual(release.authoritySurface.capabilities,caps);
  assert.deepEqual(release.authoritySurface.actions,actions);
  assert.deepEqual(release.authoritySurface.businessRoutes,routes);
  assert.deepEqual(sync.commandCenter.capabilities,caps);
  assert.deepEqual(sync.commandCenter.actions,actions);
  assert.deepEqual(sync.commandCenter.businessRoutes,routes);
});

test('fail-closed Fleet Snapshot metadata is synced without polling, persistence or remote authority',()=>{
  const q=raven.privacy;
  assert.equal(q.command_center_manual_fleet_snapshot,true);
  assert.equal(q.command_center_fleet_snapshot_memory_only,true);
  assert.equal(q.command_center_fleet_snapshot_persistence,false);
  assert.equal(q.command_center_fleet_snapshot_background_polling,false);
  assert.equal(q.command_center_fleet_snapshot_network_discovery,false);
  assert.equal(q.command_center_fleet_snapshot_automatic_remote_control,false);
  assert.equal(q.command_center_fleet_snapshot_fail_closed_invalidation,true);
  assert.equal(q.command_center_fleet_snapshot_invalidation_version,'rah-cc-fleet-snapshot-invalidation-v1');
  assert.equal(q.command_center_fleet_snapshot_failure_policy,'invalidate-selected-row-on-refresh-failure');
  assert.equal(q.command_center_fleet_snapshot_failed_refresh_invalidates_selected_row,true);
  assert.match(raven.summary,/Command Center v2\.2 retains Manual Fleet Snapshot/);
  assert.match(raven.summary,/invalidates the selected stale row before rendering a failed refresh/);
});

test('all existing Raven Command Center security boundaries remain fail-closed',()=>{
  const q=raven.privacy;
  for(const key of [
    'command_center_approved_action_requires_advertised_action',
    'command_center_approved_action_requires_capability',
    'command_center_action_execution_requires_local_approval',
    'command_center_action_execution_requires_token_proof',
    'command_center_token_proof_authentication',
    'command_center_fresh_node_agent_token_required',
    'command_center_node_local_human_confirmation'
  ])assert.equal(q[key],true,key);
  for(const key of [
    'command_center_token_network_transport',
    'command_center_bearer_authorization_transport',
    'command_center_generic_process_launch',
    'command_center_generic_action_endpoint',
    'command_center_file_access',
    'command_center_shell_access',
    'command_center_device_commands',
    'command_center_remote_control',
    'command_center_network_discovery',
    'command_center_device_background_polling',
    'command_center_rustdesk_handoff_peer_id_persistence',
    'command_center_rustdesk_handoff_password_persistence',
    'command_center_rustdesk_launch_user_supplied_path',
    'command_center_rustdesk_launch_user_supplied_arguments',
    'command_center_rustdesk_handoff_user_supplied_path',
    'command_center_rustdesk_handoff_user_supplied_arguments'
  ])assert.equal(q[key],false,key);
  assert.equal(sync.preservedBoundaries.shell,false);
  assert.equal(sync.preservedBoundaries.genericProcessLaunch,false);
  assert.equal(sync.preservedBoundaries.genericActionEndpoint,false);
  assert.equal(sync.preservedBoundaries.nativeRemoteControl,false);
});
