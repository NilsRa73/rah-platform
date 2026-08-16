import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const contract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const rollbackCore=require('../rah-command-center-core.js');
const stableCore=require('../rah-command-center-core-v1.3.js');
const rollbackCoreSource=fs.readFileSync('rah-command-center-core.js','utf8');
const stableCoreSource=fs.readFileSync('rah-command-center-core-v1.3.js','utf8');
const rollbackAgent=fs.readFileSync('rah-node-agent.py','utf8');
const stableAgent=fs.readFileSync('rah-node-agent-v0.9.py','utf8');
const rollbackHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.2.html','utf8');
const stableHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.3.html','utf8');

const capabilities=['compute','storage','display','remote-desktop'];
const actions=[
  {id:'storage-summary.read',capability:'storage',method:'GET',path:'/storage',scope:'system-volume',mutating:false},
  {id:'rustdesk.launch',capability:'remote-desktop',method:'POST',path:'/launch/rustdesk',scope:'fixed-app',mutating:true},
  {id:'rustdesk.connect',capability:'remote-desktop',method:'POST',path:'/handoff/rustdesk',scope:'fixed-app-peer-id',mutating:true}
];
const actionIds=actions.map(a=>a.id);
const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX';
const challenge='ABCDEFGHIJKLMNOPQRSTUVWXYZabcd';

function actionRows(){return actionIds.map(id=>({...stableCore.ACTION_CATALOG[id],challenge,challengeTtlSeconds:60}))}
function catalog(policyId='rah-capability-allowlist-v1',protocol='rah-node-actions-v4'){
  const value={protocol,status:'ready',sessionId,actions:actionRows()};
  if(policyId!==null)value.policyId=policyId;
  return value;
}

