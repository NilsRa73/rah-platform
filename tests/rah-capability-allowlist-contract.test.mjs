import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const contract=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const stable=require('../rah-command-center-core-v1.5.js');
const historicalCc=require('../rah-command-center-core-v1.4.js');
const stableHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.5.html','utf8');
const historicalCcHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.4.html','utf8');
const stableNode=fs.readFileSync('rah-node-agent-v1.1.py','utf8');
const candidateNode=fs.readFileSync('rah-node-agent-v1.1-candidate.py','utf8');
const rollbackNode=fs.readFileSync('rah-node-agent-v1.0.py','utf8');
const promotedV5Node=fs.readFileSync('rah-node-agent-v1.0-candidate.py','utf8');
const baseNode=fs.readFileSync('rah-node-agent.py','utf8');

const capabilities=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('canonical contract pins Stable CC 1.5 / Node Agent 1.1 / Actions v5',()=>{
  assert.equal(contract.schemaVersion,1);
  assert.equal(contract.status,'stable-node-local-approval-proof-requester-source-bound');
  assert.equal(contract.policyId,'rah-capability-allowlist-v1');
  assert.deepEqual(contract.baseline,{ravenVersion:'2.0.32',commandCenterVersion:'1.5.0',nodeAgentVersion:'1.1.0',nodeHealthProtocol:'rah-node-health-v2',nodeActionsProtocol:'rah-node-actions-v5'});
  assert.deepEqual(contract.runtimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.5.html',commandCenterCore:'rah-command-center-core-v1.5.js',nodeAgent:'rah-node-agent-v1.1.py'});
  assert.deepEqual(contract.rollbackRuntimeFiles,{commandCenter:'RAH-COMMAND-CENTER-V1.5.html',commandCenterCore:'rah-command-center-core-v1.5.js',nodeAgent:'rah-node-agent-v1.0.py'});
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
});

test('mutating fixed actions require requester-source-bound Node-local proof without adding authority',()=>{
  const reqs=contract.executionRequirements['mutating-fixed-actions'];
  for(const required of ['ephemeral-local-per-device-action-approval-exists','current-in-memory-bearer-token-is-present','enrolled-node-session-matches-current-agent-session','actions-catalog-policy-id-matches-rah-capability-allowlist-v1','node-local-human-confirmation-is-present','fresh-action-bound-single-use-challenge-is-present','fresh-node-local-single-use-approval-proof-is-present','proof-challenge-action-session-input-digest-pair-matches','requester-source-matches-node-local-approval-pair'])assert.ok(reqs.includes(required),required);
  assert.deepEqual(contract.approvalPolicy.nodeLocalProofRequiredFor,['rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(contract.approvalPolicy.nodeLocalProofNotRequiredFor,['storage-summary.read']);
  assert.deepEqual(contract.approvalPolicy.requesterSourceBindingRequiredFor,['rustdesk.launch','rustdesk.connect']);
  assert.equal(contract.approvalPolicy.requesterSourceOfTruth,'actual-server-socket-peer-ipv4');
  assert.deepEqual(contract.approvalPolicy.requesterSourceAllowedIpv4,['loopback','10.0.0.0/8','172.16.0.0/12','192.168.0.0/16']);
  assert.equal(contract.approvalPolicy.requesterSourceIpv6Allowed,false);
  assert.equal(contract.approvalPolicy.trustForwardedRequesterHeaders,false);
  assert.equal(contract.approvalPolicy.wrongRequesterDoesNotConsumeValidPair,true);
  assert.equal(contract.approvalPolicy.atomicPairPublicationBeforeGrantSignal,true);
  assert.equal(contract.approvalPolicy.requesterSourcePersistence,'in-memory-active-pair-only');
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

test('v5 protocol remains unchanged and old mutating challenge path stays disabled',()=>{
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

test('Node 1.1 Stable wrapper pins atomic requester-source Candidate behavior and Stable identity',()=>{
  assert.ok(stableNode.includes("AGENT_VERSION='1.1.0'"));
  assert.ok(stableNode.includes("CANDIDATE_PATH=Path(__file__).with_name('rah-node-agent-v1.1-candidate.py')"));
  assert.ok(candidateNode.includes("AGENT_VERSION='1.1.0-candidate'"));
  assert.ok(candidateNode.includes('self.client_address[0]'));
  assert.ok(candidateNode.includes("'requesterSource':source"));
  assert.ok(candidateNode.includes("if source!=pair.get('requesterSource'):return 'requester_mismatch'"));
  assert.ok(candidateNode.includes("intent['event'].set()"));
  assert.ok(promotedV5Node.includes("ACTIONS_PROTOCOL='rah-node-actions-v5'"));
  assert.ok(promotedV5Node.includes("ROUTES=('/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk')"));
  assert.ok(promotedV5Node.includes("MUTATING_ACTION_IDS=('rustdesk.launch','rustdesk.connect')"));
});

test('Stable browser remains fixed-source and same-origin',()=>{
  assert.ok(stableHtml.includes("const SOURCE='RAH-COMMAND-CENTER-V1.5-CANDIDATE.html'"));
  assert.ok(stableHtml.includes("sourceUrl.origin!==window.location.origin"));
  assert.ok(stableHtml.includes('Cross-origin redirect rejected.'));
  assert.ok(stableHtml.includes("replaceAll('rah-command-center-core-v1.5-candidate.js','rah-command-center-core-v1.5.js')"));
  assert.ok(stableHtml.includes("replaceAll('window.RAHCommandCenterLocalProofCandidate','window.RAHCommandCenterCoreV15')"));
  assert.doesNotMatch(stableHtml,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

test('forbidden generic power and persistence remain absent',()=>{
  const sources=[stableNode,candidateNode,rollbackNode,promotedV5Node,baseNode,stableHtml,historicalCcHtml];
  const forbiddenEndpoint=/["']\/(?:shell|exec|command|commands|files|file|remote-control|remote_control)(?:\/|["'?])/i;
  for(const source of sources)assert.doesNotMatch(source,forbiddenEndpoint);
  for(const forbidden of ['shell','generic-command-execution','generic-process-launch','arbitrary-executable-path','arbitrary-arguments','generic-file-api','generic-endpoint-dispatch','generic-approval-endpoint','native-remote-control-api'])assert.ok(contract.forbiddenRuntimePower.includes(forbidden));
  assert.ok(baseNode.includes('subprocess.Popen([path,"--connect",peer_id]'));
  assert.ok(baseNode.includes('"shell":False'));
});

test('direct rollback remains CC 1.5 / Node 1.0 with no protocol or registry change',()=>{
  assert.equal(stable.CC_VERSION,'1.5.0');
  assert.ok(rollbackNode.includes("AGENT_VERSION='1.0.0'"));
  assert.ok(rollbackNode.includes("CANDIDATE_PATH=Path(__file__).with_name('rah-node-agent-v1.0-candidate.py')"));
  assert.equal(stable.DEVICE_STORAGE_KEY,'rah.cc.devices.v1');
  assert.equal(contract.rollbackRuntimeFiles.commandCenter,'RAH-COMMAND-CENTER-V1.5.html');
  assert.equal(contract.rollbackRuntimeFiles.commandCenterCore,'rah-command-center-core-v1.5.js');
  assert.equal(contract.rollbackRuntimeFiles.nodeAgent,'rah-node-agent-v1.0.py');
  assert.equal(historicalCc.CC_VERSION,'1.4.0');
});

test('master sync cannot silently broaden authority or approval policy',()=>{
  for(const key of ['catalogExpansion','capabilityExpansion','endpointExpansion','tokenPolicyChange','approvalPolicyChange'])assert.equal(contract.masterSyncBoundary[key],'requires-explicit-new-version-and-stable-gate');
  assert.equal(contract.masterSyncBoundary.stableRuntimeMutation,'not-authorized-by-this-contract');
});