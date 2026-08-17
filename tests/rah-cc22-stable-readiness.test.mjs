import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const gate=JSON.parse(fs.readFileSync('RAH-CC22-STABLE-PROMOTION-GATE.json','utf8'));
const candidateManifest=JSON.parse(fs.readFileSync('RAH-CC22-FLEET-SNAPSHOT-INVALIDATION-CANDIDATE.json','utf8'));
const candidate=require('../rah-command-center-core-v2.2-candidate.js');
const stable=require('../rah-command-center-core-v2.1.js');
const blob=path=>execFileSync('git',['hash-object',path],{encoding:'utf8'}).trim();
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('readiness pins exact CC2.1 Stable rollback and Node1.3 baseline',()=>{
  assert.equal(gate.stage,'stable-readiness');
  assert.equal(gate.authorityDelta,'none');
  assert.equal(gate.ravenVersion,'2.0.32');
  assert.equal(gate.sourceStable.commandCenterVersion,'2.1.0');
  assert.equal(gate.sourceStable.nodeAgentVersion,'1.3.0');
  assert.equal(gate.sourceStable.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(gate.sourceStable.nodeAuthProtocol,'rah-node-auth-v2');
  assert.equal(gate.sourceStable.policyId,'rah-capability-allowlist-v1');
  assert.equal(blob(gate.sourceStable.releaseManifest.path),gate.sourceStable.releaseManifest.gitBlobSha);
  assert.equal(blob(gate.sourceStable.commandCenterCore.path),gate.sourceStable.commandCenterCore.gitBlobSha);
  assert.equal(blob(gate.sourceStable.commandCenterHtml.path),gate.sourceStable.commandCenterHtml.gitBlobSha);
  assert.equal(blob(gate.sourceStable.nodeAgent.path),gate.sourceStable.nodeAgent.gitBlobSha);
});

test('readiness pins exact immutable 2.2 Candidate bytes',()=>{
  assert.equal(gate.candidate.commandCenterVersion,'2.2.0-candidate');
  assert.equal(gate.candidate.stableRuntimeModified,false);
  assert.equal(gate.candidate.nodeRuntimeModified,false);
  assert.equal(blob(gate.candidate.manifest.path),gate.candidate.manifest.gitBlobSha);
  assert.equal(blob(gate.candidate.commandCenterCore.path),gate.candidate.commandCenterCore.gitBlobSha);
  assert.equal(blob(gate.candidate.commandCenterHtml.path),gate.candidate.commandCenterHtml.gitBlobSha);
  assert.equal(candidate.CC_VERSION,'2.2.0-candidate');
  assert.equal(candidateManifest.candidate,'2.2.0-candidate');
});

test('readiness preserves exact 4/3/5 authority and fail-closed invalidation policy',()=>{
  assert.deepEqual(gate.authoritySurface.capabilities,caps);
  assert.deepEqual(gate.authoritySurface.actions,actions);
  assert.deepEqual(gate.authoritySurface.businessRoutes,routes);
  assert.deepEqual(candidate.CAPABILITY_IDS,caps);
  assert.deepEqual(candidate.ACTION_IDS,actions);
  assert.deepEqual(candidate.AUTHENTICATED_PATHS,routes);
  assert.equal(gate.fleetSnapshotInvalidationBoundary.failurePolicy,'invalidate-selected-row-on-refresh-failure');
  assert.equal(gate.fleetSnapshotInvalidationBoundary.selectedRowRemovedBeforeFailureRender,true);
  assert.equal(gate.fleetSnapshotInvalidationBoundary.snapshotMemoryOnly,true);
  assert.equal(gate.fleetSnapshotInvalidationBoundary.snapshotPersistence,false);
  assert.equal(gate.fleetSnapshotInvalidationBoundary.backgroundPolling,false);
  assert.equal(gate.fleetSnapshotInvalidationBoundary.networkDiscovery,false);
});

test('promotion contract requires separate Stable runtime and canonical generation',()=>{
  const r=gate.stablePromotionRequirements;
  assert.equal(r.separateRuntimePromotionPrRequired,true);
  assert.equal(r.targetCommandCenterVersion,'2.2.0');
  assert.equal(r.targetNodeAgentVersion,'1.3.0');
  assert.equal(r.versionedStableCoreRequired,'rah-command-center-core-v2.2.js');
  assert.equal(r.versionedStableHtmlRequired,'RAH-COMMAND-CENTER-V2.2.html');
  assert.equal(r.stableReleaseManifestRequired,'RAH-CC22-NODE13-STABLE-RELEASE.json');
  assert.equal(r.candidateBlobPinsMustRemainExact,true);
  assert.equal(r.canonicalRootPromotionSeparate,true);
  assert.equal(r.canonicalPackageGenerationIncrementRequired,true);
  assert.equal(r.ravenMasterSyncSeparate,true);
});

test('direct rollback is exact CC2.1/Node1.3 with no migration',()=>{
  assert.deepEqual(gate.directRollback,{commandCenterVersion:'2.1.0',nodeAgentVersion:'1.3.0',nodeActionsProtocol:'rah-node-actions-v7',nodeAuthProtocol:'rah-node-auth-v2',dataMigration:'none',secretMigration:'none',registryMigration:'none'});
  assert.equal(stable.CC_VERSION,'2.1.0');
});

test('readiness explicitly forbids every generic authority expansion',()=>{
  for(const item of ['new-capabilities','new-actions','new-business-routes','network-discovery','background-polling','automatic-device-refresh','token-persistence','fleet-snapshot-persistence','shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','caller-controlled-executable-path','caller-controlled-generic-arguments','native-raven-remote-control-api'])assert.ok(gate.forbidden.includes(item),item);
});
