import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const r=JSON.parse(fs.readFileSync('RAH-CC21-CRASH-RECOVERY-READINESS.json','utf8'));
const tx=JSON.parse(fs.readFileSync('RAH-CC21-TRANSACTIONAL-PACKAGE-STAGING.json','utf8'));
const manifest=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const updater=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

test('readiness is authority-neutral and updater-only future scope',()=>{
  assert.equal(r.stage,'implementation-readiness');
  assert.equal(r.authorityDelta,'none');
  assert.equal(r.runtimeMutationInThisPhase,false);
  assert.equal(r.futureImplementationScope.updaterMutationAllowed,true);
  assert.equal(r.futureImplementationScope.commandCenterRuntimeMutation,false);
  assert.equal(r.futureImplementationScope.nodeAgentRuntimeMutation,false);
  assert.equal(r.futureImplementationScope.packageClosureExpansion,false);
  assert.equal(r.futureImplementationScope.authorityExpansion,false);
  assert.deepEqual(r.authoritySurface.capabilities,caps);
  assert.deepEqual(r.authoritySurface.actions,actions);
  assert.deepEqual(r.authoritySurface.businessRoutes,routes);
});

test('readiness pins current Fase27 baseline and explicit missing crash journal boundary',()=>{
  assert.deepEqual(r.currentStable,{ravenVersion:'2.0.32',commandCenterVersion:'2.1.0',nodeAgentVersion:'1.3.0',nodeActionsProtocol:'rah-node-actions-v7',authProtocol:'rah-node-auth-v2',policyId:'rah-capability-allowlist-v1',transactionGuard:'RAH-CC21-TRANSACTIONAL-PACKAGE-STAGING.json',updater:'UPDATE-RAH-COMMAND-CENTER.ps1'});
  assert.equal(tx.explicitLimit.powerLossAtomicity,false);
  assert.equal(tx.explicitLimit.processKillAtomicity,false);
  assert.equal(tx.explicitLimit.persistentTransactionJournal,false);
  assert.equal(tx.explicitLimit.nextResearchBoundary,'persistent-journal-and-crash-recovery');
  assert.equal(manifest.version,'2.1.0');assert.equal(manifest.canonical_package_generation,6);assert.equal(manifest.package_files.length,49);
  assert.doesNotMatch(updater,/command-center-active\.json/);
  assert.doesNotMatch(updater,/FileShare\]::None|FileShare\.None/);
});

test('exclusive lock is fixed root-local, OS-enforced, held before recovery and network, with no fallback',()=>{
  assert.deepEqual(r.exclusiveLock,{directory:'.rah-transactions',path:'.rah-transactions/command-center.lock',mechanism:'os-file-handle-fileshare-none',acquireBeforeJournalRead:true,acquireBeforeNetwork:true,holdForProcessLifetime:true,lockFileExistenceAloneIsAuthority:false,fallbackToUnlockedMode:false});
});

test('journal has fixed identity, size, paths and strict transaction ID',()=>{
  assert.equal(r.journal.directory,'.rah-transactions');
  assert.equal(r.journal.activePath,'.rah-transactions/command-center-active.json');
  assert.equal(r.journal.tempPath,'.rah-transactions/command-center-active.json.tmp');
  assert.equal(r.journal.maxBytes,131072);
  assert.equal(r.journal.product,'RAH Raven Command Center');
  assert.equal(r.journal.journalSchemaVersion,1);
  assert.equal(r.journal.releaseCommit,'a6b77f93dca5f774cdb76deb707edc71f86638a1');
  assert.equal(r.journal.transactionIdPattern,'^[0-9]{8}-[0-9]{6}-[0-9a-f]{32}$');
  assert.equal(r.journal.fixedActivationFileCount,50);
  assert.equal(r.journal.canonicalManifestLast,true);
  assert.equal(r.journal.writeStrategy,'same-directory-temp-write-through-flush-and-replace');
  assert.equal(r.journal.ambiguousActiveAndTemp,'fail-closed');
  assert.equal(r.journal.orphanTempWithoutActive,'fail-closed');
});

test('journal schema is minimal and forbids credential/security-secret material',()=>{
  assert.deepEqual(r.allowedJournalTopLevelFields,['schemaVersion','product','readinessId','transactionId','releaseCommit','phase','files']);
  assert.deepEqual(r.allowedJournalFileFields,['path','expectedBlob','existed','originalSha256']);
  const forbidden=new Set(r.forbiddenJournalMaterial);
  for(const field of ['token','authorization','authProof','nonce','password','peerId','requesterContext','requesterContextDigest','sessionSecret','actionChallenge','approvalProof'])assert.ok(forbidden.has(field));
  for(const field of r.allowedJournalTopLevelFields.concat(r.allowedJournalFileFields))assert.equal(forbidden.has(field),false);
});

