import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const core=require('../rah-command-center-core-v1.7-candidate.js');
const v16=require('../rah-command-center-core-v1.6.js');
const manifest=JSON.parse(fs.readFileSync('RAH-CC17-NODE13-TOKEN-PROOF-CANDIDATE.json','utf8'));
const readiness=JSON.parse(fs.readFileSync('RAH-TOKEN-PROOF-AUTH-CANDIDATE-GATE.json','utf8'));
const html=fs.readFileSync('RAH-COMMAND-CENTER-V1.7-CANDIDATE.html','utf8');
function gitBlobSha(path){const body=fs.readFileSync(path);return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex')}
function verify(ref){assert.equal(gitBlobSha(ref.path),ref.gitBlobSha,`${ref.path} blob drifted`)}
const session='SessionId_abcdefghijklmnop';
const nonce='Nonce_abcdefghijklmnopqrstuvwxyz123456';
const context='RequesterContext_abcdefghijklmnopqrstuvwxyz1234567890';
const challenge='Challenge_abcdefghijklmnopqrstu';
const localProof='LocalProof_abcdefghijklmnopqrstuv';
const empty=core.EMPTY_SHA256;
const bodySha=crypto.createHash('sha256').update('{"peerId":"123456789"}').digest('hex');

test('Candidate pins readiness, Stable, research and exact runtime blobs',()=>{
  assert.equal(manifest.stage,'feature-candidate');assert.equal(manifest.authorityDelta,'none');verify(manifest.readiness);verify(manifest.sourceStable.stableRelease);verify(manifest.research);for(const ref of [manifest.runtime.commandCenterCore,manifest.runtime.commandCenterHtml,manifest.runtime.nodeAgent])verify(ref);
  assert.equal(readiness.runtimeMutationAuthorized,true);assert.deepEqual(readiness.authorizedCandidateFiles,['rah-command-center-core-v1.7-candidate.js','RAH-COMMAND-CENTER-V1.7-CANDIDATE.html','rah-node-agent-v1.3-candidate.py']);
});

test('Candidate identity advances only auth/actions protocols',()=>{
  assert.equal(core.CC_VERSION,'1.7.0-candidate');assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v7');assert.equal(core.NODE_AUTH_PROTOCOL,'rah-node-auth-v2');assert.equal(core.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');assert.equal(core.AUTH_NONCE_TTL_SECONDS,30);
  assert.deepEqual([...core.CAPABILITY_IDS],manifest.authoritySurface.capabilities);assert.deepEqual([...core.ACTION_IDS],manifest.authoritySurface.actions);assert.deepEqual([...core.AUTHENTICATED_PATHS],manifest.authoritySurface.businessRoutes);assert.deepEqual(manifest.authoritySurface.newBusinessRoutes,[]);
});

test('auth challenge is challenge-only, exact-key and session-bound',()=>{
  const payload={protocol:'rah-node-auth-v2',status:'challenge',sessionId:session,nonce,nonceTtlSeconds:30};assert.deepEqual(core.sanitizeAuthChallenge(payload,session),payload);assert.equal(core.sanitizeAuthChallenge({...payload,hostname:'secret'},session),null);assert.equal(core.sanitizeAuthChallenge({...payload,sessionId:'SessionId_qrstuvwxyz123456'},session),null);assert.equal(core.sanitizeAuthChallenge({...payload,nonceTtlSeconds:31},session),null);
});

test('canonical proof grammar covers exact fixed request semantics',()=>{
  const health=core.buildAuthCanonical(session,nonce,'GET','/health',empty,{});assert.ok(health);assert.equal(health.split('\n').length,11);
  const normalActions=core.buildAuthCanonical(session,nonce,'GET','/actions',empty,{});assert.ok(normalActions);
  const intent=core.buildAuthCanonical(session,nonce,'GET','/actions',empty,{[core.APPROVAL_ACTION_HEADER]:'rustdesk.launch',[core.REQUESTER_CONTEXT_HEADER]:context});assert.ok(intent);
  const storage=core.buildAuthCanonical(session,nonce,'GET','/storage',empty,{[core.ACTION_CHALLENGE_HEADER]:challenge});assert.ok(storage);
  const launch=core.buildAuthCanonical(session,nonce,'POST','/launch/rustdesk',empty,{[core.REQUESTER_CONTEXT_HEADER]:context,[core.ACTION_CHALLENGE_HEADER]:challenge,[core.LOCAL_APPROVAL_HEADER]:localProof});assert.ok(launch);
  const handoff=core.buildAuthCanonical(session,nonce,'POST','/handoff/rustdesk',bodySha,{[core.REQUESTER_CONTEXT_HEADER]:context,[core.ACTION_CHALLENGE_HEADER]:challenge,[core.LOCAL_APPROVAL_HEADER]:localProof});assert.ok(handoff);
});

