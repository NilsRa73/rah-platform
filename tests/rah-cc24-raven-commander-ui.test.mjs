import assert from 'node:assert/strict';
import fs from 'node:fs';

const html=fs.readFileSync(new URL('../RAH-COMMAND-CENTER-V2.4-CANDIDATE.html',import.meta.url),'utf8');

for(const marker of [
  'RAVEN COMMANDER · SYSTEM STATUS',
  'HENT RAVEN SYSTEMSTATUS',
  'type="password" autocomplete="off"',
  'RAH-COMMAND-CENTER-V2.3.html',
  'rah-command-center-core-v2.4-candidate.js',
  'core.nodeRavenStatusRequest',
  'core.buildRavenStatusAuthCanonical',
  'core.attachRavenStatusAuthProof',
  'core.sanitizeRavenStatusPayload',
  'q(\'ravenToken\').value=\'\'',
  'Manual click only.',
  'background polling'
]) assert.ok(html.includes(marker),'Missing UI contract marker: '+marker);

assert.equal(html.includes('setInterval('),false,'Commander must not background-poll');
assert.equal(/localStorage\.setItem\([^\n]*ravenToken/i.test(html),false,'Fresh Node token must never be persisted');
assert.equal(html.includes('Authorization:'),false,'No Bearer/Authorization fallback');
assert.equal(html.includes('Invoke-Expression'),false,'No dynamic PowerShell execution surface');
assert.equal(html.includes('/shell'),false,'No shell endpoint');
assert.equal(html.includes('/command'),false,'No generic command endpoint');

const getStatusBody=html.slice(html.indexOf('async function getRavenStatus'),html.indexOf("if(!core||core.CC_VERSION"));
assert.ok(getStatusBody.includes('ravenProofRequest(d,token)'));
assert.ok(getStatusBody.includes('sanitizeRavenStatusPayload'));
assert.ok(getStatusBody.includes("finally{q('ravenToken').value=''}"));

console.log('CC 2.4 Raven Commander UI contract: OK');
