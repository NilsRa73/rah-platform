import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {execFileSync} from 'node:child_process';

const m=JSON.parse(fs.readFileSync('RAH-COMMAND-CENTER-VERSION.json','utf8'));
const cc=JSON.parse(fs.readFileSync('RAH-CC24-NODE14-STABLE-RELEASE.json','utf8'));
const node=JSON.parse(fs.readFileSync('RAH-NODE14-RAVEN-STATUS-STABLE-RELEASE.json','utf8'));
const launcher=fs.readFileSync('DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat','utf8');
const nodeBat=fs.readFileSync('START-RAH-NODE-AGENT.bat','utf8');
const nodeSh=fs.readFileSync('START-RAH-NODE-AGENT.sh','utf8');
const versionedBat=fs.readFileSync('START-RAH-NODE-AGENT-V1.4.bat','utf8');
const versionedSh=fs.readFileSync('START-RAH-NODE-AGENT-V1.4.sh','utf8');
const updater=fs.readFileSync('UPDATE-RAH-COMMAND-CENTER.ps1','utf8');
const expected=["RAH-COMMAND-CENTER-V2.4.html","RAH-COMMAND-CENTER-V2.4-CANDIDATE.html","rah-command-center-core-v2.4-candidate.js","rah-command-center-core-v2.4.js","RAH-CC24-NODE14-STABLE-RELEASE.json","RAH-COMMAND-CENTER-V2.3.html","RAH-COMMAND-CENTER-V2.3-CANDIDATE.html","rah-command-center-core-v2.3-candidate.js","rah-command-center-core-v2.3.js","RAH-CC23-FLEET-SNAPSHOT-REGISTRY-BINDING-CANDIDATE.json","RAH-CC23-NODE13-STABLE-RELEASE.json","RAH-COMMAND-CENTER-V2.2.html","RAH-COMMAND-CENTER-V2.2-CANDIDATE.html","rah-command-center-core-v2.2-candidate.js","rah-command-center-core-v2.2.js","RAH-CC22-FLEET-SNAPSHOT-INVALIDATION-CANDIDATE.json","RAH-CC22-NODE13-STABLE-RELEASE.json","RAH-COMMAND-CENTER-V2.1.html","RAH-COMMAND-CENTER-V2.1-CANDIDATE.html","rah-command-center-core-v2.1-candidate.js","rah-command-center-core-v2.1.js","RAH-CC21-FLEET-SNAPSHOT-CANDIDATE.json","RAH-CC21-NODE13-STABLE-RELEASE.json","RAH-COMMAND-CENTER-V2.0.html","RAH-COMMAND-CENTER-V2.0-CANDIDATE.html","rah-command-center-core-v2.0-candidate.js","rah-command-center-core-v2.0.js","RAH-CC20-PRECOMMITTED-REQUESTER-CONTEXT-CANDIDATE.json","RAH-CC20-NODE13-STABLE-RELEASE.json","RAH-COMMAND-CENTER-V1.9.html","RAH-COMMAND-CENTER-V1.9-CANDIDATE.html","rah-command-center-core-v1.9-candidate.js","rah-command-center-core-v1.9.js","RAH-CC19-IMMUTABLE-MUTATING-INTENT-CANDIDATE.json","RAH-CC19-NODE13-STABLE-RELEASE.json","RAH-COMMAND-CENTER-V1.8.html","RAH-COMMAND-CENTER-V1.8-CANDIDATE.html","RAH-COMMAND-CENTER-V1.7.html","RAH-COMMAND-CENTER-V1.7-CANDIDATE.html","RAH-COMMAND-CENTER-V1.2.html","rah-command-center-core.js","rah-command-center-core-v1.3.js","rah-command-center-core-v1.4.js","rah-command-center-core-v1.5-candidate.js","rah-command-center-core-v1.5.js","rah-command-center-core-v1.6-candidate.js","rah-command-center-core-v1.6.js","rah-command-center-core-v1.7-candidate.js","rah-command-center-core-v1.7.js","rah-command-center-core-v1.8-candidate.js","rah-command-center-core-v1.8.js","DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat","rah-node-agent.py","rah-node-agent-v0.9.py","rah-node-agent-v1.0-candidate.py","rah-node-agent-v1.0.py","rah-node-agent-v1.1-candidate.py","rah-node-agent-v1.1.py","rah-node-agent-v1.2-candidate.py","rah-node-agent-v1.3-candidate.py","rah-node-agent-v1.3.py","rah-node-agent-v1.4-candidate.py","rah-node-agent-v1.4.py","START-RAH-NODE-AGENT-V1.4.bat","START-RAH-NODE-AGENT-V1.4.sh","RAH-NODE14-RAVEN-STATUS-STABLE-RELEASE.json","START-RAH-NODE-AGENT.bat","START-RAH-NODE-AGENT.sh","RAH-CC17-NODE13-STABLE-RELEASE.json","RAH-CC18-ONE-SHOT-MUTATING-APPROVAL-CANDIDATE.json","RAH-CC18-NODE13-STABLE-RELEASE.json"];

