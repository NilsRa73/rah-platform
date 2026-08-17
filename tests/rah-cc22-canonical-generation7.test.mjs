import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

const gate=JSON.parse(fs.readFileSync('RAH-CC22-CANONICAL-GENERATION7-STABLE-GATE.json','utf8'));
const manifest=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC22-NODE13-STABLE-RELEASE.json','utf8'));
const updater=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');
const launcher=fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','utf8');
const blob=path=>execFileSync('git',['hash-object',path],{encoding:'utf8'}).trim();
const revBlob=(commit,path)=>execFileSync('git',['rev-parse',`${commit}:${path}`],{encoding:'utf8'}).trim();
const revTree=commit=>execFileSync('git',['rev-parse',`${commit}^{tree}`],{encoding:'utf8'}).trim();
function updaterAllowlist(){const m=updater.match(/\$AllowedPackageFiles=@\(\s*([\s\S]*?)\n\)/);assert.ok(m);return[...m[1].matchAll(/"([^"]+)"/g)].map(x=>x[1])}

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('canonical generation 7 identity and exact package closure',()=>{
  assert.equal(gate.stage,'canonical-stable-gate');
  assert.equal(gate.authorityDelta,'none');
  assert.equal(gate.commandCenterVersion,'2.2.0');
  assert.equal(gate.nodeAgentVersion,'1.3.0');
  assert.equal(gate.canonicalPackageGeneration,7);
  assert.equal(gate.canonicalPackageFileCount,55);
  assert.equal(gate.transactionFileCount,56);
  assert.equal(manifest.version,'2.2.0');
  assert.equal(manifest.entry,'RAH-COMMAND-CENTER-V2.2.html');
  assert.equal(manifest.runtime,'rah-command-center-core-v2.2.js');
  assert.equal(manifest.previous_stable_version,'2.1.0');
  assert.equal(manifest.canonical_package_generation,7);
  assert.equal(manifest.features.canonical_package_dependency_count,55);
  assert.equal(manifest.package_files.length,55);
  assert.equal(new Set(manifest.package_files).size,55);
  assert.deepEqual(updaterAllowlist(),manifest.package_files);
});

test('immutable release commit/tree and every canonical package blob are exact',()=>{
  const c=gate.immutableRelease.commit;
  assert.match(c,/^[0-9a-f]{40}$/);
  assert.equal(c,'9f2f69859d96155e7400924c5624f5ee734886bf');
  assert.equal(revTree(c),gate.immutableRelease.tree);
  assert.equal(gate.immutableRelease.githubVerificationRequired,true);
  assert.equal(gate.immutableRelease.githubVerificationObserved,true);
  assert.equal(gate.immutableRelease.githubVerificationReason,'valid');
  assert.equal(gate.immutableRelease.branchHeadFallback,false);
  for(const path of manifest.package_files){
    assert.ok(fs.existsSync(path),path);
    assert.equal(revBlob(c,path),blob(path),path);
  }
  assert.equal(revBlob(c,'RAH-COMMAND-CENTER-VERSION.json'),gate.canonicalFiles.manifest.gitBlobSha);
  assert.equal(revBlob(c,'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'),gate.canonicalFiles.launcher.gitBlobSha);
});

test('canonical files and updater are hash-pinned to reviewed generation 7 outputs',()=>{
  for(const pin of Object.values(gate.canonicalFiles))assert.equal(blob(pin.path),pin.gitBlobSha,pin.path);
  assert.equal(blob('UPDATE-RAH-COMMAND-CENTER.ps1'),'b7b667655fc6d9caf098936243e3aed281697b58');
});

test('updater requires GitHub verified immutable commit and exact 56-file journal',()=>{
  assert.match(updater,/\$ReleaseCommit="9f2f69859d96155e7400924c5624f5ee734886bf"/);
  assert.match(updater,/commit\.verification\.verified/);
  assert.match(updater,/git\/trees\/\$\{TreeSha\}\?recursive=1/);
  assert.match(updater,/Get-GitBlobSha/);
  assert.match(updater,/\$JournalReadinessId="rah-cc22-crash-recovery-journal-readiness-v1"/);
  assert.match(updater,/\$files\.Count-ne56/);
  assert.match(updater,/\$Files\.Count-ne56/);
  assert.match(updater,/\$TransactionFiles\.Count-ne56/);
  assert.match(updater,/for\(\$i=0;\$i-lt56;\$i\+\+\)/);
  assert.doesNotMatch(updater,/a6b77f93dca5f774cdb76deb707edc71f86638a1|Count-ne50|lt50/);
  assert.doesNotMatch(updater,/refs\/heads\/main|\/branches\/main|raw\.githubusercontent\.com\/[^\n]+\/main\//i);
  assert.equal(gate.updaterContract.releaseCommitPinned,true);
  assert.equal(gate.updaterContract.releaseCommitVerificationRequired,true);
  assert.equal(gate.updaterContract.fixedPackageAllowlistCount,55);
  assert.equal(gate.updaterContract.fixedTransactionCount,56);
  assert.equal(gate.updaterContract.recoveryBeforeNetwork,true);
  assert.equal(gate.updaterContract.exclusiveUpdaterLock,true);
  assert.equal(gate.updaterContract.durableJournal,true);
  assert.equal(gate.updaterContract.stageAllBeforeMutation,true);
  assert.equal(gate.updaterContract.rollbackOnActivationFailure,true);
});

test('CC22 Stable release preserves exact 4/3/5 authority and Node1.3',()=>{
  assert.equal(release.commandCenterVersion,'2.2.0');
  assert.equal(release.nodeAgentVersion,'1.3.0');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(release.authProtocol,'rah-node-auth-v2');
  assert.equal(release.policyId,'rah-capability-allowlist-v1');
  assert.equal(release.nodeRuntimeChange,false);
  assert.deepEqual(release.authoritySurface.capabilities,caps);
  assert.deepEqual(release.authoritySurface.actions,actions);
  assert.deepEqual(release.authoritySurface.businessRoutes,routes);
  assert.deepEqual(release.authoritySurface.newCapabilities,[]);
  assert.deepEqual(release.authoritySurface.newActions,[]);
  assert.deepEqual(release.authoritySurface.newBusinessRoutes,[]);
  assert.deepEqual(gate.authoritySurface.capabilities,caps);
  assert.deepEqual(gate.authoritySurface.actions,actions);
  assert.deepEqual(gate.authoritySurface.businessRoutes,routes);
});

test('fail-closed Fleet Snapshot invalidation is frozen without persistence/polling/remote authority',()=>{
  const f=release.fleetSnapshotInvalidation;
  assert.equal(f.version,'rah-cc-fleet-snapshot-invalidation-v1');
  assert.equal(f.failurePolicy,'invalidate-selected-row-on-refresh-failure');
  assert.equal(f.selectedRowRemovedBeforeFailureRender,true);
  assert.equal(f.successfulRefreshBehaviorChanged,false);
  assert.equal(f.refreshMode,'explicit-selected-device-click');
  assert.equal(f.freshNodeTokenRequiredPerRefreshClick,true);
  assert.equal(f.tokenPersistence,false);
  assert.equal(f.snapshotMemoryOnly,true);
  assert.equal(f.snapshotPersistence,false);
  assert.equal(f.backgroundPolling,false);
  assert.equal(f.networkDiscovery,false);
  assert.equal(f.automaticRemoteControl,false);
  assert.equal(gate.fleetSnapshotInvalidation.failurePolicy,f.failurePolicy);
  assert.equal(manifest.features.fleet_snapshot_failed_refresh_invalidates_selected_row,true);
  assert.match(launcher,/v2\.2\.0 STABLE/);
  assert.doesNotMatch(launcher,/https?:\/\/|Invoke-WebRequest|curl\b|wget\b/i);
});

test('forbidden generic authority and migration remain absent',()=>{
  for(const item of ['new-capabilities','new-actions','new-business-routes','bearer-token-network-transport','password-persistence','peer-id-persistence','shell','generic-command-execution','generic-process-launch','generic-action-endpoint','generic-file-api','caller-controlled-executable-path','caller-controlled-generic-arguments','network-discovery','background-polling','native-raven-remote-control-api'])assert.ok(gate.forbidden.includes(item),item);
  assert.equal(gate.directRollback.commandCenterVersion,'2.1.0');
  assert.equal(gate.directRollback.nodeAgentVersion,'1.3.0');
  assert.equal(gate.directRollback.dataMigration,'none');
  assert.equal(gate.directRollback.secretMigration,'none');
  assert.equal(gate.directRollback.registryMigration,'none');
  assert.equal(gate.freeze.runtimeFilesFrozen,true);
  assert.equal(gate.freeze.developmentPaused,true);
  assert.equal(gate.freeze.changePolicy,'bugfix-only-until-explicit-reopen');
});
