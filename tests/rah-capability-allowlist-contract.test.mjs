import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const contract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const stable=require('../rah-command-center-core-v1.5.js');
const rollback=require('../rah-command-center-core-v1.4.js');
const stableHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.5.html','utf8');
const rollbackHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.4.html','utf8');
const stableNode=fs.readFileSync('rah-node-agent-v1.0.py','utf8');
const candidateNode=fs.readFileSync('rah-node-agent-v1.0-candidate.py','utf8');
const rollbackNode=fs.readFileSync('rah-node-agent-v0.9.py','utf8');
const baseNode=fs.readFileSync('rah-node-agent.py','utf8');

const capabilities=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('canonical contract pins Stable CC 1.5 / Node Agent 1.0 / Actions v5',()=>{
  assert.equal(contract.schemaVersion,1);
  assert.equal(contract.status,'stable-node-local-approval-proof');
  assert.equal(contract.policyId,'rah-capability-allowlist-v1');
  assert.deepEqual(contract.baseline,{ravenVersion:'2.0.32',commandCenterVersion:'1.5.0',nodeAgentVersion:'1.0.0',nodeHealthProtocol:'rah-node-health-v2',nodeActionsProtocol:'rah-node-actions-v5'});
  assert.deepEqual(contract.runtimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.5.html',commandCenterCore:'rah-command-center-core-v1.5.js',nodeAgent:'rah-node-agent-v1.0.py'});
  assert.deepEqual(contract.rollbackRuntimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.4.html',commandCenterCore:'rah-command-center-core-v1.4.js',nodeAgent:'rah-node-agent-v0.9.py'});
});

test('Stable authority remains exactly 4 capabilities, 3 actions, 5 routes',()=>{
  assert.equal(stable.CC_VERSION,'1.5.0');
  assert.equal(stable.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v5');
  assert.equal(stable.ALLOWLIST_POLICY_ID,contract.policyId);
  assert.deepEqual([...stable.CAPABILITY_IDS],capabilities);
  assert.deepEqual([...stable.ACTION_IDS],actions);
  assert.deepEqual(contract.capabilities,capabilities);
  assert.deepEqual(contract.actions.map(a=>a.id),actions);
  assert.deepEqual(contract.routes,routes);
  assert.deepEqual([...stable.CAPABILITY_IDS],[...rollback.CAPABILITY_IDS]);
  assert.deepEqual([...stable.ACTION_IDS],[...rollback.ACTION_IDS]);
});

test('mutating fixed actions add Node-local proof without adding action or route authority',()=>{
  const reqs=contract.executionRequirements['mutating-fixed-actions'];
  for(const required of ['ephemeral-local-per-device-action-approval-exists','current-in-memory-bearer-token-is-present','enrolled-node-session-matches-current-agent-session','actions-catalog-policy-id-matches-rah-capability-allowlist-v1','node-local-human-confirmation-is-present','fresh-action-bound-single-use-challenge-is-present','fresh-node-local-single-use-approval-proof-is-present','proof-challenge-action-session-input-digest-pair-matches'])assert.ok(reqs.includes(required),required);
  assert.deepEqual(contract.approvalPolicy.nodeLocalProofRequiredFor,['rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(contract.approvalPolicy.nodeLocalProofNotRequiredFor,['storage-summary.read']);
  assert.equal(contract.approvalPolicy.proofTtlSeconds,30);
  assert.equal(contract.approvalPolicy.challengeTtlSecondsForMutatingActions,30);
  assert.equal(contract.approvalPolicy.singleUse,true);
  assert.equal(contract.approvalPolicy.atomicPairConsumption,true);
  assert.equal(contract.approvalPolicy.headlessMutatingIntent,'fail-closed');
  assert.equal(contract.approvalPolicy.networkThreadReadsStdin,false);
  assert.equal(contract.approvalPolicy.remoteFallback,false);
  assert.equal(contract.approvalPolicy.connectInputBinding,'sha256-canonical-peer-id');
  assert.equal(contract.approvalPolicy.rawPeerIdInProofState,false);
});

test('CC ephemeral approval remains memory-only and startup scrub stays required',()=>{
  assert.equal(contract.approvalPolicy.commandCenterLifetime,'current-command-center-browser-session');
  assert.equal(contract.approvalPolicy.commandCenterPersistence,'forbidden');
  assert.equal(contract.approvalPolicy.acceptPersistedApprovedActions,false);
  assert.equal(contract.approvalPolicy.startupStorageScrub,true);
  assert.equal(contract.approvalPolicy.reloadRequiresReapproval,true);
  assert.ok(contract.persistence.forbidden.includes('local-approved-action-ids'));
  const loaded=stable.normalizeDeviceRegistry([{id:'n',label:'N',role:'test',platform:'x',kind:'desktop',source:'local',enrolled:true,endpointIp:'127.0.0.1',agentSessionId:'ABCDEFGHIJKLMNOPQRSTUVWX',capabilities,permissions:stable.READ_ONLY_PERMISSIONS,advertisedActions:actions,approvedActions:['rustdesk.launch']}])[0];
  assert.deepEqual(loaded.approvedActions,[]);
  assert.equal(stable.canExecuteAction(loaded,'rustdesk.launch'),false);
});

test('v5 protocol is fail-closed against v4 and old mutating challenge path is disabled',()=>{
  assert.equal(rollback.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.equal(stable.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v5');
  const record={id:'n',enrolled:true,endpointIp:'127.0.0.1',agentSessionId:'ABCDEFGHIJKLMNOPQRSTUVWX',capabilities,advertisedActions:actions,approvedActions:['rustdesk.launch'],permissions:stable.READ_ONLY_PERMISSIONS};
  assert.equal(stable.actionChallengeRequest(record,'rustdesk.launch'),null);
  const intent=stable.localApprovalIntentRequest(record,'rustdesk.launch');
  assert.ok(intent);
  assert.match(intent.url,/^http:\/\/127\.0\.0\.1:\d+\/actions$/);
  assert.equal(intent.headers[stable.APPROVAL_ACTION_HEADER],'rustdesk.launch');
});

test('fixed approval headers are explicit and proof/challenge/token/peer persistence is forbidden',()=>{
  assert.deepEqual(contract.approvalHeaders,{intentAction:'X-RAH-Approval-Action',intentTarget:'X-RAH-Approval-Target',executionProof:'X-RAH-Local-Approval',actionChallenge:'X-RAH-Action-Challenge'});
  for(const key of ['bearer-token','action-challenge','node-local-approval-proof','password','rustdesk-peer-id'])assert.ok(contract.persistence.forbidden.includes(key));
  assert.equal(contract.tokenPolicy.storage,'forbidden');
  assert.equal(contract.tokenPolicy.networkRenewalEndpoint,'forbidden');
  assert.equal(contract.approvalPolicy.proofPersistence,'forbidden');
});

test('Node Stable wrapper pins v5 Candidate behavior and Stable identity',()=>{
  assert.ok(stableNode.includes("AGENT_VERSION='1.0.0'"));
  assert.ok(stableNode.includes("CANDIDATE_PATH=Path(__file__).with_name('rah-node-agent-v1.0-candidate.py')"));
  assert.ok(candidateNode.includes("ACTIONS_PROTOCOL='rah-node-actions-v5'"));
  assert.ok(candidateNode.includes("ROUTES=('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk')"));
  assert.ok(candidateNode.includes("MUTATING_ACTION_IDS=('rustdesk.launch','rustdesk.connect')"));
  assert.ok(candidateNode.includes("'approvalMode':'command-center-ephemeral-plus-node-local'"));
  assert.ok(candidateNode.includes('local.consume(action_id,target,challenge,proof)'));
  assert.ok(candidateNode.includes("text='rustdesk.connect:peer:'+target"));
  assert.ok(candidateNode.includes("hashlib.sha256(text.encode('utf-8')).hexdigest()"));
});

test('Stable browser is fixed-source, same-origin and maps only pinned Candidate to Stable wrappers',()=>{
  assert.ok(stableHtml.includes("const SOURCE='RAH-COMMAND-CENTER-V1.5-CANDIDATE.html'"));
  assert.ok(stableHtml.includes("sourceUrl.origin!==window.location.origin"));
  assert.ok(stableHtml.includes('Cross-origin redirect rejected.'));
  assert.ok(stableHtml.includes("replaceAll('rah-command-center-core-v1.5-candidate.js','rah-command-center-core-v1.5.js')"));
  assert.ok(stableHtml.includes("replaceAll('window.RAHCommandCenterLocalProofCandidate','window.RAHCommandCenterCoreV15')"));
  assert.doesNotMatch(stableHtml,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

test('forbidden generic power and persistence remain absent',()=>{
  const sources=[stableNode,candidateNode,rollbackNode,baseNode,stableHtml,rollbackHtml];
  const forbiddenEndpoint=/["']\/(?:shell|exec|command|commands|files|file|remote-control|remote_control)(?:\/|["'?])/i;
  for(const source of sources)assert.doesNotMatch(source,forbiddenEndpoint);
  for(const forbidden of ['shell','generic-command-execution','generic-process-launch','arbitrary-executable-path','arbitrary-arguments','generic-file-api','generic-endpoint-dispatch','generic-approval-endpoint','native-remote-control-api'])assert.ok(contract.forbiddenRuntimePower.includes(forbidden));
  assert.ok(baseNode.includes('subprocess.Popen([path,"--connect",peer_id]'));
  assert.ok(baseNode.includes('"shell":False'));
});

test('direct rollback remains CC 1.4 / Node 0.9 with no migration',()=>{
  assert.equal(rollback.CC_VERSION,'1.4.0');
  assert.equal(rollback.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v4');
  assert.ok(rollbackHtml.includes('CC 1.4 STABLE'));
  assert.ok(rollbackNode.includes("AGENT_VERSION='0.9.0'"));
  assert.equal(stable.DEVICE_STORAGE_KEY,'rah.cc.devices.v1');
  assert.equal(stable.DEVICE_STORAGE_KEY,rollback.DEVICE_STORAGE_KEY);
});

test('master sync cannot silently broaden authority or approval policy',()=>{
  for(const key of ['catalogExpansion','capabilityExpansion','endpointExpansion','tokenPolicyChange','approvalPolicyChange'])assert.equal(contract.masterSyncBoundary[key],'requires-explicit-new-version-and-stable-gate');
  assert.equal(contract.masterSyncBoundary.stableRuntimeMutation,'not-authorized-by-this-contract');
});
