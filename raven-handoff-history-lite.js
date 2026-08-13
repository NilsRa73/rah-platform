(function(root,factory){
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RavenHandoffHistoryLite=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const API_VERSION='1.0.0';
  const STORAGE_KEY='rah.raven.chatgpt-handoff-history-lite-v1';
  const VALID_SURFACES=Object.freeze(['now','studio']);

  function normalize(value){
    if(!value||value.version!==1||!VALID_SURFACES.includes(value.surface))return null;
    return Object.freeze({
      version:1,
      surface:value.surface,
      status:value.status===true,
      image:value.image===true,
      savedAt:typeof value.savedAt==='string'?value.savedAt:''
    });
  }

  function read(storage){
    if(!storage||typeof storage.getItem!=='function')return null;
    try{return normalize(JSON.parse(storage.getItem(STORAGE_KEY)||'null'));}
    catch{return null;}
  }

  function describe(item,locale='nb-NO'){
    if(!item)return Object.freeze({
      title:'Ingen lagret kvittering',
      meta:'Kun statusmarkør, bildemarkør, kildeflate og tidspunkt kan leses. Ingen prompt, tekst, analyse eller bildefil leses.'
    });
    const source=item.surface==='studio'?'Raven Studio':'Raven Now';
    const status=item.status?'STATUS KLAR':'STATUS UKJENT';
    const image=item.image?'BILDE KLAR':'UTEN BILDEMARKØR';
    let saved='ukjent tidspunkt';
    if(item.savedAt){
      const date=new Date(item.savedAt);
      if(!Number.isNaN(date.getTime()))saved=date.toLocaleString(locale);
    }
    return Object.freeze({
      title:`${source} · ${status} · ${image}`,
      meta:`Lagret ${saved}. Kun metadata fra siste eksplisitt lagrede kvittering leses; ingen prompt, tekst, analyse eller bildefil.`
    });
  }

  return Object.freeze({API_VERSION,STORAGE_KEY,VALID_SURFACES,normalize,read,describe});
});