test('canonical grammar rejects query, misplaced context, unknown header and body/method tamper',()=>{
  assert.equal(core.buildAuthCanonical(session,nonce,'GET','/health?x=1',empty,{}),'');assert.equal(core.buildAuthCanonical(session,nonce,'POST','/health',empty,{}),'');assert.equal(core.buildAuthCanonical(session,nonce,'GET','/health',empty,{[core.REQUESTER_CONTEXT_HEADER]:context}),'');assert.equal(core.buildAuthCanonical(session,nonce,'GET','/storage',empty,{[core.ACTION_CHALLENGE_HEADER]:challenge,[core.REQUESTER_CONTEXT_HEADER]:context}),'');assert.equal(core.buildAuthCanonical(session,nonce,'POST','/launch/rustdesk',bodySha,{[core.REQUESTER_CONTEXT_HEADER]:context,[core.ACTION_CHALLENGE_HEADER]:challenge,[core.LOCAL_APPROVAL_HEADER]:localProof}),'');assert.equal(core.buildAuthCanonical(session,nonce,'GET','/health',empty,{'X-Random':'x'}),'');
});

test('request builders expose exact path and attach proof without Authorization',()=>{
  const init=core.nodeAuthInitRequest('192.168.1.44');assert.deepEqual(init.headers,{[core.AUTH_INIT_HEADER]:'1'});assert.equal(init.path,'/health');
  const req=core.nodeHealthRequest('192.168.1.44'),signed=core.attachAuthProof(req,nonce,'Proof_abcdefghijklmnopqrstuvwxyz1234567890');assert.ok(signed);assert.equal(signed.headers[core.AUTH_NONCE_HEADER],nonce);assert.ok(signed.headers[core.AUTH_PROOF_HEADER]);assert.equal(Object.hasOwn(signed.headers,'Authorization'),false);
});

test('v7 catalog rejects v6 and v16 Stable rejects v7',()=>{
  const row=id=>({...core.ACTION_CATALOG[id],...(core.ACTION_CATALOG[id].mutating?{localApprovalRequired:true}:{})});const caps=['storage','remote-desktop'];const v7={protocol:'rah-node-actions-v7',status:'ready',policyId:'rah-capability-allowlist-v1',approvalMode:'command-center-ephemeral-plus-node-local',sessionId:session,actions:[row('storage-summary.read'),row('rustdesk.launch'),row('rustdesk.connect')]};const v6={...v7,protocol:'rah-node-actions-v6'};
  assert.ok(core.sanitizeActionCatalog(v7,caps,session));assert.equal(core.sanitizeActionCatalog(v6,caps,session),null);assert.equal(v16.sanitizeActionCatalog(v7,caps,session),null);assert.ok(v16.sanitizeActionCatalog(v6,caps,session));
});

test('browser uses WebCrypto and protected requests never construct Bearer transport',()=>{
  assert.match(html,/crypto\.subtle\.importKey/);assert.match(html,/crypto\.subtle\.sign/);assert.match(html,/crypto\.subtle\.digest/);assert.match(html,/nodeAuthInitRequest/);assert.match(html,/buildAuthCanonicalFromRequest/);assert.match(html,/attachAuthProof/);assert.match(html,/checkNodeBtn'\)\.onclick=checkNodeV7/);assert.match(html,/Legacy bearer transport disabled/);
  assert.doesNotMatch(html,/Authorization\s*:\s*['"]Bearer/i);assert.doesNotMatch(html,/['"]Authorization['"]\s*:\s*['"]Bearer/i);assert.doesNotMatch(html,/headers\s*=\s*\{\s*Authorization/i);
});

test('browser keeps token, nonce, proof, requester context and peer ID out of storage',()=>{
  for(const secret of ['actionToken','handoffToken','nodeToken','AUTH_NONCE_HEADER','AUTH_PROOF_HEADER','requesterContext','peerId'])assert.doesNotMatch(html,new RegExp(`localStorage\\.setItem\\([^)]*${secret}`,'i'),secret);
  assert.doesNotMatch(html,/sessionStorage\.setItem\([^)]*(?:token|nonce|proof|requesterContext|peerId)/i);
});

test('Candidate manifest forbids root/Stable authority expansion and bearer fallback',()=>{
  for(const item of ['stable-runtime-mutation','canonical-root-package-mutation','raven-master-metadata-mutation','new-business-route','new-capability','new-action','bearer-token-network-transport','bearer-fallback','network-token-renewal-endpoint','shell','generic-command-execution','generic-process-launch','generic-file-api','native-raven-remote-control-api'])assert.ok(manifest.forbidden.includes(item),item);
  assert.equal(manifest.auth.tokenNetworkTransport,false);assert.equal(manifest.auth.authorizationHeaderRejected,true);assert.equal(manifest.auth.bearerFallback,false);assert.equal(manifest.auth.proofBeforeActionOrPairConsumption,true);assert.equal(manifest.auth.handoffBodyReadOnce,true);
});
