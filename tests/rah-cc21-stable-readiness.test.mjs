import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const gate=JSON.parse(fs.readFileSync('RAH-CC21-STABLE-PROMOTION-GATE.json','utf8'));
const candidateManifest=JSON.parse(fs.readFileSync('RAH-CC21-FLEET-SNAPSHOT-CANDIDATE.json','utf8'));
const stableRelease=JSON.parse(fs.readFileSync('RAH-CC20-NODE13-STABLE-RELEASE.json','utf8'));
const stable=require('../rah-command-center-core-v2.0.js');
const candidate=require('../rah-command-center-core-v2.1-candidate.js');
const html=fs.readFileSync('RAH-COMMAND-CENTER-V2.1-CANDIDATE.html','utf8');

function gitBlob(path){return execFileSync('git',['rev-parse','HEAD:'+path],{encoding:'utf8'}).trim()}

const exactCaps=['compute','storage','display','remote-desktop'];
const exactActions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const exactRoutes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('readiness is metadata-only and targets CC 2.1 over canonical CC 2.0 / Node 1.3',()=>{
  assert.equal(gate.stage,'stable-readiness');
  assert.equal(gate.authorityDelta,'none');
  assert.equal(gate.ravenVersion,'2.0.32');
  assert.equal(gate.sourceStable.commandCenterVersion,'2.0.0');
  assert.equal(gate.sourceStable.nodeAgentVersion,'1.3.0');
  assert.equal(gate.sourceStable.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(gate.sourceStable.nodeAuthProtocol,'rah-node-auth-v2');
  assert.equal(gate.sourceStable.policyId,'rah-capability-allowlist-v1');
  assert.equal(gate.candidate.commandCenterVersion,'2.1.0-candidate');
  assert.equal(gate.candidate.stableRuntimeModified,false);
  assert.equal(gate.candidate.nodeRuntimeModified,false);
});

test('source Stable and Candidate blobs are pinned exactly from Git objects',()=>{
  for(const item of [gate.sourceStable.releaseManifest,gate.sourceStable.commandCenterCore,gate.sourceStable.commandCenterHtml,gate.sourceStable.nodeAgent,gate.candidate.manifest,gate.candidate.commandCenterCore,gate.candidate.commandCenterHtml]){
    assert.equal(gitBlob(item.path),item.gitBlobSha,item.path+' blob drift');
  }
  assert.equal(stableRelease.runtime.commandCenterCore.gitBlobSha,gate.sourceStable.commandCenterCore.gitBlobSha);
  assert.equal(stableRelease.runtime.commandCenterHtml.gitBlobSha,gate.sourceStable.commandCenterHtml.gitBlobSha);
  assert.equal(stableRelease.runtime.nodeAgent.gitBlobSha,gate.sourceStable.nodeAgent.gitBlobSha);
});

test('authority remains exactly 4 capabilities / 3 actions / 5 business routes',()=>{
  assert.deepEqual(gate.authoritySurface.capabilities,exactCaps);
  assert.deepEqual(gate.authoritySurface.actions,exactActions);
  assert.deepEqual(gate.authoritySurface.businessRoutes,exactRoutes);
  assert.deepEqual(candidate.CAPABILITY_IDS,exactCaps);
  assert.deepEqual(candidate.ACTION_IDS,exactActions);
  assert.deepEqual(candidate.AUTHENTICATED_PATHS,exactRoutes);
  assert.equal(candidate.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v7');
  assert.equal(candidate.NODE_AUTH_PROTOCOL,'rah-node-auth-v2');
  assert.equal(candidate.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
});

test('Fleet Snapshot remains explicit, enrolled-only, memory-only and non-discovering',()=>{
  const b=gate.fleetSnapshotBoundary,m=candidateManifest.fleet_snapshot;
  assert.equal(b.version,'rah-cc-fleet-snapshot-v1');
  assert.equal(b.scope,'already-enrolled-devices-only');
  assert.equal(b.refreshMode,'explicit-selected-device-click');
  assert.equal(b.freshNodeTokenRequiredPerRefreshClick,true);
  assert.equal(b.tokenPersistence,false);
  assert.equal(b.snapshotMemoryOnly,true);
  assert.equal(b.snapshotPersistence,false);
  assert.equal(b.backgroundPolling,false);
  assert.equal(b.networkDiscovery,false);
  assert.equal(b.automaticStorageRead,false);
  assert.equal(b.automaticRemoteControl,false);
  assert.equal(b.mutatingActions,false);
  assert.equal(b.sessionMatchRequired,true);
  assert.equal(b.crossSessionRefreshFailsClosed,true);
  assert.equal(m.fresh_node_token_required_per_refresh_click,true);
  assert.equal(m.snapshot_memory_only,true);
  assert.equal(m.background_polling,false);
  assert.equal(m.network_discovery,false);
});

test('Candidate UI has no polling, discovery, persistence, bearer fallback or generic authority',()=>{
  for(const marker of ['MANUAL FLEET SNAPSHOT','fleetRefreshBtn','Fresh Node token for this refresh','memory-only','no background polling'])assert.match(html,new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g,'\\$&'),'i'));
  assert.doesNotMatch(html,/setInterval\s*\(/);
  assert.doesNotMatch(html,/setTimeout\s*\(\s*refreshFleet/);
  assert.doesNotMatch(html,/localStorage\.setItem\([^)]*fleet/i);
  assert.doesNotMatch(html,/localStorage\.setItem\([^)]*token/i);
  assert.doesNotMatch(html,/Authorization\s*:\s*['"]Bearer/i);
  assert.doesNotMatch(html,/\/scan|\/discover|\/command|\/shell|\/files|\/execute|\/process/);
});

test('Stable promotion remains separate and rollback is clean CC 2.0 / same Node 1.3',()=>{
  const p=gate.stablePromotionRequirements,r=gate.directRollback;
  assert.equal(p.separateRuntimePromotionPrRequired,true);
  assert.equal(p.targetCommandCenterVersion,'2.1.0');
  assert.equal(p.targetNodeAgentVersion,'1.3.0');
  assert.equal(p.targetActionsProtocol,'rah-node-actions-v7');
  assert.equal(p.targetAuthProtocol,'rah-node-auth-v2');
  assert.equal(p.targetPolicyId,'rah-capability-allowlist-v1');
  assert.equal(p.candidateBlobPinsMustRemainExact,true);
  assert.equal(p.candidateMutationRequiresNewVersionAndGate,true);
  assert.equal(p.canonicalRootPromotionSeparate,true);
  assert.equal(p.ravenMasterSyncSeparate,true);
  assert.equal(r.commandCenterVersion,'2.0.0');
  assert.equal(r.nodeAgentVersion,'1.3.0');
  assert.equal(r.dataMigration,'none');
  assert.equal(r.secretMigration,'none');
  assert.equal(r.registryMigration,'none');
});
