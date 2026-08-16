import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const release=JSON.parse(fs.readFileSync('RAH-POLICY-STABLE-RELEASE.json','utf8'));
const contract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const stable=require('../rah-command-center-core-v1.3.js');
const candidate=require('../rah-command-center-core-v1.3-candidate.js');
const rollback=require('../rah-command-center-core.js');
const stableAgent=fs.readFileSync('rah-node-agent-v0.9.py','utf8');
const rollbackAgent=fs.readFileSync('rah-node-agent.py','utf8');

function gitBlobSha(path){
  const bytes=fs.readFileSync(path);
  return crypto.createHash('sha1').update(Buffer.from(`blob ${bytes.length}\0`)).update(bytes).digest('hex');
}

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('historical release manifest identifies policy-bound 1.3 Stable without authority expansion',()=>{
  assert.equal(release.stage,'stable');
  assert.equal(release.ravenVersion,'2.0.32');
  assert.equal(release.policyId,'rah-capability-allowlist-v1');
  assert.equal(release.commandCenterVersion,'1.3.0');
  assert.equal(release.nodeAgentVersion,'0.9.0');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v4');
  assert.equal(release.authorityDeltaFromPreviousStable,'none');
  assert.deepEqual(release.capabilities,caps);
  assert.deepEqual(release.actions,actions);
  assert.deepEqual(release.routes,routes);
  assert.equal(release.freezeAfterPromotion,true);
});

test('historical Stable 1.3 and rollback runtime blobs remain exactly pinned',()=>{
  for(const [path,sha] of Object.entries(release.stableRuntime))assert.equal(gitBlobSha(path),sha,`Stable 1.3 release blob drift: ${path}`);
  for(const [path,sha] of Object.entries(release.rollbackRuntime))assert.equal(gitBlobSha(path),sha,`Rollback blob drift: ${path}`);
});

test('current canonical contract preserves the historical 1.3 policy/protocol/authority even after later Stable promotion',()=>{
  assert.equal(contract.policyId,release.policyId);
  assert.equal(contract.baseline.nodeAgentVersion,'0.9.0');
  assert.equal(contract.baseline.nodeActionsProtocol,release.nodeActionsProtocol);
  assert.deepEqual(contract.capabilities,caps);
  assert.deepEqual(contract.actions.map(a=>a.id),actions);
  if(contract.baseline.commandCenterVersion==='1.3.0'){
    assert.equal(contract.status,'stable-policy-bound');
    assert.deepEqual(Object.values(contract.runtimeFiles).sort(),Object.keys(release.stableRuntime).sort());
    assert.deepEqual(Object.values(contract.rollbackRuntimeFiles).sort(),Object.keys(release.rollbackRuntime).sort());
  }else{
    assert.equal(contract.baseline.commandCenterVersion,'1.4.0');
    assert.equal(contract.status,'stable-ephemeral-approval');
    assert.deepEqual(contract.rollbackRuntimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.3.html',commandCenterCore:'rah-command-center-core-v1.3.js',nodeAgent:'rah-node-agent-v0.9.py'});
  }
});

test('historical Stable runtime remains authority-equivalent to approved 1.3 Candidate',()=>{
  assert.deepEqual([...stable.CAPABILITY_IDS],[...candidate.CAPABILITY_IDS]);
  assert.deepEqual([...stable.ACTION_IDS],[...candidate.ACTION_IDS]);
  for(const id of actions)assert.deepEqual(stable.ACTION_CATALOG[id],candidate.ACTION_CATALOG[id]);
  assert.equal(stable.NODE_ACTIONS_PROTOCOL,candidate.NODE_ACTIONS_PROTOCOL);
  assert.equal(stable.ALLOWLIST_POLICY_ID,candidate.ALLOWLIST_POLICY_ID);
  assert.equal(stable.DEVICE_STORAGE_KEY,candidate.DEVICE_STORAGE_KEY);
});

test('1.2 / 0.8 historical rollback evidence remains intact',()=>{
  assert.equal(rollback.CC_VERSION,'1.2.0');
  assert.equal(rollback.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v3');
  assert.ok(rollbackAgent.includes('AGENT_VERSION="0.8.0"'));
  assert.ok(rollbackAgent.includes('ACTIONS_PROTOCOL="rah-node-actions-v3"'));
  assert.equal(release.rollback.dataMigration,'none');
  assert.equal(release.rollback.secretMigration,'none');
  assert.equal(release.rollback.deviceRegistryKey,stable.DEVICE_STORAGE_KEY);
  assert.equal(release.rollback.restoreVersionedRollbackRuntime,true);
});

test('Node Agent 0.9 wrapper changes policy/protocol but not capability/action/server ownership',()=>{
  assert.ok(stableAgent.includes("AGENT_VERSION='0.9.0'"));
  assert.ok(stableAgent.includes("ACTIONS_PROTOCOL='rah-node-actions-v4'"));
  assert.ok(stableAgent.includes("ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1'"));
  assert.ok(stableAgent.includes('ALLOWED_CAPABILITIES=_base.ALLOWED_CAPABILITIES'));
  assert.ok(stableAgent.includes('ACTION_CATALOG=_base.ACTION_CATALOG'));
  assert.ok(stableAgent.includes('create_server=_base.create_server'));
  assert.ok(stableAgent.includes("BASE_PATH=Path(__file__).with_name('rah-node-agent.py')"));
});

test('historical release contains no generic runtime endpoint authority',()=>{
  const forbidden=/["']\/(?:shell|exec|command|commands|file|files|remote-control|remote_control|token|auth\/refresh)(?:\/|["'?])/i;
  assert.doesNotMatch(stableAgent,forbidden);
  assert.ok(rollbackAgent.includes('("/health","/actions","/storage","/launch/rustdesk","/handoff/rustdesk")'));
});
