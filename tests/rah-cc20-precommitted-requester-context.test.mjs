import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const core=require('../rah-command-center-core-v2.0-candidate.js');
const manifest=JSON.parse(fs.readFileSync('RAH-CC20-PRECOMMITTED-REQUESTER-CONTEXT-CANDIDATE.json','utf8'));
const canonical=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const source=fs.readFileSync('rah-command-center-core-v2.0-candidate.js','utf8');
const ui=()=>fs.readFileSync('RAH-COMMAND-CENTER-V2.0-CANDIDATE.html','utf8');
const targetDigest='b'.repeat(64),contextDigest='c'.repeat(64),otherContextDigest='d'.repeat(64);

function record(overrides={}){return {id:'main-pc',label:'Main PC',role:'Command Center host',kind:'desktop',status:'unverified',source:'local',enrolled:true,endpointIp:'192.168.1.25',agentHostname:'main',agentVersion:'1.3.0',agentProtocol:'rah-node-health-v2',agentSessionId:'Abcdefghijklmnopqrstuvwx1234',platform:'Windows 11',capabilities:['remote-desktop'],permissions:{},advertisedActions:['rustdesk.launch','rustdesk.connect'],approvedActions:['rustdesk.launch','rustdesk.connect'],remoteControlEnabled:false,commandsEnabled:false,...overrides}}
function ledger(id='A'.repeat(32),now=()=>1000){return new core.PrecommittedRequesterContextLedger({idFactory:()=>id,now})}

test('Candidate identity and authority remain unchanged',()=>{
  assert.equal(core.CC_VERSION,'2.0.0-candidate');
  assert.equal(core.PRECOMMITTED_REQUESTER_CONTEXT_VERSION,'rah-cc-precommitted-requester-context-v1');
  assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v7');
  assert.equal(core.NODE_AUTH_PROTOCOL,'rah-node-auth-v2');
  assert.deepEqual(core.CAPABILITY_IDS,['compute','storage','display','remote-desktop']);
  assert.deepEqual(core.ACTION_IDS,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.equal(manifest.authorityDelta,'none');
  assert.deepEqual(manifest.authoritySurface.newCapabilities,[]);
  assert.deepEqual(manifest.authoritySurface.newActions,[]);
  assert.deepEqual(manifest.authoritySurface.newBusinessRoutes,[]);
  assert.equal(manifest.runtime.nodeRuntimeChange,false);
  assert.equal(canonical.product,'RAH Raven Command Center');
  assert.equal(canonical.stage,'stable');
  assert.equal(canonical.raven_contract,'2.0.32');
  assert.equal(canonical.node_agent.agent_version,'1.3.0');
});

test('precommitted binding retains immutable intent and adds requester-context digest',()=>{
  const b=core.precommittedRequesterContextBinding(record(),'rustdesk.connect',targetDigest,contextDigest);
  assert.ok(b);
  assert.equal(b.bindingVersion,'rah-cc-mutating-intent-v1');
  assert.equal(b.contextBindingVersion,'rah-cc-precommitted-requester-context-v1');
  assert.equal(b.endpointIp,'192.168.1.25');
  assert.equal(b.agentSessionId,'Abcdefghijklmnopqrstuvwx1234');
  assert.equal(b.actionId,'rustdesk.connect');
  assert.equal(b.targetDigest,targetDigest);
  assert.equal(b.requesterContextDigest,contextDigest);
  assert.deepEqual(b.capabilities,['remote-desktop']);
  assert.deepEqual(b.advertisedActions,['rustdesk.connect','rustdesk.launch']);
  assert.deepEqual(b.approvedActions,['rustdesk.connect','rustdesk.launch']);
});

test('ticket is memory-only single-use and stores digest not raw requester context',()=>{
  const l=ledger();
  const t=l.approve(record(),'rustdesk.connect',targetDigest,contextDigest);assert.ok(t);
  assert.equal(t.requesterContextDigest,contextDigest);
  assert.doesNotMatch(JSON.stringify(t),/actualRequesterContext|rawRequesterContext|ctx-secret/i);
  const snap=l.snapshot();
  assert.equal(snap.requesterContextDigestBound,true);
  assert.equal(snap.rawRequesterContextsStored,false);
  assert.equal(snap.persistent,false);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',targetDigest,contextDigest),true);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',targetDigest,contextDigest),false);
});

test('requester-context digest mismatch consumes and rejects ticket',()=>{
  const l=ledger();const t=l.approve(record(),'rustdesk.connect',targetDigest,contextDigest);assert.ok(t);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',targetDigest,otherContextDigest),false);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',targetDigest,contextDigest),false);
});

