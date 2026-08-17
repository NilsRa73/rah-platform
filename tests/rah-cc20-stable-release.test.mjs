import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const release=JSON.parse(fs.readFileSync('RAH-CC20-NODE13-STABLE-RELEASE.json','utf8'));
const candidate=JSON.parse(fs.readFileSync('RAH-CC20-PRECOMMITTED-REQUESTER-CONTEXT-CANDIDATE.json','utf8'));
const stableCore=require('../rah-command-center-core-v2.0.js');
const stableCoreSource=fs.readFileSync('rah-command-center-core-v2.0.js','utf8');
const stableHtml=fs.readFileSync('RAH-COMMAND-CENTER-V2.0.html','utf8');
function blob(path){return execFileSync('git',['rev-parse',`HEAD:${path}`],{encoding:'utf8'}).trim()}

test('Stable v2.0 identity and authority are exact',()=>{
  assert.equal(release.stage,'stable-release');
  assert.equal(release.authorityDelta,'none');
  assert.equal(release.ravenVersion,'2.0.32');
  assert.equal(release.commandCenterVersion,'2.0.0');
  assert.equal(release.nodeAgentVersion,'1.3.0');
  assert.equal(release.nodeHealthProtocol,'rah-node-health-v2');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(release.authProtocol,'rah-node-auth-v2');
  assert.equal(release.policyId,'rah-capability-allowlist-v1');
  assert.equal(release.nodeRuntimeChange,false);
  assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
  assert.deepEqual(release.authoritySurface.newCapabilities,[]);
  assert.deepEqual(release.authoritySurface.newActions,[]);
  assert.deepEqual(release.authoritySurface.newBusinessRoutes,[]);
});

test('Stable and Candidate Git blobs are pinned exactly',()=>{
  for(const row of [release.runtime.commandCenterCore,release.runtime.commandCenterHtml,release.runtime.nodeAgent,release.pinnedCandidate.manifest,release.pinnedCandidate.commandCenterCore,release.pinnedCandidate.commandCenterHtml,release.directRollback.previousStableRelease,release.directRollback.commandCenterCore,release.directRollback.commandCenterHtml,release.directRollback.nodeAgent])assert.equal(blob(row.path),row.gitBlobSha,row.path);
});