test('generation 9 canonical package is exact 71-file closure',()=>{
  assert.equal(m.version,'2.4.0'); assert.equal(m.stage,'stable');
  assert.equal(m.entry,'RAH-COMMAND-CENTER-V2.4.html');
  assert.equal(m.runtime,'rah-command-center-core-v2.4.js');
  assert.equal(m.previous_stable_version,'2.3.0');
  assert.equal(m.stable_release_manifest,'RAH-CC24-NODE14-STABLE-RELEASE.json');
  assert.equal(m.canonical_package_generation,9);
  assert.equal(m.features.canonical_package_dependency_count,71);
  assert.deepEqual(m.package_files,expected);
  assert.equal(expected.length,71); assert.equal(new Set(expected).size,71);
  for(const f of expected) assert.ok(fs.existsSync(f),f);
});

test('generation 8 remains a complete historical subset',()=>{
  const raw=execFileSync('git',['show','1f5339841958bf0c2b4e737a5307f00029f8cf68:RAH-COMMAND-CENTER-VERSION.json'],{encoding:'utf8'});
  const old=JSON.parse(raw);
  assert.equal(old.version,'2.3.0'); assert.equal(old.canonical_package_generation,8);
  assert.equal(old.package_files.length,61);
  for(const f of old.package_files) assert.ok(expected.includes(f),'missing historical file '+f);
});

test('canonical launchers select CC 2.4 and Node 1.4 without authority widening',()=>{
  assert.match(launcher,/RAH-COMMAND-CENTER-V2\.4\.html/);
  assert.match(launcher,/v2\.4\.0 STABLE/);
  assert.match(launcher,/RAVEN COMMANDER/i);
  assert.doesNotMatch(launcher,/Invoke-WebRequest|curl\b|wget\b|https?:\/\//i);
  assert.equal(nodeBat,versionedBat);
  assert.equal(nodeSh,versionedSh);
  assert.match(nodeBat,/rah-node-agent-v1\.4\.py/);
  assert.match(nodeSh,/rah-node-agent-v1\.4\.py/);
});

test('CC 2.4 Stable Commander boundary is fixed read-only and rollbackable',()=>{
  assert.equal(cc.commandCenterVersion,'2.4.0');
  assert.equal(cc.nodeAgentVersion,'1.4.0');
  assert.equal(cc.ravenCommanderVersion,'rah-cc-raven-commander-v1');
  assert.equal(cc.ravenStatusRoute,'/raven/status');
  assert.equal(cc.ravenStatusFixedCapability,'system-inventory');
  assert.deepEqual(cc.authoritySurface.capabilities,['compute','storage','display','remote-desktop']);
  assert.deepEqual(cc.authoritySurface.actions,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(cc.authoritySurface.newBusinessRoutes,['/raven/status']);
  const r=cc.authoritySurface.newRoute;
  assert.equal(r.method,'GET'); assert.equal(r.mutating,false);
  assert.equal(r.fixedRavenCapability,'system-inventory');
  assert.equal(r.localRavenHop,'http://127.0.0.1:18765');
  assert.equal(r.callerControlledArguments,false); assert.equal(r.callerControlledPath,false);
  assert.equal(r.arbitraryCommands,false); assert.equal(r.backgroundPolling,false);
  assert.equal(cc.directRollback.commandCenterVersion,'2.3.0');
  assert.equal(cc.directRollback.nodeAgentVersion,'1.3.0');
  assert.equal(cc.directRollback.dataMigration,'none');
  assert.equal(cc.directRollback.secretMigration,'none');
  assert.equal(cc.directRollback.registryMigration,'none');
});

test('Node 1.4 Stable exposes only the fixed Raven status delta',()=>{
  assert.equal(node.nodeAgentVersion,'1.4.0');
  assert.equal(node.ravenStatusRoute,'/raven/status');
  assert.equal(node.ravenStatusFixedCapability,'system-inventory');
  assert.deepEqual(node.authoritySurface.newBusinessRoutes,['/raven/status']);
  const r=node.authoritySurface.newRouteProperties['/raven/status'];
  assert.equal(r.method,'GET'); assert.equal(r.mutating,false);
  assert.equal(r.requiresCapability,'compute');
  assert.equal(r.fixedRavenCapability,'system-inventory');
  assert.equal(r.localRavenHop,'http://127.0.0.1:18765');
  assert.equal(r.callerControlledArguments,false); assert.equal(r.callerControlledPath,false);
  assert.equal(r.arbitraryCommands,false); assert.equal(r.backgroundPolling,false);
});

test('package-anchor phase deliberately leaves generation-8 updater immutable',()=>{
  assert.match(updater,/\$ReleaseCommit="1f5339841958bf0c2b4e737a5307f00029f8cf68"/);
  assert.match(updater,/commit\.verification\.verified/);
  assert.match(updater,/rah-cc23-crash-recovery-journal-readiness-v1/);
  assert.match(updater,/\$files\.Count-ne62/);
});
