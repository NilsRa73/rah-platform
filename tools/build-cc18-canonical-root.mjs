import fs from 'node:fs';
import assert from 'node:assert/strict';

const manifestPath='RAH-COMMAND-CENTER-VERSION.json';
const launcherPath='DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat';
const nodeBatPath='START-RAH-NODE-AGENT.bat';
const nodeShPath='START-RAH-NODE-AGENT.sh';
const updaterPath='UPDATE-RAH-COMMAND-CENTER.ps1';
const packagingPath='tests/rah-command-center-packaging.test.mjs';
const workflowPath='.github/workflows/validate-rah-command-center.yml';

const packageFiles=[
  'RAH-COMMAND-CENTER-V1.8.html',
  'RAH-COMMAND-CENTER-V1.8-CANDIDATE.html',
  'RAH-COMMAND-CENTER-V1.7.html',
  'RAH-COMMAND-CENTER-V1.7-CANDIDATE.html',
  'RAH-COMMAND-CENTER-V1.2.html',
  'rah-command-center-core.js',
  'rah-command-center-core-v1.3.js',
  'rah-command-center-core-v1.4.js',
  'rah-command-center-core-v1.5-candidate.js',
  'rah-command-center-core-v1.5.js',
  'rah-command-center-core-v1.6-candidate.js',
  'rah-command-center-core-v1.6.js',
  'rah-command-center-core-v1.7-candidate.js',
  'rah-command-center-core-v1.7.js',
  'rah-command-center-core-v1.8-candidate.js',
  'rah-command-center-core-v1.8.js',
  'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat',
  'rah-node-agent.py',
  'rah-node-agent-v0.9.py',
  'rah-node-agent-v1.0-candidate.py',
  'rah-node-agent-v1.0.py',
  'rah-node-agent-v1.1-candidate.py',
  'rah-node-agent-v1.1.py',
  'rah-node-agent-v1.2-candidate.py',
  'rah-node-agent-v1.3-candidate.py',
  'rah-node-agent-v1.3.py',
  'START-RAH-NODE-AGENT.bat',
  'START-RAH-NODE-AGENT.sh',
  'RAH-CC17-NODE13-STABLE-RELEASE.json',
  'RAH-CC18-ONE-SHOT-MUTATING-APPROVAL-CANDIDATE.json',
  'RAH-CC18-NODE13-STABLE-RELEASE.json'
];
assert.equal(packageFiles.length,31);
for(const file of packageFiles)assert.ok(fs.existsSync(file),`missing required package dependency: ${file}`);

const release=JSON.parse(fs.readFileSync('RAH-CC18-NODE13-STABLE-RELEASE.json','utf8'));
assert.equal(release.stage,'stable-release');
assert.equal(release.commandCenterVersion,'1.8.0');
assert.equal(release.nodeAgentVersion,'1.3.0');
assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');
assert.equal(release.authProtocol,'rah-node-auth-v2');
assert.equal(release.policyId,'rah-capability-allowlist-v1');
assert.equal(release.nodeRuntimeChange,false);
assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
assert.deepEqual(release.oneShotApproval.requiredActions,['rustdesk.launch','rustdesk.connect']);
assert.equal(release.oneShotApproval.ttlMs,90000);
assert.equal(release.oneShotApproval.maxOutstanding,32);
assert.equal(release.oneShotApproval.memoryOnly,true);
assert.equal(release.oneShotApproval.persistent,false);
assert.equal(release.oneShotApproval.singleUse,true);
assert.equal(release.oneShotApproval.consumeBeforeNodeLocalConfirmation,true);
assert.equal(release.oneShotApproval.consumeOnBindingMismatch,true);
assert.equal(release.oneShotApproval.storesRawTarget,false);

const m=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
assert.equal(m.version,'1.7.0','builder requires reviewed v1.7 canonical template');
assert.equal(m.entry,'RAH-COMMAND-CENTER-V1.7.html');
assert.equal(m.runtime,'rah-command-center-core-v1.7.js');
assert.equal(m.node_agent.agent_version,'1.3.0');
assert.equal(m.node_agent.actions_protocol,'rah-node-actions-v7');
assert.equal(m.node_agent.auth_protocol,'rah-node-auth-v2');

m.version='1.8.0';
m.stage='stable';
m.released_at='2026-08-17';
m.stable_since='2026-08-17';
m.entry='RAH-COMMAND-CENTER-V1.8.html';
m.runtime='rah-command-center-core-v1.8.js';
m.previous_stable_version='1.7.0';
m.package_files=packageFiles;
m.stable_release_manifest='RAH-CC18-NODE13-STABLE-RELEASE.json';
m.canonical_package_generation=3;
m.runtime_feature_change=false;
m.development_reopened=true;
m.development_paused=true;
m.change_policy='bugfix-only-until-explicit-reopen';

