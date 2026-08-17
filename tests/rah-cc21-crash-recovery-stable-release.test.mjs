import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

const release=JSON.parse(fs.readFileSync('RAH-CC21-CRASH-RECOVERY-STABLE-RELEASE.json','utf8'));
const gate=JSON.parse(fs.readFileSync(release.releaseEvidence.stableGate.path,'utf8'));
const candidate=JSON.parse(fs.readFileSync(release.releaseEvidence.candidate.path,'utf8'));
const readiness=JSON.parse(fs.readFileSync(release.releaseEvidence.readiness.path,'utf8'));
const manifest=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const hash=path=>execFileSync('git',['hash-object',path],{encoding:'utf8'}).trim();
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('Stable release pins updater, Candidate, readiness and Stable Gate bytes exactly',()=>{
  assert.equal(release.stage,'stable-updater-security-release');
  assert.equal(release.releaseId,'rah-cc21-crash-recovery-stable-v1');
  assert.equal(release.status,'stable');
  assert.equal(release.authorityDelta,'none');
  for(const item of Object.values(release.releaseEvidence)){
    assert.ok(fs.existsSync(item.path),item.path);
    assert.equal(hash(item.path),item.gitBlobSha,`${item.path}: Stable release evidence drift`);
  }
  assert.equal(gate.stage,'stable-promotion-gate');
  assert.equal(gate.status,'ready-for-explicit-stable-release');
  assert.equal(gate.gateId,release.releaseEvidence.stableGate.gateId);
  assert.equal(candidate.candidateId,release.releaseEvidence.candidate.candidateId);
  assert.equal(readiness.readinessId,release.releaseEvidence.readiness.readinessId);
});

test('Stable release preserves exact current CC2.1 / Node1.3 generation 6 authority baseline',()=>{
  assert.deepEqual(release.baseline,{ravenVersion:'2.0.32',commandCenterVersion:'2.1.0',nodeAgentVersion:'1.3.0',nodeHealthProtocol:'rah-node-health-v2',nodeActionsProtocol:'rah-node-actions-v7',authProtocol:'rah-node-auth-v2',policyId:'rah-capability-allowlist-v1',canonicalPackageGeneration:6,canonicalPackageFileCount:49,transactionFileCount:50,immutablePackageReleaseCommit:'a6b77f93dca5f774cdb76deb707edc71f86638a1'});
  assert.equal(manifest.version,'2.1.0');assert.equal(manifest.stage,'stable');assert.equal(manifest.canonical_package_generation,6);
  assert.equal(manifest.package_files.length,49);assert.equal(new Set(manifest.package_files).size,49);
  assert.deepEqual(release.authoritySurface.capabilities,caps);
  assert.deepEqual(release.authoritySurface.actions,actions);
  assert.deepEqual(release.authoritySurface.businessRoutes,routes);
  assert.deepEqual(gate.authoritySurface,release.authoritySurface);
  assert.deepEqual(candidate.authoritySurface,release.authoritySurface);
});

test('promotion changes evidence only and not accepted updater/runtime/package/protocol/policy bytes',()=>{
  assert.deepEqual(release.releaseChange,{updaterBytesChangedDuringPromotion:false,commandCenterRuntimeChanged:false,nodeAgentRuntimeChanged:false,canonicalPackageChanged:false,capabilitiesChanged:false,actionsChanged:false,routesChanged:false,protocolsChanged:false,policyChanged:false,dataMigrationRequired:false,secretMigrationRequired:false});
  assert.equal(release.releaseEvidence.updater.gitBlobSha,gate.acceptedEvidence.updater.gitBlobSha);
  assert.equal(release.releaseEvidence.candidate.gitBlobSha,gate.acceptedEvidence.candidate.gitBlobSha);
  assert.equal(release.releaseEvidence.readiness.gitBlobSha,gate.acceptedEvidence.readiness.gitBlobSha);
});

test('Stable updater contract includes complete crash-recovery and prior supply-chain boundary',()=>{
  const s=release.stableUpdaterContract;
  for(const key of ['exclusiveProcessLifetimeUpdaterLock','recoveryBeforeNetwork','fullStagingBeforeMutation','gitBlobVerificationBeforeMutation','fullVerifiedBackupBeforeActivation','activationStartedJournalDurableBeforeMutation','canonicalManifestActivatesLast','committedJournalDurableOnlyAfterFinalBlobVerification','rollbackStartedJournalDurableBeforeRecoveryMutation','activationAndRollbackRecoveryIdempotent','committedStateVerifiedBeforeJournalRetirement'])assert.equal(s[key],true,key);
  assert.equal(s.fixedTransactionDirectory,'.rah-transactions');
  assert.equal(s.fixedLockPath,'.rah-transactions/command-center.lock');
  assert.equal(s.fixedJournalPath,'.rah-transactions/command-center-active.json');
  assert.equal(s.fixedJournalTempPath,'.rah-transactions/command-center-active.json.tmp');
  assert.equal(s.journalMaxBytes,131072);
  assert.equal(s.durableJournalWrites,'same-directory-temp-write-through-flush-and-replace');
  assert.equal(s.exactOrderedTransactionFileCount,50);
  assert.equal(s.malformedOrAmbiguousRecoveryState,'fail-closed');
  assert.equal(s.secretPersistence,false);
  assert.equal(s.localTamperCryptographicResistanceClaimed,false);
});

test('future updater or recovery-contract drift requires a new Candidate and Stable Gate',()=>{
  assert.deepEqual(release.futureChangePolicy,{updaterByteDriftRequiresNewCandidateAndStableGate:true,journalSchemaExpansionRequiresNewCandidateAndStableGate:true,recoveryStateMachineExpansionRequiresNewCandidateAndStableGate:true,authorityExpansionRequiresVersionedRuntimeGate:true});
});

test('Stable release retains explicit forbidden broad powers and secret persistence',()=>{
  const forbidden=new Set(release.forbiddenPower);
  for(const item of ['shell','generic-command-execution','generic-process-launch','caller-controlled-executable-path','caller-controlled-generic-argument-array','generic-file-api','generic-endpoint-dispatch','native-raven-remote-control-api','bearer-token-persistence','challenge-persistence','approval-proof-persistence','password-persistence','peer-id-persistence'])assert.ok(forbidden.has(item),item);
});
