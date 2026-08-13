import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync('raven-handoff-receipt.js','utf8');
const sandbox={globalThis:{}};
vm.createContext(sandbox);
vm.runInContext(source,sandbox,{filename:'raven-handoff-receipt.js'});
const api=sandbox.globalThis.RavenHandoffReceipt;
assert.ok(api,'shared Handoff Receipt API missing');
assert.equal(api.API_VERSION,'1.0.0');
assert.deepEqual(Array.from(api.QUERY_KEYS),['handoffReturn','handoffStatus','handoffImage']);

const params=values=>({get:key=>Object.prototype.hasOwnProperty.call(values,key)?values[key]:null});
assert.equal(api.parse(null),null);
assert.equal(api.parse({}),null);
assert.equal(api.parse(params({handoffReturn:'no'})),null);

const ready=api.parse(params({handoffReturn:'ready',handoffStatus:'ready',handoffImage:'ready'}));
assert.equal(ready.status,true);
assert.equal(ready.image,true);
assert.equal(Object.isFrozen(ready),true);
const statusOnly=api.parse(params({handoffReturn:'ready',handoffStatus:'ready'}));
assert.equal(statusOnly.status,true);
assert.equal(statusOnly.image,false);
const unknown=api.parse(params({handoffReturn:'ready'}));
assert.equal(unknown.status,false);
assert.equal(unknown.image,false);

const described=api.describe(ready);
assert.equal(described.statusText,'STATUS: KLAR');
assert.equal(described.imageText,'BILDE: KLAR');
assert.match(described.meta,/bekrefter ikke mottak i ChatGPT/);
assert.equal(Object.isFrozen(described),true);
assert.equal(api.describe(statusOnly).imageText,'BILDE: IKKE MARKERT');
assert.equal(api.describe(unknown).statusText,'STATUS: UKJENT');
assert.match(api.describe(null).meta,/Ingen gyldig Handoff-returmarkør/);

for(const forbidden of [
  /localStorage/,/sessionStorage/,/setItem\(/,/removeItem\(/,/fetch\(/,/XMLHttpRequest/,
  /navigator\./,/location\./,/history\./,/window\.open/,/writeState\(/,/activeMission\s*=/,
  /activeProject\s*=/,/\/agent\/run/
])assert.doesNotMatch(source,forbidden);
assert.doesNotMatch(source,/prompt|analysis|answer|imageData|dataUrl|Blob\(/i);
console.log('Shared Handoff Receipt policy v1.0.0 is pure, URL-value-based and read-only.');