delete m.features.canonical_v17_package;
m.features.canonical_v18_package=true;
m.features.canonical_v12_compatibility_base=true;
m.features.canonical_package_fixed_dependency_closure=true;
m.features.canonical_package_dependency_count=31;
m.features.one_shot_mutating_approval=true;
m.features.one_shot_required_actions=['rustdesk.launch','rustdesk.connect'];
m.features.one_shot_ttl_ms=90000;
m.features.one_shot_max_outstanding=32;
m.features.one_shot_memory_only=true;
m.features.one_shot_persistence=false;
m.features.one_shot_single_use=true;
m.features.one_shot_consume_before_node_local_confirmation=true;
m.features.one_shot_consume_on_binding_mismatch=true;
m.features.one_shot_binds_device_id=true;
m.features.one_shot_binds_node_session=true;
m.features.one_shot_binds_action_id=true;
m.features.one_shot_binds_target_digest=true;
m.features.one_shot_stores_raw_target=false;
m.features.one_shot_secure_random_required=true;
m.features.one_shot_math_random_fallback=false;
m.features.storage_summary_requires_one_shot=false;

m.release_gate={
  status:'passed',
  gate_version:'2.1.0',
  requires_tests:[
    'tests/rah-command-center-packaging.test.mjs',
    'tests/rah-cc18-one-shot-mutating-approval.test.mjs',
    'tests/rah-cc18-stable-release.test.mjs',
    'tests/test_rah_node_agent_stable_v13.py'
  ],
  stable_raven_runtime_frozen:true,
  runtime_files_frozen:true,
  change_policy:'bugfix-only-until-explicit-reopen'
};
fs.writeFileSync(manifestPath,JSON.stringify(m,null,2)+'\n');

let launcher=fs.readFileSync(launcherPath,'utf8');
launcher=launcher.replaceAll('RAH-COMMAND-CENTER-V1.7.html','RAH-COMMAND-CENTER-V1.8.html')
  .replaceAll('v1.7.0 STABLE','v1.8.0 STABLE')
  .replaceAll('i v1.7;','i v1.8;')
  .replaceAll('v1.7-pakke','v1.8-pakke');
