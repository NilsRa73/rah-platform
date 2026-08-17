import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const release=JSON.parse(fs.readFileSync('RAH-CC21-NODE13-STABLE-RELEASE.json','utf8'));
const readiness=JSON.parse(fs.readFileSync('RAH-CC21-STABLE-PROMOTION-GATE.json','utf8'));
const candidateManifest=JSON.parse(fs.readFileSync('RAH-CC21-FLEET-SNAPSHOT-CANDIDATE.json','utf8'));
const rootManifest=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const stableCore=require('../rah-command-center-core-v2.1.js');
const stableCoreSource=fs.readFileSync('rah-command-center-core-v2.1.js','utf8');
const stableHtml=fs.readFileSync('RAH-COMMAND-CENTER-V2.1.html','utf8');
function blob(path){return execFileSync('git',['rev-parse',`HEAD:${path}`],{encoding:'utf8'}).trim()}

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('Stable v2.1 identity and authority are exact',()=>{
  assert.equal(release.stage,'stable-release');
  assert.equal(release.authorityDelta,'none');
  assert.equal(release.ravenVersion,'2.0.32');
  assert.equal(release.commandCenterVersion,'2.1.0');
  assert.equal(release.nodeAgentVersion,'1.3.0');
  assert.equal(release.nodeHealthProtocol,'rah-node-health-v2');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(release.authProtocol,'rah-node-auth-v2');
  assert.equal(release.policyId,'rah-capability-allowlist-v1');
  assert.equal(release.nodeRuntimeChange,false);
  assert.deepEqual(release.authoritySurface.capabilities,caps);
  assert.deepEqual(release.authoritySurface.actions,actions);
  assert.deepEqual(release.authoritySurface.businessRoutes,routes);
  assert.deepEqual(release.authoritySurface.newCapabilities,[]);
  assert.deepEqual(release.authoritySurface.newActions,[]);
  assert.deepEqual(release.authoritySurface.newBusinessRoutes,[]);
});

test('Stable runtime, Candidate, readiness and rollback blobs are pinned exactly',()=>{
  const rows=[release.runtime.commandCenterCore,release.runtime.commandCenterHtml,release.runtime.nodeAgent,release.pinnedCandidate.manifest,release.pinnedCandidate.commandCenterCore,release.pinnedCandidate.commandCenterHtml,release.readiness,release.directRollback.previousStableRelease,release.directRollback.commandCenterCore,release.directRollback.commandCenterHtml,release.directRollback.nodeAgent];
  for(const row of rows)assert.equal(blob(row.path),row.gitBlobSha,row.path+' blob drift');
  assert.equal(release.readiness.gitBlobSha,blob('RAH-CC21-STABLE-PROMOTION-GATE.json'));
  assert.equal(readiness.candidate.commandCenterCore.gitBlobSha,release.pinnedCandidate.commandCenterCore.gitBlobSha);
  assert.equal(readiness.candidate.commandCenterHtml.gitBlobSha,release.pinnedCandidate.commandCenterHtml.gitBlobSha);
});

