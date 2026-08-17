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

function gitBlobSha(buffer){
  const header=Buffer.from(`blob ${buffer.length}\0`,'ascii');
  return crypto.createHash('sha1').update(header).update(buffer).digest('hex');
}
function anchoredBlob(path){return git('rev-parse',`${guard.releaseCommit}:${path}`)}
function anchoredMode(path){
  const line=git('ls-tree',guard.releaseCommit,'--',path);
  const match=line.match(/^(\d+)\s+blob\s+[0-9a-f]{40}\t/);
  assert.ok(match,`${path}: expected anchored blob tree entry`);
  return match[1];
}

test('guard extends the immutable CC2.1 trust anchor without changing 4/3/5 authority',()=>{
  assert.equal(guard.stage,'stable-updater-downloaded-blob-verification');
  assert.equal(guard.authorityDelta,'none');
  assert.equal(guard.releaseCommit,trust.releaseCommit);
  assert.equal(guard.releaseCommit,'a6b77f93dca5f774cdb76deb707edc71f86638a1');
  assert.equal(guard.packageFileCount,49);
  assert.deepEqual(guard.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(guard.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(guard.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
});

test('reference Git blob object calculation matches the anchored tree for manifest and all 49 package files',()=>{
  const paths=[guard.canonicalManifest,...manifest.package_files];
  assert.equal(paths.length,50);
  assert.equal(new Set(paths).size,50);
  for(const path of paths){
    const bytes=fs.readFileSync(path);
    assert.equal(gitBlobSha(bytes),anchoredBlob(path),`${path}: Git blob identity mismatch`);
    assert.equal(anchoredMode(path),'100644',`${path}: anchored Git mode drift`);
  }
});

test('updater requires verified commit tree SHA and exact non-truncated 100644 blob map',()=>{
  assert.match(updater,/commit\.tree\.sha/);
  assert.match(updater,/Resolve-PackageBlobMap/);
  assert.match(updater,/git\/trees\/\$\{TreeSha\}\?recursive=1/);
  assert.match(updater,/if\(\$treeInfo\.truncated\)/);
  assert.match(updater,/item\.type\)\-ne"blob"/);
  assert.match(updater,/item\.mode\)\-ne"100644"/);
  assert.match(updater,/\$map\.ContainsKey\(\$path\)/);
  assert.match(updater,/\$RequiredTreeFiles\.Count/);
  assert.doesNotMatch(updater,/120000/);
  assert.equal(guard.treePolicy.symlinkMode120000Rejected,true);
  assert.equal(guard.treePolicy.submoduleMode160000Rejected,true);
});

test('updater implements Git blob SHA-1 over raw bytes as object identity',()=>{
  assert.match(updater,/function Get-GitBlobSha/);
  assert.match(updater,/ReadAllBytes/);
  assert.match(updater,/"blob \$\(\$bytes\.Length\)`0"/);
  assert.match(updater,/Security\.Cryptography\.SHA1/);
  assert.equal(guard.downloadPolicy.sha1Role,'git-object-identity-bound-to-already-verified-commit-tree-not-standalone-trust');
});

test('manifest and Stable release metadata are blob-verified before parsing',()=>{
  const manifestDownload=updater.indexOf('Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$ManifestName"');
  const manifestVerify=updater.indexOf('$manifestBlob=Get-GitBlobSha -Path $manifestTemp');
  const manifestParse=updater.indexOf('$manifest=Get-Content -LiteralPath $manifestTemp');
  assert.ok(manifestDownload>=0&&manifestVerify>manifestDownload&&manifestParse>manifestVerify);
  const releaseDownload=updater.indexOf('Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$releasePath"');
  const releaseVerify=updater.indexOf('$releaseBlob=Get-GitBlobSha -Path $releaseTemp');
  const releaseParse=updater.indexOf('$release=Get-Content -LiteralPath $releaseTemp');
  assert.ok(releaseDownload>=0&&releaseVerify>releaseDownload&&releaseParse>releaseVerify);
});

test('every package download is blob-verified before local comparison, backup or replacement',()=>{
  const download=updater.indexOf('Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$encodedPath" -OutFile $download');
  const verify=updater.indexOf('$downloadBlob=Get-GitBlobSha -Path $download');
  const compare=updater.indexOf('$oldHash=Get-FileHashSafe -Path $target');
  const backup=updater.indexOf('$backupTarget=Join-Path $BackupDir');
  const replace=updater.indexOf('Move-Item -LiteralPath $download -Destination $target -Force');
  assert.ok(download>=0&&verify>download&&compare>verify&&backup>compare&&replace>backup);
  assert.match(updater,/if\(\$downloadBlob-ne\$expectedBlob\)\{throw/);
  assert.equal(guard.downloadPolicy.verifyEveryPackageDownloadBeforeLocalComparison,true);
  assert.equal(guard.downloadPolicy.verifyBeforeBackupOrReplacement,true);
});

test('anchored release contract remains Node1.3 Actions v7 Auth v2 policy v1',()=>{
  assert.equal(release.commandCenterVersion,'2.1.0');
  assert.equal(release.nodeAgentVersion,'1.3.0');
  assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
  assert.equal(release.authProtocol,'rah-node-auth-v2');
  assert.equal(release.policyId,'rah-capability-allowlist-v1');
});
