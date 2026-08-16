import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';

const require=createRequire(import.meta.url);
const baseCore=require('../rah-command-center-core.js');
const rollbackCore=require('../rah-command-center-core-v1.3.js');
const stableCore=require('../rah-command-center-core-v1.4.js');
const contract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const baseCoreSource=fs.readFileSync('rah-command-center-core.js','utf8');
const rollbackCoreSource=fs.readFileSync('rah-command-center-core-v1.3.js','utf8');
const stableCoreSource=fs.readFileSync('rah-command-center-core-v1.4.js','utf8');
const baseAgent=fs.readFileSync('rah-node-agent.py','utf8');
const stableAgent=fs.readFileSync('rah-node-agent-v0.9.py','utf8');
const baseHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.2.html','utf8');
const rollbackHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.3.html','utf8');
const stableHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.4.html','utf8');

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
function enrolledWithPersistedApproval(){
  return{
    id:'node',label:'Node',role:'test',platform:'TestOS',kind:'desktop',source:'local',status:'unverified',
    enrolled:true,endpointIp:'127.0.0.1',agentSessionId:sessionId,agentHostname:'node',agentVersion:'0.9.0',
    capabilities,permissions:stableCore.READ_ONLY_PERMISSIONS,advertisedActions:actionIds,approvedActions:['rustdesk.launch'],remoteControlEnabled:false,commandsEnabled:false
  };
}

