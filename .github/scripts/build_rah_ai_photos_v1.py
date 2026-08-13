from pathlib import Path
import json

html_path=Path('RAH-AI-PHOTOS.html')
html=html_path.read_text(encoding='utf-8')
assert 'Golden Gallery v0.2' in html
assert 'GOLDEN GALLERY · v0.2' in html
html=html.replace('RAH AI Photos · Golden Gallery v0.2','RAH AI Photos · Golden Gallery v1.0')
html=html.replace('GOLDEN GALLERY · v0.2','GOLDEN GALLERY · v1.0')
old_actions='<div class="actions"><span class="badge">LOCAL ONLY</span><span class="badge" id="storageBadge">LAGRING: STARTER…</span><button class="btn primary" id="importButton">＋ IMPORTER BILDER</button><input id="fileInput" type="file" accept="image/*" multiple hidden /></div>'
new_actions='<div class="actions"><span class="badge">LOCAL ONLY</span><span class="badge">STABLE v1.0</span><span class="badge" id="storageBadge">LAGRING: STARTER…</span><button class="btn" id="exportBackup">EKSPORTER BACKUP</button><button class="btn" id="restoreBackup">GJENOPPRETT</button><input id="backupInput" type="file" accept="application/json,.json" hidden /><button class="btn primary" id="importButton">＋ IMPORTER BILDER</button><input id="fileInput" type="file" accept="image/*" multiple hidden /></div>'
assert old_actions in html
html=html.replace(old_actions,new_actions)
old_privacy='Golden Gallery sender ingenting automatisk. Lokal AI kan bare kontaktes på denne maskinen og bare etter et eksplisitt klikk. Forslag blir ikke lagret på bildet før du velger BRUK FORSLAG.'
new_privacy='Golden Gallery sender ingenting automatisk. Lokal AI er loopback-only og krever eksplisitt klikk. Metadata-backup inneholder aldri bildefilene; gjenoppretting valideres først og endrer bare metadata på bilder som allerede finnes.'
assert old_privacy in html
html=html.replace(old_privacy,new_privacy)
html=html.replace('<script src="rah-ai-photos-local-ai.js"></script>','<script src="rah-ai-photos-backup.js"></script>\n<script src="rah-ai-photos-local-ai.js"></script>')
html_path.write_text(html,encoding='utf-8')

backup=Path('rah-ai-photos-backup.js')
backup.write_text(r'''(()=>{
  'use strict';
  const SCHEMA='rah-ai-photos-metadata-backup';
  const SCHEMA_VERSION=1;
  const MAX_ENTRIES=100000;
  const cleanText=(value,max=1200)=>String(value??'').trim().slice(0,max);
  const cleanTags=value=>[...new Set((Array.isArray(value)?value:[]).map(item=>cleanText(item,80)).filter(Boolean))].slice(0,30);
  const fingerprint=photo=>`${cleanText(photo?.name,260)}\u0000${Number(photo?.size)||0}\u0000${cleanText(photo?.type,120)}`;
  function normalizeEntry(source){
    const item=source&&typeof source==='object'?source:{};
    return Object.freeze({
      id:cleanText(item.id,180),name:cleanText(item.name,260),size:Math.max(0,Number(item.size)||0),type:cleanText(item.type,120),
      title:cleanText(item.title,500),album:cleanText(item.album,240)||'Inbox',description:cleanText(item.description,1200),
      tags:Object.freeze(cleanTags(item.tags)),favorite:Boolean(item.favorite)
    });
  }
  function createBackup(photos){
    const entries=(Array.isArray(photos)?photos:[]).map(normalizeEntry);
    return Object.freeze({schema:SCHEMA,schemaVersion:SCHEMA_VERSION,product:'RAH AI Photos',edition:'Golden Gallery',exportedAt:new Date().toISOString(),photoCount:entries.length,imagesIncluded:false,photos:Object.freeze(entries)});
  }
  function validateBackup(data){
    if(!data||typeof data!=='object'||Array.isArray(data))throw new Error('Backupfilen er ikke et gyldig objekt.');
    if(data.schema!==SCHEMA)throw new Error('Dette er ikke en Golden Gallery metadata-backup.');
    if(data.schemaVersion!==SCHEMA_VERSION)throw new Error('Backupformatet støttes ikke av denne versjonen.');
    if(data.imagesIncluded!==false)throw new Error('Backupen må være metadata-only.');
    if(!Array.isArray(data.photos))throw new Error('Backupen mangler bildelisten.');
    if(data.photos.length>MAX_ENTRIES)throw new Error('Backupen inneholder for mange poster.');
    const photos=data.photos.map(normalizeEntry);
    return Object.freeze({schema:SCHEMA,schemaVersion:SCHEMA_VERSION,product:'RAH AI Photos',edition:'Golden Gallery',exportedAt:cleanText(data.exportedAt,80),photoCount:photos.length,imagesIncluded:false,photos:Object.freeze(photos)});
  }
  function parseBackup(text){let data;try{data=JSON.parse(String(text||''));}catch{throw new Error('Kunne ikke lese backupfilen som JSON.');}return validateBackup(data);}
  function planRestore(backup,currentPhotos){
    const safe=validateBackup(backup);
    const current=Array.isArray(currentPhotos)?currentPhotos:[];
    const byId=new Map(current.filter(item=>item?.id).map(item=>[String(item.id),item]));
    const byFingerprint=new Map();
    for(const item of current){const key=fingerprint(item);if(!byFingerprint.has(key))byFingerprint.set(key,[]);byFingerprint.get(key).push(item);}
    const used=new Set(),matches=[];let skipped=0;
    for(const meta of safe.photos){
      let target=meta.id?byId.get(meta.id):null;
      if(target&&used.has(target.id))target=null;
      if(!target){const candidates=byFingerprint.get(fingerprint(meta))||[];target=candidates.find(item=>!used.has(item.id))||null;}
      if(!target){skipped++;continue;}
      used.add(target.id);
      matches.push(Object.freeze({photoId:String(target.id),metadata:Object.freeze({title:meta.title,album:meta.album,description:meta.description,tags:meta.tags,favorite:meta.favorite})}));
    }
    return Object.freeze({matches:Object.freeze(matches),matched:matches.length,skipped,total:safe.photos.length});
  }
  window.RAHPhotosBackup=Object.freeze({SCHEMA,SCHEMA_VERSION,createBackup,validateBackup,parseBackup,planRestore});
})();
''',encoding='utf-8')

