import fs from 'node:fs';
import assert from 'node:assert/strict';

const manifestPath='RAH-COMMAND-CENTER-VERSION.json';
const launcherPath='DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat';
const nodeBatPath='START-RAH-NODE-AGENT.bat';
const nodeShPath='START-RAH-NODE-AGENT.sh';
const updaterPath='UPDATE-RAH-COMMAND-CENTER.ps1';
const packagingPath='tests/rah-command-center-packaging.test.mjs';
const additions=[
  'RAH-COMMAND-CENTER-V1.9.html',
  'RAH-COMMAND-CENTER-V1.9-CANDIDATE.html',
  'rah-command-center-core-v1.9-candidate.js',
  'rah-command-center-core-v1.9.js',
  'RAH-CC19-IMMUTABLE-MUTATING-INTENT-CANDIDATE.json',
  'RAH-CC19-NODE13-STABLE-RELEASE.json'
];
const m=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
assert.equal(m.version,'1.8.0');
assert.equal(m.stage,'stable');
assert.equal(m.entry,'RAH-COMMAND-CENTER-V1.8.html');
assert.equal(m.runtime,'rah-command-center-core-v1.8.js');
assert.equal(m.node_agent.agent_version,'1.3.0');
assert.equal(m.node_agent.actions_protocol,'rah-node-actions-v7');
assert.equal(m.node_agent.auth_protocol,'rah-node-auth-v2');
assert.equal(m.package_files.length,31);
const packageFiles=[...additions,...m.package_files];
assert.equal(new Set(packageFiles).size,37);
assert.equal(packageFiles.length,37);
for(const f of packageFiles)assert.ok(fs.existsSync(f),`missing package dependency ${f}`);
const release=JSON.parse(fs.readFileSync('RAH-CC19-NODE13-STABLE-RELEASE.json','utf8'));
assert.equal(release.stage,'stable-release');
assert.equal(release.commandCenterVersion,'1.9.0');
assert.equal(release.nodeAgentVersion,'1.3.0');
assert.equal(release.nodeRuntimeChange,false);
assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
assert.equal(release.authProtocol,'rah-node-auth-v2');
assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
assert.equal(release.mutatingIntentBinding.bindsEndpointIpv4,true);
assert.equal(release.mutatingIntentBinding.bindsCapabilitySnapshot,true);
assert.equal(release.mutatingIntentBinding.bindsAdvertisedActionSnapshot,true);
assert.equal(release.mutatingIntentBinding.bindsApprovedActionSnapshot,true);
assert.equal(release.mutatingIntentBinding.storesRawTarget,false);

m.version='1.9.0';
m.released_at='2026-08-17';
m.stable_since='2026-08-17';
m.entry='RAH-COMMAND-CENTER-V1.9.html';
m.runtime='rah-command-center-core-v1.9.js';
m.previous_stable_version='1.8.0';
m.package_files=packageFiles;
m.stable_release_manifest='RAH-CC19-NODE13-STABLE-RELEASE.json';
m.canonical_package_generation=4;
m.runtime_feature_change=false;
m.development_reopened=true;
m.development_paused=true;
m.change_policy='bugfix-only-until-explicit-reopen';
delete m.features.canonical_v18_package;
m.features.canonical_v19_package=true;
m.features.canonical_package_fixed_dependency_closure=true;
m.features.canonical_package_dependency_count=37;
m.features.immutable_mutating_intent_binding=true;
m.features.mutating_intent_binding_version='rah-cc-mutating-intent-v1';
m.features.mutating_intent_required_actions=['rustdesk.launch','rustdesk.connect'];
m.features.mutating_intent_storage_read_required=false;
m.features.mutating_intent_ttl_ms=90000;
m.features.mutating_intent_max_outstanding=32;
m.features.mutating_intent_memory_only=true;
m.features.mutating_intent_persistence=false;
m.features.mutating_intent_single_use=true;
m.features.mutating_intent_consume_before_node_local_confirmation=true;
m.features.mutating_intent_consume_on_mismatch=true;
m.features.mutating_intent_binds_endpoint_ipv4=true;
m.features.mutating_intent_binds_policy_and_protocols=true;
m.features.mutating_intent_binds_required_capability=true;
m.features.mutating_intent_binds_capability_snapshot=true;
m.features.mutating_intent_binds_advertised_action_snapshot=true;
m.features.mutating_intent_binds_approved_action_snapshot=true;
m.features.mutating_intent_binds_target_digest=true;
m.features.mutating_intent_stores_raw_target=false;
m.features.mutating_intent_secure_random_required=true;
m.features.mutating_intent_math_random_fallback=false;
m.release_gate={status:'passed',gate_version:'2.2.0',requires_tests:['tests/rah-command-center-packaging.test.mjs','tests/rah-cc19-immutable-mutating-intent.test.mjs','tests/rah-cc19-stable-release.test.mjs','tests/test_rah_node_agent_stable_v13.py'],stable_raven_runtime_frozen:true,runtime_files_frozen:true,change_policy:'bugfix-only-until-explicit-reopen'};
fs.writeFileSync(manifestPath,JSON.stringify(m,null,2)+'\n');

