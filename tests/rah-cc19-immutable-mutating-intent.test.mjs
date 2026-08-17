import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const core=require('../rah-command-center-core-v1.9-candidate.js');
const manifest=JSON.parse(fs.readFileSync('RAH-CC19-IMMUTABLE-MUTATING-INTENT-CANDIDATE.json','utf8'));
const canonical=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const coreSource=fs.readFileSync('rah-command-center-core-v1.9-candidate.js','utf8');
const html=()=>fs.readFileSync('RAH-COMMAND-CENTER-V1.9-CANDIDATE.html','utf8');
const peerDigest='b'.repeat(64);

function record(overrides={}){
  return {
    id:'main-pc',label:'Main PC',role:'Command Center host',kind:'desktop',status:'unverified',source:'local',
    enrolled:true,endpointIp:'192.168.1.25',agentHostname:'main',agentVersion:'1.3.0',agentProtocol:'rah-node-health-v2',
    agentSessionId:'Abcdefghijklmnopqrstuvwx1234',platform:'Windows 11',
    capabilities:['remote-desktop'],permissions:{},
    advertisedActions:['rustdesk.launch','rustdesk.connect'],approvedActions:['rustdesk.launch','rustdesk.connect'],
    remoteControlEnabled:false,commandsEnabled:false,...overrides
  };
}
function newLedger(id='A'.repeat(32),now=()=>1000){return new core.IntentBoundMutatingApprovalLedger({idFactory:()=>id,now})}

test('Candidate identity and authority remain unchanged',()=>{
  assert.equal(core.CC_VERSION,'1.9.0-candidate');
  assert.equal(core.MUTATING_INTENT_BINDING_VERSION,'rah-cc-mutating-intent-v1');
  assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v7');
  assert.equal(core.NODE_AUTH_PROTOCOL,'rah-node-auth-v2');
  assert.deepEqual(core.CAPABILITY_IDS,['compute','storage','display','remote-desktop']);
  assert.deepEqual(core.ACTION_IDS,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.equal(manifest.authorityDelta,'none');
  assert.deepEqual(manifest.authoritySurface.newCapabilities,[]);
  assert.deepEqual(manifest.authoritySurface.newActions,[]);
  assert.deepEqual(manifest.authoritySurface.newBusinessRoutes,[]);
  assert.equal(manifest.runtime.nodeRuntimeChange,false);
  assert.equal(canonical.version,'1.8.0');
  assert.equal(canonical.stage,'stable');
});

test('mutating intent binds endpoint protocols policy capability and authority snapshots',()=>{
  const b=core.mutatingIntentBinding(record(),'rustdesk.connect',peerDigest);
  assert.ok(b);
  assert.equal(b.deviceId,'main-pc');
  assert.equal(b.endpointIp,'192.168.1.25');
  assert.equal(b.agentSessionId,'Abcdefghijklmnopqrstuvwx1234');
  assert.equal(b.policyId,'rah-capability-allowlist-v1');
  assert.equal(b.nodeHealthProtocol,'rah-node-health-v2');
  assert.equal(b.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(b.nodeAuthProtocol,'rah-node-auth-v2');
  assert.equal(b.actionId,'rustdesk.connect');
  assert.equal(b.requiredCapability,'remote-desktop');
  assert.deepEqual(b.capabilities,['remote-desktop']);
  assert.deepEqual(b.advertisedActions,['rustdesk.connect','rustdesk.launch']);
  assert.deepEqual(b.approvedActions,['rustdesk.connect','rustdesk.launch']);
  assert.equal(b.targetDigest,peerDigest);
});

test('ticket remains one-shot memory-only and stores no raw target',()=>{
  const l=newLedger();
  const t=l.approve(record(),'rustdesk.connect',peerDigest);
  assert.ok(t);
  assert.equal(t.endpointIp,'192.168.1.25');
  assert.equal(t.targetDigest,peerDigest);
  assert.doesNotMatch(JSON.stringify(t),/123456789|peerId|rawTarget/i);
  const snap=l.snapshot();
  assert.equal(snap.outstandingCount,1);
  assert.equal(snap.endpointBound,true);
  assert.equal(snap.authoritySnapshotBound,true);
  assert.equal(snap.rawTargetsStored,false);
  assert.equal(snap.persistent,false);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',peerDigest),true);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',peerDigest),false);
});

test('endpoint change consumes and rejects ticket even with same device and Node session',()=>{
  const l=newLedger();const t=l.approve(record(),'rustdesk.connect',peerDigest);assert.ok(t);
  const moved=record({endpointIp:'192.168.1.26'});
  assert.equal(core.canExecuteAction(moved,'rustdesk.connect'),true);
  assert.equal(l.consume(t.approvalId,moved,'rustdesk.connect',peerDigest),false);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',peerDigest),false);
});