js_path=Path('rah-ai-photos.js')
js=js_path.read_text(encoding='utf-8')
old_ui="    fileInput:$('fileInput'),importButton:$('importButton'),dropImportButton:$('dropImportButton'),dropzone:$('dropzone'),"
new_ui="    fileInput:$('fileInput'),importButton:$('importButton'),dropImportButton:$('dropImportButton'),dropzone:$('dropzone'),\n    exportBackup:$('exportBackup'),restoreBackup:$('restoreBackup'),backupInput:$('backupInput'),"
assert old_ui in js
js=js.replace(old_ui,new_ui)
anchor='\n  function bind(){'
assert anchor in js
backup_code=r'''

  function backupFilename(){return `RAH-AI-Photos-Metadata-Backup-${new Date().toISOString().slice(0,10)}.json`;}
  function exportMetadataBackup(){
    const api=window.RAHPhotosBackup;if(!api){setStatus('Backupmodulen mangler.');return;}
    const backup=api.createBackup(state.photos);
    const blob=new Blob([JSON.stringify(backup,null,2)+'\n'],{type:'application/json'});
    const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=backupFilename();document.body.appendChild(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),0);
    setStatus(`Metadata-backup eksportert for ${backup.photoCount} bilde${backup.photoCount===1?'':'r'}. Bildefiler er ikke inkludert.`);
  }
  async function restoreMetadataBackup(file){
    const api=window.RAHPhotosBackup;if(!api){setStatus('Backupmodulen mangler.');return;}
    if(!file)return;
    if(Number(file.size||0)>10*1024*1024){setStatus('Backupfilen er for stor. Maks 10 MB metadata.');return;}
    let backup,plan;
    try{backup=api.parseBackup(await file.text());plan=api.planRestore(backup,state.photos);}catch(error){setStatus(`Backup avvist: ${error.message}`);return;}
    if(!plan.matched){setStatus(`Backupen er gyldig, men ingen av ${plan.total} poster matcher bilder som finnes i galleriet.`);return;}
    const message=`Gjenopprette metadata på ${plan.matched} bilde${plan.matched===1?'':'r'}? ${plan.skipped} backup-post${plan.skipped===1?'':'er'} uten treff hoppes over. Ingen bilder slettes eller erstattes.`;
    if(!confirm(message)){setStatus('Gjenoppretting avbrutt. Ingen metadata ble endret.');return;}
    for(const step of plan.matches){
      const photo=state.photos.find(item=>String(item.id)===step.photoId);if(!photo)continue;
      photo.title=step.metadata.title||titleFromName(photo.name);photo.album=step.metadata.album||'Inbox';photo.description=String(step.metadata.description||'').slice(0,1200);photo.tags=cleanTags(step.metadata.tags.join(','));photo.favorite=Boolean(step.metadata.favorite);await storagePut(photo);
    }
    await reload();setStatus(`Metadata gjenopprettet på ${plan.matched} bilde${plan.matched===1?'':'r'}. ${plan.skipped} post${plan.skipped===1?'':'er'} ble hoppet over.`);
  }
'''
js=js.replace(anchor,backup_code+anchor)
bind_old="    ui.importButton.addEventListener('click',pick);\n    ui.dropImportButton.addEventListener('click',pick);"
bind_new="    ui.importButton.addEventListener('click',pick);\n    ui.dropImportButton.addEventListener('click',pick);\n    ui.exportBackup.addEventListener('click',exportMetadataBackup);\n    ui.restoreBackup.addEventListener('click',()=>ui.backupInput.click());\n    ui.backupInput.addEventListener('change',async()=>{await restoreMetadataBackup(ui.backupInput.files?.[0]);ui.backupInput.value='';});"
assert bind_old in js
js=js.replace(bind_old,bind_new)
js_path.write_text(js,encoding='utf-8')

