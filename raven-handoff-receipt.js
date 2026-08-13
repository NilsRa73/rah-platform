(function(root,factory){
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RavenHandoffReceipt=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const API_VERSION='1.0.0';
  const READY='ready';
  const QUERY_KEYS=Object.freeze(['handoffReturn','handoffStatus','handoffImage']);

  function parse(params){
    if(!params||typeof params.get!=='function')return null;
    if(params.get('handoffReturn')!==READY)return null;
    return Object.freeze({
      status:params.get('handoffStatus')===READY,
      image:params.get('handoffImage')===READY
    });
  }

  function describe(receipt){
    if(!receipt)return Object.freeze({
      meta:'Ingen gyldig Handoff-returmarkør.',
      statusText:'STATUS: UKJENT',
      imageText:'BILDE: IKKE MARKERT'
    });
    return Object.freeze({
      meta:receipt.status
        ?(receipt.image
          ?'Status og bilde er lokalt markert klare etter eksplisitte handlinger. Dette bekrefter ikke mottak i ChatGPT.'
          :'Status er lokalt markert klar; bilde var valgfritt. Dette bekrefter ikke mottak i ChatGPT.')
        :'Returmarkør finnes, men status er ikke markert klar.',
      statusText:receipt.status?'STATUS: KLAR':'STATUS: UKJENT',
      imageText:receipt.image?'BILDE: KLAR':'BILDE: IKKE MARKERT'
    });
  }

  return Object.freeze({API_VERSION,READY,QUERY_KEYS,parse,describe});
});
