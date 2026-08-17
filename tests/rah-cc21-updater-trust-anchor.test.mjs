import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

const anchor=JSON.parse(fs.readFileSync('RAH-CC21-UPDATER-TRUST-ANCHOR.json','utf8'));
const current=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC21-NODE13-STABLE-RELEASE.json','utf8'));
const updater=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');
const git=(...args)=>execFileSync('git',args,{encoding:'utf8'}).trim();
const showJson=(commit,path)=>JSON.parse(git('show',`${commit}:${path}`));

function currentBlob(path){return git('hash-object',path)}
function anchoredBlob(commit,path){return git('rev-parse',`${commit}:${path}`)}

test('trust anchor pins the verified canonical CC 2.1 promotion commit and unchanged authority',()=>{
  assert.equal(anchor.stage,'stable-updater-trust-anchor');
  assert.equal(anchor.authorityDelta,'none');
  assert.match(anchor.releaseCommit,/^[0-9a-f]{40}$/);
  assert.equal(anchor.releaseCommit,'a6b77f93dca5f774cdb76deb707edc71f86638a1');
  assert.equal(anchor.releaseCommitVerification.githubApiVerifiedRequired,true);
  assert.equal(anchor.releaseCommitVerification.returnedShaMustMatchExactly,true);
  assert.equal(anchor.releaseCommitVerification.branchHeadFallback,false);
  assert.deepEqual(anchor.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(anchor.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(anchor.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
});

test('anchored commit is an ancestor and contains the exact canonical generation-6 manifest',()=>{
  execFileSync('git',['merge-base','--is-ancestor',anchor.releaseCommit,'HEAD']);
  const anchored=showJson(anchor.releaseCommit,anchor.canonicalPackage.manifest);
  assert.equal(anchored.product,anchor.canonicalPackage.product);
  assert.equal(anchored.version,'2.1.0');assert.equal(anchored.stage,'stable');
  assert.equal(anchored.canonical_package_generation,6);
  assert.equal(anchored.features.canonical_package_dependency_count,49);
  assert.equal(anchored.entry,anchor.canonicalPackage.entry);
  assert.equal(anchored.runtime,anchor.canonicalPackage.runtime);
  assert.equal(anchored.stable_release_manifest,anchor.canonicalPackage.stableReleaseManifest);
  assert.equal(anchored.package_files.length,49);
  assert.equal(new Set(anchored.package_files).size,49);
});

test('current canonical package contract still matches the anchored release contract exactly',()=>{
  const anchored=showJson(anchor.releaseCommit,anchor.canonicalPackage.manifest);
  assert.equal(current.version,anchored.version);
  assert.equal(current.stage,anchored.stage);
  assert.equal(current.canonical_package_generation,anchored.canonical_package_generation);
  assert.equal(current.stable_release_manifest,anchored.stable_release_manifest);
  assert.deepEqual(current.package_files,anchored.package_files);
  assert.equal(current.package_files.length,49);
});

test('all 49 current package files remain byte-identical to the release anchor',()=>{
  for(const path of current.package_files){
    assert.ok(fs.existsSync(path),path);
    assert.equal(currentBlob(path),anchoredBlob(anchor.releaseCommit,path),`${path}: canonical package drift since release anchor`);
  }
});

test('anchored Stable release retains Node1.3 v7 auth-v2 policy-v1 exact 4/3/5 boundary',()=>{
  const anchoredRelease=showJson(anchor.releaseCommit,anchor.canonicalPackage.stableReleaseManifest);
  for(const candidate of [release,anchoredRelease]){
    assert.equal(candidate.commandCenterVersion,'2.1.0');
    assert.equal(candidate.nodeAgentVersion,'1.3.0');
    assert.equal(candidate.nodeActionsProtocol,'rah-node-actions-v7');
    assert.equal(candidate.authProtocol,'rah-node-auth-v2');
    assert.equal(candidate.policyId,'rah-capability-allowlist-v1');
    assert.deepEqual(candidate.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
    assert.deepEqual(candidate.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
    assert.deepEqual(candidate.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
  }
});

test('updater resolves only the fixed release commit, verifies it, and has no latest-main fallback',()=>{
  const escaped=anchor.releaseCommit.replace(/[.*+?^${}()|[\]\\]/g,'\\$&');
  assert.match(updater,new RegExp(`\\$ReleaseCommit="${escaped}"`));
  assert.match(updater,/\$ApiBase\/commits\/\$ReleaseCommit/);
  assert.match(updater,/commit\.verification\.verified/);
  assert.match(updater,/\$sha\.ToLowerInvariant\(\)-ne\$ReleaseCommit\.ToLowerInvariant\(\)/);
  assert.match(updater,/\$RawBase="https:\/\/raw\.githubusercontent\.com\/\$RepoOwner\/\$RepoName\/\$ResolvedCommit"/);
  assert.doesNotMatch(updater,/\$RepoBranch\s*=\s*"main"/);
  assert.doesNotMatch(updater,/commits\/\$RepoBranch/);
  assert.doesNotMatch(updater,/raw\.githubusercontent\.com\/\$RepoOwner\/\$RepoName\/\$RepoBranch/);
});

test('new package bytes require a new version or canonical generation and explicit release gate',()=>{
  assert.equal(anchor.downloadPolicy.currentCanonicalPackageMustRemainByteIdenticalToAnchor,true);
  assert.equal(anchor.downloadPolicy.newPackageBytesRequire,'new-command-center-version-or-canonical-package-generation-and-explicit-release-gate');
  assert.ok(anchor.forbiddenFallbacks.includes('latest-main-as-package-source'));
});
