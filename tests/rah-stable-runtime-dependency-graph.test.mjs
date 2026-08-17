import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';

const policy=JSON.parse(fs.readFileSync('RAH-STABLE-RUNTIME-DEPENDENCY-GRAPH.json','utf8'));
const canonical=JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json','utf8'));
const rootFiles=new Set(fs.readdirSync('.',{withFileTypes:true}).filter(x=>x.isFile()).map(x=>x.name));
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];

function gitBlobSha(path){const body=fs.readFileSync(path);return crypto.createHash('sha1').update(Buffer.from(`blob ${body.length}\0`)).update(body).digest('hex')}
function dependencies(path){
  const source=fs.readFileSync(path,'utf8');
  const out=new Set();
  if(path.endsWith('.py')){
    for(const m of source.matchAll(/with_name\(['"]([^'"]+\.py)['"]\)/g))if(rootFiles.has(m[1]))out.add(m[1]);
  }else if(path.endsWith('.js')){
    for(const m of source.matchAll(/require\(['"]\.\/([^'"]+\.js)['"]\)/g))if(rootFiles.has(m[1]))out.add(m[1]);
  }else if(path.endsWith('.html')){
    for(const m of source.matchAll(/['"]([A-Za-z0-9_.-]+\.(?:js|html))['"]/g))if(rootFiles.has(m[1]))out.add(m[1]);
  }
  return [...out];
}
function walk(entrypoints,maxDepth=32){
  const seen=new Set(),edges=[];
  function visit(path,depth){
    assert.ok(depth<=maxDepth,`dependency depth exceeded at ${path}`);
    if(seen.has(path))return;seen.add(path);
    for(const dep of dependencies(path)){edges.push([path,dep]);visit(dep,depth+1)}
  }
  for(const e of entrypoints)visit(e,0);
  return{seen,edges};
}
function stableEvidenceFiles(){
  return [...rootFiles].filter(name=>/STABLE-RELEASE\.json$/.test(name)||/STABLE-PROMOTION-GATE\.json$/.test(name)||/PROMOTED-IMPLEMENTATION.*\.json$/.test(name));
}
function stableEvidencePins(){
  const pins=new Set();
  for(const file of stableEvidenceFiles())for(const m of fs.readFileSync(file,'utf8').matchAll(/\b[0-9a-f]{40}\b/g))pins.add(m[0]);
  return pins;
}

test('dependency guard is authority-neutral and follows canonical CC 1.6.1 / Node 1.2.1',()=>{
  assert.equal(policy.stage,'stable-runtime-dependency-guard');
  assert.equal(policy.authorityDelta,'none');
  assert.deepEqual(policy.canonicalBaseline,{ravenVersion:'2.0.32',commandCenterVersion:'1.6.1',nodeAgentVersion:'1.2.1',nodeHealthProtocol:'rah-node-health-v2',nodeActionsProtocol:'rah-node-actions-v6',policyId:'rah-capability-allowlist-v1'});
  assert.deepEqual(canonical.baseline,policy.canonicalBaseline);
  assert.deepEqual(policy.authoritySurface,{capabilities:caps,actions,routes});
  assert.deepEqual(canonical.capabilities,caps);assert.deepEqual(canonical.actions.map(x=>x.id),actions);assert.deepEqual(canonical.routes,routes);
});

test('current Stable entrypoints directly depend on promoted paths, not current Candidate runtime paths',()=>{
  const node=fs.readFileSync('rah-node-agent-v1.2.1.py','utf8');
  const core=fs.readFileSync('rah-command-center-core-v1.6.1.js','utf8');
  const html=fs.readFileSync('RAH-COMMAND-CENTER-V1.6.1.html','utf8');
  assert.match(node,/with_name\('rah-node-agent-v1\.2-promoted\.py'\)/);assert.doesNotMatch(node,/with_name\('rah-node-agent-v1\.2-candidate\.py'\)/);
  assert.match(core,/require\('\.\/rah-command-center-core-v1\.6-promoted\.js'\)/);assert.doesNotMatch(core,/require\('\.\/rah-command-center-core-v1\.6-candidate\.js'\)/);
  assert.match(html,/const SOURCE='RAH-COMMAND-CENTER-V1\.6-PROMOTED\.html'/);assert.doesNotMatch(html,/const SOURCE='RAH-COMMAND-CENTER-V1\.6-CANDIDATE\.html'/);
  assert.match(html,/const STABLE_INJECTION='[^']*rah-command-center-core-v1\.6-promoted\.js[^']*rah-command-center-core-v1\.6\.1\.js/);
});

test('recursive Stable graph resolves only repository-root files and terminates',()=>{
  const graph=walk(policy.stableEntrypoints,policy.dependencyDiscovery.maxDepth);
  for(const path of graph.seen){assert.ok(rootFiles.has(path),`non-root dependency: ${path}`);assert.ok(!path.includes('/')&&!path.includes('\\'),`nested dependency: ${path}`)}
  for(const promoted of policy.promotedImplementation)assert.ok(graph.seen.has(promoted),`promoted implementation not reachable: ${promoted}`);
  assert.ok(graph.edges.length>0);
});

test('every transitive candidate-labeled alias is frozen by Stable release/promotion evidence',()=>{
  const graph=walk(policy.stableEntrypoints,policy.dependencyDiscovery.maxDepth),pins=stableEvidencePins();
  const legacy=[...graph.seen].filter(path=>/candidate/i.test(path));
  assert.ok(legacy.length>0,'expected at least one legacy Candidate-labelled alias in historical chain');
  for(const path of legacy){
    const sha=gitBlobSha(path);
    assert.ok(pins.has(sha),`${path} (${sha}) is a transitive Candidate-labelled dependency without Stable release/promotion pin`);
  }
});

test('Candidate manifests alone are never used as acceptable pin evidence',()=>{
  const evidence=stableEvidenceFiles();
  assert.ok(evidence.length>0);
  for(const file of evidence)assert.ok(!(/CANDIDATE\.json$/).test(file),`candidate manifest incorrectly accepted as Stable evidence: ${file}`);
  assert.equal(policy.legacyTransitivePolicy.candidateManifestAloneIsInsufficientEvidence,true);
  assert.equal(policy.legacyTransitivePolicy.unPinnedOrDriftedLegacyAlias,'fail-closed');
});

test('promoted implementation mutation and authority expansion remain separately gated',()=>{
  assert.equal(policy.directDependencyPolicy.stableEntrypointMayReferenceCurrentCandidatePath,false);
  assert.equal(policy.directDependencyPolicy.promotedMutationRequiresNewVersionAndStableGate,true);
  for(const x of ['new-capabilities','new-actions','new-routes','generic-endpoint','generic-approval-endpoint','generic-command-execution','generic-process-launch','shell','generic-file-api','generic-endpoint-dispatch','caller-controlled-executable-path','caller-controlled-generic-arguments','native-raven-remote-control-api','forwarding-header-identity','secret-persistence','network-token-renewal-endpoint'])assert.ok(policy.forbiddenExpansion.includes(x),x);
});
