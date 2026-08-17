import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

const c=JSON.parse(fs.readFileSync('RAH-CC21-CRASH-RECOVERY-CANDIDATE.json','utf8'));
const r=JSON.parse(fs.readFileSync('RAH-CC21-CRASH-RECOVERY-READINESS.json','utf8'));
const manifest=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const updater=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');
const hash=path=>execFileSync('git',['hash-object',path],{encoding:'utf8'}).trim();
const pos=s=>{const i=updater.indexOf(s);assert.ok(i>=0,`missing updater marker: ${s}`);return i};
const section=(start,end)=>{const a=pos(start),b=pos(end);assert.ok(b>a);return updater.slice(a,b)};

const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];
const fixed50=[...manifest.package_files,'RAH-COMMAND-CENTER-VERSION.json'];

test('Candidate is updater-only and authority-neutral on the current CC2.1 / Node1.3 baseline',()=>{
  assert.equal(c.stage,'candidate-updater-crash-recovery');
  assert.equal(c.authorityDelta,'none');
  assert.deepEqual(c.baseline,{ravenVersion:'2.0.32',commandCenterVersion:'2.1.0',nodeAgentVersion:'1.3.0',nodeActionsProtocol:'rah-node-actions-v7',authProtocol:'rah-node-auth-v2',policyId:'rah-capability-allowlist-v1',canonicalPackageGeneration:6,canonicalPackageFileCount:49,transactionFileCount:50,releaseCommit:'a6b77f93dca5f774cdb76deb707edc71f86638a1'});
  assert.equal(c.implementation.commandCenterRuntimeMutation,false);
  assert.equal(c.implementation.nodeAgentRuntimeMutation,false);
  assert.equal(c.implementation.canonicalPackageClosureExpansion,false);
  assert.equal(c.implementation.networkApiExpansion,false);
  assert.deepEqual(c.authoritySurface.capabilities,caps);
  assert.deepEqual(c.authoritySurface.actions,actions);
  assert.deepEqual(c.authoritySurface.businessRoutes,routes);
});

test('Fase28 readiness evidence remains byte-frozen and Candidate implements the same negative-test set',()=>{
  assert.equal(c.readinessEvidence.path,'RAH-CC21-CRASH-RECOVERY-READINESS.json');
  assert.equal(c.readinessEvidence.gitBlobSha,'b5527e41b322aef4cb803b9341e8c4b616364c3b');
  assert.equal(hash(c.readinessEvidence.path),c.readinessEvidence.gitBlobSha);
  assert.equal(c.readinessEvidence.readinessId,r.readinessId);
  assert.deepEqual(c.negativeTests,r.negativeImplementationTestsRequired);
});

