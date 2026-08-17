import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import {execFileSync} from 'node:child_process';

const guard=JSON.parse(fs.readFileSync('RAH-CC21-DOWNLOADED-BLOB-VERIFICATION.json','utf8'));
const trust=JSON.parse(fs.readFileSync('RAH-CC21-UPDATER-TRUST-ANCHOR.json','utf8'));
const manifest=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC21-NODE13-STABLE-RELEASE.json','utf8'));
const updater=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');
const git=(...args)=>execFileSync('git',args,{encoding:'utf8'}).trim();

function gitBlobSha(buffer){const header=Buffer.from(`blob ${buffer.length}\0`,'ascii');return crypto.createHash('sha1').update(header).update(buffer).digest('hex')}
function anchoredBlob(path){return git('rev-parse',`${guard.releaseCommit}:${path}`)}
function anchoredMode(path){const line=git('ls-tree',guard.releaseCommit,'--',path);const match=line.match(/^(\d+)\s+blob\s+[0-9a-f]{40}\t/);assert.ok(match,`${path}: expected anchored blob tree entry`);return match[1]}

test('guard extends the immutable CC2.1 trust anchor without changing 4/3/5 authority',()=>{
  assert.equal(guard.stage,'stable-updater-downloaded-blob-verification');assert.equal(guard.authorityDelta,'none');assert.equal(guard.releaseCommit,trust.releaseCommit);assert.equal(guard.releaseCommit,'a6b77f93dca5f774cdb76deb707edc71f86638a1');assert.equal(guard.packageFileCount,49);
  assert.deepEqual(guard.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);assert.deepEqual(guard.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);assert.deepEqual(guard.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
});

test('reference Git blob object calculation matches the anchored tree for manifest and all 49 package files',()=>{
  const paths=[guard.canonicalManifest,...manifest.package_files];assert.equal(paths.length,50);assert.equal(new Set(paths).size,50);
  for(const path of paths){const bytes=fs.readFileSync(path);assert.equal(gitBlobSha(bytes),anchoredBlob(path),`${path}: Git blob identity mismatch`);assert.equal(anchoredMode(path),'100644',`${path}: anchored Git mode drift`)}
});

test('updater requires verified commit tree SHA and exact non-truncated 100644 blob map',()=>{
  assert.match(updater,/commit\.tree\.sha/);assert.match(updater,/Resolve-PackageBlobMap/);assert.match(updater,/git\/trees\/\$\{TreeSha\}\?recursive=1/);assert.match(updater,/if\(\$treeInfo\.truncated\)/);assert.match(updater,/item\.type\)\-ne"blob"/);assert.match(updater,/item\.mode\)\-ne"100644"/);assert.match(updater,/\$map\.ContainsKey\(\$path\)/);assert.match(updater,/\$RequiredTreeFiles\.Count/);assert.doesNotMatch(updater,/120000/);assert.equal(guard.treePolicy.symlinkMode120000Rejected,true);assert.equal(guard.treePolicy.submoduleMode160000Rejected,true);
});

test('updater implements Git blob SHA-1 over raw bytes as object identity',()=>{
  assert.match(updater,/function Get-GitBlobSha/);assert.match(updater,/ReadAllBytes/);assert.match(updater,/"blob \$\(\$bytes\.Length\)`0"/);assert.match(updater,/Security\.Cryptography\.SHA1/);assert.equal(guard.downloadPolicy.sha1Role,'git-object-identity-bound-to-already-verified-commit-tree-not-standalone-trust');
});

test('canonical manifest is downloaded into staging, blob-verified, then parsed',()=>{
  const call=updater.indexOf('$stagedManifest=Download-StagedFile -RelativePath $ManifestName');
  const helperDownload=updater.indexOf('Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$encodedPath" -OutFile $staged');
  const helperVerify=updater.indexOf('$stagedBlob=Get-GitBlobSha -Path $staged');
  const parse=updater.indexOf('$manifest=Get-Content -LiteralPath $stagedManifest');
  assert.ok(helperDownload>=0&&helperVerify>helperDownload&&call>helperVerify&&parse>call);
  assert.equal(guard.downloadPolicy.verifyCanonicalManifestBeforeParsing,true);
});

test('Stable release manifest is staged and blob-verified before its contract is parsed',()=>{
  const packageStage=updater.indexOf('foreach($relativePath in $manifest.package_files){$null=Download-StagedFile');
  const releasePath=updater.indexOf('$stagedRelease=Get-SafeChildPath -Base $StagingDir -RelativePath $releasePath');
  const releaseParse=updater.indexOf('$release=Get-Content -LiteralPath $stagedRelease');
  assert.ok(packageStage>=0&&releasePath>packageStage&&releaseParse>releasePath);
  assert.equal(guard.downloadPolicy.verifyStableReleaseManifestBeforeParsing,true);
});

test('every staged package byte is Git-blob verified before backup or activation',()=>{
  const helperVerify=updater.indexOf('$stagedBlob=Get-GitBlobSha -Path $staged');
  const finalStageVerify=updater.indexOf('Final staged Git blob verification failed');
  const stageComplete=updater.indexOf('$StageVerificationComplete=$true');
  const backup=updater.indexOf('$OriginalState=Backup-Transaction');
  const activation=updater.indexOf('$ActivationStarted=$true');
  assert.ok(helperVerify>=0&&finalStageVerify>helperVerify&&stageComplete>finalStageVerify&&backup>stageComplete&&activation>backup);
  assert.equal(guard.downloadPolicy.verifyEveryPackageDownloadBeforeLocalComparison,true);
  assert.equal(guard.downloadPolicy.verifyBeforeBackupOrReplacement,true);
});

test('activation re-verifies staged bytes before each local replacement',()=>{
  const copy=updater.indexOf('Copy-Item -LiteralPath $staged -Destination $activateTemp -Force');
  const verify=updater.indexOf('$activationBlob=Get-GitBlobSha -Path $activateTemp');
  const replace=updater.indexOf('Move-Item -LiteralPath $activateTemp -Destination $target -Force');
  assert.ok(copy>=0&&verify>copy&&replace>verify);
  assert.match(updater,/if\(\$activationBlob-ne\$expectedBlob\)\{throw/);
});

test('anchored release contract remains Node1.3 Actions v7 Auth v2 policy v1',()=>{
  assert.equal(release.commandCenterVersion,'2.1.0');assert.equal(release.nodeAgentVersion,'1.3.0');assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');assert.equal(release.authProtocol,'rah-node-auth-v2');assert.equal(release.policyId,'rah-capability-allowlist-v1');
});
