import test from 'node:test';
import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const stable=require('../rah-command-center-core.js');
const candidate=require('../rah-command-center-core-v1.3-candidate.js');
const stableContract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const candidateContract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CANDIDATE.json','utf8'));
const gate=JSON.parse(fs.readFileSync('RAH-POLICY-STABLE-PROMOTION-GATE.json','utf8'));
const stableAgent=fs.readFileSync('rah-node-agent.py','utf8');
const candidateAgent=fs.readFileSync('rah-node-agent-v0.9-candidate.py','utf8');

function gitBlobSha(path){
  const bytes=fs.readFileSync(path);
  const prefix=Buffer.from(`blob ${bytes.length}\0`,'utf8');
  return crypto.createHash('sha1').update(prefix).update(bytes).digest('hex');
}

const capabilities=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('promotion gate is readiness-only with zero authority delta',()=>{
  assert.equal(gate.stage,'promotion-readiness');
  assert.equal(gate.gateId,'rah-policy-stable-promotion-v1');
  assert.equal(gate.authorityDelta,'none');
  assert.match(gate.promotionRule,/separate PR/i);
});

test('promotion source files are cryptographically pinned as Git blobs',()=>{
  for(const [path,sha] of Object.entries(gate.stableBaseline.files))assert.equal(gitBlobSha(path),sha,`Stable blob drift: ${path}`);
  for(const [path,sha] of Object.entries(gate.candidate.files))assert.equal(gitBlobSha(path),sha,`Candidate blob drift: ${path}`);
});

test('Stable and Candidate capability surfaces are exactly identical',()=>{
  assert.deepEqual([...stable.CAPABILITY_IDS],capabilities);
  assert.deepEqual([...candidate.CAPABILITY_IDS],capabilities);
  assert.deepEqual(gate.authoritySurface.capabilities,capabilities);
  assert.deepEqual(stableContract.capabilities,capabilities);
  assert.deepEqual(candidateContract.capabilities,capabilities);
});

test('Stable and Candidate action surfaces and metadata are exactly identical',()=>{
  assert.deepEqual([...stable.ACTION_IDS],actions);
  assert.deepEqual([...candidate.ACTION_IDS],actions);
  assert.deepEqual(gate.authoritySurface.actions,actions);
  assert.deepEqual(candidateContract.actions,actions);
  for(const id of actions)assert.deepEqual(candidate.ACTION_CATALOG[id],stable.ACTION_CATALOG[id]);
  assert.deepEqual(stableContract.actions.map(a=>a.id),actions);
});

test('Node Agent Candidate inherits the Stable capability, action and route authority',()=>{
  assert.ok(candidateAgent.includes('ALLOWED_CAPABILITIES=_base.ALLOWED_CAPABILITIES'));
  assert.ok(candidateAgent.includes('ACTION_CATALOG=_base.ACTION_CATALOG'));
  assert.ok(candidateAgent.includes('create_server=_base.create_server'));
  assert.ok(candidateAgent.includes("BASE_PATH=Path(__file__).with_name('rah-node-agent.py')"));
  assert.ok(stableAgent.includes('("/health","/actions","/storage","/launch/rustdesk","/handoff/rustdesk")'));
  assert.deepEqual(gate.authoritySurface.routes,routes);
  const forbiddenEndpoint=/["']\/(?:shell|exec|command|commands|file|files|remote-control|remote_control|token|auth\/refresh)(?:\/|["'?])/i;
  assert.doesNotMatch(candidateAgent,forbiddenEndpoint);
});

test('allowed behavior delta is limited to version, protocol, policy enforcement and fixed UI loader',()=>{
  assert.deepEqual(gate.allowedBehaviorDelta,[
    'version-labels',
    'actions-protocol-v3-to-v4',
    'exact-policy-id-required-on-actions-catalog',
    'candidate-browser-loader-over-frozen-v1.2-ui'
  ]);
  assert.equal(stable.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v3');
  assert.equal(candidate.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.equal(candidate.ALLOWLIST_POLICY_ID,stableContract.policyId);
  assert.equal(candidateContract.expectedPolicyId,stableContract.policyId);
});

test('rollback needs no registry or secret migration',()=>{
  assert.equal(stable.DEVICE_STORAGE_KEY,'rah.cc.devices.v1');
  assert.equal(candidate.DEVICE_STORAGE_KEY,stable.DEVICE_STORAGE_KEY);
  assert.equal(gate.persistenceCompatibility.deviceRegistryKey,stable.DEVICE_STORAGE_KEY);
  assert.equal(gate.persistenceCompatibility.dataMigration,'none');
  assert.equal(gate.persistenceCompatibility.secretMigration,'none');
  assert.equal(gate.persistenceCompatibility.approvalExpansion,'none');
  assert.equal(gate.rollback.dataMigrationRequired,false);
  assert.equal(gate.rollback.restoreStableRuntimeBlobs,true);
  assert.equal(gate.rollback.deviceRegistryCompatible,true);
});

test('promotion gate does not itself authorize Stable runtime mutation',()=>{
  assert.equal(stableContract.masterSyncBoundary.stableRuntimeMutation,'not-authorized-by-this-contract');
  assert.equal(stableContract.masterSyncBoundary.endpointExpansion,'requires-explicit-new-version-and-stable-gate');
  assert.equal(stableContract.masterSyncBoundary.capabilityExpansion,'requires-explicit-new-version-and-stable-gate');
  assert.equal(stableContract.masterSyncBoundary.catalogExpansion,'requires-explicit-new-version-and-stable-gate');
});
