import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const guard=JSON.parse(fs.readFileSync('RAH-CC21-TRANSACTIONAL-PACKAGE-STAGING.json','utf8'));
const manifest=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const updater=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');

const pos=s=>{const i=updater.indexOf(s);assert.ok(i>=0,`missing updater marker: ${s}`);return i};

test('transaction guard preserves CC2.1 Node1.3 v7 auth-v2 exact 4/3/5 authority',()=>{
  assert.equal(guard.stage,'stable-updater-transactional-staging');
  assert.equal(guard.authorityDelta,'none');
  assert.deepEqual(guard.baseline,{ravenVersion:'2.0.32',commandCenterVersion:'2.1.0',nodeAgentVersion:'1.3.0',nodeActionsProtocol:'rah-node-actions-v7',authProtocol:'rah-node-auth-v2',policyId:'rah-capability-allowlist-v1'});
  assert.deepEqual(guard.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(guard.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(guard.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
});

test('transaction is exactly canonical manifest plus 49 package files and manifest activates last',()=>{
  assert.equal(manifest.package_files.length,49);
  assert.equal(guard.transaction.packageFileCount,49);
  assert.equal(guard.transaction.activationFileCount,50);
  assert.match(updater,/\$TransactionFiles=@\(\$manifest\.package_files\|ForEach-Object\{\[string\]\$_\}\)\+@\(\$ManifestName\)/);
  assert.match(updater,/if\(\$TransactionFiles\.Count-ne50-or@\(\$TransactionFiles\|Select-Object -Unique\)\.Count-ne50\)/);
  assert.equal(guard.transaction.canonicalManifestActivatedLast,true);
});

test('all downloads and Git blob checks finish before backup or first activation',()=>{
  const stageStart=pos('$StagingDir=Join-Path');
  const packageStage=pos('foreach($relativePath in $manifest.package_files){$null=Download-StagedFile');
  const stageComplete=pos('$StageVerificationComplete=$true');
  const backup=pos('$OriginalState=Backup-Transaction');
  const activation=pos('$ActivationStarted=$true');
  assert.ok(stageStart<packageStage&&packageStage<stageComplete&&stageComplete<backup&&backup<activation);
  assert.match(updater,/if\(-not\$StageVerificationComplete\)\{throw/);
  assert.equal(guard.transaction.allStagedFilesGitBlobVerified,true);
});

test('Stable release contract is validated from staged bytes before activation',()=>{
  const releaseStage=pos('$stagedRelease=Get-SafeChildPath -Base $StagingDir -RelativePath $releasePath');
  const releaseParse=pos('$release=Get-Content -LiteralPath $stagedRelease');
  const releaseCheck=pos('Assert-StableReleaseContract -Release $release');
  const backup=pos('$OriginalState=Backup-Transaction');
  assert.ok(releaseStage<releaseParse&&releaseParse<releaseCheck&&releaseCheck<backup);
  assert.equal(guard.transaction.stableReleaseContractValidatedFromStaging,true);
});

test('every existing target is backed up and SHA-256 verified before activation',()=>{
  assert.match(updater,/function Backup-Transaction/);
  assert.match(updater,/\$originalHash=Get-FileHashSafe -Path \$target/);
  assert.match(updater,/Copy-Item -LiteralPath \$target -Destination \$backup -Force/);
  assert.match(updater,/if\(\(Get-FileHashSafe -Path \$backup\)-ne\$originalHash\)\{throw/);
  assert.match(updater,/Existed=\$true;Sha256=\$originalHash/);
  assert.match(updater,/Existed=\$false;Sha256=\$null/);
  assert.equal(guard.transaction.backupEveryExistingTargetBeforeActivation,true);
  assert.equal(guard.transaction.backupSha256VerifiedBeforeActivation,true);
});

test('activation re-verifies same-directory temp before replacement and verifies final targets',()=>{
  assert.match(updater,/\$activateTemp="\$target\.rah-activate-\$Stamp"/);
  assert.match(updater,/Copy-Item -LiteralPath \$staged -Destination \$activateTemp -Force/);
  assert.match(updater,/\$activationBlob=Get-GitBlobSha -Path \$activateTemp/);
  assert.match(updater,/if\(\$activationBlob-ne\$expectedBlob\)\{throw/);
  const verify=pos('$activationBlob=Get-GitBlobSha -Path $activateTemp');
  const replace=pos('Move-Item -LiteralPath $activateTemp -Destination $target -Force');
  assert.ok(verify<replace);
  assert.match(updater,/foreach\(\$relative in \$Files\)\{\$target=Get-SafeTargetPath/);
  assert.match(updater,/Post-activation Git blob mismatch/);
  assert.equal(guard.transaction.activationTempGitBlobReverified,true);
  assert.equal(guard.transaction.postActivationGitBlobVerification,true);
});

test('handled activation failure restores originals and removes originally absent targets',()=>{
  assert.match(updater,/function Restore-Transaction/);
  assert.match(updater,/if\(\$state\.Existed\)/);
  assert.match(updater,/Move-Item -LiteralPath \$restoreTemp -Destination \$target -Force/);
  assert.match(updater,/elseif\(Test-Path -LiteralPath \$target\)/);
  assert.match(updater,/Remove-Item -LiteralPath \$target -Force/);
  assert.match(updater,/Restore-Transaction -Files \$TransactionFiles -OriginalState \$OriginalState/);
  assert.match(updater,/Activation failed and original package was restored/);
  assert.equal(guard.transaction.handledActivationFailure,'restore-all-original-files-and-remove-originally-absent-targets');
});

test('staging is cleaned on exit while successful backup is retained',()=>{
  assert.match(updater,/Remove-Item -LiteralPath \$StagingDir -Recurse -Force/);
  assert.doesNotMatch(updater,/Remove-Item -LiteralPath \$BackupDir -Recurse/);
  assert.equal(guard.transaction.stagingCleanupOnExit,true);
  assert.equal(guard.transaction.successfulBackupRetention,true);
});

test('phase explicitly does not claim power-loss or process-kill atomicity',()=>{
  assert.equal(guard.explicitLimit.powerLossAtomicity,false);
  assert.equal(guard.explicitLimit.processKillAtomicity,false);
  assert.equal(guard.explicitLimit.persistentTransactionJournal,false);
  assert.equal(guard.explicitLimit.nextResearchBoundary,'persistent-journal-and-crash-recovery');
});
