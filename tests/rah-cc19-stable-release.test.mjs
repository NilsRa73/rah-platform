import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const release=JSON.parse(fs.readFileSync('RAH-CC19-NODE13-STABLE-RELEASE.json','utf8'));
const candidate=JSON.parse(fs.readFileSync('RAH-CC19-IMMUTABLE-MUTATING-INTENT-CANDIDATE.json','utf8'));
const stableCore=require('../rah-command-center-core-v1.9.js');
const stableCoreSource=fs.readFileSync('rah-command-center-core-v1.9.js','utf8');
const stableHtml=fs.readFileSync('RAH-COMMAND-CENTER-V1.9.html','utf8');
function blob(path){return execFileSync('git',['rev-parse',`HEAD:${path}`],{encoding:'utf8'}).trim()}

test('Stable v1.9 identity and authority are exact',()=>{
  assert.equal(release.stage,'stable-release');
  assert.equal(release.authorityDelta,'none');
  assert.equal(release.ravenVersion,'2.0.32');
  assert.equal(release.commandCenterVersion,'1.9.0');
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

test('Stable core is strict immutable-intent wrapper over v1.9 Candidate',()=>{
  assert.equal(stableCore.CC_VERSION,'1.9.0');
  assert.equal(stableCore.MUTATING_INTENT_BINDING_VERSION,'rah-cc-mutating-intent-v1');
  assert.match(stableCoreSource,/require\('\.\/rah-command-center-core-v1\.9-candidate\.js'\)/);
  assert.match(stableCoreSource,/candidate\.CC_VERSION!=='1\.9\.0-candidate'/);
  assert.match(stableCoreSource,/candidate\.MUTATING_INTENT_BINDING_VERSION!=='rah-cc-mutating-intent-v1'/);
  assert.doesNotMatch(stableCoreSource,/Math\.random|shell|child_process|exec\(/);
});

test('Stable UI loads only pinned same-origin v1.9 Candidate and overlays Stable core',()=>{
  assert.match(stableHtml,/RAH Raven Command Center v1\.9 Stable/);
  assert.match(stableHtml,/const SOURCE='RAH-COMMAND-CENTER-V1\.9-CANDIDATE\.html'/);
  assert.match(stableHtml,/sourceUrl\.origin!==window\.location\.origin/);
  assert.match(stableHtml,/rah-command-center-core-v1\.9-candidate\.js/);
  assert.match(stableHtml,/rah-command-center-core-v1\.9\.js/);
  assert.match(stableHtml,/RAHCommandCenterCoreV19/);
  assert.match(stableHtml,/Cross-origin redirect rejected/);
});

test('immutable mutating intent Stable contract is memory-only and drift-fail-closed',()=>{
  const b=release.mutatingIntentBinding;
  assert.deepEqual(b.requiredActions,['rustdesk.launch','rustdesk.connect']);
  assert.equal(b.readOnlyStorageRequiresIntentBinding,false);
  assert.equal(b.ttlMs,90000);assert.equal(b.maxOutstanding,32);
  assert.equal(b.memoryOnly,true);assert.equal(b.persistent,false);assert.equal(b.singleUse,true);
  assert.equal(b.consumeBeforeNodeLocalConfirmation,true);assert.equal(b.consumeOnMismatch,true);
  for(const key of ['bindsDeviceId','bindsEndpointIpv4','bindsNodeSession','bindsPolicyId','bindsNodeHealthProtocol','bindsNodeActionsProtocol','bindsNodeAuthProtocol','bindsActionId','bindsRequiredCapability','bindsCapabilitySnapshot','bindsAdvertisedActionSnapshot','bindsApprovedActionSnapshot','bindsTargetDigest','secureRandomRequired'])assert.equal(b[key],true,key);
  assert.equal(b.storesRawTarget,false);assert.equal(b.mathRandomFallback,false);
});

test('Candidate evidence matches Stable immutable-intent contract',()=>{
  const c=candidate.mutatingIntentBinding,s=release.mutatingIntentBinding;
  assert.equal(candidate.commandCenterVersion,'1.9.0-candidate');
  assert.equal(candidate.sourceStableVersion,'1.8.0');
  assert.equal(candidate.runtime.nodeRuntimeChange,false);
  assert.equal(c.version,s.version);
  assert.deepEqual(c.requiredActions,s.requiredActions);
  assert.equal(c.retainsOneShotTtlMs,s.ttlMs);
  assert.equal(c.retainsMaxOutstanding,s.maxOutstanding);
  for(const key of ['memoryOnly','persistent','singleUse','consumeBeforeNodeLocalConfirmation','bindsDeviceId','bindsEndpointIpv4','bindsNodeSession','bindsPolicyId','bindsNodeHealthProtocol','bindsNodeActionsProtocol','bindsNodeAuthProtocol','bindsActionId','bindsRequiredCapability','bindsCapabilitySnapshot','bindsAdvertisedActionSnapshot','bindsApprovedActionSnapshot','bindsTargetDigest','storesRawTarget','secureRandomRequired','mathRandomFallback'])assert.equal(c[key],s[key],key);
  assert.equal(c.consumeOnMismatch,s.consumeOnMismatch);
});

test('rollback is direct to v1.8 with unchanged Node 1.3 and no migration',()=>{
  const r=release.directRollback;
  assert.equal(r.commandCenterVersion,'1.8.0');
  assert.equal(r.nodeAgentVersion,'1.3.0');
  assert.equal(r.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(r.authProtocol,'rah-node-auth-v2');
  assert.equal(r.nodeAgent.gitBlobSha,release.runtime.nodeAgent.gitBlobSha);
  assert.equal(r.dataMigration,'none');assert.equal(r.secretMigration,'none');assert.equal(r.registryMigration,'none');
});

test('forbidden persistence and generic authority expansion remain explicit',()=>{
  for(const x of ['mutating-intent-ticket','raw-target','rustdesk-peer-id','node-token','password'])assert.ok(release.forbiddenPersistence.includes(x),x);
  for(const x of ['new-capabilities','new-actions','new-routes','bearer-token-network-transport','shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','native-raven-remote-control-api'])assert.ok(release.forbiddenRuntimeExpansion.includes(x),x);
});
