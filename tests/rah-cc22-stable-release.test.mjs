import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const release=JSON.parse(fs.readFileSync('RAH-CC22-NODE13-STABLE-RELEASE.json','utf8'));
const readiness=JSON.parse(fs.readFileSync('RAH-CC22-STABLE-PROMOTION-GATE.json','utf8'));
const canonical=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const canonicalGate=JSON.parse(fs.readFileSync('RAH-CC22-CANONICAL-GENERATION7-STABLE-GATE.json','utf8'));
const stable=require('../rah-command-center-core-v2.2.js');
const candidate=require('../rah-command-center-core-v2.2-candidate.js');
const html=fs.readFileSync('RAH-COMMAND-CENTER-V2.2.html','utf8');
const blob=path=>execFileSync('git',['hash-object',path],{encoding:'utf8'}).trim();
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('versioned CC2.2 Stable pins exact gated Candidate and Node1.3',()=>{
  assert.equal(release.stage,'stable-release');
  assert.equal(release.authorityDelta,'none');
  assert.equal(release.ravenVersion,'2.0.32');
  assert.equal(release.commandCenterVersion,'2.2.0');
  assert.equal(release.nodeAgentVersion,'1.3.0');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(release.authProtocol,'rah-node-auth-v2');
  assert.equal(release.policyId,'rah-capability-allowlist-v1');
  assert.equal(release.nodeRuntimeChange,false);
  assert.equal(stable.CC_VERSION,'2.2.0');
  assert.equal(candidate.CC_VERSION,'2.2.0-candidate');
  for(const pin of [release.runtime.commandCenterCore,release.runtime.commandCenterHtml,release.runtime.nodeAgent,release.pinnedCandidate.manifest,release.pinnedCandidate.commandCenterCore,release.pinnedCandidate.commandCenterHtml,release.readiness])assert.equal(blob(pin.path),pin.gitBlobSha,pin.path);
});

test('Stable wrapper preserves exact 4/3/5 authority and fail-closed policy',()=>{
  assert.deepEqual(stable.CAPABILITY_IDS,caps);
  assert.deepEqual(stable.ACTION_IDS,actions);
  assert.deepEqual(stable.AUTHENTICATED_PATHS,routes);
  assert.equal(stable.FLEET_SNAPSHOT_VERSION,'rah-cc-fleet-snapshot-v1');
  assert.equal(stable.FLEET_SNAPSHOT_INVALIDATION_VERSION,'rah-cc-fleet-snapshot-invalidation-v1');
  assert.equal(stable.FLEET_SNAPSHOT_FAILURE_POLICY,'invalidate-selected-row-on-refresh-failure');
  assert.deepEqual(release.authoritySurface.capabilities,caps);
  assert.deepEqual(release.authoritySurface.actions,actions);
  assert.deepEqual(release.authoritySurface.businessRoutes,routes);
  assert.deepEqual(release.authoritySurface.newCapabilities,[]);
  assert.deepEqual(release.authoritySurface.newActions,[]);
  assert.deepEqual(release.authoritySurface.newBusinessRoutes,[]);
});

test('Stable UI pins Candidate and switches runtime to Stable core only',()=>{
  for(const marker of [
    "SOURCE='RAH-COMMAND-CENTER-V2.2-CANDIDATE.html'",
    "rah-command-center-core-v2.2-candidate.js",
    "rah-command-center-core-v2.2.js",
    "window.RAHCommandCenterCoreV22",
    "core.CC_VERSION!=='2.2.0'",
    "Stable failed closed"
  ])assert.ok(html.includes(marker),marker);
  assert.doesNotMatch(html,/\/scan|\/discover|\/command|\/shell|\/files|\/process|\/execute/);
});

test('release preserves fail-closed memory-only Fleet Snapshot invalidation',()=>{
  const f=release.fleetSnapshotInvalidation;
  assert.equal(f.failurePolicy,'invalidate-selected-row-on-refresh-failure');
  assert.equal(f.selectedRowRemovedBeforeFailureRender,true);
  assert.equal(f.successfulRefreshBehaviorChanged,false);
  assert.equal(f.refreshMode,'explicit-selected-device-click');
  assert.equal(f.freshNodeTokenRequiredPerRefreshClick,true);
  assert.equal(f.tokenProofAuthenticationRequired,true);
  assert.equal(f.tokenPersistence,false);
  assert.equal(f.snapshotMemoryOnly,true);
  assert.equal(f.snapshotPersistence,false);
  assert.equal(f.backgroundPolling,false);
  assert.equal(f.networkDiscovery,false);
  assert.equal(f.automaticRemoteControl,false);
  assert.equal(f.nodeRuntimeChange,false);
});

test('direct rollback is exact CC2.1 Stable without migrations',()=>{
  assert.equal(blob(release.directRollback.previousStableRelease.path),release.directRollback.previousStableRelease.gitBlobSha);
  assert.equal(blob(release.directRollback.commandCenterCore.path),release.directRollback.commandCenterCore.gitBlobSha);
  assert.equal(blob(release.directRollback.commandCenterHtml.path),release.directRollback.commandCenterHtml.gitBlobSha);
  assert.equal(blob(release.directRollback.nodeAgent.path),release.directRollback.nodeAgent.gitBlobSha);
  assert.equal(release.directRollback.commandCenterVersion,'2.1.0');
  assert.equal(release.directRollback.nodeAgentVersion,'1.3.0');
  assert.equal(release.directRollback.dataMigration,'none');
  assert.equal(release.directRollback.secretMigration,'none');
  assert.equal(release.directRollback.registryMigration,'none');
});

test('separate canonical root promotion is now completed as generation 7',()=>{
  assert.equal(readiness.stablePromotionRequirements.canonicalRootPromotionSeparate,true);
  assert.equal(release.canonicalRootPromotion,'separate-phase-required');
  assert.equal(release.canonicalPackageGenerationIncrementRequired,true);
  assert.equal(canonicalGate.stage,'canonical-stable-gate');
  assert.equal(canonicalGate.authorityDelta,'none');
  assert.equal(canonical.version,'2.2.0');
  assert.equal(canonical.entry,'RAH-COMMAND-CENTER-V2.2.html');
  assert.equal(canonical.runtime,'rah-command-center-core-v2.2.js');
  assert.equal(canonical.previous_stable_version,'2.1.0');
  assert.equal(canonical.canonical_package_generation,7);
  assert.equal(canonical.features.canonical_package_dependency_count,55);
  assert.equal(canonical.stable_release_manifest,'RAH-CC22-NODE13-STABLE-RELEASE.json');
});

test('forbidden persistence and authority expansion stay explicit',()=>{
  for(const item of ['fleet-snapshot','fleet-refresh-token','node-token','password','rustdesk-peer-id'])assert.ok(release.forbiddenPersistence.includes(item),item);
  for(const item of ['new-capabilities','new-actions','new-routes','network-discovery','background-polling','shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','caller-controlled-executable-path','caller-controlled-generic-arguments','native-raven-remote-control-api'])assert.ok(release.forbiddenRuntimeExpansion.includes(item),item);
});