test('Stable core is a strict wrapper over exact CC 2.1 Candidate',()=>{
  assert.equal(stableCore.CC_VERSION,'2.1.0');
  assert.equal(stableCore.FLEET_SNAPSHOT_VERSION,'rah-cc-fleet-snapshot-v1');
  assert.equal(stableCore.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v7');
  assert.equal(stableCore.NODE_AUTH_PROTOCOL,'rah-node-auth-v2');
  assert.equal(stableCore.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.deepEqual(stableCore.CAPABILITY_IDS,caps);
  assert.deepEqual(stableCore.ACTION_IDS,actions);
  assert.deepEqual(stableCore.AUTHENTICATED_PATHS,routes);
  assert.match(stableCoreSource,/require\('\.\/rah-command-center-core-v2\.1-candidate\.js'\)/);
  assert.match(stableCoreSource,/candidate\.CC_VERSION!=='2\.1\.0-candidate'/);
  assert.match(stableCoreSource,/candidate\.FLEET_SNAPSHOT_VERSION!=='rah-cc-fleet-snapshot-v1'/);
  assert.doesNotMatch(stableCoreSource,/Math\.random|child_process|exec\(/);
});

test('Stable UI loads same-origin pinned CC 2.1 Candidate and overlays Stable core',()=>{
  assert.match(stableHtml,/RAH Raven Command Center v2\.1 Stable/);
  assert.match(stableHtml,/const SOURCE='RAH-COMMAND-CENTER-V2\.1-CANDIDATE\.html'/);
  assert.match(stableHtml,/sourceUrl\.origin!==window\.location\.origin/);
  assert.match(stableHtml,/rah-command-center-core-v2\.1-candidate\.js/);
  assert.match(stableHtml,/rah-command-center-core-v2\.1\.js/);
  assert.match(stableHtml,/RAHCommandCenterCoreV21/);
  assert.match(stableHtml,/Cross-origin redirect rejected/);
});

test('Manual Fleet Snapshot Stable boundary is exact and persistence-free',()=>{
  const f=release.fleetSnapshot;
  assert.equal(f.version,'rah-cc-fleet-snapshot-v1');
  assert.equal(f.scope,'already-enrolled-devices-only');
  assert.equal(f.refreshMode,'explicit-selected-device-click');
  assert.equal(f.freshNodeTokenRequiredPerRefreshClick,true);
  assert.equal(f.tokenProofAuthenticationRequired,true);
  assert.equal(f.sessionMatchRequired,true);
  assert.equal(f.tokenPersistence,false);
  assert.equal(f.snapshotMemoryOnly,true);
  assert.equal(f.snapshotPersistence,false);
  assert.equal(f.backgroundPolling,false);
  assert.equal(f.networkDiscovery,false);
  assert.equal(f.automaticStorageRead,false);
  assert.equal(f.automaticRemoteControl,false);
  assert.equal(f.mutatingActions,false);
  assert.equal(f.crossSessionRefreshFailsClosed,true);
  assert.equal(candidateManifest.fleet_snapshot.snapshot_memory_only,true);
  assert.equal(candidateManifest.fleet_snapshot.background_polling,false);
  assert.equal(candidateManifest.fleet_snapshot.network_discovery,false);
});

test('existing mutating security chain remains retained',()=>{
  for(const x of ['one-shot-mutating-approval','immutable-mutating-intent','precommitted-requester-context','node-session-match','exact-policy-id','token-proof-authentication','actual-requester-source-match','node-local-human-confirmation','fresh-action-challenge','fresh-node-local-approval-proof'])assert.ok(release.retainedExistingSecurity.includes(x),x);
});

test('rollback is direct to CC 2.0 with unchanged Node 1.3 and no migration',()=>{
  const r=release.directRollback;
  assert.equal(r.commandCenterVersion,'2.0.0');
  assert.equal(r.nodeAgentVersion,'1.3.0');
  assert.equal(r.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(r.authProtocol,'rah-node-auth-v2');
  assert.equal(r.nodeAgent.gitBlobSha,release.runtime.nodeAgent.gitBlobSha);
  assert.equal(r.dataMigration,'none');
  assert.equal(r.secretMigration,'none');
  assert.equal(r.registryMigration,'none');
});

test('generic authority, discovery, polling and secret persistence remain forbidden',()=>{
  for(const x of ['fleet-snapshot','fleet-refresh-token','node-token','auth-nonce','auth-proof','action-challenge','node-local-approval-proof','password','rustdesk-peer-id'])assert.ok(release.forbiddenPersistence.includes(x),x);
  for(const x of ['new-capabilities','new-actions','new-routes','network-discovery','background-polling','automatic-device-refresh','bearer-token-network-transport','shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','native-raven-remote-control-api'])assert.ok(release.forbiddenRuntimeExpansion.includes(x),x);
});

test('versioned Stable promotion does not silently advance canonical root',()=>{
  assert.equal(release.canonicalRootPromotion,'separate-phase-required');
  assert.equal(release.ravenMasterSync,'separate-phase-required');
  assert.equal(rootManifest.version,'2.0.0');
  assert.equal(rootManifest.entry,'RAH-COMMAND-CENTER-V2.0.html');
  assert.equal(rootManifest.runtime,'rah-command-center-core-v2.0.js');
});
