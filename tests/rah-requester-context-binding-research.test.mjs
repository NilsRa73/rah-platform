import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {
  RequesterContextResearchModel,CAPABILITIES,ACTIONS,MUTATING_ACTIONS,ROUTES,
  REQUESTER_CONTEXT_HEADER,RESEARCH_PROTOCOL,POLICY_ID,
  validRequesterContext,requesterContextDigest,normalizeRequesterSource
} from '../research/rah-requester-context-binding-model.mjs';

const contract=JSON.parse(fs.readFileSync('RAH-REQUESTER-CONTEXT-BINDING-RESEARCH.json','utf8'));
const threat=fs.readFileSync('RAH-REQUESTER-CONTEXT-BINDING-THREAT-MODEL.md','utf8');
const sessionId='ABCDEFGHIJKLMNOPQRSTUVWX';
const contextA='A'.repeat(40);
const contextB='B'.repeat(40);

function sequence(values){let i=0;return()=>values[i++]||`fallback-${i}-ABCDEFGHIJKLMNOPQRSTUVWXYZ`;}
function model(values=['request-AAAAAAAAAAAAAAAAAAAA','challenge-BBBBBBBBBBBBBBBBBBBB','proof-CCCCCCCCCCCCCCCCCCCCCCCC']){
  return new RequesterContextResearchModel({sessionId,clock:()=>100,random:sequence(values),ttlSeconds:30});
}
function approve(m,{actionId='rustdesk.launch',target='',source='192.168.1.20',context=contextA}={}){
  const intent=m.requestIntent({actionId,target,requesterSource:source,requesterContext:context});
  assert.equal(intent.ok,true);
  const result=m.confirmLocal({requestId:intent.localPrompt.requestId,approved:true});
  assert.equal(result.ok,true);
  return result.grant;
}

