import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const release=JSON.parse(fs.readFileSync(path.join(ROOT,'RAH-NODE14-RAVEN-STATUS-STABLE-RELEASE.json'),'utf8'));
function blobSha(rel){const data=fs.readFileSync(path.join(ROOT,rel));const head=Buffer.from(`blob ${data.length}\0`);return crypto.createHash('sha1').update(head).update(data).digest('hex')}

assert.equal(release.schemaVersion,1);
assert.equal(release.stage,'stable-release');
assert.equal(release.releaseId,'rah-node14-raven-status-stable-v1');
assert.equal(release.authorityDelta,'fixed-read-only-route-addition');
assert.equal(release.nodeAgentVersion,'1.4.0');
assert.equal(release.authProtocol,'rah-node-auth-v2');
assert.equal(release.ravenStatusProtocol,'rah-node-raven-status-v1');
assert.equal(release.ravenStatusRoute,'/raven/status');
assert.equal(release.ravenStatusFixedCapability,'system-inventory');
assert.deepEqual(release.authoritySurface.newBusinessRoutes,['/raven/status']);
const route=release.authoritySurface.newRouteProperties['/raven/status'];
assert.equal(route.method,'GET');
assert.equal(route.mutating,false);
assert.equal(route.requiresCapability,'compute');
assert.equal(route.fixedRavenCapability,'system-inventory');
assert.equal(route.localRavenHop,'http://127.0.0.1:18765');
assert.equal(route.callerControlledArguments,false);
assert.equal(route.callerControlledPath,false);
assert.equal(route.arbitraryCommands,false);
assert.equal(route.backgroundPolling,false);

for(const row of [release.runtime.nodeAgent,release.runtime.windowsStarter,release.runtime.linuxStarter,release.pinnedCandidate.nodeAgent,release.directRollback.nodeAgent,release.directRollback.release,release.canonicalCompatibility.canonicalWindowsStarter,release.canonicalCompatibility.canonicalLinuxStarter]){
  assert.equal(blobSha(row.path),row.gitBlobSha,`Blob pin mismatch: ${row.path}`);
}
assert.equal(release.runtime.windowsStarter.path,'START-RAH-NODE-AGENT-V1.4.bat');
assert.equal(release.runtime.linuxStarter.path,'START-RAH-NODE-AGENT-V1.4.sh');
assert.equal(release.canonicalCompatibility.commandCenterVersion,'2.3.0');
assert.equal(release.canonicalCompatibility.canonicalWindowsStarter.nodeAgentVersion,'1.3.0');
assert.equal(release.canonicalCompatibility.canonicalLinuxStarter.nodeAgentVersion,'1.3.0');
assert.equal(release.canonicalCompatibility.policy,'preserve-cc23-canonical-until-cc24-stable-promotion');
assert.equal(release.directRollback.nodeAgentVersion,'1.3.0');
assert.equal(release.directRollback.dataMigration,'none');
assert.equal(release.directRollback.secretMigration,'none');
assert.equal(release.directRollback.registryMigration,'none');
assert.equal(release.freezeAfterPromotion,true);

const bat=fs.readFileSync(path.join(ROOT,'START-RAH-NODE-AGENT-V1.4.bat'),'utf8');
for(const marker of ['RAH NODE AGENT v1.4 STABLE','rah-node-agent-v1.4.py','rah-node-agent-v1.4-candidate.py','raw.githubusercontent.com/NilsRa73/rah-platform/main','127.0.0.1:18765','HMAC-SHA256'])assert.ok(bat.includes(marker),`Versioned Windows starter missing ${marker}`);
assert.equal(/Invoke-Expression|\biex\b|DownloadString/i.test(bat),false,'Versioned Windows starter must not dynamically execute downloaded text');

const sh=fs.readFileSync(path.join(ROOT,'START-RAH-NODE-AGENT-V1.4.sh'),'utf8');
for(const marker of ['RAH NODE AGENT v1.4 STABLE','rah-node-agent-v1.4.py','rah-node-agent-v1.4-candidate.py','raw.githubusercontent.com/NilsRa73/rah-platform/main','127.0.0.1:18765'])assert.ok(sh.includes(marker),`Versioned Linux starter missing ${marker}`);
assert.equal(/eval\s|sh\s+-c|bash\s+-c/.test(sh),false,'Versioned Linux starter must not dynamically execute downloaded text');

const canonicalBat=fs.readFileSync(path.join(ROOT,'START-RAH-NODE-AGENT.bat'),'utf8');
const canonicalSh=fs.readFileSync(path.join(ROOT,'START-RAH-NODE-AGENT.sh'),'utf8');
assert.match(canonicalBat,/RAH Node Agent 1\.3 Stable/);
assert.match(canonicalBat,/rah-node-agent-v1\.3\.py/);
assert.match(canonicalSh,/RAH NODE AGENT v1\.3 STABLE/);
assert.match(canonicalSh,/rah-node-agent-v1\.3\.py/);
assert.doesNotMatch(canonicalBat,/rah-node-agent-v1\.4/);
assert.doesNotMatch(canonicalSh,/rah-node-agent-v1\.4/);

const stable=fs.readFileSync(path.join(ROOT,'rah-node-agent-v1.4.py'),'utf8');
for(const marker of ["AGENT_VERSION = '1.4.0'","Stage: Stable","RAVEN_STATUS_ROUTE","RAVEN_FIXED_CAPABILITY = _impl.RAVEN_FIXED_CAPABILITY","RAHNodeAgent/1.4"])assert.ok(stable.includes(marker),`Stable wrapper missing ${marker}`);
assert.equal(stable.includes('subprocess'),false,'Stable wrapper must not add a new process execution surface');
assert.equal(stable.includes('os.system'),false,'Stable wrapper must not add shell execution');

console.log('Node Agent 1.4 Stable release contract: OK');