assert.match(launcher,/RAH-COMMAND-CENTER-V1\.8\.html/);
assert.doesNotMatch(launcher,/Invoke-WebRequest|curl\b|wget\b|https?:\/\//i);
fs.writeFileSync(launcherPath,launcher);

for(const p of [nodeBatPath,nodeShPath]){
  let s=fs.readFileSync(p,'utf8').replaceAll('v1.7-pakken','v1.8-pakken').replaceAll('v1.7-pakke','v1.8-pakke');
  assert.match(s,/rah-node-agent-v1\.3\.py/);
  fs.writeFileSync(p,s);
}

let up=fs.readFileSync(updaterPath,'utf8');
const allowStart=up.indexOf('$AllowedPackageFiles=@(');
const stampStart=up.indexOf('$Stamp=',allowStart);
assert.ok(allowStart>=0&&stampStart>allowStart,'updater allowlist block not found');
const allowBlock='$AllowedPackageFiles=@(\n'+packageFiles.map(f=>'  "'+f+'"').join(',\n')+'\n)\n';
up=up.slice(0,allowStart)+allowBlock+up.slice(stampStart);
up=up.replaceAll('RAH-COMMAND-CENTER-V1.7.html','RAH-COMMAND-CENTER-V1.8.html')
  .replaceAll('rah-command-center-core-v1.7.js','rah-command-center-core-v1.8.js')
  .replaceAll('RAH-CC17-NODE13-STABLE-RELEASE.json','RAH-CC18-NODE13-STABLE-RELEASE.json')
  .replaceAll('commandCenterVersion-ne"1.7.0"','commandCenterVersion-ne"1.8.0"')
  .replaceAll('manifest.version-ne"1.7.0"','manifest.version-ne"1.8.0"')
  .replaceAll('Command Center v1.7 pakkeoppdatering','Command Center v1.8 pakkeoppdatering')
  .replaceAll('Command Center v1.7 Stable','Command Center v1.8 Stable')
  .replaceAll('Command Center v1.7','Command Center v1.8')
  .replaceAll('canonical v1.7 Stable','canonical v1.8 Stable')
  .replaceAll('v1.7-pakken','v1.8-pakken');
assert.match(up,/manifest\.version-ne"1\.8\.0"/);
assert.match(up,/RAH-CC18-NODE13-STABLE-RELEASE\.json/);
for(const file of packageFiles)assert.ok(up.includes('"'+file+'"'),`updater allowlist missing ${file}`);
fs.writeFileSync(updaterPath,up);

const filesLiteral=JSON.stringify(packageFiles);
const packaging=`import test from'node:test';\nimport assert from'node:assert/strict';\nimport fs from'node:fs';\nconst m=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));\nconst release=JSON.parse(fs.readFileSync('RAH-CC18-NODE13-STABLE-RELEASE.json','utf8'));\nconst up=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');\nconst launcher=fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','utf8');\nconst nodeBat=fs.readFileSync('START-RAH-NODE-AGENT.bat','utf8');\nconst nodeSh=fs.readFileSync('START-RAH-NODE-AGENT.sh','utf8');\nconst files=${filesLiteral};\n\ntest('canonical v1.8 Stable package closure',()=>{assert.equal(m.version,'1.8.0');assert.equal(m.stage,'stable');assert.equal(m.entry,'RAH-COMMAND-CENTER-V1.8.html');assert.equal(m.runtime,'rah-command-center-core-v1.8.js');assert.equal(m.previous_stable_version,'1.7.0');assert.equal(m.stable_release_manifest,'RAH-CC18-NODE13-STABLE-RELEASE.json');assert.equal(m.canonical_package_generation,3);assert.equal(m.release_gate.status,'passed');assert.equal(m.release_gate.runtime_files_frozen,true);assert.equal(m.development_paused,true);assert.equal(m.change_policy,'bugfix-only-until-explicit-reopen');assert.deepEqual(m.package_files,files);assert.equal(files.length,31);for(const f of files)assert.ok(fs.existsSync(f),\`missing package dependency \${f}\`);});\n\ntest('canonical launcher is offline and opens v1.8 Stable',()=>{assert.match(launcher,/RAH-COMMAND-CENTER-V1\\.8\\.html/);assert.match(launcher,/v1\\.8\\.0 STABLE/);assert.doesNotMatch(launcher,/Invoke-WebRequest|curl\\b|wget\\b|https?:\\/\\//i)});\n\ntest('Node launchers retain exact Stable Node 1.3',()=>{assert.match(nodeBat,/rah-node-agent-v1\\.3\\.py/);assert.match(nodeSh,/rah-node-agent-v1\\.3\\.py/);assert.doesNotMatch(nodeBat,/rah-node-agent\\.py" --allow-lan/);assert.doesNotMatch(nodeSh,/python3 \\.\\/rah-node-agent\\.py --allow-lan/)});\n\ntest('manual updater pins exact immutable 31-file closure and v1.8 release',()=>{for(const f of files)assert.ok(up.includes('"'+f+'"'),f);assert.match(up,/Resolve-VerifiedRepositoryCommit/);assert.match(up,/commit\\.verification\\.verified/);assert.match(up,/Assert-FixedPackageContract/);assert.match(up,/Assert-StableReleaseContract/);assert.match(up,/manifest\\.version-ne"1\\.8\\.0"/);assert.match(up,/release_gate\\.runtime_files_frozen/);assert.match(up,/RAH-CC18-NODE13-STABLE-RELEASE\\.json/)});\n\ntest('canonical authority stays frozen and one-shot policy is exact',()=>{assert.equal(release.commandCenterVersion,'1.8.0');assert.equal(release.nodeAgentVersion,'1.3.0');assert.equal(release.nodeActionsProtocol,'rah-node-actions-v7');assert.equal(release.authProtocol,'rah-node-auth-v2');assert.equal(release.nodeRuntimeChange,false);assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);assert.deepEqual(release.oneShotApproval.requiredActions,['rustdesk.launch','rustdesk.connect']);assert.equal(release.oneShotApproval.readOnlyStorageRequiresOneShot,false);assert.equal(release.oneShotApproval.ttlMs,90000);assert.equal(release.oneShotApproval.maxOutstanding,32);assert.equal(release.oneShotApproval.memoryOnly,true);assert.equal(release.oneShotApproval.persistent,false);assert.equal(release.oneShotApproval.singleUse,true);assert.equal(release.oneShotApproval.consumeBeforeNodeLocalConfirmation,true);assert.equal(release.oneShotApproval.consumeOnBindingMismatch,true);assert.equal(release.oneShotApproval.storesRawTarget,false);assert.equal(m.features.one_shot_mutating_approval,true);assert.equal(m.features.one_shot_math_random_fallback,false);});\n`;
fs.writeFileSync(packagingPath,packaging);

const workflow=`name: Validate RAH Command Center Canonical v1.8\non:\n  pull_request:\n    paths:\n      - 'RAH-COMMAND-CENTER-VERSION.json'\n      - 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'\n      - 'START-RAH-NODE-AGENT.bat'\n      - 'START-RAH-NODE-AGENT.sh'\n      - 'UPDATE-RAH-COMMAND-CENTER.ps1'\n      - 'RAH-COMMAND-CENTER-V1.8.html'\n      - 'RAH-COMMAND-CENTER-V1.8-CANDIDATE.html'\n      - 'rah-command-center-core-v1.8.js'\n      - 'rah-command-center-core-v1.8-candidate.js'\n      - 'RAH-CC18-ONE-SHOT-MUTATING-APPROVAL-CANDIDATE.json'\n      - 'RAH-CC18-NODE13-STABLE-RELEASE.json'\n      - 'rah-node-agent-v1.3.py'\n      - 'tests/rah-command-center-packaging.test.mjs'\n      - 'tests/rah-cc18-one-shot-mutating-approval.test.mjs'\n      - 'tests/rah-cc18-stable-release.test.mjs'\n      - 'tests/test_rah_node_agent_stable_v13.py'\n      - '.github/workflows/validate-rah-command-center.yml'\n  push:\n    branches: [main]\n    paths:\n      - 'RAH-COMMAND-CENTER-VERSION.json'\n      - 'DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat'\n      - 'START-RAH-NODE-AGENT.bat'\n      - 'START-RAH-NODE-AGENT.sh'\n      - 'UPDATE-RAH-COMMAND-CENTER.ps1'\n      - 'RAH-COMMAND-CENTER-V1.8.html'\n      - 'RAH-COMMAND-CENTER-V1.8-CANDIDATE.html'\n      - 'rah-command-center-core-v1.8.js'\n      - 'rah-command-center-core-v1.8-candidate.js'\n      - 'RAH-CC18-ONE-SHOT-MUTATING-APPROVAL-CANDIDATE.json'\n      - 'RAH-CC18-NODE13-STABLE-RELEASE.json'\n      - 'rah-node-agent-v1.3.py'\n      - 'tests/rah-command-center-packaging.test.mjs'\n      - 'tests/rah-cc18-one-shot-mutating-approval.test.mjs'\n      - 'tests/rah-cc18-stable-release.test.mjs'\n      - 'tests/test_rah_node_agent_stable_v13.py'\n      - '.github/workflows/validate-rah-command-center.yml'\npermissions: {contents: read}\njobs:\n  validate:\n    runs-on: ubuntu-latest\n    timeout-minutes: 18\n    steps:\n      - uses: actions/checkout@v4\n      - uses: actions/setup-node@v4\n        with: {node-version: '22'}\n      - uses: actions/setup-python@v5\n        with: {python-version: '3.12'}\n      - name: Preserve root compatibility core and historical UI contracts\n        run: |\n          node --test tests/rah-command-center-core.test.mjs\n          node --test tests/rah-command-center-v05.test.mjs\n          node --test tests/rah-command-center-v06.test.mjs\n          node --test tests/rah-command-center-v07.test.mjs\n          node --test tests/rah-command-center-v08.test.mjs\n          node --test tests/rah-command-center-v09.test.mjs\n          node --test tests/rah-command-center-v10.test.mjs\n          node --test tests/rah-command-center-v11.test.mjs\n          RAH_CC_V12_SECTION=ui node --test tests/rah-command-center-v12.test.mjs\n          RAH_CC_V12_SECTION=agent node --test tests/rah-command-center-v12.test.mjs\n          RAH_CC_V12_SECTION=core node --test tests/rah-command-center-v12.test.mjs\n      - name: Validate canonical v1.8 package closure\n        run: node --test tests/rah-command-center-packaging.test.mjs\n      - name: Re-run v1.8 one-shot Candidate matrix\n        run: node --test tests/rah-cc18-one-shot-mutating-approval.test.mjs\n      - name: Re-run v1.8 Stable release pins\n        run: node --test tests/rah-cc18-stable-release.test.mjs\n      - name: Re-run Stable Node Agent 1.3 live boundary\n        run: python3 -m unittest tests/test_rah_node_agent_stable_v13.py -v\n      - name: Preserve Raven 2.0.32 release gate\n        run: node --test tests/raven-release-gate.test.mjs\n      - name: Parse manual PowerShell updater scripts\n        shell: pwsh\n        run: |\n          [void][scriptblock]::Create((Get-Content -LiteralPath ./UPDATE-RAH-COMMAND-CENTER.ps1 -Raw))\n          [void][scriptblock]::Create((Get-Content -LiteralPath ./UPDATE-RAH-RAVEN.ps1 -Raw))\n`;
fs.writeFileSync(workflowPath,workflow);

const finalManifest=JSON.parse(fs.readFileSync(manifestPath,'utf8'));
assert.equal(finalManifest.version,'1.8.0');
assert.equal(finalManifest.package_files.length,31);
assert.equal(finalManifest.features.one_shot_mutating_approval,true);
console.log('CC v1.8 canonical root files generated: 7 permanent files, 31-file closure.');
