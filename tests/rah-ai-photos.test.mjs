import assert from 'node:assert/strict';
import fs from 'node:fs';

const html=fs.readFileSync('RAH-AI-PHOTOS.html','utf8');
const js=fs.readFileSync('rah-ai-photos.js','utf8');
const manifest=JSON.parse(fs.readFileSync('RAH-AI-PHOTOS-VERSION.json','utf8'));

assert.equal(manifest.product,'RAH AI Photos');
assert.equal(manifest.edition,'Golden Gallery');
assert.equal(manifest.version,'0.1.0');
assert.equal(manifest.local_only,true);
assert.equal(manifest.features.indexeddb_persistence,true);
assert.equal(manifest.features.external_upload,false);
assert.equal(manifest.features.network_calls,false);
assert.equal(manifest.features.automatic_ai_analysis,false);

assert.match(html,/RAH AI Photos · Golden Gallery v0\.1/);
assert.match(html,/id="fileInput"[^>]*accept="image\/\*"[^>]*multiple/);
assert.match(html,/id="dropzone"/);
assert.match(html,/id="searchInput"/);
assert.match(html,/id="albumFilter"/);
assert.match(html,/id="favoriteFilter"/);
assert.match(html,/id="editorDialog"/);
assert.match(html,/script src="rah-ai-photos\.js"/);

assert.match(js,/indexedDB\.open\(DB_NAME,DB_VERSION\)/);
assert.match(js,/createObjectStore\(STORE,\{keyPath:'id'\}\)/);
assert.match(js,/String\(file\.type\)\.startsWith\('image\/'\)/);
assert.match(js,/album:'Inbox'/);
assert.match(js,/tags:\[\]/);
assert.match(js,/favorite:false/);
assert.match(js,/URL\.createObjectURL\(photo\.blob\)/);
assert.match(js,/storageDelete\(activeId\)/);
assert.match(js,/confirm\(`/);
assert.match(js,/state\.query/);
assert.match(js,/state\.favoritesOnly/);
assert.match(js,/storageMode='memory'/);

for(const forbidden of [/fetch\s*\(/,/XMLHttpRequest/,/WebSocket/,/sendBeacon/,/navigator\.clipboard/,/getUserMedia/]){
  assert.doesNotMatch(js,forbidden,`Golden Gallery v0.1 must stay local-only: ${forbidden}`);
}

console.log('RAH AI Photos Golden Gallery v0.1: local import, IndexedDB gallery, albums, tags, favorites and search OK.');
