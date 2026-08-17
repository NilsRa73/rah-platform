import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const release=JSON.parse(fs.readFileSync('RAH-CC20-NODE13-STABLE-RELEASE.json','utf8'));

test('historical CC 2.0 Stable identity remains frozen',()=>{
  assert.equal(release.stage,'stable-release');
  assert.equal(release.ravenVersion,'2.0.32');
  assert.equal(release.commandCenterVersion,'2.0.0');
  assert.equal(release.nodeAgentVersion,'1.3.0');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(release.authProtocol,'rah-node-auth-v2');
  assert.equal(release.policyId,'rah-capability-allowlist-v1');
  assert.equal(release.nodeRuntimeChange,false);
});

test('historical CC 2.0 authority remains exactly 4 / 3 / 5',()=>{
  assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
  assert.deepEqual(release.authoritySurface.newCapabilities,[]);
  assert.deepEqual(release.authoritySurface.newActions,[]);
  assert.deepEqual(release.authoritySurface.newBusinessRoutes,[]);
});

test('historical CC 2.0 requester-context boundary remains persistence-free',()=>{
  const b=release.precommittedRequesterContext;
  assert.equal(b.version,'rah-cc-precommitted-requester-context-v1');
  assert.equal(b.generatedAtArm,true);
  assert.equal(b.rawRequesterContextMemoryOnly,true);
  assert.equal(b.rawRequesterContextPersistent,false);
  assert.equal(b.ticketStoresRequesterContextDigestOnly,true);
  assert.equal(b.bindsRequesterContextDigest,true);
  assert.equal(b.sameContextUsedForNodeLocalConfirmationAndExecution,true);
  assert.equal(b.singleUse,true);
  assert.equal(b.consumeOnContextMismatch,true);
  assert.equal(b.mathRandomFallback,false);
});

test('historical CC 2.0 generic authority and secrets remain forbidden',()=>{
  for(const item of ['new-capabilities','new-actions','new-routes','bearer-token-network-transport','shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','native-raven-remote-control-api'])assert.ok(release.forbiddenRuntimeExpansion.includes(item),item);
  for(const item of ['node-token','auth-nonce','auth-proof','action-challenge','node-local-approval-proof','password','rustdesk-peer-id','raw-requester-context'])assert.ok(release.forbiddenPersistence.includes(item),item);
});

console.log('RAH CC v2.0 historical Raven master evidence: PASS');