test('canonical contract pins policy-bound Stable 1.3 / 0.9 baseline',()=>{
  assert.equal(contract.schemaVersion,1);
  assert.equal(contract.policyId,'rah-capability-allowlist-v1');
  assert.equal(contract.status,'stable-policy-bound');
  assert.equal(contract.baseline.ravenVersion,'2.0.32');
  assert.equal(contract.baseline.commandCenterVersion,'1.3.0');
  assert.equal(contract.baseline.nodeAgentVersion,'0.9.0');
  assert.equal(contract.baseline.nodeHealthProtocol,'rah-node-health-v2');
  assert.equal(contract.baseline.nodeActionsProtocol,'rah-node-actions-v4');
  assert.deepEqual(contract.runtimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.3.html',commandCenterCore:'rah-command-center-core-v1.3.js',nodeAgent:'rah-node-agent-v0.9.py'});
});

test('Stable core exposes exactly the same four capabilities and three fixed actions',()=>{
  assert.equal(stableCore.CC_VERSION,'1.3.0');
  assert.equal(stableCore.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.equal(stableCore.ALLOWLIST_POLICY_ID,contract.policyId);
  assert.deepEqual([...stableCore.CAPABILITY_IDS],capabilities);
  assert.deepEqual([...stableCore.ACTION_IDS],actionIds);
  assert.deepEqual(contract.capabilities,capabilities);
  for(const action of actions){
    const row=stableCore.ACTION_CATALOG[action.id];
    assert.deepEqual({id:row.id,capability:row.capability,method:row.method,path:row.path,scope:row.scope,mutating:row.mutating},action);
  }
});

test('Stable Node Agent inherits the exact rollback authority surface and adds no route',()=>{
  assert.ok(stableAgent.includes('ALLOWED_CAPABILITIES=_base.ALLOWED_CAPABILITIES'));
  assert.ok(stableAgent.includes('ACTION_CATALOG=_base.ACTION_CATALOG'));
  assert.ok(stableAgent.includes('create_server=_base.create_server'));
  assert.ok(rollbackAgent.includes('ALLOWED_CAPABILITIES=("compute","storage","display","remote-desktop")'));
  assert.ok(rollbackAgent.includes('("/health","/actions","/storage","/launch/rustdesk","/handoff/rustdesk")'));
  assert.deepEqual(contract.actions.map(a=>a.path).sort(),['/handoff/rustdesk','/launch/rustdesk','/storage']);
});

test('Stable v1.3 requires exact v4 protocol, policy ID, session and action metadata',()=>{
  const accepted=stableCore.sanitizeActionCatalog(catalog(),capabilities,sessionId);
  assert.ok(accepted);
  assert.equal(accepted.policyId,contract.policyId);
  assert.deepEqual(accepted.actions,actionIds);
  assert.equal(stableCore.sanitizeActionCatalog(catalog(null),capabilities,sessionId),null);
  assert.equal(stableCore.sanitizeActionCatalog(catalog('wrong-policy'),capabilities,sessionId),null);
  assert.equal(stableCore.sanitizeActionCatalog(catalog(contract.policyId,'rah-node-actions-v3'),capabilities,sessionId),null);
  assert.equal(stableCore.sanitizeActionCatalog(catalog(),capabilities,'ZYXWVUTSRQPONMLKJIHGFEDC'),null);
});

test('execution remains capability + advertisement + local approval + session + policy + fresh challenge gated',()=>{
  assert.ok(rollbackCoreSource.includes('d.capabilities.includes(a.capability)'));
  assert.ok(rollbackCoreSource.includes('d.advertisedActions.includes(actionId)'));
  assert.ok(rollbackCoreSource.includes('d.approvedActions.includes(actionId)'));
  assert.ok(stableCoreSource.includes('payload.policyId!==ALLOWLIST_POLICY_ID'));
  assert.ok(stableCoreSource.includes('expected&&sessionId!==expected'));
  assert.ok(stableCoreSource.includes('actionChallengeFromCatalog'));
  assert.ok(rollbackHtml.includes('freshActionChallenge'));
  assert.ok(rollbackAgent.includes('consume_action_challenge'));
  assert.ok(rollbackAgent.includes('ACTION_CHALLENGE_TTL_SECONDS=60'));
  assert.ok(contract.executionRequirements.includes('actions-catalog-policy-id-matches-rah-capability-allowlist-v1'));
});

test('bearer token remains process-memory only with no network renewal endpoint',()=>{
  assert.equal(contract.tokenPolicy.storage,'forbidden');
  assert.equal(contract.tokenPolicy.networkRenewalEndpoint,'forbidden');
  assert.ok(stableAgent.includes("token=_base.secrets.token_urlsafe(32)"));
  assert.ok(rollbackAgent.includes('is_authorized(self.headers.get("Authorization"),token)'));
  for(const id of ['nodeToken','actionToken','handoffToken'])assert.ok(rollbackHtml.includes(`document.getElementById('${id}').value=''`));
  for(const source of [stableCoreSource,rollbackCoreSource,stableAgent,rollbackAgent]){
    assert.doesNotMatch(source,/["']\/token(?:\/|["'?])/i);
    assert.doesNotMatch(source,/["']\/auth\/refresh(?:\/|["'?])/i);
  }
});

test('browser persistence and registry compatibility stay unchanged',()=>{
  assert.equal(stableCore.DEVICE_STORAGE_KEY,'rah.cc.devices.v1');
  assert.equal(stableCore.DEVICE_STORAGE_KEY,rollbackCore.DEVICE_STORAGE_KEY);
  const writes=rollbackHtml.match(/localStorage\.setItem\(/g)||[];
  assert.equal(writes.length,1);
  assert.ok(rollbackHtml.includes('localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(devices))'));
  assert.equal((stableHtml.match(/localStorage\.setItem\(/g)||[]).length,0);
  for(const forbidden of ['bearer-token','action-challenge','password','rustdesk-peer-id'])assert.ok(contract.persistence.forbidden.includes(forbidden));
});

test('Stable browser surface is fixed-source, same-origin and fail-closed',()=>{
  assert.ok(stableHtml.includes("const SOURCE='RAH-COMMAND-CENTER-V1.2.html'"));
  assert.ok(stableHtml.includes('rah-command-center-core-v1.3.js'));
  assert.ok(stableHtml.includes('window.RAHCommandCenterCore=window.RAHCommandCenterCoreV13'));
  assert.ok(stableHtml.includes('sourceUrl.origin!==window.location.origin'));
  assert.ok(stableHtml.includes('Cross-origin redirect rejected.'));
  assert.ok(stableHtml.includes('Expected unique rollback core marker not found.'));
  assert.doesNotMatch(stableHtml,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

test('forbidden generic runtime authority remains absent',()=>{
  const forbiddenEndpoint=/["']\/(?:shell|exec|command|commands|files|file|remote-control|remote_control)(?:\/|["'?])/i;
  for(const source of [stableCoreSource,stableAgent,rollbackCoreSource,rollbackAgent])assert.doesNotMatch(source,forbiddenEndpoint);
  assert.ok(rollbackAgent.includes('"shell":False'));
  assert.equal(stableCore.READ_ONLY_PERMISSIONS.shell,false);
  assert.equal(stableCore.READ_ONLY_PERMISSIONS.files,false);
  assert.equal(stableCore.READ_ONLY_PERMISSIONS.commands,false);
  assert.equal(stableCore.READ_ONLY_PERMISSIONS.remoteControl,false);
});

test('RustDesk handoff remains typed with fixed executable ownership',()=>{
  assert.equal(stableCore.sanitizePeerId('123456789'),'123456789');
  assert.ok(rollbackCoreSource.includes('body:{peerId:id}'));
  assert.ok(rollbackAgent.includes('set(payload.keys())!={"peerId"}'));
  assert.ok(rollbackAgent.includes('subprocess.Popen([path,"--connect",peer_id]'));
  assert.ok(rollbackAgent.includes('"shell":False'));
  assert.ok(!rollbackHtml.includes('name="exePath"'));
  assert.ok(!rollbackHtml.includes('name="arguments"'));
  assert.ok(!rollbackHtml.includes('name="password"'));
});

test('rollback 1.2 / 0.8 remains intact and requires no registry migration',()=>{
  assert.equal(rollbackCore.CC_VERSION,'1.2.0');
  assert.equal(rollbackCore.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v3');
  assert.ok(rollbackAgent.includes('AGENT_VERSION="0.8.0"'));
  assert.ok(rollbackAgent.includes('ACTIONS_PROTOCOL="rah-node-actions-v3"'));
  assert.deepEqual(contract.rollbackRuntimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.2.html',commandCenterCore:'rah-command-center-core.js',nodeAgent:'rah-node-agent.py'});
});

test('contract forbids silent master-sync authority expansion after promotion',()=>{
  for(const key of ['catalogExpansion','capabilityExpansion','endpointExpansion','tokenPolicyChange'])assert.equal(contract.masterSyncBoundary[key],'requires-explicit-new-version-and-stable-gate');
  assert.equal(contract.masterSyncBoundary.stableRuntimeMutation,'not-authorized-by-this-contract');
});