test('capability snapshot drift consumes and rejects ticket',()=>{
  const l=newLedger();const t=l.approve(record(),'rustdesk.connect',peerDigest);assert.ok(t);
  const changed=record({capabilities:['remote-desktop','display']});
  assert.equal(core.canExecuteAction(changed,'rustdesk.connect'),true);
  assert.equal(l.consume(t.approvalId,changed,'rustdesk.connect',peerDigest),false);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',peerDigest),false);
});

test('advertised action snapshot drift consumes and rejects ticket',()=>{
  const l=newLedger();const t=l.approve(record(),'rustdesk.connect',peerDigest);assert.ok(t);
  const changed=record({advertisedActions:['rustdesk.launch','rustdesk.connect','storage-summary.read']});
  assert.equal(core.canExecuteAction(changed,'rustdesk.connect'),true);
  assert.equal(l.consume(t.approvalId,changed,'rustdesk.connect',peerDigest),false);
});

test('approved action snapshot drift consumes and rejects ticket',()=>{
  const l=newLedger();const t=l.approve(record(),'rustdesk.connect',peerDigest);assert.ok(t);
  const changed=record({approvedActions:['rustdesk.connect']});
  assert.equal(core.canExecuteAction(changed,'rustdesk.connect'),true);
  assert.equal(l.consume(t.approvalId,changed,'rustdesk.connect',peerDigest),false);
});

test('target mismatch remains fail-closed and consumed',()=>{
  const l=newLedger();const t=l.approve(record(),'rustdesk.connect',peerDigest);assert.ok(t);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect','c'.repeat(64)),false);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',peerDigest),false);
});

test('launch retains exact empty-target digest and storage cannot enter mutating ledger',()=>{
  const l=newLedger('D'.repeat(32));
  const t=l.approve(record(),'rustdesk.launch',core.EMPTY_TARGET_DIGEST);assert.ok(t);
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.launch',core.EMPTY_TARGET_DIGEST),true);
  const storage=record({capabilities:['storage'],advertisedActions:['storage-summary.read'],approvedActions:['storage-summary.read']});
  assert.equal(l.approve(storage,'storage-summary.read',core.EMPTY_TARGET_DIGEST),null);
});

test('TTL and maximum outstanding remain bounded by v1.8 Stable constants',()=>{
  let now=1000;const l=newLedger('E'.repeat(32),()=>now);
  const t=l.approve(record(),'rustdesk.connect',peerDigest);assert.ok(t);
  assert.equal(t.expiresAt-t.approvedAt,90000);
  now=91001;
  assert.equal(l.consume(t.approvalId,record(),'rustdesk.connect',peerDigest),false);
  assert.equal(l.snapshot().ttlMs,90000);
  assert.equal(l.snapshot().maxOutstanding,32);
});

test('security ID generation has no Math.random fallback',()=>{
  assert.doesNotMatch(coreSource,/Math\.random/);
  assert.match(coreSource,/cryptoObj\.getRandomValues/);
  assert.equal(manifest.mutatingIntentBinding.secureRandomRequired,true);
  assert.equal(manifest.mutatingIntentBinding.mathRandomFallback,false);
});

test('Candidate UI uses intent-bound ledger and consumes before Node-local confirmation',()=>{
  const s=html();
  assert.match(s,/RAH Raven Command Center v1\.9 Candidate/);
  assert.match(s,/rah-command-center-core-v1\.9-candidate\.js/);
  assert.match(s,/RAHCommandCenterIntentBindingCandidate/);
  assert.match(s,/new core\.IntentBoundMutatingApprovalLedger\(\)/);
  assert.match(s,/endpoint \+ authority snapshot/i);
  const consume=s.indexOf('ledger.consume('),intent=s.indexOf('core.localApprovalIntentRequest(');
  assert.ok(consume>=0&&intent>consume,'intent-bound ticket must be consumed before Node-local confirmation request');
  assert.doesNotMatch(s,/JSON\.stringify\(ledger|localStorage\.setItem\([^\n]*ticket|sessionStorage\.setItem\([^\n]*ticket/i);
});

test('Candidate contract keeps persistence and generic authority disabled',()=>{
  const b=manifest.mutatingIntentBinding;
  assert.equal(b.memoryOnly,true);assert.equal(b.persistent,false);assert.equal(b.singleUse,true);assert.equal(b.consumeBeforeNodeLocalConfirmation,true);assert.equal(b.consumeOnMismatch,true);
  assert.equal(b.bindsEndpointIpv4,true);assert.equal(b.bindsCapabilitySnapshot,true);assert.equal(b.bindsAdvertisedActionSnapshot,true);assert.equal(b.bindsApprovedActionSnapshot,true);assert.equal(b.storesRawTarget,false);
  for(const forbidden of ['shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','native-raven-remote-control-api'])assert.ok(manifest.forbidden.includes(forbidden),forbidden);
});
