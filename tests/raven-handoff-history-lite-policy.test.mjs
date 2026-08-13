import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

const source=fs.readFileSync('raven-handoff-history-lite.js','utf8');
assert.match(source,/API_VERSION='1\.0\.0'/);
assert.match(source,/rah\.raven\.chatgpt-handoff-history-lite-v1/);
assert.match(source,/function normalize\(value\)/);
assert.match(source,/function read\(storage\)/);
assert.match(source,/function describe\(item,locale='nb-NO'\)/);
for(const forbidden of [/setItem\(/,/removeItem\(/,/localStorage/,/sessionStorage/,/fetch\(/,/navigator\./,/location\./,/writeState\(/,/activeMission\s*=/,/activeProject\s*=/,/\.done\s*=/,/\/agent\/run/])assert.doesNotMatch(source,forbidden);

const context={globalThis:{}};
vm.createContext(context);
vm.runInContext(source,context);
const api=context.globalThis.RavenHandoffHistoryLite;
assert.ok(api);
assert.equal(api.API_VERSION,'1.0.0');
assert.equal(api.STORAGE_KEY,'rah.raven.chatgpt-handoff-history-lite-v1');
assert.ok(Object.isFrozen(api));
assert.ok(Object.isFrozen(api.VALID_SURFACES));

const calls=[];
const storage={getItem(key){calls.push(key);return JSON.stringify({version:1,surface:'now',status:true,image:false,savedAt:'2026-08-13T09:00:00.000Z'});}};
const item=api.read(storage);
assert.equal(calls.length,1);
assert.equal(calls[0],api.STORAGE_KEY);
assert.deepEqual(JSON.parse(JSON.stringify(item)),{version:1,surface:'now',status:true,image:false,savedAt:'2026-08-13T09:00:00.000Z'});
assert.ok(Object.isFrozen(item));
assert.equal(api.normalize({version:1,surface:'other'}),null);
assert.equal(api.normalize({version:2,surface:'now'}),null);
assert.equal(api.read({getItem(){return '{bad json';}}),null);
assert.equal(api.read(null),null);

const empty=api.describe(null);
assert.match(empty.title,/Ingen lagret kvittering/);
assert.match(empty.meta,/Ingen prompt, tekst, analyse eller bildefil leses/);
assert.ok(Object.isFrozen(empty));
const view=api.describe(item,'nb-NO');
assert.match(view.title,/Raven Now · STATUS KLAR · UTEN BILDEMARKØR/);
assert.match(view.meta,/Kun metadata fra siste eksplisitt lagrede kvittering leses/);
assert.ok(Object.isFrozen(view));

console.log('Shared Handoff History Lite policy v1.0.0 is read-only, metadata-only and value-based.');
