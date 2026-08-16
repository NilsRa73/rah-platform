import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const stable=require('../rah-command-center-core-v1.3.js');
const candidate=require('../rah-command-center-core-v1.4-candidate.js');
const manifest=JSON.parse(fs.readFileSync('RAH-CC14-STABLE-PROMOTION-GATE.json','utf8'));
const stableContract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const candidateContract=JSON.parse(fs.readFileSync('RAH-EPHEMERAL-APPROVAL-CANDIDATE.json','utf8'));
const candidateHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.4-CANDIDATE.html','utf8');

function gitBlobSha(path){
  const body=fs.readFileSync(path);
  const header=Buffer.from(`blob ${body.length}\0`);
  return crypto.createHash('sha1').update(header).update(body).digest('hex');
}

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('promotion manifest pins the reviewed Candidate, Stable rollback and unchanged Node Agent blobs',()=>{
  assert.equal(manifest.schemaVersion,1);
  assert.equal(manifest.stage,'promotion-readiness');
  assert.equal(manifest.authorityDelta,'none');
  for(const ref of [
    manifest.candidate.commandCenterCore,
    manifest.candidate.commandCenterHtml,
    manifest.candidate.candidateContract,
    manifest.currentStable.commandCenterCore,
    manifest.currentStable.commandCenterHtml,
    manifest.currentStable.canonicalContract
  ]) assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`);
  assert.equal(gitBlobSha(manifest.nodeAgent.path),manifest.nodeAgent.gitBlobSha,'Node Agent 0.9 must remain byte-identical');
  assert.equal(manifest.nodeAgent.mustRemainUnchanged,true);
});

test('CC 1.4 Candidate preserves exact Stable capability/action/protocol/policy authority',()=>{
  assert.equal(candidate.CC_VERSION,'1.4.0-candidate');
  assert.equal(stable.CC_VERSION,'1.3.0');
  assert.deepEqual([...candidate.CAPABILITY_IDS],caps);
  assert.deepEqual([...candidate.ACTION_IDS],actions);
  assert.deepEqual([...candidate.CAPABILITY_IDS],[...stable.CAPABILITY_IDS]);
  assert.deepEqual([...candidate.ACTION_IDS],[...stable.ACTION_IDS]);
  assert.equal(candidate.NODE_ACTIONS_PROTOCOL,stable.NODE_ACTIONS_PROTOCOL);
  assert.equal(candidate.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.equal(candidate.ALLOWLIST_POLICY_ID,stable.ALLOWLIST_POLICY_ID);
  assert.equal(candidate.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.deepEqual(candidateContract.routes,routes);
  assert.deepEqual(manifest.authoritySurface.capabilities,caps);
  assert.deepEqual(manifest.authoritySurface.actions,actions);
  assert.deepEqual(manifest.authoritySurface.routes,routes);
});

test('persistence delta is strictly an authority reduction',()=>{
  assert.ok(stableContract.persistence.allowed.includes('local-approved-action-ids'));
  assert.ok(!candidateContract.persistentEnrollmentMetadata.includes('local-approved-action-ids'));
  assert.equal(candidateContract.approvalPolicy.persistApprovedActions,false);
  assert.equal(candidateContract.approvalPolicy.acceptPersistedApprovedActions,false);
  assert.equal(candidateContract.approvalPolicy.scrubPersistedApprovedActionsOnLoad,true);
  assert.equal(candidateContract.approvalPolicy.startupStorageScrubBeforeInteraction,true);
  assert.equal(candidateContract.approvalPolicy.reloadRequiresReapproval,true);
  assert.equal(manifest.persistenceDelta.type,'authority-reduction');
  assert.deepEqual(manifest.persistenceDelta.removeFromPersistentAllowed,['local-approved-action-ids']);
  assert.equal(manifest.persistenceDelta.dataMigrationRequired,false);
  assert.equal(manifest.persistenceDelta.secretMigrationRequired,false);
});

test('Candidate core strips persisted approvals while runtime approval remains possible only in memory',()=>{
  const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX';
  const stored=[{
    id:'node',label:'Node',role:'test',platform:'TestOS',kind:'desktop',source:'local',status:'unverified',
    enrolled:true,endpointIp:'127.0.0.1',agentSessionId:sessionId,agentHostname:'node',agentVersion:'0.9.0',
    capabilities:caps,advertisedActions:actions,approvedActions:['rustdesk.launch']
  }];
  let device=candidate.normalizeDeviceRegistry(stored)[0];
  assert.deepEqual(device.approvedActions,[]);
  assert.equal(candidate.canExecuteAction(device,'rustdesk.launch'),false);
  device=candidate.approveDeviceAction([device],'node','rustdesk.launch')[0];
  assert.equal(candidate.canExecuteAction(device,'rustdesk.launch'),true);
  const persisted=candidate.persistableDeviceRegistry([device])[0];
  assert.deepEqual(persisted.approvedActions,[]);
  assert.equal(candidate.normalizeDeviceRegistry([persisted])[0].approvedActions.length,0);
});

test('browser Candidate performs startup scrub before normal saves and remains fixed-source same-origin',()=>{
  assert.ok(candidateHtml.includes("const SOURCE='RAH-COMMAND-CENTER-V1.2.html'"));
  assert.ok(candidateHtml.includes('startup')||candidateHtml.includes('scrubbed'));
  assert.ok(candidateHtml.includes('core.persistableDeviceRegistry(loaded)'));
  assert.ok(candidateHtml.includes('core.persistableDeviceRegistry(devices)'));
  assert.ok(candidateHtml.includes('.replace(LOAD_MARKER,LOAD_REPLACEMENT).replace(SAVE_MARKER,SAVE_REPLACEMENT)'));
  assert.ok(candidateHtml.includes('sourceUrl.origin!==window.location.origin'));
  assert.ok(candidateHtml.includes('Cross-origin redirect rejected.'));
  assert.doesNotMatch(candidateHtml,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

test('rollback remains CC 1.3 + Node 0.9 with the same registry key and no migration',()=>{
  assert.equal(manifest.rollback.targetCommandCenterVersion,'1.3.0');
  assert.equal(manifest.rollback.commandCenterCorePath,'rah-command-center-core-v1.3.js');
  assert.equal(manifest.rollback.commandCenterHtmlPath,'RAH-COMMAND-CENTER-V1.3.html');
  assert.equal(manifest.rollback.nodeAgentVersion,'0.9.0');
  assert.equal(manifest.rollback.registryKey,'rah.cc.devices.v1');
  assert.equal(manifest.persistenceDelta.registryKey,'rah.cc.devices.v1');
  assert.equal(manifest.rollback.requiresDataMigration,false);
});

test('readiness contract explicitly forbids authority expansion',()=>{
  for(const item of ['new-capabilities','new-actions','new-routes','shell','generic-command-execution','generic-process-launch','caller-controlled-executable-path','caller-controlled-generic-arguments','generic-file-api','generic-endpoint-dispatch','native-raven-remote-control-api','bearer-token-persistence','challenge-persistence','password-persistence','peer-id-persistence','network-token-renewal-endpoint']){
    assert.ok(manifest.forbiddenExpansion.includes(item),`missing forbidden expansion ${item}`);
  }
});
