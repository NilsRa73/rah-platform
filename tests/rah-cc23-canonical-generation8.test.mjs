import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

const gate=JSON.parse(fs.readFileSync('RAH-CC23-CANONICAL-GENERATION8-STABLE-GATE.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC23-NODE13-STABLE-RELEASE.json','utf8'));
const commit=gate.immutableRelease.commit;
const show=(path)=>execFileSync('git',['show',`${commit}:${path}`],{encoding:'utf8'});
const revBlob=(path)=>execFileSync('git',['rev-parse',`${commit}:${path}`],{encoding:'utf8'}).trim();
const revTree=()=>execFileSync('git',['rev-parse',`${commit}^{tree}`],{encoding:'utf8'}).trim();
const historicManifest=JSON.parse(show('RAH-COMMAND-CENTER-VERSION.json'));
const historicUpdater=show('UPDATE-RAH-COMMAND-CENTER.ps1');
const historicLauncher=show('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat');
function historicAllowlist(){const x=historicUpdater.match(/\$AllowedPackageFiles=@\(\s*([\s\S]*?)\n\)/);assert.ok(x);return[...x[1].matchAll(/"([^"]+)"/g)].map(z=>z[1])}
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('historical generation 8 canonical identity and closure remain immutable',()=>{
  assert.equal(gate.stage,'canonical-stable-gate');assert.equal(gate.authorityDelta,'none');assert.equal(gate.commandCenterVersion,'2.3.0');assert.equal(gate.nodeAgentVersion,'1.3.0');assert.equal(gate.canonicalPackageGeneration,8);assert.equal(gate.canonicalPackageFileCount,61);assert.equal(gate.transactionFileCount,62);
  assert.equal(historicManifest.version,'2.3.0');assert.equal(historicManifest.entry,'RAH-COMMAND-CENTER-V2.3.html');assert.equal(historicManifest.runtime,'rah-command-center-core-v2.3.js');assert.equal(historicManifest.previous_stable_version,'2.2.0');assert.equal(historicManifest.canonical_package_generation,8);assert.equal(historicManifest.features.canonical_package_dependency_count,61);assert.equal(historicManifest.package_files.length,61);assert.equal(new Set(historicManifest.package_files).size,61);assert.deepEqual(historicAllowlist(),historicManifest.package_files);
});

test('historical immutable release tree and reviewed blob pins remain exact',()=>{
  assert.equal(commit,'1f5339841958bf0c2b4e737a5307f00029f8cf68');assert.equal(revTree(),gate.immutableRelease.tree);assert.equal(gate.immutableRelease.githubVerificationRequired,true);assert.equal(gate.immutableRelease.githubVerificationObserved,true);assert.equal(gate.immutableRelease.githubVerificationReason,'valid');assert.equal(gate.immutableRelease.branchHeadFallback,false);
  for(const row of Object.values(gate.canonicalFiles))assert.equal(revBlob(row.path),row.gitBlobSha,row.path);
  assert.equal(revBlob('RAH-COMMAND-CENTER-VERSION.json'),gate.canonicalFiles.manifest.gitBlobSha);assert.equal(revBlob('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'),gate.canonicalFiles.launcher.gitBlobSha);
});

test('historical updater retains verified immutable trust and 62-file crash transaction',()=>{
  assert.match(historicUpdater,/\$ReleaseCommit="1f5339841958bf0c2b4e737a5307f00029f8cf68"/);assert.match(historicUpdater,/commit\.verification\.verified/);assert.match(historicUpdater,/git\/trees\/\$\{TreeSha\}\?recursive=1/);assert.match(historicUpdater,/Get-GitBlobSha/);assert.match(historicUpdater,/rah-cc23-crash-recovery-journal-readiness-v1/);assert.match(historicUpdater,/\$files\.Count-ne62/);assert.match(historicUpdater,/\$Files\.Count-ne62/);assert.match(historicUpdater,/\$TransactionFiles\.Count-ne62/);assert.match(historicUpdater,/for\(\$i=0;\$i-lt62;\$i\+\+\)/);assert.doesNotMatch(historicUpdater,/refs\/heads\/main|\/branches\/main/);
  assert.equal(gate.updaterContract.recoveryBeforeNetwork,true);assert.equal(gate.updaterContract.exclusiveUpdaterLock,true);assert.equal(gate.updaterContract.durableJournal,true);assert.equal(gate.updaterContract.stageAllBeforeMutation,true);assert.equal(gate.updaterContract.verifyAllStagedGitBlobs,true);assert.equal(gate.updaterContract.rollbackOnActivationFailure,true);
});

test('historical Node1.3 exact 4/3/5 authority remains pinned',()=>{
  assert.equal(release.commandCenterVersion,'2.3.0');assert.equal(release.nodeAgentVersion,'1.3.0');assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');assert.equal(release.authProtocol,'rah-node-auth-v2');assert.equal(release.policyId,'rah-capability-allowlist-v1');assert.equal(release.nodeRuntimeChange,false);assert.deepEqual(release.authoritySurface.capabilities,caps);assert.deepEqual(release.authoritySurface.actions,actions);assert.deepEqual(release.authoritySurface.businessRoutes,routes);assert.deepEqual(release.authoritySurface.newCapabilities,[]);assert.deepEqual(release.authoritySurface.newActions,[]);assert.deepEqual(release.authoritySurface.newBusinessRoutes,[]);assert.deepEqual(gate.authoritySurface.capabilities,caps);assert.deepEqual(gate.authoritySurface.actions,actions);assert.deepEqual(gate.authoritySurface.businessRoutes,routes);
});

test('historical registry binding, launcher and failed-refresh boundaries remain fail closed',()=>{
  const x=release.registryBinding;assert.equal(x.policy,'prune-row-on-registry-identity-drift');assert.deepEqual(x.identityFields,['deviceId','endpointIp','sessionId']);assert.equal(x.pruneRemovedDevice,true);assert.equal(x.pruneEndpointChange,true);assert.equal(x.pruneNodeSessionChange,true);assert.equal(x.samePageSignal,'device-grid-mutation-observer');assert.equal(x.crossTabSignal,'storage-event-exact-device-registry-key');assert.equal(x.snapshotMemoryOnly,true);assert.equal(x.snapshotPersistence,false);assert.equal(x.tokenPersistence,false);assert.equal(x.timers,false);assert.equal(x.backgroundPolling,false);assert.equal(x.networkDiscovery,false);assert.equal(x.automaticRemoteControl,false);assert.equal(release.retainedCc22.failurePolicy,'invalidate-selected-row-on-refresh-failure');assert.equal(release.retainedCc22.selectedRowInvalidatedBeforeFailureRender,true);assert.match(historicLauncher,/v2\.3\.0 STABLE/);assert.doesNotMatch(historicLauncher,/https?:\/\/|Invoke-WebRequest|curl\b|wget\b/i);
});

test('historical rollback and frozen forbidden surface remain explicit',()=>{
  assert.equal(gate.directRollback.commandCenterVersion,'2.2.0');assert.equal(gate.directRollback.canonicalPackageGeneration,7);assert.equal(gate.directRollback.nodeAgentVersion,'1.3.0');assert.equal(gate.directRollback.dataMigration,'none');assert.equal(gate.directRollback.secretMigration,'none');assert.equal(gate.directRollback.registryMigration,'none');for(const x of ['new-capabilities','new-actions','new-business-routes','bearer-token-network-transport','password-persistence','peer-id-persistence','shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','caller-controlled-executable-path','caller-controlled-generic-arguments','network-discovery','background-polling','native-raven-remote-control-api'])assert.ok(gate.forbidden.includes(x),x);assert.equal(gate.freeze.runtimeFilesFrozen,true);assert.equal(gate.freeze.developmentPaused,true);
});