let launcher=fs.readFileSync(launcherPath,'utf8');
launcher=launcher.replaceAll('RAH-COMMAND-CENTER-V1.8.html','RAH-COMMAND-CENTER-V1.9.html').replaceAll('v1.8.0 STABLE','v1.9.0 STABLE').replaceAll('i v1.8;','i v1.9;').replaceAll('v1.8-pakke','v1.9-pakke');
assert.match(launcher,/RAH-COMMAND-CENTER-V1\.9\.html/);
assert.doesNotMatch(launcher,/Invoke-WebRequest|curl\b|wget\b|https?:\/\//i);
fs.writeFileSync(launcherPath,launcher);
for(const p of [nodeBatPath,nodeShPath]){
  let s=fs.readFileSync(p,'utf8').replaceAll('v1.8-pakken','v1.9-pakken').replaceAll('v1.8-pakke','v1.9-pakke');
  assert.match(s,/rah-node-agent-v1\.3\.py/);fs.writeFileSync(p,s);
}

let up=fs.readFileSync(updaterPath,'utf8');
const oldAllowStart=up.indexOf('$AllowedPackageFiles=@('),oldStamp=up.indexOf('$Stamp=',oldAllowStart);
assert.ok(oldAllowStart>=0&&oldStamp>oldAllowStart);
up=up.slice(0,oldAllowStart)+up.slice(oldStamp);
up=up.replaceAll('RAH-COMMAND-CENTER-V1.8.html','RAH-COMMAND-CENTER-V1.9.html')
  .replaceAll('rah-command-center-core-v1.8.js','rah-command-center-core-v1.9.js')
  .replaceAll('RAH-CC18-NODE13-STABLE-RELEASE.json','RAH-CC19-NODE13-STABLE-RELEASE.json')
  .replaceAll('commandCenterVersion-ne"1.8.0"','commandCenterVersion-ne"1.9.0"')
  .replaceAll('manifest.version-ne"1.8.0"','manifest.version-ne"1.9.0"')
  .replaceAll('Command Center v1.8','Command Center v1.9')
  .replaceAll('canonical v1.8 Stable','canonical v1.9 Stable')
  .replaceAll('v1.8-pakken','v1.9-pakken');
const allowBlock='$AllowedPackageFiles=@(\n'+packageFiles.map(f=>'  "'+f+'"').join(',\n')+'\n)\n';
const stamp=up.indexOf('$Stamp=');assert.ok(stamp>=0);up=up.slice(0,stamp)+allowBlock+up.slice(stamp);
assert.match(up,/manifest\.version-ne"1\.9\.0"/);
assert.match(up,/RAH-CC19-NODE13-STABLE-RELEASE\.json/);
for(const f of packageFiles)assert.ok(up.includes('"'+f+'"'),`updater missing ${f}`);
fs.writeFileSync(updaterPath,up);

const filesLiteral=JSON.stringify(packageFiles);
const packaging=`import test from'node:test';\nimport assert from'node:assert/strict';\nimport fs from'node:fs';\nconst m=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));\nconst release=JSON.parse(fs.readFileSync('RAH-CC19-NODE13-STABLE-RELEASE.json','utf8'));\nconst up=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');\nconst launcher=fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','utf8');\nconst nodeBat=fs.readFileSync('START-RAH-NODE-AGENT.bat','utf8');\nconst nodeSh=fs.readFileSync('START-RAH-NODE-AGENT.sh','utf8');\nconst files=${filesLiteral};\n\ntest('canonical v1.9 Stable package closure',()=>{assert.equal(m.version,'1.9.0');assert.equal(m.stage,'stable');assert.equal(m.entry,'RAH-COMMAND-CENTER-V1.9.html');assert.equal(m.runtime,'rah-command-center-core-v1.9.js');assert.equal(m.previous_stable_version,'1.8.0');assert.equal(m.stable_release_manifest,'RAH-CC19-NODE13-STABLE-RELEASE.json');assert.equal(m.canonical_package_generation,4);assert.equal(m.release_gate.status,'passed');assert.equal(m.release_gate.runtime_files_frozen,true);assert.equal(m.development_paused,true);assert.deepEqual(m.package_files,files);assert.equal(files.length,37);for(const f of files)assert.ok(fs.existsSync(f),f)});\n\ntest('canonical launcher is offline and opens v1.9 Stable',()=>{assert.match(launcher,/RAH-COMMAND-CENTER-V1\\.9\\.html/);assert.match(launcher,/v1\\.9\\.0 STABLE/);assert.doesNotMatch(launcher,/Invoke-WebRequest|curl\\b|wget\\b|https?:\\/\\//i)});\n\ntest('Node launchers retain exact Stable Node 1.3',()=>{assert.match(nodeBat,/rah-node-agent-v1\\.3\\.py/);assert.match(nodeSh,/rah-node-agent-v1\\.3\\.py/)});\n\ntest('manual updater pins exact immutable 37-file closure and v1.9 release',()=>{for(const f of files)assert.ok(up.includes('"'+f+'"'),f);assert.match(up,/Resolve-VerifiedRepositoryCommit/);assert.match(up,/commit\\.verification\\.verified/);assert.match(up,/Assert-FixedPackageContract/);assert.match(up,/Assert-StableReleaseContract/);assert.match(up,/manifest\\.version-ne"1\\.9\\.0"/);assert.match(up,/RAH-CC19-NODE13-STABLE-RELEASE\\.json/)});\n\ntest('canonical authority stays frozen and immutable intent policy is exact',()=>{assert.equal(release.commandCenterVersion,'1.9.0');assert.equal(release.nodeAgentVersion,'1.3.0');assert.equal(release.nodeRuntimeChange,false);assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);const b=release.mutatingIntentBinding;assert.equal(b.bindsEndpointIpv4,true);assert.equal(b.bindsCapabilitySnapshot,true);assert.equal(b.bindsAdvertisedActionSnapshot,true);assert.equal(b.bindsApprovedActionSnapshot,true);assert.equal(b.memoryOnly,true);assert.equal(b.persistent,false);assert.equal(b.singleUse,true);assert.equal(b.storesRawTarget,false);assert.equal(m.features.immutable_mutating_intent_binding,true);assert.equal(m.features.mutating_intent_math_random_fallback,false)});\n`;
fs.writeFileSync(packagingPath,packaging);
console.log('CC v1.9 canonical generated: 6 non-workflow root files, 37-file closure.');