test('Stable core is strict wrapper over v2.0 precommitted-context Candidate',()=>{
  assert.equal(stableCore.CC_VERSION,'2.0.0');
  assert.equal(stableCore.PRECOMMITTED_REQUESTER_CONTEXT_VERSION,'rah-cc-precommitted-requester-context-v1');
  assert.equal(stableCore.MUTATING_INTENT_BINDING_VERSION,'rah-cc-mutating-intent-v1');
  assert.match(stableCoreSource,/require\('\.\/rah-command-center-core-v2\.0-candidate\.js'\)/);
  assert.match(stableCoreSource,/candidate\.CC_VERSION!=='2\.0\.0-candidate'/);
  assert.match(stableCoreSource,/candidate\.PRECOMMITTED_REQUESTER_CONTEXT_VERSION!=='rah-cc-precommitted-requester-context-v1'/);
  assert.doesNotMatch(stableCoreSource,/Math\.random|child_process|exec\(/);
});

test('Stable UI loads only same-origin pinned v2.0 Candidate and overlays Stable core',()=>{
  assert.match(stableHtml,/RAH Raven Command Center v2\.0 Stable/);
  assert.match(stableHtml,/const SOURCE='RAH-COMMAND-CENTER-V2\.0-CANDIDATE\.html'/);
  assert.match(stableHtml,/sourceUrl\.origin!==window\.location\.origin/);
  assert.match(stableHtml,/rah-command-center-core-v2\.0-candidate\.js/);
  assert.match(stableHtml,/rah-command-center-core-v2\.0\.js/);
  assert.match(stableHtml,/RAHCommandCenterCoreV20/);
  assert.match(stableHtml,/Cross-origin redirect rejected/);
});

test('precommitted requester context Stable contract is exact and persistence-free',()=>{
  const b=release.precommittedRequesterContext;
  assert.deepEqual(b.requiredActions,['rustdesk.launch','rustdesk.connect']);
  assert.equal(b.readOnlyStorageRequiresContextPrecommit,false);
  assert.equal(b.ttlMs,90000);assert.equal(b.maxOutstanding,32);
  assert.equal(b.generatedAtArm,true);assert.equal(b.secureRandomRequired,true);assert.equal(b.mathRandomFallback,false);
  assert.equal(b.rawRequesterContextMemoryOnly,true);assert.equal(b.rawRequesterContextPersistent,false);
  assert.equal(b.ticketStoresRequesterContextDigestOnly,true);assert.equal(b.bindsRequesterContextDigest,true);
  assert.equal(b.sameContextUsedForNodeLocalConfirmationAndExecution,true);
  assert.equal(b.singleUse,true);assert.equal(b.consumeBeforeNodeLocalConfirmation,true);assert.equal(b.consumeOnContextMismatch,true);
  assert.equal(b.storesRawRequesterContextInTicket,false);
});

test('v1.9 immutable intent binding remains retained underneath v2.0',()=>{
  const b=release.retainedImmutableIntent;
  assert.equal(b.version,'rah-cc-mutating-intent-v1');
  for(const key of ['bindsEndpointIpv4','bindsNodeSession','bindsPolicyId','bindsNodeHealthProtocol','bindsNodeActionsProtocol','bindsNodeAuthProtocol','bindsRequiredCapability','bindsCapabilitySnapshot','bindsAdvertisedActionSnapshot','bindsApprovedActionSnapshot','bindsActionId','bindsTargetDigest'])assert.equal(b[key],true,key);
});

test('Candidate evidence matches Stable precommit contract',()=>{
  const c=candidate.precommittedRequesterContext,s=release.precommittedRequesterContext;
  assert.equal(candidate.commandCenterVersion,'2.0.0-candidate');
  assert.equal(candidate.sourceStableVersion,'1.9.0');
  assert.equal(candidate.runtime.nodeRuntimeChange,false);
  assert.equal(c.version,s.version);
  assert.deepEqual(c.requiredActions,s.requiredActions);
  assert.equal(c.retainsOneShotTtlMs,s.ttlMs);
  assert.equal(c.retainsMaxOutstanding,s.maxOutstanding);
  for(const key of ['generatedAtArm','secureRandomRequired','mathRandomFallback','rawRequesterContextMemoryOnly','rawRequesterContextPersistent','ticketStoresRequesterContextDigestOnly','bindsRequesterContextDigest','sameContextUsedForNodeLocalConfirmationAndExecution','singleUse','consumeBeforeNodeLocalConfirmation','consumeOnContextMismatch','storesRawRequesterContextInTicket'])assert.equal(c[key],s[key],key);
});

test('rollback is direct to v1.9 with unchanged Node 1.3 and no migration',()=>{
  const r=release.directRollback;
  assert.equal(r.commandCenterVersion,'1.9.0');
  assert.equal(r.nodeAgentVersion,'1.3.0');
  assert.equal(r.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(r.authProtocol,'rah-node-auth-v2');
  assert.equal(r.nodeAgent.gitBlobSha,release.runtime.nodeAgent.gitBlobSha);
  assert.equal(r.dataMigration,'none');assert.equal(r.secretMigration,'none');assert.equal(r.registryMigration,'none');
});

test('forbidden persistence and generic authority expansion remain explicit',()=>{
  for(const x of ['raw-requester-context','requester-context-digest-after-ticket-lifetime','raw-target','rustdesk-peer-id','node-token','password'])assert.ok(release.forbiddenPersistence.includes(x),x);
  for(const x of ['new-capabilities','new-actions','new-routes','caller-supplied-requester-context','bearer-token-network-transport','shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','native-raven-remote-control-api'])assert.ok(release.forbiddenRuntimeExpansion.includes(x),x);
});
