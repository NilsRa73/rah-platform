(()=>{
  'use strict';

  const DB_NAME='rah-ai-photos';
  const DB_VERSION=1;
  const STORE='photos';
  const memoryStore=new Map();
  const urls=new Map();
  let db=null;
  let storageMode='indexeddb';
  let activeId=null;
  const state={photos:[],query:'',album:'all',favoritesOnly:false};

  const $=id=>document.getElementById(id);
  const ui={
    fileInput:$('fileInput'),importButton:$('importButton'),dropImportButton:$('dropImportButton'),dropzone:$('dropzone'),
    status:$('statusText'),storageBadge:$('storageBadge'),search:$('searchInput'),album:$('albumFilter'),
    favoriteFilter:$('favoriteFilter'),grid:$('galleryGrid'),empty:$('emptyState'),photoCount:$('photoCount'),
    albumCount:$('albumCount'),favoriteCount:$('favoriteCount'),dialog:$('editorDialog'),closeEditor:$('closeEditor'),
    editorPreview:$('editorPreview'),editorTitle:$('editorTitle'),editorAlbum:$('editorAlbum'),editorTags:$('editorTags'),
    editorFavorite:$('editorFavorite'),editorInfo:$('editorInfo'),deletePhoto:$('deletePhoto'),downloadPhoto:$('downloadPhoto'),savePhoto:$('savePhoto')
  };

  const setStatus=text=>{ui.status.textContent=text;};
  const safeId=()=>globalThis.crypto?.randomUUID?.() || `photo-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const cleanTags=value=>[...new Set(String(value||'').split(',').map(v=>v.trim()).filter(Boolean))].slice(0,30);
  const titleFromName=name=>String(name||'Bilde').replace(/\.[^.]+$/,'').trim()||'Bilde';
  const humanBytes=n=>{
    const bytes=Number(n)||0;
    if(bytes<1024)return `${bytes} B`;
    if(bytes<1024**2)return `${(bytes/1024).toFixed(1)} KB`;
    return `${(bytes/1024**2).toFixed(1)} MB`;
  };

  function openDb(){
    return new Promise((resolve,reject)=>{
      if(!('indexedDB' in window)) return reject(new Error('IndexedDB unavailable'));
      const req=indexedDB.open(DB_NAME,DB_VERSION);
      req.onupgradeneeded=()=>{
        const database=req.result;
        if(!database.objectStoreNames.contains(STORE)){
          const store=database.createObjectStore(STORE,{keyPath:'id'});
          store.createIndex('importedAt','importedAt');
          store.createIndex('album','album');
        }
      };
      req.onsuccess=()=>resolve(req.result);
      req.onerror=()=>reject(req.error||new Error('Kunne ikke åpne lokal database'));
    });
  }

  function dbRequest(mode,action){
    return new Promise((resolve,reject)=>{
      const tx=db.transaction(STORE,mode);
      const store=tx.objectStore(STORE);
      let request;
      try{request=action(store);}catch(err){reject(err);return;}
      if(request){
        request.onsuccess=()=>resolve(request.result);
        request.onerror=()=>reject(request.error||new Error('Lagringsfeil'));
      } else {
        tx.oncomplete=()=>resolve();
        tx.onerror=()=>reject(tx.error||new Error('Lagringsfeil'));
      }
    });
  }

  async function storageGetAll(){
    if(storageMode==='memory') return [...memoryStore.values()];
    return dbRequest('readonly',store=>store.getAll());
  }
  async function storagePut(item){
    if(storageMode==='memory'){memoryStore.set(item.id,item);return item;}
    await dbRequest('readwrite',store=>store.put(item));
    return item;
  }
  async function storageDelete(id){
    if(storageMode==='memory'){memoryStore.delete(id);return;}
    await dbRequest('readwrite',store=>store.delete(id));
  }

  function photoUrl(photo){
    if(urls.has(photo.id))return urls.get(photo.id);
    const url=URL.createObjectURL(photo.blob);
    urls.set(photo.id,url);
    return url;
  }
  function revokeUrl(id){
    const url=urls.get(id);
    if(url){URL.revokeObjectURL(url);urls.delete(id);}
  }

  function filteredPhotos(){
    const q=state.query.trim().toLocaleLowerCase('no');
    return state.photos
      .filter(p=>state.album==='all'||p.album===state.album)
      .filter(p=>!state.favoritesOnly||p.favorite)
      .filter(p=>{
        if(!q)return true;
        return [p.name,p.title,p.album,...(p.tags||[])].join(' ').toLocaleLowerCase('no').includes(q);
      })
      .sort((a,b)=>String(b.importedAt).localeCompare(String(a.importedAt)));
  }

  function updateAlbumOptions(){
    const current=state.album;
    const albums=[...new Set(state.photos.map(p=>p.album||'Inbox'))].sort((a,b)=>a.localeCompare(b,'no'));
    ui.album.innerHTML='<option value="all">Alle album</option>' + albums.map(a=>`<option value="${escapeHtml(a)}">${escapeHtml(a)}</option>`).join('');
    state.album=albums.includes(current)||current==='all'?current:'all';
    ui.album.value=state.album;
    ui.albumCount.textContent=String(albums.length);
  }

  function escapeHtml(value){
    return String(value??'').replace(/[&<>'"]/g,ch=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[ch]));
  }

  function render(){
    updateAlbumOptions();
    ui.photoCount.textContent=String(state.photos.length);
    ui.favoriteCount.textContent=String(state.photos.filter(p=>p.favorite).length);
    ui.favoriteFilter.setAttribute('aria-pressed',String(state.favoritesOnly));
    ui.favoriteFilter.textContent=state.favoritesOnly?'★ VISER FAVORITTER':'☆ KUN FAVORITTER';

    const photos=filteredPhotos();
    ui.grid.innerHTML='';
    for(const photo of photos){
      const article=document.createElement('article');
      article.className='card';
      article.dataset.photoId=photo.id;
      const tags=(photo.tags||[]).slice(0,4).map(tag=>`<span class="tag">${escapeHtml(tag)}</span>`).join('');
      article.innerHTML=`<div class="thumb"><img alt="${escapeHtml(photo.title||photo.name)}" /><button class="fav ${photo.favorite?'on':''}" title="Favoritt" aria-label="Bytt favoritt">${photo.favorite?'★':'☆'}</button></div><div class="meta"><div class="title">${escapeHtml(photo.title||photo.name)}</div><div class="small">${escapeHtml(photo.album||'Inbox')} · ${humanBytes(photo.size)}</div><div class="tags">${tags}</div></div>`;
      article.querySelector('img').src=photoUrl(photo);
      article.querySelector('.fav').addEventListener('click',async event=>{
        event.stopPropagation();
        await toggleFavorite(photo.id);
      });
      article.addEventListener('click',()=>openEditor(photo.id));
      ui.grid.appendChild(article);
    }
    const noPhotos=photos.length===0;
    ui.empty.classList.toggle('show',noPhotos);
    ui.empty.textContent=state.photos.length===0?'Ingen bilder ennå. Importer noen bilder for å starte Golden Gallery.':'Ingen bilder matcher filteret.';
  }

  async function reload(){
    state.photos=await storageGetAll();
    render();
  }

  async function importFiles(fileList){
    const files=[...fileList].filter(file=>file && String(file.type).startsWith('image/'));
    if(!files.length){setStatus('Ingen gyldige bildefiler valgt.');return;}
    setStatus(`Importerer ${files.length} bilde${files.length===1?'':'r'}…`);
    let imported=0;
    for(const file of files){
      const photo={
        id:safeId(),name:file.name||'Bilde',title:titleFromName(file.name),type:file.type||'image/unknown',size:file.size||0,
        importedAt:new Date().toISOString(),album:'Inbox',tags:[],favorite:false,blob:file
      };
      await storagePut(photo);
      imported++;
    }
    await reload();
    setStatus(`${imported} bilde${imported===1?'':'r'} importert lokalt.`);
  }

  async function toggleFavorite(id){
    const photo=state.photos.find(p=>p.id===id);
    if(!photo)return;
    photo.favorite=!photo.favorite;
    await storagePut(photo);
    await reload();
  }

  function openEditor(id){
    const photo=state.photos.find(p=>p.id===id);
    if(!photo)return;
    activeId=id;
    ui.editorPreview.src=photoUrl(photo);
    ui.editorTitle.value=photo.title||photo.name;
    ui.editorAlbum.value=photo.album||'Inbox';
    ui.editorTags.value=(photo.tags||[]).join(', ');
    ui.editorFavorite.checked=Boolean(photo.favorite);
    ui.editorInfo.textContent=`${photo.name} · ${humanBytes(photo.size)} · ${photo.type}`;
    ui.dialog.showModal();
  }

  async function saveActive(){
    const photo=state.photos.find(p=>p.id===activeId);
    if(!photo)return;
    photo.title=ui.editorTitle.value.trim()||titleFromName(photo.name);
    photo.album=ui.editorAlbum.value.trim()||'Inbox';
    photo.tags=cleanTags(ui.editorTags.value);
    photo.favorite=ui.editorFavorite.checked;
    await storagePut(photo);
    ui.dialog.close();
    activeId=null;
    await reload();
    setStatus('Bildedetaljer lagret lokalt.');
  }

  async function deleteActive(){
    if(!activeId)return;
    const photo=state.photos.find(p=>p.id===activeId);
    if(!photo)return;
    if(!confirm(`Slette «${photo.title||photo.name}» fra Golden Gallery?`))return;
    await storageDelete(activeId);
    revokeUrl(activeId);
    ui.dialog.close();
    activeId=null;
    await reload();
    setStatus('Bildet er slettet fra lokal lagring.');
  }

  function downloadActive(){
    const photo=state.photos.find(p=>p.id===activeId);
    if(!photo)return;
    const a=document.createElement('a');
    a.href=photoUrl(photo);
    a.download=photo.name||'rah-ai-photo';
    document.body.appendChild(a);
    a.click();
    a.remove();
    setStatus('Originalbildet ble klargjort for lokal nedlasting.');
  }

  function bind(){
    const pick=()=>ui.fileInput.click();
    ui.importButton.addEventListener('click',pick);
    ui.dropImportButton.addEventListener('click',pick);
    ui.fileInput.addEventListener('change',async()=>{await importFiles(ui.fileInput.files);ui.fileInput.value='';});
    for(const eventName of ['dragenter','dragover'])ui.dropzone.addEventListener(eventName,event=>{event.preventDefault();ui.dropzone.classList.add('drag');});
    for(const eventName of ['dragleave','drop'])ui.dropzone.addEventListener(eventName,event=>{event.preventDefault();ui.dropzone.classList.remove('drag');});
    ui.dropzone.addEventListener('drop',event=>importFiles(event.dataTransfer.files));
    ui.search.addEventListener('input',()=>{state.query=ui.search.value;render();});
    ui.album.addEventListener('change',()=>{state.album=ui.album.value;render();});
    ui.favoriteFilter.addEventListener('click',()=>{state.favoritesOnly=!state.favoritesOnly;render();});
    ui.closeEditor.addEventListener('click',()=>ui.dialog.close());
    ui.savePhoto.addEventListener('click',saveActive);
    ui.deletePhoto.addEventListener('click',deleteActive);
    ui.downloadPhoto.addEventListener('click',downloadActive);
    ui.dialog.addEventListener('close',()=>{activeId=null;});
  }

  async function start(){
    bind();
    try{
      db=await openDb();
      storageMode='indexeddb';
      ui.storageBadge.textContent='LAGRING: INDEXEDDB';
      setStatus('Klar. Lokal persistent lagring er aktiv.');
    }catch(error){
      storageMode='memory';
      ui.storageBadge.textContent='LAGRING: MIDLERTIDIG MINNE';
      setStatus('IndexedDB er ikke tilgjengelig. Galleriet virker, men bilder beholdes bare til siden lukkes.');
      console.warn('RAH AI Photos storage fallback:',error);
    }
    await reload();
  }

  window.addEventListener('beforeunload',()=>{for(const id of [...urls.keys()])revokeUrl(id);});
  start().catch(error=>{console.error(error);setStatus(`Kunne ikke starte Golden Gallery: ${error.message}`);});
})();
