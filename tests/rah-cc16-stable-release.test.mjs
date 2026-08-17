import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const stable=require('../rah-command-center-core-v1.6.js');
const release=JSON.parse(fs.readFileSync('RAH-CC16-NODE12-STABLE-RELEASE.json','utf8'));
const gate=JSON.parse(fs.readFileSync('RAH-CC16-NODE12-STABLE-PROMOTION-GATE.json','utf8'));
const candidate=JSON.parse(fs.readFileSync('RAH-CC16-REQUESTER-CONTEXT-CANDIDATE.json','utf8'));
const html=fs.readFileSync('RAH-COMMAND-CENTER-V1.6.html','utf8');
function gitBlobSha(path){const body=fs.readFileSync(path);return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex')}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('Stable release identity and authority are exact',()=>{
  assert.equal(release.stage,'stable-release');assert.equal(release.authorityDelta,'none');
  assert.equal(release.commandCenterVersion,'1.6.0');assert.equal(release.nodeAgentVersion,'1.2.0');
  assert.equal(release.nodeHealthProtocol,'rah-node-health-v2');assert.equal(release.nodeActionsProtocol,'rah-node-actions-v6');assert.equal(release.policyId,'rah-capability-allowlist-v1');
  assert.deepEqual(release.authoritySurface,{capabilities:caps,actions,routes});
  assert.deepEqual(gate.authoritySurface,release.authoritySurface);assert.deepEqual(candidate.authoritySurface,release.authoritySurface);
  assert.equal(release.freezeAfterPromotion,true);
});

test('Stable and Candidate runtime plus rollback blobs are pinned',()=>{
  for(const ref of Object.values(release.runtime))verify(ref);
  for(const ref of Object.values(release.pinnedCandidate))verify(ref);
  for(const ref of [release.directRollback.commandCenterCore,release.directRollback.commandCenterHtml,release.directRollback.nodeAgent,release.directRollback.previousStableRelease])verify(ref);
  for(const ref of Object.values(gate.targetStable).filter(v=>v&&typeof v==='object'&&v.path))verify(ref);
  for(const ref of Object.values(gate.candidate))verify(ref);
  for(const ref of [gate.directRollback.stableRelease,gate.directRollback.commandCenterCore,gate.directRollback.commandCenterHtml,gate.directRollback.nodeAgent])verify(ref);
});

test('Stable core is a strict identity wrapper over the gated v6 Candidate',()=>{
  assert.equal(stable.CC_VERSION,'1.6.0');
  assert.equal(stable.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v6');
  assert.equal(stable.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.equal(stable.REQUESTER_CONTEXT_HEADER,'X-RAH-Requester-Context');
  assert.deepEqual([...stable.CAPABILITY_IDS],caps);assert.deepEqual([...stable.ACTION_IDS],actions);
});

test('Stable UI retains Candidate implementation and layers Stable core without silent replacement',()=>{
  assert.match(html,/RAH-COMMAND-CENTER-V1\.6-CANDIDATE\.html/);
  assert.match(html,/rah-command-center-core-v1\.6-candidate\.js/);
  assert.match(html,/rah-command-center-core-v1\.6\.js/);
  assert.match(html,/window\.RAHCommandCenterCoreV16/);
  assert.match(html,/CC 1\.6 STABLE/);
  assert.match(html,/Stable failed closed:/);
});

test('rollback is direct and migration-free',()=>{
  assert.equal(release.directRollback.commandCenterVersion,'1.5.0');assert.equal(release.directRollback.nodeAgentVersion,'1.1.0');assert.equal(release.directRollback.nodeActionsProtocol,'rah-node-actions-v5');
  assert.equal(release.directRollback.dataMigration,'none');assert.equal(release.directRollback.secretMigration,'none');assert.equal(release.directRollback.registryMigration,'none');
});

test('all legacy and new sensitive persistence remains forbidden',()=>{
  for(const key of ['local-approved-action-ids','bearer-token','action-challenge','node-local-approval-proof','raw-requester-context','requester-context-digest-after-pair-lifetime','password','rustdesk-peer-id','action-result','executable-path','arbitrary-arguments'])assert.ok(release.forbiddenPersistence.includes(key),key);
  for(const key of ['new-capabilities','new-actions','new-routes','shell','generic-command-execution','generic-process-launch','generic-file-api','native-raven-remote-control-api','forwarding-header-identity','network-token-renewal-endpoint'])assert.ok(release.forbiddenRuntimeExpansion.includes(key),key);
});
