import assert from 'node:assert/strict';
import crypto from 'node:crypto';
import fs from 'node:fs';
import vm from 'node:vm';

const read=p=>fs.readFileSync(p,'utf8');
const bytes=p=>fs.readFileSync(p);
const json=p=>JSON.parse(read(p));
const blobSha=b=>crypto.createHash('sha1').update(Buffer.from(`blob ${b.length}\0`)).update(b).digest('hex');

const stableHtml=read('RAH-RAVEN-CARE-HUB-V0.5-STABLE.html');
const stableManifest=json('RAH-RAVEN-CARE-HUB-V0.5-STABLE.json');
const candidateHtml=read('RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.html');
const release=json('RAH-RAVEN-CARE-HUB-V0.5-STABLE-RELEASE.json');

assert.equal(stableManifest.product,'RAH Raven Care Hub');
assert.equal(stableManifest.version,'0.5.0');
assert.equal(stableManifest.stage,'stable');
assert.equal(stableManifest.authority_delta,'none');
assert.equal(stableManifest.release_gate.status,'passed');
assert.equal(stableManifest.release_gate.runtime_files_frozen,true);
assert.equal(stableManifest.development_paused,true);
assert.equal(stableManifest.change_policy,'bugfix-only-until-explicit-reopen');

const normalized=candidateHtml
  .replace('<title>RAH Raven Care Hub v0.5 Candidate</title>','<title>RAH Raven Care Hub v0.5 Stable</title>')
  .replace('v0.5 Candidate · eksplisitt lokal read-only handoff','v0.5 Stable · eksplisitt lokal read-only handoff')
  .replace('CANDIDATE · STABLE v0.4 URØRT','STABLE · v0.5')
  .replace("version:'0.5.0-candidate'","version:'0.5.0'");
assert.equal(stableHtml,normalized,'historical v0.5 Stable must remain exact Candidate normalization');
assert.equal(blobSha(bytes('RAH-RAVEN-CARE-HUB-V0.5-STABLE.html')),release.pins.stableHtml.gitBlob);
assert.equal(blobSha(bytes('RAH-RAVEN-CARE-HUB-V0.5-STABLE.json')),release.pins.stableManifest.gitBlob);
assert.equal(blobSha(bytes('RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.html')),release.pins.candidateHtml.gitBlob);
assert.equal(blobSha(bytes('RAH-RAVEN-CARE-HUB-V0.5-CANDIDATE.json')),release.pins.candidateManifest.gitBlob);
assert.equal(release.authorityDelta,'none');
assert.equal(release.dataMigrationRequired,false);
assert.equal(release.rollback.version,'0.4.0');

assert.match(stableHtml,/STABLE · v0\.5/);
assert.doesNotMatch(stableHtml,/\bCANDIDATE\b/i);
assert.equal((stableHtml.match(/fetch\s*\(/g)??[]).length,1);
assert.ok(stableHtml.includes("const CASE_HEALTH_URL='http://127.0.0.1:18765/health'"));
for(const forbidden of ['/case/extract','/case/analyze','/capture/','/lm/','localstorage','sessionstorage','indexeddb','setinterval(','settimeout(','getusermedia','xmlhttprequest'])assert.equal(stableHtml.toLowerCase().includes(forbidden),false,forbidden);
const scripts=[...stableHtml.matchAll(/<script(?:\s[^>]*)?>([\s\S]*?)<\/script>/gi)].map(m=>m[1]);
assert.equal(scripts.length,1);new vm.Script(scripts[0]);

console.log('Raven Care Hub v0.5 historical Stable rollback PASS');
