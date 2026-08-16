import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const release=JSON.parse(fs.readFileSync('RAH-CC15-NODE10-STABLE-RELEASE.json','utf8'));
const contract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const core=require('../rah-command-center-core-v1.5.js');
const candidate=require('../rah-command-center-core-v1.5-candidate.js');
const rollback=require('../rah-command-center-core-v1.4.js');
const hash=path=>execFileSync('git',['hash-object',path],{encoding:'utf8'}).trim();
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('release manifest pins every Stable runtime and canonical contract blob',()=>{
  assert.equal(release.stage,'stable-release');
  assert.equal(release.authorityDelta,'none');
  assert.equal(release.commandCenterVersion,'1.5.0');
  assert.equal(release.nodeAgentVersion,'1.0.0');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v5');
  for(const item of Object.values(release.runtime))assert.equal(hash(item.path),item.gitBlobSha,item.path);
});

test('release pins immutable Candidate implementation and direct rollback',()=>{
  for(const item of Object.values(release.pinnedImplementation))assert.equal(hash(item.path),item.gitBlobSha,item.path);
  for(const key of ['commandCenterCore','commandCenterHtml','nodeAgent']){
    const item=release.directRollback[key];assert.equal(hash(item.path),item.gitBlobSha,item.path);
  }
  assert.equal(release.directRollback.commandCenterVersion,'1.4.0');
  assert.equal(release.directRollback.nodeAgentVersion,'0.9.0');
  assert.equal(release.directRollback.dataMigration,'none');
  assert.equal(release.directRollback.secretMigration,'none');
});

test('Stable wrapper changes identity only and Candidate behavior remains the authority implementation',()=>{
  assert.equal(core.CC_VERSION,'1.5.0');
  assert.equal(candidate.CC_VERSION,'1.5.0-candidate');
  assert.equal(core.NODE_ACTIONS_PROTOCOL,candidate.NODE_ACTIONS_PROTOCOL);
  assert.equal(core.ALLOWLIST_POLICY_ID,candidate.ALLOWLIST_POLICY_ID);
  assert.deepEqual([...core.CAPABILITY_IDS],[...candidate.CAPABILITY_IDS]);
  assert.deepEqual([...core.ACTION_IDS],[...candidate.ACTION_IDS]);
  for(const fn of ['sanitizeActionCatalog','localApprovalGrantFromCatalog','localApprovalIntentRequest','actionExecutionRequest','rustDeskHandoffRequest'])assert.equal(core[fn],candidate[fn]);
});

test('Stable and rollback authority surfaces are equal while v5 and v4 stay isolated',()=>{
  assert.deepEqual([...core.CAPABILITY_IDS],caps);
  assert.deepEqual([...core.ACTION_IDS],actions);
  assert.deepEqual([...rollback.CAPABILITY_IDS],caps);
  assert.deepEqual([...rollback.ACTION_IDS],actions);
  assert.deepEqual(release.authoritySurface,{capabilities:caps,actions,routes});
  assert.deepEqual(contract.capabilities,caps);
  assert.deepEqual(contract.actions.map(a=>a.id),actions);
  assert.deepEqual(contract.routes,routes);
  assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v5');
  assert.equal(rollback.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
});

test('Node-local proof is additive only for the two existing mutating actions',()=>{
  assert.deepEqual([...core.MUTATING_ACTION_IDS],['rustdesk.launch','rustdesk.connect']);
  assert.equal(contract.approvalPolicy.proofTtlSeconds,30);
  assert.equal(contract.approvalPolicy.challengeTtlSecondsForMutatingActions,30);
  assert.equal(contract.approvalPolicy.atomicPairConsumption,true);
  assert.equal(contract.approvalPolicy.singleUse,true);
  assert.equal(contract.approvalPolicy.headlessMutatingIntent,'fail-closed');
  assert.equal(contract.approvalPolicy.remoteFallback,false);
  assert.equal(contract.approvalPolicy.proofPersistence,'forbidden');
  assert.ok(contract.persistence.forbidden.includes('node-local-approval-proof'));
});