test('existing endpoint and authority snapshot drift remains fail-closed',()=>{
  for(const changed of [record({endpointIp:'192.168.1.26'}),record({capabilities:['remote-desktop','display']}),record({approvedActions:['rustdesk.connect']}),record({advertisedActions:['rustdesk.connect']})]){
    const l=ledger('B'.repeat(32));const t=l.approve(record(),'rustdesk.connect',targetDigest,contextDigest);assert.ok(t);
    assert.equal(l.consume(t.approvalId,changed,'rustdesk.connect',targetDigest,contextDigest),false);
  }
});

test('target mismatch remains fail-closed and consumed',()=>{
  const l=ledger();const t=l.approve(record(),'rustdesk.connect',targetDigest,contextDigest);assert.ok(t);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect','e'.repeat(64),contextDigest),false);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',targetDigest,contextDigest),false);
});

test('launch uses empty target digest but still requires precommitted context digest; storage is excluded',()=>{
  const l=ledger('F'.repeat(32));const t=l.approve(record(),'rustdesk.launch',core.EMPTY_TARGET_DIGEST,contextDigest);assert.ok(t);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.launch',core.EMPTY_TARGET_DIGEST,contextDigest),true);
  const storage=record({capabilities:['storage'],advertisedActions:['storage-summary.read'],approvedActions:['storage-summary.read']});
  assert.equal(l.approve(storage,'storage-summary.read',core.EMPTY_TARGET_DIGEST,contextDigest),null);
});

test('TTL and maximum outstanding remain bounded by previous Stable constants',()=>{
  let now=1000;const l=ledger('G'.repeat(32),()=>now);const t=l.approve(record(),'rustdesk.connect',targetDigest,contextDigest);assert.ok(t);
  assert.equal(t.expiresAt-t.approvedAt,90000);now=91001;
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',targetDigest,contextDigest),false);
  assert.equal(l.snapshot().ttlMs,90000);assert.equal(l.snapshot().maxOutstanding,32);
});

test('security IDs have no Math.random fallback',()=>{
  assert.doesNotMatch(source,/Math\.random/);assert.match(source,/cryptoObj\.getRandomValues/);
  assert.equal(manifest.precommittedRequesterContext.secureRandomRequired,true);
  assert.equal(manifest.precommittedRequesterContext.mathRandomFallback,false);
});

test('Candidate UI precommits context at Arm and reuses it after ticket consumption',()=>{
  const s=ui();
  assert.match(s,/RAH Raven Command Center v2\.0 Candidate/);
  assert.match(s,/rah-command-center-core-v2\.0-candidate\.js/);
  assert.match(s,/RAHCommandCenterPrecommittedContextCandidate/);
  assert.match(s,/new core\.PrecommittedRequesterContextLedger\(\)/);
  assert.match(s,/armedRequesterContext/);
  const armStart=s.indexOf('async function arm()'),runStart=s.indexOf('async function runMutating()');
  assert.ok(armStart>=0&&runStart>armStart);
  const armBlock=s.slice(armStart,runStart),runBlock=s.slice(runStart);
  assert.match(armBlock,/const context=newContext\(\)/);
  assert.match(armBlock,/contextDigest=await sha\(context\)/);
  assert.match(armBlock,/ledger\.approve\(d,action,digest,contextDigest\)/);
  assert.match(runBlock,/context=armedRequesterContext/);
  assert.match(runBlock,/contextDigest=await sha\(context\)/);
  assert.match(runBlock,/ledger\.consume\(approvalId,d,action,digest,contextDigest\)/);
  assert.doesNotMatch(runBlock,/context=newContext\(\)/);
  const consume=runBlock.indexOf('ledger.consume('),intent=runBlock.indexOf('core.localApprovalIntentRequest(');
  assert.ok(consume>=0&&intent>consume,'precommitted ticket must be consumed before Node-local confirmation');
});

test('raw requester context is not persisted or embedded in ticket storage',()=>{
  const s=ui();
  assert.doesNotMatch(s,/localStorage\.setItem\([^\n]*armedRequesterContext|sessionStorage\.setItem\([^\n]*armedRequesterContext|JSON\.stringify\([^\n]*armedRequesterContext/i);
  assert.equal(manifest.precommittedRequesterContext.rawRequesterContextMemoryOnly,true);
  assert.equal(manifest.precommittedRequesterContext.rawRequesterContextPersistent,false);
  assert.equal(manifest.precommittedRequesterContext.ticketStoresRequesterContextDigestOnly,true);
  assert.equal(manifest.precommittedRequesterContext.storesRawRequesterContextInTicket,false);
});

test('Candidate keeps generic authority and secret persistence disabled',()=>{
  assert.equal(manifest.precommittedRequesterContext.sameContextUsedForNodeLocalConfirmationAndExecution,true);
  assert.equal(manifest.precommittedRequesterContext.singleUse,true);
  assert.equal(manifest.precommittedRequesterContext.consumeBeforeNodeLocalConfirmation,true);
  assert.equal(manifest.precommittedRequesterContext.consumeOnContextMismatch,true);
  for(const x of ['shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','native-raven-remote-control-api'])assert.ok(manifest.forbidden.includes(x),x);
});
