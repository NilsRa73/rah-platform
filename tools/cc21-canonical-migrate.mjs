import fs from 'node:fs';

const manifestPath='RAH-COMMAND-CENTER-VERSION.json';
const updaterPath='UPDATE-RAH-COMMAND-CENTER.ps1';
const launcherPath='DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat';
const nodeBatPath='START-RAH-NODE-AGENT.bat';
const workflowPath='.github/workflows/validate-rah-command-center.yml';
const testPath='tests/rah-command-center-packaging.test.mjs';

function read(p){return fs.readFileSync(p,'utf8')}
function write(p,s){fs.writeFileSync(p,s)}
function mustReplace(text,from,to,label){if(!text.includes(from))throw new Error('Missing '+label+': '+from);return text.replace(from,to)}
function count(text,needle){return text.split(needle).length-1}

const nextFiles=[
  'RAH-COMMAND-CENTER-V2.1.html',
  'RAH-COMMAND-CENTER-V2.1-CANDIDATE.html',
  'rah-command-center-core-v2.1-candidate.js',
  'rah-command-center-core-v2.1.js',
  'RAH-CC21-FLEET-SNAPSHOT-CANDIDATE.json',
  'RAH-CC21-NODE13-STABLE-RELEASE.json'
];

const m=JSON.parse(read(manifestPath));
if(m.version!=='2.0.0'||m.stage!=='stable'||m.entry!=='RAH-COMMAND-CENTER-V2.0.html'||m.runtime!=='rah-command-center-core-v2.0.js')throw new Error('Canonical input is not exact CC 2.0 Stable');
if(m.stable_release_manifest!=='RAH-CC20-NODE13-STABLE-RELEASE.json'||m.canonical_package_generation!==5||m.package_files.length!==43)throw new Error('Unexpected CC 2.0 canonical package baseline');
for(const f of nextFiles)if(m.package_files.includes(f))throw new Error('CC 2.1 artifact already present: '+f);
m.version='2.1.0';
m.entry='RAH-COMMAND-CENTER-V2.1.html';
m.runtime='rah-command-center-core-v2.1.js';
m.previous_stable_version='2.0.0';
m.package_files=[...nextFiles,...m.package_files];
m.features.canonical_package_dependency_count=49;
delete m.features.canonical_v20_package;
m.features.canonical_v21_package=true;
m.features.manual_fleet_snapshot=true;
m.features.fleet_snapshot_version='rah-cc-fleet-snapshot-v1';
m.features.fleet_snapshot_scope='already-enrolled-devices-only';
m.features.fleet_snapshot_explicit_selected_device_refresh=true;
m.features.fleet_snapshot_fresh_node_token_per_refresh=true;
m.features.fleet_snapshot_token_proof_authentication=true;
m.features.fleet_snapshot_session_match_required=true;
m.features.fleet_snapshot_token_persistence=false;
m.features.fleet_snapshot_memory_only=true;
m.features.fleet_snapshot_persistence=false;
m.features.fleet_snapshot_background_polling=false;
m.features.fleet_snapshot_network_discovery=false;
m.features.fleet_snapshot_automatic_storage_read=false;
m.features.fleet_snapshot_automatic_remote_control=false;
m.features.fleet_snapshot_mutating_actions=false;
m.features.fleet_snapshot_cross_session_refresh_fails_closed=true;
m.release_gate.gate_version='2.4.0';
m.release_gate.requires_tests=['tests/rah-command-center-packaging.test.mjs','tests/rah-cc21-fleet-snapshot.test.mjs','tests/rah-cc21-stable-release.test.mjs','tests/test_rah_node_agent_stable_v13.py'];
m.stable_release_manifest='RAH-CC21-NODE13-STABLE-RELEASE.json';
m.canonical_package_generation=6;
write(manifestPath,JSON.stringify(m,null,2)+'\n');

