import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const read=p=>fs.readFileSync(p,'utf8');
const json=p=>JSON.parse(read(p));
const gitBlob=p=>execFileSync('git',['rev-parse',`HEAD:${p}`],{encoding:'utf8'}).trim();
const release=json('RAH-CC18-NODE13-STABLE-RELEASE.json');
const candidate=json('RAH-CC18-ONE-SHOT-MUTATING-APPROVAL-CANDIDATE.json');
const stableCore=read('rah-command-center-core-v1.8.js');
const stableHtml=read('RAH-COMMAND-CENTER-V1.8.html');
const candidateCore=read('rah-command-center-core-v1.8-candidate.js');
const candidateHtml=read('RAH-COMMAND-CENTER-V1.8-CANDIDATE.html');

const CAPS=['compute','storage','display','remote-desktop'];
const ACTIONS=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const ROUTES=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('Stable v1.8 identity and authority are exact',()=>{
  assert.equal(release.stage,'stable-release');
  assert.equal(release.releaseId,'rah-cc18-node13-one-shot-stable-v1');
  assert.equal(release.authorityDelta,'none');
  assert.equal(release.ravenVersion,'2.0.32');
  assert.equal(release.commandCenterVersion,'1.8.0');
  assert.equal(release.nodeAgentVersion,'1.3.0');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(release.authProtocol,'rah-node-auth-v2');
  assert.equal(release.policyId,'rah-capability-allowlist-v1');
  assert.equal(release.nodeRuntimeChange,false);
  assert.deepEqual(release.authoritySurface.capabilities,CAPS);
  assert.deepEqual(release.authoritySurface.actions,ACTIONS);
  assert.deepEqual(release.authoritySurface.businessRoutes,ROUTES);
  assert.deepEqual(release.authoritySurface.newCapabilities,[]);
  assert.deepEqual(release.authoritySurface.newActions,[]);
  assert.deepEqual(release.authoritySurface.newBusinessRoutes,[]);
});

test('Stable and Candidate Git blobs are pinned exactly',()=>{
  for(const item of Object.values(release.runtime))assert.equal(gitBlob(item.path),item.gitBlobSha,item.path);
  for(const item of Object.values(release.pinnedCandidate))assert.equal(gitBlob(item.path),item.gitBlobSha,item.path);
  assert.equal(gitBlob(release.directRollback.previousStableRelease.path),release.directRollback.previousStableRelease.gitBlobSha);
  assert.equal(gitBlob(release.directRollback.commandCenterCore.path),release.directRollback.commandCenterCore.gitBlobSha);
  assert.equal(gitBlob(release.directRollback.commandCenterHtml.path),release.directRollback.commandCenterHtml.gitBlobSha);
  assert.equal(gitBlob(release.directRollback.nodeAgent.path),release.directRollback.nodeAgent.gitBlobSha);
});

