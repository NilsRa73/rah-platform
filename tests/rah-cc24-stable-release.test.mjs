import assert from 'node:assert/strict';
import fs from 'node:fs';
import crypto from 'node:crypto';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import candidate from '../rah-command-center-core-v2.4-candidate.js';
import stable from '../rah-command-center-core-v2.4.js';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const release=JSON.parse(fs.readFileSync(path.join(ROOT,'RAH-CC24-NODE14-STABLE-RELEASE.json'),'utf8'));
function blobSha(rel){const data=fs.readFileSync(path.join(ROOT,rel));const head=Buffer.from(`blob ${data.length}\0`);return crypto.createHash('sha1').update(head).update(data).digest('hex')}

assert.equal(stable.CC_VERSION,'2.4.0');
assert.equal(candidate.CC_VERSION,'2.4.0-candidate');
for(const key of ['RAVEN_COMMANDER_VERSION','RAVEN_STATUS_PROTOCOL','RAVEN_STATUS_ROUTE','RAVEN_STATUS_CAPABILITY','NODE_AUTH_PROTOCOL','ALLOWLIST_POLICY_ID'])assert.equal(stable[key],candidate[key],`Stable drift: ${key}`);
for(const key of ['nodeRavenStatusUrl','nodeRavenStatusRequest','buildRavenStatusAuthCanonical','attachRavenStatusAuthProof','sanitizeRavenStatusPayload','ravenCommanderEligibleDevice'])assert.equal(stable[key],candidate[key],`Stable must pin Candidate function: ${key}`);
assert.equal(stable.RAVEN_COMMANDER_VERSION,'rah-cc-raven-commander-v1');
assert.equal(stable.RAVEN_STATUS_PROTOCOL,'rah-node-raven-status-v1');
assert.equal(stable.RAVEN_STATUS_ROUTE,'/raven/status');
assert.equal(stable.RAVEN_STATUS_CAPABILITY,'system-inventory');
assert.equal(stable.NODE_AUTH_PROTOCOL,'rah-node-auth-v2');

assert.equal(release.schemaVersion,1);
assert.equal(release.stage,'stable-release');
assert.equal(release.releaseId,'rah-cc24-node14-raven-commander-stable-v1');
assert.equal(release.commandCenterVersion,'2.4.0');
assert.equal(release.nodeAgentVersion,'1.4.0');
assert.equal(release.ravenCommanderVersion,'rah-cc-raven-commander-v1');
assert.equal(release.ravenStatusProtocol,'rah-node-raven-status-v1');
assert.equal(release.ravenStatusRoute,'/raven/status');
assert.equal(release.ravenStatusFixedCapability,'system-inventory');
for(const row of [release.runtime.commandCenterCore,release.runtime.commandCenterHtml,release.runtime.nodeAgent,release.runtime.nodeStableRelease,release.pinnedCandidate.commandCenterCore,release.pinnedCandidate.commandCenterHtml,release.pinnedCandidate.nodeAgent,release.directRollback.previousStableRelease,release.directRollback.commandCenterCore,release.directRollback.commandCenterHtml,release.directRollback.nodeAgent])assert.equal(blobSha(row.path),row.gitBlobSha,`Blob pin mismatch: ${row.path}`);
assert.equal(release.directRollback.commandCenterVersion,'2.3.0');
assert.equal(release.directRollback.nodeAgentVersion,'1.3.0');
assert.equal(release.directRollback.dataMigration,'none');
assert.equal(release.directRollback.secretMigration,'none');
assert.equal(release.directRollback.registryMigration,'none');
assert.equal(release.targetCanonicalPackageGeneration,9);
assert.equal(release.canonicalRootPromotion,'separate-phase-required');
assert.equal(release.freezeAfterPromotion,true);

const route=release.authoritySurface.newRoute;
assert.equal(route.path,'/raven/status');
assert.equal(route.method,'GET');
assert.equal(route.mutating,false);
assert.equal(route.requiresCapability,'compute');
assert.equal(route.fixedRavenCapability,'system-inventory');
assert.equal(route.localRavenHop,'http://127.0.0.1:18765');
for(const key of ['callerControlledArguments','callerControlledPath','arbitraryCommands','backgroundPolling','automaticExecution','tokenPersistence'])assert.equal(route[key],false,key);
for(const [key,value] of Object.entries({manualClickRequired:true,freshNodeTokenMemoryOnly:true,freshNodeTokenClearedAfterRequest:true,authorizationBearerFallback:false,sourceBoundSingleUseNonce:true,hmacSha256Proof:true,nodeSessionExactMatch:true,payloadReadOnlyProofRequired:true,payloadFilesModifiedFalseRequired:true,payloadArbitraryCommandsFalseRequired:true,localOnlyHopRequired:true,backgroundPolling:false,networkDiscovery:false,genericShell:false,genericFileApi:false,genericProcessApi:false}))assert.equal(release.commanderBoundary[key],value,key);

const html=fs.readFileSync(path.join(ROOT,'RAH-COMMAND-CENTER-V2.4.html'),'utf8');
for(const marker of ['RAVEN COMMANDER STABLE','v2.4 Stable','HENT RAVEN SYSTEMSTATUS','Node Agent 1.4 Stable','rah-command-center-core-v2.4-candidate.js','rah-command-center-core-v2.4.js','RAH-COMMAND-CENTER-V2.3.html',"core.CC_VERSION!=='2.4.0'","q('ravenToken').value=''"])assert.ok(html.includes(marker),`Stable UI missing ${marker}`);
assert.equal(html.includes('setInterval('),false,'No Commander background polling');
assert.equal(/localStorage\.setItem\([^\n]*ravenToken/i.test(html),false,'Node token must not persist');
assert.equal(html.includes('Authorization:'),false,'No Bearer fallback');
assert.equal(html.includes('/shell'),false,'No shell endpoint');
assert.equal(html.includes('/command'),false,'No generic command endpoint');

console.log('CC 2.4 Stable Raven Commander promotion: OK');