let launcher=read(launcherPath);
launcher=mustReplace(launcher,'RAH-COMMAND-CENTER-V2.0.html','RAH-COMMAND-CENTER-V2.1.html','launcher entry');
launcher=mustReplace(launcher,'v2.0.0 STABLE','v2.1.0 STABLE','launcher version');
launcher=mustReplace(launcher,'i v2.0;','i v2.1;','launcher token-proof text');
launcher=mustReplace(launcher,'RAH-COMMAND-CENTER-V2.0.html ble ikke funnet','RAH-COMMAND-CENTER-V2.1.html ble ikke funnet','launcher missing text');
write(launcherPath,launcher);

let nodeBat=read(nodeBatPath);
nodeBat=mustReplace(nodeBat,'for v2.0-pakken.','for v2.1-pakken.','Node launcher package hint');
write(nodeBatPath,nodeBat);

let updater=read(updaterPath);
if(!updater.includes('$AllowedPackageFiles=@('))throw new Error('Updater fixed allowlist marker missing');
const eol=updater.includes('\r\n')?'\r\n':'\n';
const allowMarker='$AllowedPackageFiles=@('+eol;
if(count(updater,allowMarker)!==1)throw new Error('Updater allowlist marker is not unique');
const insert=nextFiles.map(x=>'  "'+x+'",').join(eol)+eol;
updater=updater.replace(allowMarker,allowMarker+insert);
const stableFn=/function Assert-StableReleaseContract\{[^\r\n]+\}/;
if(!stableFn.test(updater))throw new Error('Updater Stable contract function not found');
updater=updater.replace(stableFn,'function Assert-StableReleaseContract{param($Release)if($Release.stage-ne"stable-release"){throw "Stable release-manifest har feil stage."};if($Release.commandCenterVersion-ne"2.1.0"-or $Release.nodeAgentVersion-ne"1.3.0"){throw "Stable release-manifest har uventet CC/Node-versjon."};if($Release.nodeActionsProtocol-ne"rah-node-actions-v7"-or $Release.authProtocol-ne"rah-node-auth-v2"-or $Release.policyId-ne"rah-capability-allowlist-v1"){throw "Stable release-manifest har uventet protokoll/policy."};$caps=@($Release.authoritySurface.capabilities);$actions=@($Release.authoritySurface.actions);$routes=@($Release.authoritySurface.businessRoutes);if(($caps -join \",\")-ne\"compute,storage,display,remote-desktop\"){throw "Stable release har uventet capability authority."};if(($actions -join \",\")-ne\"storage-summary.read,rustdesk.launch,rustdesk.connect\"){throw "Stable release har uventet action authority."};if(($routes -join \",\")-ne\"/health,/actions,/storage,/launch/rustdesk,/handoff/rustdesk\"){throw "Stable release har uventet route authority."};if($Release.fleetSnapshot.version-ne"rah-cc-fleet-snapshot-v1"-or $Release.fleetSnapshot.scope-ne"already-enrolled-devices-only"-or -not $Release.fleetSnapshot.freshNodeTokenRequiredPerRefreshClick-or -not $Release.fleetSnapshot.tokenProofAuthenticationRequired-or -not $Release.fleetSnapshot.sessionMatchRequired-or $Release.fleetSnapshot.tokenPersistence-or $Release.fleetSnapshot.snapshotPersistence-or $Release.fleetSnapshot.backgroundPolling-or $Release.fleetSnapshot.networkDiscovery-or $Release.fleetSnapshot.automaticRemoteControl){throw "Stable release har uventet Fleet Snapshot boundary."}}');
for(const [a,b,label] of [
  ['Start RAH Raven Command Center v2.0 Stable','Start RAH Raven Command Center v2.1 Stable','shortcut description'],
  ['Starter eksplisitt RAH Command Center v2.0 pakkeoppdatering.','Starter eksplisitt RAH Command Center v2.1 pakkeoppdatering.','update start log'],
  ['manifest.version-ne"2.0.0"','manifest.version-ne"2.1.0"','manifest version'],
  ['canonical v2.0 Stable','canonical v2.1 Stable','manifest error text'],
  ['RAH-COMMAND-CENTER-V2.0.html"-or [string]$manifest.runtime-ne"rah-command-center-core-v2.0.js','RAH-COMMAND-CENTER-V2.1.html"-or [string]$manifest.runtime-ne"rah-command-center-core-v2.1.js','canonical entry runtime'],
  ['RAH-CC20-NODE13-STABLE-RELEASE.json','RAH-CC21-NODE13-STABLE-RELEASE.json','stable release path'],
  ['Command Center v2.0 Stable klar fra verifisert commit','Command Center v2.1 Stable klar fra verifisert commit','final update log'],
  ['RAH Command Center v2.0 Stable er klar.','RAH Command Center v2.1 Stable er klar.','final console text']
])updater=mustReplace(updater,a,b,label);
write(updaterPath,updater);