test('exclusive FileShare.None lock is fixed root-local and acquired before recovery and all network resolution',()=>{
  assert.equal(c.implementation.fixedTransactionDirectory,'.rah-transactions');
  assert.equal(c.implementation.fixedLockPath,'.rah-transactions/command-center.lock');
  assert.equal(c.implementation.exclusiveLockMechanism,'os-file-handle-fileshare-none');
  assert.equal(c.implementation.lockHeldForProcessLifetime,true);
  assert.match(updater,/\$TransactionRoot=Join-Path \$Root "\.rah-transactions"/);
  assert.match(updater,/\$LockPath=Join-Path \$TransactionRoot "command-center\.lock"/);
  assert.match(updater,/\[IO\.File\]::Open\(\$LockPath,\[IO\.FileMode\]::OpenOrCreate,\[IO\.FileAccess\]::ReadWrite,\[IO\.FileShare\]::None\)/);
  const mainStart=updater.lastIndexOf('\ntry{\n  $LockHandle=Acquire-UpdaterLock');
  assert.ok(mainStart>=0,'main updater flow marker missing');
  const mainFlow=updater.slice(mainStart);
  const lock=mainFlow.indexOf('$LockHandle=Acquire-UpdaterLock');
  const recovery=mainFlow.indexOf('Resolve-PendingRecovery');
  const network=mainFlow.indexOf('$releaseIdentity=Resolve-VerifiedRepositoryCommit');
  assert.ok(lock>=0&&recovery>=0&&network>=0&&lock<recovery&&recovery<network);
  assert.match(updater,/finally\{[\s\S]*\$LockHandle\.Dispose\(\)/);
  const recoveryBody=section('function Resolve-PendingRecovery{','function Activate-Transaction{');
  assert.doesNotMatch(recoveryBody,/Invoke-(?:RestMethod|WebRequest)|raw\.githubusercontent|api\.github/);
});

test('journal paths, identity, size and exact ordered 50-file set are fixed',()=>{
  assert.equal(c.implementation.fixedJournalPath,'.rah-transactions/command-center-active.json');
  assert.equal(c.implementation.fixedJournalTempPath,'.rah-transactions/command-center-active.json.tmp');
  assert.equal(c.implementation.journalMaxBytes,131072);
  assert.deepEqual(c.journal.topLevelFields,['schemaVersion','product','readinessId','transactionId','releaseCommit','phase','files']);
  assert.deepEqual(c.journal.fileFields,['path','expectedBlob','existed','originalSha256']);
  assert.equal(fixed50.length,50);assert.equal(new Set(fixed50).size,50);
  assert.match(updater,/\$CanonicalTransactionFiles=@\(\$AllowedPackageFiles\)\+@\(\$ManifestName\)/);
  assert.match(updater,/if\(\$files\.Count-ne50\)/);
  assert.match(updater,/\$path-ne\$CanonicalTransactionFiles\[\$i\]/);
  assert.match(updater,/Get-SafeTargetPath -RelativePath \$path/);
  assert.match(updater,/\$seen\.ContainsKey\(\$path\)/);
  assert.match(updater,/\^\[0-9a-f\]\{40\}\$/);
  assert.match(updater,/\^\[0-9A-F\]\{64\}\$/);
});

test('journal reader rejects ambiguous, orphan, oversized, malformed and unknown state before recovery',()=>{
  assert.match(updater,/if\(\$hasActive-and\$hasTemp\)\{throw/);
  assert.match(updater,/if\(-not\$hasActive-and\$hasTemp\)\{throw/);
  assert.match(updater,/\$length-lt2-or\$length-gt\$JournalMaxBytes/);
  assert.match(updater,/ConvertFrom-Json/);
  assert.match(updater,/malformed JSON/);
  assert.match(updater,/\$allowedPhases=@\("staged","backup-complete","activation-started","committed","rollback-started"\)/);
  assert.match(updater,/Journal identity mismatch/);
  assert.match(updater,/Journal peker på feil release commit/);
  assert.match(updater,/Journal har ugyldig transactionId/);
});

test('durable journal write uses same-directory temp, write-through, Flush(true), and replace/rename',()=>{
  assert.equal(c.implementation.journalWriteStrategy,'same-directory-temp-write-through-flush-and-replace');
  assert.match(updater,/IO\.FileOptions\]::WriteThrough/);
  assert.match(updater,/\$stream\.Flush\(\$true\)/);
  assert.match(updater,/\[IO\.File\]::Replace\(\$JournalTempPath,\$JournalPath,\$null\)/);
  assert.match(updater,/\[IO\.File\]::Move\(\$JournalTempPath,\$JournalPath\)/);
  const writeBody=section('function Write-JournalDurable{','function Copy-Journal{');
  assert.match(writeBody,/JournalTempPath/);assert.match(writeBody,/JournalPath/);
});

test('phase transitions are closed and durable writes precede target mutation',()=>{
  assert.deepEqual(c.journal.phases,['staged','backup-complete','activation-started','committed','rollback-started']);
  assert.deepEqual(c.journal.transitions,[['staged','backup-complete'],['backup-complete','activation-started'],['activation-started','committed'],['activation-started','rollback-started'],['committed','rollback-started']]);
  const stagedWrite=pos('Write-JournalDurable -Journal $ActiveJournal');
  const backup=pos('$OriginalState=Backup-Transaction');
  const backupComplete=pos('$ActiveJournal=Add-OriginalStateToJournal');
  const activationFlag=pos('$ActivationStarted=$true');
  const activationPhase=pos('$ActiveJournal=Set-JournalPhase -Journal $ActiveJournal -NextPhase "activation-started"');
  const activation=pos('$result=Activate-Transaction -Files $TransactionFiles');
  const committed=pos('$ActiveJournal=Set-JournalPhase -Journal $ActiveJournal -NextPhase "committed"');
  const finalVerify=pos('Test-JournalInstalledBlobs -Journal $ActiveJournal');
  assert.ok(stagedWrite<backup&&backup<backupComplete&&backupComplete<activationFlag&&activationFlag<activationPhase&&activationPhase<activation&&activation<committed&&committed<finalVerify);
  assert.equal(c.journal.activationStartedDurableBeforeFirstTargetMutation,true);
  assert.equal(c.journal.committedDurableOnlyAfterFinalBlobVerification,true);
});

test('startup recovery implements every closed phase without network and verifies backups/restored state',()=>{
  const body=section('function Resolve-PendingRecovery{','function Activate-Transaction{');
  for(const phase of ['"staged"','"backup-complete"','"activation-started"','"rollback-started"','"committed"'])assert.match(body,new RegExp(phase.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')));
  assert.match(body,/Assert-BackupSet/);
  assert.match(body,/Set-JournalPhase -Journal \$journal -NextPhase "rollback-started"/);
  assert.match(body,/Restore-Transaction/);
  assert.match(body,/Assert-OriginalStateRestored/);
  assert.match(body,/Test-JournalInstalledBlobs/);
  assert.match(body,/Retire-Journal/);
  assert.doesNotMatch(body,/Invoke-(?:RestMethod|WebRequest)/);
});

test('handled live activation error durably enters rollback-started before restore and retires only after verification',()=>{
  const main=updater.slice(pos('$OriginalState=Backup-Transaction'));
  assert.match(main,/Set-JournalPhase -Journal \$ActiveJournal -NextPhase "rollback-started"[\s\S]*Restore-Transaction -Files \$TransactionFiles -OriginalState \$OriginalState[\s\S]*Assert-OriginalStateRestored -Files \$TransactionFiles -OriginalState \$OriginalState[\s\S]*Retire-Journal/);
  assert.match(main,/Activation failed and original package was restored/);
});

test('journal constructor contains only fixed non-secret metadata',()=>{
  const ctor=section('function New-TransactionJournal{','function Add-OriginalStateToJournal{');
  for(const field of c.journal.topLevelFields.concat(c.journal.fileFields))assert.match(ctor,new RegExp(field));
  const forbidden=new Set(c.forbiddenJournalMaterial);
  for(const field of r.forbiddenJournalMaterial)assert.ok(forbidden.has(field));
  for(const secret of c.forbiddenJournalMaterial)assert.doesNotMatch(ctor,new RegExp(secret,'i'),`secret-like journal material ${secret}`);
});

test('Candidate adds no broad power or runtime authority surface',()=>{
  const forbidden=new Set(c.forbiddenPower);
  for(const item of ['shell','generic-command-execution','generic-process-launch','caller-controlled-executable-path','caller-controlled-generic-argument-array','generic-file-api','generic-endpoint-dispatch','native-raven-remote-control-api','bearer-token-persistence','challenge-persistence','approval-proof-persistence','password-persistence','peer-id-persistence'])assert.ok(forbidden.has(item));
  assert.equal(c.implementation.networkApiExpansion,false);
});
