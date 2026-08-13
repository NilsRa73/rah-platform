(()=>{
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
