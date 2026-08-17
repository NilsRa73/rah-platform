import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const core=require('../rah-command-center-core-v1.6.1.js');
const coreSource=fs.readFileSync('rah-command-center-core-v1.6.1.js','utf8');
const html=fs.readFileSync('RAH-COMMAND-CENTER-V1.6.1.html','utf8');
const promotedHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.6-PROMOTED.html','utf8');

const context='RequesterContext_abcdefghijklmnopqrstuvwxyz1234567890';
const session='ABCDEFGHIJKLMNOPQRSTUVWX';
const caps=['storage','remote-desktop'];
const record={id:'n',enrolled:true,endpointIp:'127.0.0.1',agentSessionId:session,capabilities:caps,advertisedActions:['storage-summary.read','rustdesk.launch','rustdesk.connect'],approvedActions:['rustdesk.launch','rustdesk.connect'],permissions:{storageRead:true,displayRead:false,remoteDesktopHandoff:true,commands:false,files:false,remoteControl:false}};

test('patch identity keeps v6 policy and exact fixed authority',()=>{
  assert.equal(core.CC_VERSION,'1.6.1');
  assert.equal(core.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v6');
  assert.equal(core.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
  assert.equal(core.REQUESTER_CONTEXT_HEADER,'X-RAH-Requester-Context');
  assert.deepEqual([...core.CAPABILITY_IDS],['compute','storage','display','remote-desktop']);
  assert.deepEqual([...core.ACTION_IDS],['storage-summary.read','rustdesk.launch','rustdesk.connect']);
});

test('patch core imports promoted implementation, never current Candidate path',()=>{
  assert.match(coreSource,/require\('\.\/rah-command-center-core-v1\.6-promoted\.js'\)/);
  assert.doesNotMatch(coreSource,/require\('\.\/rah-command-center-core-v1\.6-candidate\.js'\)/);
});

test('patch browser fetches promoted HTML and injects promoted plus patch core',()=>{
  assert.ok(html.includes("const SOURCE='RAH-COMMAND-CENTER-V1.6-PROMOTED.html'"));
  assert.ok(html.includes('rah-command-center-core-v1.6-promoted.js'));
  assert.ok(html.includes('rah-command-center-core-v1.6.1.js'));
  assert.ok(html.includes('window.RAHCommandCenterCoreV161'));
  assert.ok(html.includes('sourceUrl.origin!==window.location.origin'));
  assert.ok(html.includes('Cross-origin redirect rejected.'));
  assert.ok(promotedHtml.includes('rah-command-center-core-v1.6-candidate.js'));
  assert.ok(html.includes('PROMOTED_MARKER'));
});

test('mutating request builders preserve one fixed context header and typed peer body',()=>{
  const launchGrant={actionId:'rustdesk.launch',challenge:'challenge-AAAAAAAAAAAA',challengeTtlSeconds:30,localApprovalProof:'proof-BBBBBBBBBBBBBBBB',localApprovalProofTtlSeconds:30};
  const launch=core.actionExecutionRequest(record,'rustdesk.launch',launchGrant,context);
  assert.ok(launch);assert.deepEqual(Object.keys(launch.headers).sort(),[core.ACTION_CHALLENGE_HEADER,core.LOCAL_APPROVAL_HEADER,core.REQUESTER_CONTEXT_HEADER].sort());
  const connectRecord={...record,approvedActions:['rustdesk.connect']};
  const connectGrant={actionId:'rustdesk.connect',challenge:'challenge-CCCCCCCCCCCC',challengeTtlSeconds:30,localApprovalProof:'proof-DDDDDDDDDDDDDDDD',localApprovalProofTtlSeconds:30};
  const handoff=core.rustDeskHandoffRequest(connectRecord,'123456789',connectGrant,context);
  assert.ok(handoff);assert.deepEqual(handoff.body,{peerId:'123456789'});assert.deepEqual(Object.keys(handoff.headers).sort(),[core.ACTION_CHALLENGE_HEADER,core.LOCAL_APPROVAL_HEADER,core.REQUESTER_CONTEXT_HEADER].sort());
});

test('storage request remains requester-context free',()=>{
  const storageRecord={...record,approvedActions:['storage-summary.read']};
  const req=core.actionExecutionRequest(storageRecord,'storage-summary.read','storage-challenge-AAAAAAAA');
  assert.ok(req);assert.deepEqual(Object.keys(req.headers),[core.ACTION_CHALLENGE_HEADER]);
  assert.equal(core.actionExecutionRequest(storageRecord,'storage-summary.read','storage-challenge-AAAAAAAA',context),null);
});
