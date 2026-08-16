import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const stable=require('../rah-command-center-core-v1.4.js');
const rollback=require('../rah-command-center-core-v1.3.js');
const release=JSON.parse(fs.readFileSync('RAH-CC14-STABLE-RELEASE.json','utf8'));
const contract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const stableHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.4.html','utf8');
const nodeAgent=fs.readFileSync('rah-node-agent-v0.9.py','utf8');

function gitBlobSha(path){
  const body=fs.readFileSync(path);
  const header=Buffer.from(`blob ${body.length}\0`);
  return crypto.createHash('sha1').update(header).update(body).digest('hex');
}
function verifyRef(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('Stable release manifest pins every release, rollback and Candidate reference blob',()=>{
  assert.equal(release.schemaVersion,1);
  assert.equal(release.stage,'stable-release');
  assert.equal(release.releaseId,'rah-cc14-ephemeral-approval-stable-v1');
  assert.equal(release.authorityDelta,'none');
  for(const ref of [
    release.stableRuntime.commandCenterCore,
    release.stableRuntime.commandCenterHtml,
    release.stableRuntime.canonicalContract,
    release.stableRuntime.nodeAgent,
    release.rollbackRuntime.commandCenterCore,
    release.rollbackRuntime.commandCenterHtml,
    release.rollbackRuntime.nodeAgent,
    release.candidateReference.commandCenterCore,
    release.candidateReference.commandCenterHtml,
    release.candidateReference.candidateContract,
    release.candidateReference.readinessManifest
  ]) verifyRef(ref);
});

test('Stable 1.4 has exact version, protocol, policy, capability and action surface',()=>{
  assert.equal(stable.CC_VERSION,'1.4.0');
  assert.equal(stable.APPROVAL_PERSISTENCE,'ephemeral-browser-session');
  assert.equal(stable.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.equal(stable.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.deepEqual([...stable.CAPABILITY_IDS],caps);
  assert.deepEqual([...stable.ACTION_IDS],actions);
  assert.deepEqual([...stable.CAPABILITY_IDS],[...rollback.CAPABILITY_IDS]);
  assert.deepEqual([...stable.ACTION_IDS],[...rollback.ACTION_IDS]);
  assert.deepEqual(release.authoritySurface.capabilities,caps);
  assert.deepEqual(release.authoritySurface.actions,actions);
  assert.deepEqual(release.authoritySurface.routes,routes);
});

test('canonical contract exactly names Stable 1.4 and unchanged Node Agent 0.9',()=>{
  assert.equal(contract.status,'stable-ephemeral-approval');
  assert.equal(contract.baseline.ravenVersion,'2.0.32');
  assert.equal(contract.baseline.commandCenterVersion,'1.4.0');
  assert.equal(contract.baseline.nodeAgentVersion,'0.9.0');
  assert.equal(contract.baseline.nodeActionsProtocol,'rah-node-actions-v4');
  assert.equal(contract.policyId,'rah-capability-allowlist-v1');
  assert.deepEqual(contract.runtimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.4.html',commandCenterCore:'rah-command-center-core-v1.4.js',nodeAgent:'rah-node-agent-v0.9.py'});
  assert.ok(nodeAgent.includes("AGENT_VERSION='0.9.0'"));
  assert.ok(nodeAgent.includes("ACTIONS_PROTOCOL='rah-node-actions-v4'"));
  assert.ok(nodeAgent.includes("ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1'"));
});

test('approval persistence is forbidden, stale approvals are scrubbed and reload requires reapproval',()=>{
  assert.equal(release.approvalPolicy.lifetime,'current-command-center-browser-session');
  assert.equal(release.approvalPolicy.persistApprovedActions,false);
  assert.equal(release.approvalPolicy.acceptPersistedApprovedActions,false);
  assert.equal(release.approvalPolicy.startupStorageScrub,true);
  assert.equal(release.approvalPolicy.reloadRequiresReapproval,true);
  assert.equal(contract.approvalPolicy.persistence,'forbidden');
  assert.ok(!contract.persistence.allowed.includes('local-approved-action-ids'));
  assert.ok(contract.persistence.forbidden.includes('local-approved-action-ids'));
  assert.ok(stableHtml.includes('core.persistableDeviceRegistry(loaded)'));
  assert.ok(stableHtml.includes('core.persistableDeviceRegistry(devices)'));
  assert.ok(stableHtml.includes('.replace(LOAD_MARKER,LOAD_REPLACEMENT).replace(SAVE_MARKER,SAVE_REPLACEMENT)'));
});

test('persisted approval cannot execute after Stable 1.4 load but a fresh in-memory approval can',()=>{
  const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX';
  const stored=[{
    id:'node',label:'Node',role:'test',platform:'TestOS',kind:'desktop',source:'local',status:'unverified',
    enrolled:true,endpointIp:'127.0.0.1',agentSessionId:sessionId,agentHostname:'node',agentVersion:'0.9.0',
    capabilities:caps,advertisedActions:actions,approvedActions:['rustdesk.launch']
  }];
  let device=stable.normalizeDeviceRegistry(stored)[0];
  assert.deepEqual(device.approvedActions,[]);
  assert.equal(stable.canExecuteAction(device,'rustdesk.launch'),false);
  device=stable.approveDeviceAction([device],'node','rustdesk.launch')[0];
  assert.equal(stable.canExecuteAction(device,'rustdesk.launch'),true);
  assert.deepEqual(stable.persistableDeviceRegistry([device])[0].approvedActions,[]);
});

test('direct rollback is byte-pinned CC 1.3 plus the same Node 0.9 and same registry key',()=>{
  assert.equal(rollback.CC_VERSION,'1.3.0');
  assert.equal(release.rollbackRuntime.commandCenterVersion,'1.3.0');
  assert.equal(release.rollbackRuntime.registryKey,'rah.cc.devices.v1');
  assert.equal(stable.DEVICE_STORAGE_KEY,'rah.cc.devices.v1');
  assert.equal(stable.DEVICE_STORAGE_KEY,rollback.DEVICE_STORAGE_KEY);
  assert.equal(release.rollbackRuntime.requiresDataMigration,false);
  assert.equal(release.rollbackRuntime.requiresSecretMigration,false);
  assert.equal(release.rollbackRuntime.nodeAgent.gitBlobSha,release.stableRuntime.nodeAgent.gitBlobSha);
});

test('Stable browser loader remains fixed-source same-origin and fail-closed',()=>{
  assert.ok(stableHtml.includes("const SOURCE='RAH-COMMAND-CENTER-V1.2.html'"));
  assert.ok(stableHtml.includes('window.RAHCommandCenterCore=window.RAHCommandCenterCoreV14'));
  assert.ok(stableHtml.includes('sourceUrl.origin!==window.location.origin'));
  assert.ok(stableHtml.includes('Cross-origin redirect rejected.'));
  assert.ok(stableHtml.includes('Expected unique core marker not found.'));
  assert.ok(stableHtml.includes('Expected unique load marker not found.'));
  assert.ok(stableHtml.includes('Expected unique persistence marker not found.'));
  assert.doesNotMatch(stableHtml,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

test('release forbids generic runtime or persistence expansion',()=>{
  for(const item of ['local-approved-action-ids','bearer-token','action-challenge','password','rustdesk-peer-id','action-result','executable-path','arbitrary-arguments'])assert.ok(release.forbiddenPersistence.includes(item));
  for(const item of ['new-capabilities','new-actions','new-routes','shell','generic-command-execution','generic-process-launch','caller-controlled-executable-path','caller-controlled-generic-arguments','generic-file-api','generic-endpoint-dispatch','native-raven-remote-control-api','network-token-renewal-endpoint'])assert.ok(release.forbiddenRuntimeExpansion.includes(item));
});