test('research is runtime-neutral and preserves exact Stable 4/3/5 authority',()=>{
  assert.equal(contract.stage,'research-only');
  assert.equal(contract.authorityDelta,'none');
  assert.equal(contract.runtimeMutationAuthorized,false);
  assert.deepEqual(contract.authoritySurface.capabilities,[...CAPABILITIES]);
  assert.deepEqual(contract.authoritySurface.actions,[...ACTIONS]);
  assert.deepEqual(contract.authoritySurface.routes,[...ROUTES]);
  assert.deepEqual([...MUTATING_ACTIONS],['rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(contract.sourceStable,{ravenVersion:'2.0.32',commandCenterVersion:'1.5.0',nodeAgentVersion:'1.1.0',nodeActionsProtocol:'rah-node-actions-v5',policyId:'rah-capability-allowlist-v1'});
});

test('proposed grammar is one fixed context header and explicit Actions v6 Candidate boundary',()=>{
  assert.equal(REQUESTER_CONTEXT_HEADER,'X-RAH-Requester-Context');
  assert.equal(RESEARCH_PROTOCOL,'rah-node-actions-v6');
  assert.equal(POLICY_ID,'rah-capability-allowlist-v1');
  assert.equal(contract.researchProtocolGrammar.newFixedHeader,REQUESTER_CONTEXT_HEADER);
  assert.equal(contract.researchProtocolGrammar.genericMetadataMap,false);
  assert.equal(contract.researchProtocolGrammar.genericHeaderName,false);
  assert.equal(contract.researchProtocolGrammar.protocolVersionChangeRequiredIfImplemented,true);
  assert.equal(contract.hypotheticalCandidate.nodeActionsProtocol,'rah-node-actions-v6');
});

test('requester context format is narrow and digest never equals raw context',()=>{
  assert.equal(validRequesterContext(contextA),true);
  assert.equal(validRequesterContext('short'),false);
  assert.equal(validRequesterContext('!'.repeat(40)),false);
  const digest=requesterContextDigest(contextA);
  assert.match(digest,/^[0-9a-f]{64}$/);
  assert.notEqual(digest,contextA);
  assert.equal(normalizeRequesterSource('127.0.0.1'),'127.0.0.1');
  assert.equal(normalizeRequesterSource('10.1.2.3'),'10.1.2.3');
  assert.equal(normalizeRequesterSource('172.31.2.3'),'172.31.2.3');
  assert.equal(normalizeRequesterSource('192.168.2.3'),'192.168.2.3');
  assert.equal(normalizeRequesterSource('8.8.8.8'),'');
  assert.equal(normalizeRequesterSource('::1'),'');
});

test('correct requester source plus context consumes approved pair exactly once',()=>{
  const m=model();
  const grant=approve(m);
  assert.equal(m.consume({actionId:'rustdesk.launch',requesterSource:'192.168.1.20',requesterContext:contextA,challenge:grant.challenge,proof:grant.localApprovalProof}),'ok');
  assert.equal(m.consume({actionId:'rustdesk.launch',requesterSource:'192.168.1.20',requesterContext:contextA,challenge:grant.challenge,proof:grant.localApprovalProof}),'missing');
});

test('same source with wrong context fails without consuming pair for correct context',()=>{
  const m=model();
  const grant=approve(m);
  assert.equal(m.consume({actionId:'rustdesk.launch',requesterSource:'192.168.1.20',requesterContext:contextB,challenge:grant.challenge,proof:grant.localApprovalProof}),'requester_context_mismatch');
  assert.equal(m.consume({actionId:'rustdesk.launch',requesterSource:'192.168.1.20',requesterContext:contextA,challenge:grant.challenge,proof:grant.localApprovalProof}),'ok');
});

test('wrong source remains an independent fail-closed gate and does not consume correct pair',()=>{
  const m=model();
  const grant=approve(m);
  assert.equal(m.consume({actionId:'rustdesk.launch',requesterSource:'192.168.1.21',requesterContext:contextA,challenge:grant.challenge,proof:grant.localApprovalProof}),'requester_source_mismatch');
  assert.equal(m.consume({actionId:'rustdesk.launch',requesterSource:'192.168.1.20',requesterContext:contextA,challenge:grant.challenge,proof:grant.localApprovalProof}),'ok');
});

test('fixed action, capability, policy, protocol, source and context are checked before local confirmation',()=>{
  const m=model();
  assert.equal(m.requestIntent({actionId:'shell',requesterSource:'192.168.1.20',requesterContext:contextA}).error,'mutating_fixed_action_required');
  assert.equal(m.requestIntent({actionId:'rustdesk.launch',requesterSource:'192.168.1.20',requesterContext:contextA,advertisedActions:['storage-summary.read']}).error,'action_not_advertised');
  assert.equal(m.requestIntent({actionId:'rustdesk.launch',requesterSource:'192.168.1.20',requesterContext:contextA,capabilities:['storage']}).error,'remote_desktop_capability_not_enabled');
  assert.equal(m.requestIntent({actionId:'rustdesk.launch',requesterSource:'8.8.8.8',requesterContext:contextA}).error,'requester_source_not_allowed');
  assert.equal(m.requestIntent({actionId:'rustdesk.launch',requesterSource:'192.168.1.20',requesterContext:'short'}).error,'requester_context_invalid');
  assert.equal(m.requestIntent({actionId:'rustdesk.launch',requesterSource:'192.168.1.20',requesterContext:contextA,policyId:'wrong'}).error,'policy_mismatch');
  assert.equal(m.requestIntent({actionId:'rustdesk.launch',requesterSource:'192.168.1.20',requesterContext:contextA,protocol:'rah-node-actions-v5'}).error,'protocol_mismatch');
});

test('snapshot contains only context digest and never raw context, challenge, proof or peer target',()=>{
  const m=model();
  const grant=approve(m,{actionId:'rustdesk.connect',target:'123456789',source:'10.0.0.42',context:contextA});
  const snap=JSON.stringify(m.snapshot());
  assert.ok(snap.includes(requesterContextDigest(contextA)));
  assert.ok(!snap.includes(contextA));
  assert.ok(!snap.includes(grant.challenge));
  assert.ok(!snap.includes(grant.localApprovalProof));
  assert.ok(!snap.includes('123456789'));
  assert.match(threat,/not a new authentication system/i);
  assert.equal(contract.securityClaims.uniqueClientIdentity,false);
  assert.equal(contract.securityClaims.authenticationReplacement,false);
  assert.equal(contract.securityClaims.transportSecurityReplacement,false);
  assert.equal(contract.securityClaims.protectsWhenAttackerCanReadCommandCenterMemory,false);
  assert.equal(contract.securityClaims.protectsWhenAttackerCanObserveAllTransientSecrets,false);
});