manifest_path=Path('RAH-AI-PHOTOS-VERSION.json')
m=json.loads(manifest_path.read_text(encoding='utf-8'))
assert m['version']=='0.2.0'
m['version']='1.0.0';m['stage']='stable-local-photo-library';m['released_at']='2026-08-13';m['stable']=True
m['features'].update({'metadata_backup_export':True,'metadata_backup_restore':True,'metadata_backup_schema_version':1,'metadata_backup_images_included':False,'restore_metadata_only':True,'restore_requires_explicit_confirmation':True,'restore_skips_unknown_photos':True,'restore_never_deletes_photos':True})
m['next_milestone']='paused-stable-v1';m['v1_target']='achieved'
m['release_gate']={'stage':'stable','runtime':'browser-local','backup_contract':'metadata-only','ai_network_scope':'loopback-only','automatic_ai_analysis':False,'external_upload':False}
manifest_path.write_text(json.dumps(m,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

test_path=Path('tests/rah-ai-photos.test.mjs')
test_path.write_text(r'''import assert from 'node:assert/strict';import fs from 'node:fs';
const html=fs.readFileSync('RAH-AI-PHOTOS.html','utf8'),js=fs.readFileSync('rah-ai-photos.js','utf8'),ai=fs.readFileSync('rah-ai-photos-local-ai.js','utf8'),backup=fs.readFileSync('rah-ai-photos-backup.js','utf8'),manifest=JSON.parse(fs.readFileSync('RAH-AI-PHOTOS-VERSION.json','utf8'));
assert.equal(manifest.product,'RAH AI Photos');assert.equal(manifest.edition,'Golden Gallery');assert.equal(manifest.version,'1.0.0');assert.equal(manifest.stage,'stable-local-photo-library');assert.equal(manifest.stable,true);assert.equal(manifest.local_only,true);assert.equal(manifest.features.indexeddb_persistence,true);assert.equal(manifest.features.local_ai_explicit_click_only,true);assert.equal(manifest.features.local_ai_loopback_only,true);assert.equal(manifest.features.external_upload,false);assert.equal(manifest.features.network_scope,'loopback-only');assert.equal(manifest.features.automatic_ai_analysis,false);assert.equal(manifest.features.metadata_backup_export,true);assert.equal(manifest.features.metadata_backup_restore,true);assert.equal(manifest.features.metadata_backup_images_included,false);assert.equal(manifest.features.restore_metadata_only,true);assert.equal(manifest.features.restore_requires_explicit_confirmation,true);assert.equal(manifest.features.restore_never_deletes_photos,true);
for(const marker of [/Golden Gallery v1\.0/,/STABLE v1\.0/,/id="exportBackup"/,/id="restoreBackup"/,/id="backupInput"/,/rah-ai-photos-backup\.js/,/rah-ai-photos-local-ai\.js/,/rah-ai-photos\.js/])assert.match(html,marker);
assert.match(js,/function exportMetadataBackup\(\)/);assert.match(js,/async function restoreMetadataBackup\(file\)/);assert.match(js,/api\.createBackup\(state\.photos\)/);assert.match(js,/api\.parseBackup\(await file\.text\(\)\)/);assert.match(js,/api\.planRestore\(backup,state\.photos\)/);assert.match(js,/if\(!confirm\(message\)\)/);assert.match(js,/await storagePut\(photo\)/);assert.doesNotMatch(js,/fetch\s*\(/,'Main gallery runtime must not perform network calls directly.');
assert.match(backup,/SCHEMA='rah-ai-photos-metadata-backup'/);assert.match(backup,/SCHEMA_VERSION=1/);assert.match(backup,/imagesIncluded:false/);assert.match(backup,/function validateBackup\(data\)/);assert.match(backup,/function planRestore\(backup,currentPhotos\)/);for(const forbidden of [/fetch\s*\(/,/XMLHttpRequest/,/WebSocket/,/localStorage/,/indexedDB/,/storagePut/,/removeItem/,/setItem/])assert.doesNotMatch(backup,forbidden,`Backup policy must stay pure/read-only: ${forbidden}`);
assert.match(ai,/ALLOWED_HOSTS=new Set/);assert.match(ai,/Eksterne AI-adresser er blokkert/);const importBody=js.slice(js.indexOf('async function importFiles'),js.indexOf('async function toggleFavorite'));assert.doesNotMatch(importBody,/analyzeImage|discoverModels|fetch\s*\(/,'Import must never trigger AI.');
console.log('RAH AI Photos Golden Gallery v1.0: stable local library, explicit loopback AI and metadata-only backup/restore contract OK.');
''',encoding='utf-8')

backup_test=Path('tests/rah-ai-photos-backup.test.mjs')
backup_test.write_text(r'''import assert from 'node:assert/strict';import fs from 'node:fs';import vm from 'node:vm';
const source=fs.readFileSync('rah-ai-photos-backup.js','utf8');const context={window:{},URL,Date,Object,Map,Set,Array,JSON,String,Number,Boolean,Error};vm.runInNewContext(source,context);const api=context.window.RAHPhotosBackup;assert.ok(api);assert.equal(api.SCHEMA,'rah-ai-photos-metadata-backup');assert.equal(api.SCHEMA_VERSION,1);
const current=[{id:'a',name:'one.jpg',size:10,type:'image/jpeg',title:'Old',album:'Inbox',description:'',tags:[],favorite:false,blob:{secret:'not exported'}},{id:'b',name:'two.png',size:20,type:'image/png',title:'Two',album:'Inbox',description:'',tags:[],favorite:false}];
const created=api.createBackup(current);assert.equal(created.imagesIncluded,false);assert.equal(created.photoCount,2);assert.equal('blob' in created.photos[0],false);assert.equal(JSON.stringify(created).includes('secret'),false);
const parsed=api.parseBackup(JSON.stringify(created));assert.equal(parsed.photos.length,2);assert.throws(()=>api.parseBackup('{bad'),/JSON/);assert.throws(()=>api.validateBackup({...created,schema:'other'}),/ikke en Golden Gallery/);assert.throws(()=>api.validateBackup({...created,imagesIncluded:true}),/metadata-only/);
const restore=api.validateBackup({...created,photos:[{...created.photos[0],title:'Restored',album:'Trips',description:'Desc',tags:['x','x','y'],favorite:true},{id:'missing',name:'two.png',size:20,type:'image/png',title:'Fingerprint',album:'A',tags:[],favorite:false}]});const plan=api.planRestore(restore,current);assert.equal(plan.matched,2);assert.equal(plan.skipped,0);assert.equal(plan.matches[0].photoId,'a');assert.equal(plan.matches[0].metadata.title,'Restored');assert.equal(plan.matches[1].photoId,'b');assert.equal(plan.matches[1].metadata.title,'Fingerprint');assert.equal(Object.isFrozen(plan),true);assert.equal(Object.isFrozen(plan.matches),true);
const skip=api.planRestore(api.validateBackup({...created,photos:[{id:'none',name:'none.jpg',size:99,type:'image/jpeg',title:'X'}]}),current);assert.equal(skip.matched,0);assert.equal(skip.skipped,1);
console.log('RAH AI Photos metadata backup schema, validation and non-destructive restore planning: OK.');
''',encoding='utf-8')

release_test=Path('tests/rah-ai-photos-v1-release-gate.test.mjs')
release_test.write_text(r'''import assert from 'node:assert/strict';import fs from 'node:fs';
const m=JSON.parse(fs.readFileSync('RAH-AI-PHOTOS-VERSION.json','utf8'));assert.equal(m.version,'1.0.0');assert.equal(m.stage,'stable-local-photo-library');assert.equal(m.stable,true);assert.equal(m.v1_target,'achieved');assert.equal(m.next_milestone,'paused-stable-v1');assert.equal(m.release_gate?.stage,'stable');assert.equal(m.release_gate?.backup_contract,'metadata-only');assert.equal(m.release_gate?.ai_network_scope,'loopback-only');assert.equal(m.release_gate?.automatic_ai_analysis,false);assert.equal(m.release_gate?.external_upload,false);for(const path of ['RAH-AI-PHOTOS.html','rah-ai-photos.js','rah-ai-photos-local-ai.js','rah-ai-photos-backup.js','tests/rah-ai-photos.test.mjs','tests/rah-ai-photos-backup.test.mjs'])assert.equal(fs.existsSync(path),true,`${path} must exist`);assert.equal(fs.existsSync('.github/scripts/build_rah_ai_photos_v1.py'),false,'temporary builder must not ship in stable release');assert.equal(fs.existsSync('.github/workflows/build-rah-ai-photos-v1.yml'),false,'temporary builder workflow must not ship in stable release');console.log('RAH AI Photos Golden Gallery v1.0 stable release gate: OK.');
''',encoding='utf-8')

print('Built RAH AI Photos Golden Gallery v1.0 stable candidate')