test('phase machine is closed and durable ordering precedes mutation authority',()=>{
  assert.deepEqual(r.phaseMachine.allowedPersistedPhases,['staged','backup-complete','activation-started','committed','rollback-started']);
  assert.deepEqual(r.phaseMachine.transitions,[['staged','backup-complete'],['backup-complete','activation-started'],['activation-started','committed'],['activation-started','rollback-started'],['committed','rollback-started']]);
  assert.equal(r.phaseMachine.activationStartedDurableBeforeFirstTargetMutation,true);
  assert.equal(r.phaseMachine.committedDurableOnlyAfterAllFinalBlobsVerify,true);
  assert.equal(r.phaseMachine.rollbackStartedDurableBeforeRecoveryMutation,true);
});

test('startup recovery is fail-closed and conservative before network',()=>{
  assert.deepEqual(r.recoveryBeforeNetwork,{staged:'retire-active-transaction-without-target-rollback','backup-complete':'retire-active-transaction-without-target-rollback','activation-started':'write-rollback-started-then-restore-pretransaction-state','rollback-started':'idempotently-restore-pretransaction-state',committed:'verify-all-50-current-target-blobs-else-write-rollback-started-and-restore',unknownPhase:'fail-closed'});
});

test('journal file records are exact fixed transaction metadata with no arbitrary paths',()=>{
  const v=r.journalFileValidation;
  assert.equal(v.pathsMustEqualCanonicalOrdered50FileSet,true);
  assert.equal(v.duplicatesForbidden,true);
  assert.equal(v.pathTraversalForbidden,true);
  assert.equal(v.absolutePathsForbidden,true);
  assert.equal(v.expectedBlobPattern,'^[0-9a-f]{40}$');
  assert.equal(v.originalSha256PatternWhenExisted,'^[0-9A-F]{64}$');
  assert.equal(v.originalSha256MustBeNullWhenAbsent,true);
  assert.equal(v.existedMustBeBooleanAfterBackupComplete,true);
  assert.equal(v.backupAndStagingDirectoriesDerivedFromTransactionIdOnly,true);
});

test('recovery requires verified backup and verifies the restored pretransaction state',()=>{
  const v=r.recoveryVerification;
  for(const key of ['existingTargetsRestoredOnlyFromVerifiedBackup','backupSha256MustMatchJournalBeforeRestore','restoreTempSha256MustMatchBeforeReplace','originallyAbsentTargetsMayOnlyBeRemovedIfInFixed50FileSet','postRecoveryOriginalStateVerifiedForAll50','journalRetiredOnlyAfterRecoveryVerification'])assert.equal(v[key],true,key);
});

test('crash semantics are recovery guarantees, not false atomicity claims',()=>{
  assert.equal(r.crashSemantics.crashBeforeActivationStarted,'no-target-mutation-authorized');
  assert.equal(r.crashSemantics.crashAfterActivationStartedBeforeCommitted,'conservative-rollback-on-next-start');
  assert.equal(r.crashSemantics.crashAfterCommitted,'verify-committed-package-then-retire-or-rollback');
  assert.equal(r.crashSemantics.powerLossAtomicAcross50FilesClaimed,false);
  assert.equal(r.crashSemantics.processKillAtomicAcross50FilesClaimed,false);
  assert.equal(r.crashSemantics.crashRecoverableRollbackTarget,true);
});

test('implementation gate requires negative tests for ambiguity, concurrency, path and recovery cases',()=>{
  const required=['second-updater-process-lock-denied','network-not-reached-before-recovery-resolution','oversized-journal-rejected','malformed-json-rejected','active-and-temp-ambiguity-rejected','orphan-temp-rejected','wrong-product-rejected','wrong-release-commit-rejected','bad-transaction-id-rejected','unknown-phase-rejected','wrong-file-count-order-or-path-rejected','duplicate-path-rejected','absolute-or-traversal-path-rejected','invalid-blob-or-sha256-rejected','missing-or-mismatched-backup-rejected','activation-started-recovery-is-idempotent','rollback-started-recovery-is-idempotent','committed-package-mismatch-rolls-back','journal-contains-no-secret-material'];
  assert.deepEqual(r.negativeImplementationTestsRequired,required);
});
