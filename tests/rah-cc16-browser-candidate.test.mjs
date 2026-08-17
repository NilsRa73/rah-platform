import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const html=fs.readFileSync('RAH-COMMAND-CENTER-V1.6-CANDIDATE.html','utf8');

test('browser Candidate loads only fixed same-origin rollback UI source and versioned cores',()=>{
  assert.ok(html.includes("const SOURCE='RAH-COMMAND-CENTER-V1.2.html'"));
  assert.ok(html.includes("sourceUrl.origin!==window.location.origin"));
  assert.ok(html.includes('Cross-origin redirect rejected.'));
  assert.ok(html.includes('rah-command-center-core-v1.5.js'));
  assert.ok(html.includes('rah-command-center-core-v1.6-candidate.js'));
  assert.ok(html.includes('window.RAHCommandCenterRequesterContextCandidate'));
  assert.doesNotMatch(html,/URLSearchParams|location\.search|location\.hash|prompt\s*\(/);
});

test('requester context is generated with browser CSPRNG for one mutating flow only',()=>{
  assert.ok(html.includes('function newRequesterContextV6()'));
  assert.ok(html.includes('window.crypto.getRandomValues(bytes)'));
  assert.ok(html.includes('new Uint8Array(24)'));
  assert.ok(html.includes("let requesterContext=''"));
  assert.ok(html.includes("finally{requesterContext=''"));
  assert.doesNotMatch(html,/localStorage\.(?:setItem|getItem)\([^\n]*requesterContext/i);
  assert.doesNotMatch(html,/sessionStorage/i);
});

test('v6 HTTP helper allows only the five fixed security headers plus normal authorization/content-type',()=>{
  const marker="allowed=[core.ACTION_CHALLENGE_HEADER,core.LOCAL_APPROVAL_HEADER,core.APPROVAL_ACTION_HEADER,core.APPROVAL_TARGET_HEADER,core.REQUESTER_CONTEXT_HEADER]";
  assert.ok(html.includes(marker));
  assert.ok(html.includes("throw new Error('Invalid fixed v6 request header.')"));
  assert.ok(html.includes("headers={Authorization:'Bearer '+token}"));
});

test('storage flow never creates or passes requester context',()=>{
  assert.ok(html.includes("const challenge=await freshStorageChallengeV6(d,token),req=core.actionExecutionRequest(d,action,challenge)"));
  assert.doesNotMatch(html,/freshStorageChallengeV6\([^)]*requesterContext/);
});

test('RustDesk launch reuses the same ephemeral requester context across approval and execution',()=>{
  assert.ok(html.includes("requesterContext=newRequesterContextV6()"));
  assert.ok(html.includes("freshLocalGrantV6(d,action,token,undefined,requesterContext)"));
  assert.ok(html.includes("core.actionExecutionRequest(d,action,grant,requesterContext)"));
});

test('RustDesk handoff reuses same context and keeps peer ID transient',()=>{
  assert.ok(html.includes("freshLocalGrantV6(d,'rustdesk.connect',token,peerId,requesterContext)"));
  assert.ok(html.includes("core.rustDeskHandoffRequest(d,peerId,grant,requesterContext)"));
  assert.ok(html.includes("document.getElementById('handoffPeerId').value=''"));
  assert.ok(html.includes("document.getElementById('handoffToken').value=''"));
});

test('browser preserves ephemeral approved-action persistence scrub inherited from Stable 1.4+',()=>{
  assert.ok(html.includes('core.persistableDeviceRegistry(loaded)'));
  assert.ok(html.includes('core.persistableDeviceRegistry(devices)'));
});
