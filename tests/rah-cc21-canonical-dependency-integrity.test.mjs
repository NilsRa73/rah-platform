import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

const guard=JSON.parse(fs.readFileSync('RAH-CC21-CANONICAL-DEPENDENCY-INTEGRITY.json','utf8'));
const manifest=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const release=JSON.parse(fs.readFileSync('RAH-CC21-NODE13-STABLE-RELEASE.json','utf8'));
const packageFiles=[...manifest.package_files];
const packageSet=new Set(packageFiles);
const text=path=>fs.readFileSync(path,'utf8');
const hash=path=>execFileSync('git',['hash-object',path],{encoding:'utf8'}).trim();
const norm=dep=>dep.replace(/^\.\//,'').replaceAll('\\','/');

function collectPins(value,map=new Map()){
  if(Array.isArray(value)){for(const item of value)collectPins(item,map);return map}
  if(!value||typeof value!=='object')return map;
  if(typeof value.path==='string'&&/^[0-9a-f]{40}$/.test(value.gitBlobSha||'')){
    if(!map.has(value.path))map.set(value.path,new Set());
    map.get(value.path).add(value.gitBlobSha);
  }
  for(const child of Object.values(value))collectPins(child,map);
  return map;
}

const stablePins=new Map();
for(const evidence of guard.stableEvidenceManifests){
  const parsed=JSON.parse(text(evidence.path));
  for(const [path,shas] of collectPins(parsed)){
    if(!stablePins.has(path))stablePins.set(path,new Set());
    for(const sha of shas)stablePins.get(path).add(sha);
  }
}

function jsDependencies(path){
  const source=text(path),deps=[];
  for(const match of source.matchAll(/\brequire\s*\(([^)]*)\)/g)){
    const arg=match[1].trim(),literal=arg.match(/^(['"])([^'"]+)\1$/);
    if(!literal){if(arg.includes('./')||arg.includes('../'))assert.fail(`${path}: dynamic local require is forbidden: ${arg}`);continue}
    if(literal[2].startsWith('./')||literal[2].startsWith('../'))deps.push(norm(literal[2]));
  }
  return [...new Set(deps)];
}

function pyDependencies(path){
  const source=text(path),deps=[];
  for(const match of source.matchAll(/\bwith_name\s*\(([^)]*)\)/g)){
    const arg=match[1].trim(),literal=arg.match(/^(['"])([^'"]+)\1$/);
    assert.ok(literal,`${path}: dynamic with_name dependency is forbidden: ${arg}`);
    deps.push(norm(literal[2]));
  }
  return [...new Set(deps)];
}

function htmlDependencies(path){
  const source=text(path),deps=[];
  for(const match of source.matchAll(/\bSOURCE\s*=\s*(['"])([^'"]+)\1/g))deps.push(norm(match[2]));
  for(const match of source.matchAll(/\bsrc=["']([^"']+)["']/g)){
    const dep=match[1];
    if(!/^[a-z][a-z0-9+.-]*:/i.test(dep)&&!dep.startsWith('//'))deps.push(norm(dep));
  }
  return [...new Set(deps.filter(dep=>/\.(?:html|js)$/i.test(dep)))];
}

function dependencies(path){
  if(path.endsWith('.js'))return jsDependencies(path);
  if(path.endsWith('.py'))return pyDependencies(path);
  if(path.endsWith('.html'))return htmlDependencies(path);
  return [];
}

function assertCandidatePinned(path){
  if(!/candidate/i.test(path))return;
  const current=hash(path),pins=stablePins.get(path);
  assert.ok(pins&&pins.has(current),`${path}: Candidate blob ${current} is not pinned by frozen Stable release evidence`);
}

function walkRuntime(root){
  const seen=new Set(),edges=[];
  function visit(path){
    path=norm(path);
    if(seen.has(path))return;
    seen.add(path);
    assert.ok(packageSet.has(path),`${path}: runtime dependency is outside canonical 49-file package`);
    assert.ok(fs.existsSync(path),`${path}: runtime dependency missing`);
    assertCandidatePinned(path);
    for(const dep of dependencies(path)){
      assert.ok(packageSet.has(dep),`${path} -> ${dep}: dependency outside canonical package`);
      assert.ok(fs.existsSync(dep),`${path} -> ${dep}: dependency missing`);
      assertCandidatePinned(dep);
      edges.push([path,dep]);
      visit(dep);
    }
  }
  visit(root);
  return {seen,edges};
}

function updaterAllowlist(){
  const up=text(guard.canonicalPackage.manualUpdater);
  const match=up.match(/\$AllowedPackageFiles=@\(\s*([\s\S]*?)\n\)/);
  assert.ok(match,'manual updater AllowedPackageFiles block missing');
  return [...match[1].matchAll(/"([^"]+)"/g)].map(x=>x[1]);
}

test('guard pins current canonical CC 2.1 / Node 1.3 / v7 auth-v2 baseline and exact 4/3/5 authority',()=>{
  assert.equal(guard.stage,'stable-canonical-dependency-integrity');
  assert.equal(guard.authorityDelta,'none');
  assert.deepEqual(guard.baseline,{ravenVersion:'2.0.32',commandCenterVersion:'2.1.0',nodeAgentVersion:'1.3.0',nodeHealthProtocol:'rah-node-health-v2',nodeActionsProtocol:'rah-node-actions-v7',authProtocol:'rah-node-auth-v2',policyId:'rah-capability-allowlist-v1'});
  assert.deepEqual(guard.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(guard.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(guard.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
});

test('canonical generation 6 package is exact unique 49-file closure',()=>{
  assert.equal(manifest.version,'2.1.0');assert.equal(manifest.stage,'stable');
  assert.equal(manifest.canonical_package_generation,6);assert.equal(manifest.features.canonical_package_dependency_count,49);
  assert.equal(packageFiles.length,49);assert.equal(packageSet.size,49);
  assert.equal(manifest.entry,guard.canonicalPackage.entry);assert.equal(manifest.runtime,guard.canonicalPackage.runtime);
  assert.equal(manifest.stable_release_manifest,guard.canonicalPackage.stableReleaseManifest);
  for(const path of packageFiles)assert.ok(fs.existsSync(path),path);
});

test('Stable evidence manifests are themselves frozen and only Stable release evidence supplies Candidate pins',()=>{
  for(const evidence of guard.stableEvidenceManifests){
    assert.ok(fs.existsSync(evidence.path),evidence.path);
    assert.equal(hash(evidence.path),evidence.gitBlobSha,`${evidence.path}: Stable evidence blob drift`);
    const parsed=JSON.parse(text(evidence.path));
    assert.equal(parsed.stage,'stable-release',`${evidence.path}: evidence is not Stable release`);
    assert.equal(parsed.authorityDelta,'none',`${evidence.path}: authority delta drift`);
  }
});

test('current CC2.1 release pins its Stable runtime and direct Candidate implementation exactly',()=>{
  for(const item of Object.values(release.runtime))assert.equal(hash(item.path),item.gitBlobSha,`${item.path}: Stable runtime blob drift`);
  for(const item of Object.values(release.pinnedCandidate))assert.equal(hash(item.path),item.gitBlobSha,`${item.path}: CC2.1 Candidate blob drift`);
  assert.equal(release.nodeRuntimeChange,false);
});

test('recursive Stable runtime dependency graph stays inside canonical package and every Candidate edge is Stable-pinned',()=>{
  const roots=[manifest.entry,manifest.runtime,guard.canonicalPackage.nodeRuntime];
  const results=roots.map(walkRuntime);
  const allEdges=results.flatMap(x=>x.edges).map(x=>x.join(' -> '));
  assert.ok(allEdges.includes('rah-command-center-core-v2.1.js -> rah-command-center-core-v2.1-candidate.js'));
  assert.ok(allEdges.includes('rah-command-center-core-v2.1-candidate.js -> rah-command-center-core-v2.0.js'));
  assert.ok(allEdges.includes('rah-node-agent-v1.3.py -> rah-node-agent-v1.3-candidate.py'));
  assert.ok(allEdges.includes('rah-node-agent-v1.3-candidate.py -> rah-node-agent-v1.2-candidate.py'));
});

test('Stable HTML source binding remains fixed same-origin and Candidate blobs are release-pinned',()=>{
  const stable=text(manifest.entry);
  assert.match(stable,/const SOURCE='RAH-COMMAND-CENTER-V2\.1-CANDIDATE\.html'/);
  assert.match(stable,/sourceUrl\.origin!==window\.location\.origin/);
  assert.match(stable,/new URL\(response\.url\)\.origin!==window\.location\.origin/);
  assert.doesNotMatch(stable,/const SOURCE\s*=\s*(?:location|window|document|localStorage)/);
  assertCandidatePinned('RAH-COMMAND-CENTER-V2.1-CANDIDATE.html');
  assertCandidatePinned('rah-command-center-core-v2.1-candidate.js');
});

test('manual updater uses exact canonical closure and immutable verified commit downloads',()=>{
  const up=text(guard.canonicalPackage.manualUpdater),allowed=updaterAllowlist();
  assert.equal(allowed.length,49);assert.equal(new Set(allowed).size,49);assert.deepEqual(allowed,packageFiles);
  assert.match(up,/Resolve-VerifiedRepositoryCommit/);assert.match(up,/commit\.verification\.verified/);
  assert.match(up,/\$RawBase="https:\/\/raw\.githubusercontent\.com\/\$RepoOwner\/\$RepoName\/\$ResolvedCommit"/);
  assert.doesNotMatch(up,/\$RawBase="https:\/\/raw\.githubusercontent\.com\/\$RepoOwner\/\$RepoName\/\$RepoBranch"/);
  assert.match(up,/if\(\$releasePath-ne"RAH-CC21-NODE13-STABLE-RELEASE\.json"\)/);
  assert.match(up,/IsPathRooted/);assert.match(up,/Contains\("\.\."\)/);assert.match(up,/StartsWith\(\$rootFull/);
});

test('dependency policy requires an explicit new version or canonical generation for closure expansion',()=>{
  assert.equal(guard.dependencyPolicy.dependencyOutsideCanonicalPackage,'forbidden');
  assert.equal(guard.dependencyPolicy.candidateDependency,'allowed-only-when-current-blob-is-pinned-by-frozen-stable-release-evidence');
  assert.equal(guard.dependencyPolicy.candidateManifestAloneIsSufficientEvidence,false);
  assert.equal(guard.dependencyPolicy.canonicalPackageExpansion,'requires-new-command-center-version-or-canonical-package-generation-and-explicit-gate');
});