test('canonical contract pins ephemeral-approval Stable 1.4 / Node Agent 0.9 baseline',()=>{
  assert.equal(contract.schemaVersion,1);
  assert.equal(contract.policyId,'rah-capability-allowlist-v1');
  assert.equal(contract.status,'stable-ephemeral-approval');
  assert.equal(contract.baseline.ravenVersion,'2.0.32');
  assert.equal(contract.baseline.commandCenterVersion,'1.4.0');
  assert.equal(contract.baseline.nodeAgentVersion,'0.9.0');
  assert.equal(contract.baseline.nodeHealthProtocol,'rah-node-health-v2');
  assert.equal(contract.baseline.nodeActionsProtocol,'rah-node-actions-v4');
  assert.deepEqual(contract.runtimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.4.html',commandCenterCore:'rah-command-center-core-v1.4.js',nodeAgent:'rah-node-agent-v0.9.py'});
});

test('Stable 1.4 exposes exactly the same four capabilities and three fixed actions',()=>{
  assert.equal(stableCore.CC_VERSION,'1.4.0');
  assert.equal(stableCore.APPROVAL_PERSISTENCE,'ephemeral-browser-session');
  assert.equal(stableCore.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.equal(stableCore.ALLOWLIST_POLICY_ID,contract.policyId);
  assert.deepEqual([...stableCore.CAPABILITY_IDS],capabilities);
  assert.deepEqual([...stableCore.ACTION_IDS],actionIds);
  assert.deepEqual([...stableCore.CAPABILITY_IDS],[...rollbackCore.CAPABILITY_IDS]);
  assert.deepEqual([...stableCore.ACTION_IDS],[...rollbackCore.ACTION_IDS]);
  assert.deepEqual(contract.capabilities,capabilities);
  for(const action of actions){
    const row=stableCore.ACTION_CATALOG[action.id];
    assert.deepEqual({id:row.id,capability:row.capability,method:row.method,path:row.path,scope:row.scope,mutating:row.mutating},action);
  }
});

test('Node Agent 0.9 authority surface remains unchanged and adds no route',()=>{
  assert.ok(stableAgent.includes("AGENT_VERSION='0.9.0'"));
  assert.ok(stableAgent.includes("ACTIONS_PROTOCOL='rah-node-actions-v4'"));
  assert.ok(stableAgent.includes("ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1'"));
  assert.ok(stableAgent.includes('ALLOWED_CAPABILITIES=_base.ALLOWED_CAPABILITIES'));
  assert.ok(stableAgent.includes('ACTION_CATALOG=_base.ACTION_CATALOG'));
  assert.ok(stableAgent.includes('create_server=_base.create_server'));
  assert.ok(baseAgent.includes('ALLOWED_CAPABILITIES=("compute","storage","display","remote-desktop")'));
  assert.ok(baseAgent.includes('("/health","/actions","/storage","/launch/rustdesk","/handoff/rustdesk")'));
  assert.deepEqual(contract.actions.map(a=>a.path).sort(),['/handoff/rustdesk','/launch/rustdesk','/storage']);
});

test('Stable 1.4 still requires exact v4 protocol, policy ID, session and action metadata',()=>{
  const accepted=stableCore.sanitizeActionCatalog(catalog(),capabilities,sessionId);
  assert.ok(accepted);
  assert.equal(accepted.policyId,contract.policyId);
  assert.deepEqual(accepted.actions,actionIds);
  assert.equal(stableCore.sanitizeActionCatalog(catalog(null),capabilities,sessionId),null);
  assert.equal(stableCore.sanitizeActionCatalog(catalog('wrong-policy'),capabilities,sessionId),null);
  assert.equal(stableCore.sanitizeActionCatalog(catalog(contract.policyId,'rah-node-actions-v3'),capabilities,sessionId),null);
  assert.equal(stableCore.sanitizeActionCatalog(catalog(),capabilities,'ZYXWVUTSRQPONMLKJIHGFEDC'),null);
});

test('execution remains capability + advertisement + ephemeral local approval + session + policy + fresh challenge gated',()=>{
  const loaded=stableCore.normalizeDeviceRegistry([enrolledWithPersistedApproval()])[0];
  assert.deepEqual(loaded.approvedActions,[]);
  assert.equal(stableCore.canExecuteAction(loaded,'rustdesk.launch'),false);
  const approved=stableCore.approveDeviceAction([loaded],'node','rustdesk.launch')[0];
  assert.equal(stableCore.canExecuteAction(approved,'rustdesk.launch'),true);
  assert.deepEqual(stableCore.persistableDeviceRegistry([approved])[0].approvedActions,[]);
  assert.ok(baseCoreSource.includes('d.capabilities.includes(a.capability)'));
  assert.ok(baseCoreSource.includes('d.advertisedActions.includes(actionId)'));
  assert.ok(baseCoreSource.includes('d.approvedActions.includes(actionId)'));
  assert.ok(rollbackCoreSource.includes('payload.policyId!==ALLOWLIST_POLICY_ID'));
  assert.ok(rollbackCoreSource.includes('expected&&sessionId!==expected'));
  assert.ok(rollbackCoreSource.includes('actionChallengeFromCatalog'));
  assert.ok(baseHtml.includes('freshActionChallenge'));
  assert.ok(baseAgent.includes('consume_action_challenge'));
  assert.ok(baseAgent.includes('ACTION_CHALLENGE_TTL_SECONDS=60'));
  assert.ok(contract.executionRequirements.includes('ephemeral-local-per-device-action-approval-exists'));
  assert.ok(contract.executionRequirements.includes('actions-catalog-policy-id-matches-rah-capability-allowlist-v1'));
});

test('approval persistence is forbidden and startup scrub is mandatory',()=>{
  assert.equal(contract.approvalPolicy.lifetime,'current-command-center-browser-session');
  assert.equal(contract.approvalPolicy.persistence,'forbidden');
  assert.equal(contract.approvalPolicy.acceptPersistedApprovedActions,false);
  assert.equal(contract.approvalPolicy.startupStorageScrub,true);
  assert.equal(contract.approvalPolicy.reloadRequiresReapproval,true);
  assert.ok(!contract.persistence.allowed.includes('local-approved-action-ids'));
  assert.ok(contract.persistence.forbidden.includes('local-approved-action-ids'));
  assert.ok(stableHtml.includes('core.persistableDeviceRegistry(loaded)'));
  assert.ok(stableHtml.includes('core.persistableDeviceRegistry(devices)'));
  assert.ok(stableHtml.includes('.replace(LOAD_MARKER,LOAD_REPLACEMENT).replace(SAVE_MARKER,SAVE_REPLACEMENT)'));
});

test('bearer token remains process-memory only with no network renewal endpoint',()=>{
  assert.equal(contract.tokenPolicy.storage,'forbidden');
  assert.equal(contract.tokenPolicy.networkRenewalEndpoint,'forbidden');
  assert.ok(stableAgent.includes("token=_base.secrets.token_urlsafe(32)"));
  assert.ok(baseAgent.includes('is_authorized(self.headers.get("Authorization"),token)'));
  for(const id of ['nodeToken','actionToken','handoffToken'])assert.ok(baseHtml.includes(`document.getElementById('${id}').value=''`));
  for(const source of [stableCoreSource,rollbackCoreSource,baseCoreSource,stableAgent,baseAgent]){
    assert.doesNotMatch(source,/["']\/token(?:\/|["'?])/i);
    assert.doesNotMatch(source,/["']\/auth\/refresh(?:\/|["'?])/i);
  }
});

test('Stable browser surface is fixed-source, same-origin and fail-closed',()=>{
  assert.ok(stableHtml.includes("const SOURCE='RAH-COMMAND-CENTER-V1.2.html'"));
  assert.ok(stableHtml.includes('rah-command-center-core-v1.3.js'));
  assert.ok(stableHtml.includes('rah-command-center-core-v1.4.js'));
  assert.ok(stableHtml.includes('window.RAHCommandCenterCore=window.RAHCommandCenterCoreV14'));
  assert.ok(stableHtml.includes('sourceUrl.origin!==window.location.origin'));
  assert.ok(stableHtml.includes('Cross-origin redirect rejected.'));
  assert.ok(stableHtml.includes('Expected unique load marker not found.'));
  assert.ok(stableHtml.includes('Expected unique persistence marker not found.'));
  assert.doesNotMatch(stableHtml,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

test('forbidden generic runtime authority remains absent',()=>{
  const forbiddenEndpoint=/["']\/(?:shell|exec|command|commands|files|file|remote-control|remote_control)(?:\/|["'?])/i;
  for(const source of [stableCoreSource,rollbackCoreSource,stableAgent,baseCoreSource,baseAgent])assert.doesNotMatch(source,forbiddenEndpoint);
  assert.ok(baseAgent.includes('"shell":False'));
  assert.equal(stableCore.READ_ONLY_PERMISSIONS.shell,false);
  assert.equal(stableCore.READ_ONLY_PERMISSIONS.files,false);
  assert.equal(stableCore.READ_ONLY_PERMISSIONS.commands,false);
  assert.equal(stableCore.READ_ONLY_PERMISSIONS.remoteControl,false);
});

test('RustDesk handoff remains typed with fixed executable ownership',()=>{
  assert.equal(stableCore.sanitizePeerId('123456789'),'123456789');
  assert.ok(baseCoreSource.includes('body:{peerId:id}'));
  assert.ok(baseAgent.includes('set(payload.keys())!={"peerId"}'));
  assert.ok(baseAgent.includes('subprocess.Popen([path,"--connect",peer_id]'));
  assert.ok(baseAgent.includes('"shell":False'));
  assert.ok(!baseHtml.includes('name="exePath"'));
  assert.ok(!baseHtml.includes('name="arguments"'));
  assert.ok(!baseHtml.includes('name="password"'));
});

test('rollback target is CC 1.3 with the same Node Agent 0.9 and registry key',()=>{
  assert.equal(rollbackCore.CC_VERSION,'1.3.0');
  assert.equal(rollbackCore.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.equal(rollbackCore.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.equal(stableCore.DEVICE_STORAGE_KEY,'rah.cc.devices.v1');
  assert.equal(stableCore.DEVICE_STORAGE_KEY,rollbackCore.DEVICE_STORAGE_KEY);
  assert.deepEqual(contract.rollbackRuntimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.3.html',commandCenterCore:'rah-command-center-core-v1.3.js',nodeAgent:'rah-node-agent-v0.9.py'});
  assert.ok(rollbackHtml.includes('RAH RAVEN · CC 1.3 STABLE'));
});

test('contract forbids silent master-sync authority or approval-persistence expansion',()=>{
  for(const key of ['catalogExpansion','capabilityExpansion','endpointExpansion','tokenPolicyChange','approvalPersistenceChange'])assert.equal(contract.masterSyncBoundary[key],'requires-explicit-new-version-and-stable-gate');
  assert.equal(contract.masterSyncBoundary.stableRuntimeMutation,'not-authorized-by-this-contract');
});