let wf=read(workflowPath);
wf=mustReplace(wf,'Validate RAH Command Center Canonical v2.0','Validate RAH Command Center Canonical v2.1','workflow name');
const updaterPathLine="      - 'UPDATE-RAH-COMMAND-CENTER.ps1'"+eol;
if(count(wf,updaterPathLine)!==2)throw new Error('Expected updater path twice in canonical workflow');
const wfInsert=nextFiles.map(x=>"      - '"+x+"'").join(eol)+eol;
wf=wf.split(updaterPathLine).join(updaterPathLine+wfInsert);
wf=wf.split("tests/rah-cc20-precommitted-requester-context.test.mjs").join("tests/rah-cc21-fleet-snapshot.test.mjs");
wf=wf.split("tests/rah-cc20-stable-release.test.mjs").join("tests/rah-cc21-stable-release.test.mjs");
wf=wf.split('canonical v2.0 package closure').join('canonical v2.1 package closure');
wf=wf.split('v2.0 precommitted requester-context Candidate matrix').join('v2.1 Manual Fleet Snapshot Candidate matrix');
wf=wf.split('CC 2.0 Stable release pins').join('CC 2.1 Stable release pins');
write(workflowPath,wf);

const expected=[...nextFiles,
  'RAH-COMMAND-CENTER-V2.0.html','RAH-COMMAND-CENTER-V2.0-CANDIDATE.html','rah-command-center-core-v2.0-candidate.js','rah-command-center-core-v2.0.js','RAH-CC20-PRECOMMITTED-REQUESTER-CONTEXT-CANDIDATE.json','RAH-CC20-NODE13-STABLE-RELEASE.json',
  'RAH-COMMAND-CENTER-V1.9.html','RAH-COMMAND-CENTER-V1.9-CANDIDATE.html','rah-command-center-core-v1.9-candidate.js','rah-command-center-core-v1.9.js','RAH-CC19-IMMUTABLE-MUTATING-INTENT-CANDIDATE.json','RAH-CC19-NODE13-STABLE-RELEASE.json','RAH-COMMAND-CENTER-V1.8.html','RAH-COMMAND-CENTER-V1.8-CANDIDATE.html','RAH-COMMAND-CENTER-V1.7.html','RAH-COMMAND-CENTER-V1.7-CANDIDATE.html','RAH-COMMAND-CENTER-V1.2.html','rah-command-center-core.js','rah-command-center-core-v1.3.js','rah-command-center-core-v1.4.js','rah-command-center-core-v1.5-candidate.js','rah-command-center-core-v1.5.js','rah-command-center-core-v1.6-candidate.js','rah-command-center-core-v1.6.js','rah-command-center-core-v1.7-candidate.js','rah-command-center-core-v1.7.js','rah-command-center-core-v1.8-candidate.js','rah-command-center-core-v1.8.js','DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','rah-node-agent.py','rah-node-agent-v0.9.py','rah-node-agent-v1.0-candidate.py','rah-node-agent-v1.0.py','rah-node-agent-v1.1-candidate.py','rah-node-agent-v1.1.py','rah-node-agent-v1.2-candidate.py','rah-node-agent-v1.3-candidate.py','rah-node-agent-v1.3.py','START-RAH-NODE-AGENT.bat','START-RAH-NODE-AGENT.sh','RAH-CC17-NODE13-STABLE-RELEASE.json','RAH-CC18-ONE-SHOT-MUTATING-APPROVAL-CANDIDATE.json','RAH-CC18-NODE13-STABLE-RELEASE.json'
];
if(expected.length!==49)throw new Error('Expected package closure length drift');
const test=`import test from'node:test';\nimport assert from'node:assert/strict';\nimport fs from'node:fs';\nconst m=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));\nconst release=JSON.parse(fs.readFileSync('RAH-CC21-NODE13-STABLE-RELEASE.json','utf8'));\nconst up=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');\nconst launcher=fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','utf8');\nconst nodeBat=fs.readFileSync('START-RAH-NODE-AGENT.bat','utf8');\nconst nodeSh=fs.readFileSync('START-RAH-NODE-AGENT.sh','utf8');\nconst files=${JSON.stringify(expected)};\n\ntest('canonical v2.1 Stable package closure',()=>{assert.equal(m.version,'2.1.0');assert.equal(m.stage,'stable');assert.equal(m.entry,'RAH-COMMAND-CENTER-V2.1.html');assert.equal(m.runtime,'rah-command-center-core-v2.1.js');assert.equal(m.previous_stable_version,'2.0.0');assert.equal(m.stable_release_manifest,'RAH-CC21-NODE13-STABLE-RELEASE.json');assert.equal(m.canonical_package_generation,6);assert.equal(m.features.canonical_package_dependency_count,49);assert.equal(m.release_gate.status,'passed');assert.equal(m.release_gate.runtime_files_frozen,true);assert.equal(m.development_paused,true);assert.deepEqual(m.package_files,files);assert.equal(files.length,49);for(const f of files)assert.ok(fs.existsSync(f),f)});\ntest('canonical launcher is offline and opens v2.1 Stable',()=>{assert.match(launcher,/RAH-COMMAND-CENTER-V2\\.1\\.html/);assert.match(launcher,/v2\\.1\\.0 STABLE/);assert.doesNotMatch(launcher,/Invoke-WebRequest|curl\\b|wget\\b|https?:\\/\\//i)});\ntest('Node launchers retain exact Stable Node 1.3',()=>{assert.match(nodeBat,/rah-node-agent-v1\\.3\\.py/);assert.match(nodeSh,/rah-node-agent-v1\\.3\\.py/)});\ntest('manual updater pins exact immutable 49-file closure and v2.1 release',()=>{for(const f of files)assert.ok(up.includes('\\"'+f+'\\"'),f);assert.match(up,/Resolve-VerifiedRepositoryCommit/);assert.match(up,/commit\\.verification\\.verified/);assert.match(up,/Assert-FixedPackageContract/);assert.match(up,/Assert-StableReleaseContract/);assert.match(up,/manifest\\.version-ne\\"2\\.1\\.0\\"/);assert.match(up,/RAH-CC21-NODE13-STABLE-RELEASE\\.json/);assert.match(up,/rah-cc-fleet-snapshot-v1/)});\ntest('canonical authority stays frozen and Fleet Snapshot is manual memory-only',()=>{assert.equal(release.commandCenterVersion,'2.1.0');assert.equal(release.nodeAgentVersion,'1.3.0');assert.equal(release.nodeRuntimeChange,false);assert.deepEqual(release.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);assert.deepEqual(release.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);assert.deepEqual(release.authoritySurface.businessRoutes,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);const f=release.fleetSnapshot;assert.equal(f.scope,'already-enrolled-devices-only');assert.equal(f.freshNodeTokenRequiredPerRefreshClick,true);assert.equal(f.tokenProofAuthenticationRequired,true);assert.equal(f.sessionMatchRequired,true);assert.equal(f.snapshotMemoryOnly,true);assert.equal(f.snapshotPersistence,false);assert.equal(f.backgroundPolling,false);assert.equal(f.networkDiscovery,false);assert.equal(f.automaticRemoteControl,false);assert.equal(m.features.manual_fleet_snapshot,true);assert.equal(m.features.fleet_snapshot_memory_only,true);assert.equal(m.features.fleet_snapshot_persistence,false);assert.equal(m.features.fleet_snapshot_background_polling,false);assert.equal(m.features.fleet_snapshot_network_discovery,false)});\n`;
write(testPath,test);

console.log('CC 2.1 canonical migration prepared: 49-file fixed closure, Node 1.3 unchanged, authority unchanged.');