test('Stable core is a strict one-shot wrapper over v1.8 Candidate',()=>{
  const core=require('../rah-command-center-core-v1.8.js');
  assert.equal(core.CC_VERSION,'1.8.0');
  assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v7');
  assert.equal(core.NODE_AUTH_PROTOCOL,'rah-node-auth-v2');
  assert.equal(core.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.equal(core.ONE_SHOT_APPROVAL_TTL_MS,90000);
  assert.equal(core.ONE_SHOT_APPROVAL_MAX_OUTSTANDING,32);
  assert.deepEqual(Array.from(core.MUTATING_ACTION_IDS),['rustdesk.launch','rustdesk.connect']);
  assert.match(stableCore,/require\('\.\/rah-command-center-core-v1\.8-candidate\.js'\)/);
  assert.match(stableCore,/Unexpected CC 1\.8 Candidate contract/);
});

test('Stable UI loads only the pinned same-origin Candidate and overlays Stable core',()=>{
  assert.match(stableHtml,/RAH-COMMAND-CENTER-V1\.8-CANDIDATE\.html/);
  assert.match(stableHtml,/sourceUrl\.origin!==window\.location\.origin/);
  assert.match(stableHtml,/Cross-origin redirect rejected/);
  assert.match(stableHtml,/rah-command-center-core-v1\.8-candidate\.js/);
  assert.match(stableHtml,/rah-command-center-core-v1\.8\.js/);
  assert.match(stableHtml,/window\.RAHCommandCenterOneShotCandidate=window\.RAHCommandCenterCoreV18/);
  assert.match(candidateHtml,/ONE-SHOT MUTATING APPROVAL/);
});

test('one-shot Stable contract is memory-only, single-use and consume-before-confirmation',()=>{
  const o=release.oneShotApproval;
  assert.deepEqual(o.requiredActions,['rustdesk.launch','rustdesk.connect']);
  assert.equal(o.readOnlyStorageRequiresOneShot,false);
  assert.equal(o.ttlMs,90000);
  assert.equal(o.maxOutstanding,32);
  assert.equal(o.memoryOnly,true);
  assert.equal(o.persistent,false);
  assert.equal(o.singleUse,true);
  assert.equal(o.consumeBeforeNodeLocalConfirmation,true);
  assert.equal(o.consumeOnBindingMismatch,true);
  assert.equal(o.bindsDeviceId,true);
  assert.equal(o.bindsNodeSession,true);
  assert.equal(o.bindsActionId,true);
  assert.equal(o.bindsTargetDigest,true);
  assert.equal(o.storesRawTarget,false);
  assert.equal(o.secureRandomRequired,true);
  assert.equal(o.mathRandomFallback,false);
  assert.doesNotMatch(candidateCore,/Math\.random/);
  assert.match(candidateCore,/this\._tickets\.delete\(id\);/);
});

test('Candidate evidence matches Stable one-shot contract',()=>{
  assert.equal(candidate.stage,'feature-candidate');
  assert.equal(candidate.commandCenterVersion,'1.8.0-candidate');
  assert.equal(candidate.authorityDelta,'none');
  assert.equal(candidate.nodeAgentVersion,'1.3.0');
  assert.equal(candidate.runtime.nodeRuntimeChange,false);
  assert.deepEqual(candidate.authoritySurface.capabilities,CAPS);
  assert.deepEqual(candidate.authoritySurface.actions,ACTIONS);
  assert.deepEqual(candidate.authoritySurface.businessRoutes,ROUTES);
  assert.equal(candidate.oneShotApproval.ttlMs,90000);
  assert.equal(candidate.oneShotApproval.memoryOnly,true);
  assert.equal(candidate.oneShotApproval.singleUse,true);
  assert.equal(candidate.oneShotApproval.storesRawTarget,false);
});

test('rollback is direct to v1.7 with unchanged Node 1.3 and no migration',()=>{
  const r=release.directRollback;
  assert.equal(r.commandCenterVersion,'1.7.0');
  assert.equal(r.nodeAgentVersion,'1.3.0');
  assert.equal(r.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(r.authProtocol,'rah-node-auth-v2');
  assert.equal(r.previousStableRelease.path,'RAH-CC17-NODE13-STABLE-RELEASE.json');
  assert.equal(r.nodeAgent.gitBlobSha,release.runtime.nodeAgent.gitBlobSha);
  assert.equal(r.dataMigration,'none');
  assert.equal(r.secretMigration,'none');
  assert.equal(r.registryMigration,'none');
});

test('forbidden persistence and authority expansion remain explicit',()=>{
  for(const key of ['one-shot-ticket','raw-target','rustdesk-peer-id','node-token','auth-nonce','auth-proof','password'])assert.ok(release.forbiddenPersistence.includes(key),key);
  for(const key of ['new-capability','new-action','new-business-route','bearer-token-network-transport','shell','generic-command-execution','generic-process-launch','generic-file-api','native-raven-remote-control-api'])assert.ok(release.forbiddenRuntimeExpansion.includes(key),key);
  assert.equal(release.freezeAfterPromotion,true);
});
