(function(root,factory){
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RavenStudioLaunchClient=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';

  function timeoutMessage(timeoutMs){
    const seconds=Math.max(0.1,Number(timeoutMs||0)/1000);
    return 'Bridge timeout etter '+seconds.toLocaleString('no-NO',{maximumFractionDigits:1})+' sekunder.';
  }

  async function requestJson(fetchImpl,url,payload,timeoutMs){
    if(typeof fetchImpl!=='function')throw new Error('Fetch-funksjon mangler.');
    const limit=Number.isFinite(Number(timeoutMs))&&Number(timeoutMs)>0?Number(timeoutMs):5000;
    const controller=new AbortController();
    const timer=setTimeout(()=>controller.abort(),limit);
    try{
      const response=await fetchImpl(url,{
        method:'POST',
        cache:'no-store',
        headers:{'Content-Type':'application/json'},
        body:JSON.stringify(payload),
        signal:controller.signal
      });
      const data=await response.json().catch(()=>({ok:false,error:'Ugyldig svar fra lokal Bridge.'}));
      if(!response.ok||data?.ok===false){
        const error=new Error(data?.error||('Bridge HTTP '+response.status));
        error.bridgeData=data;
        error.httpStatus=response.status;
        throw error;
      }
      return data;
    }catch(error){
      if(error?.name==='AbortError'){
        const timeoutError=new Error(timeoutMessage(limit));
        timeoutError.code='BRIDGE_TIMEOUT';
        timeoutError.timeoutMs=limit;
        throw timeoutError;
      }
      throw error;
    }finally{
      clearTimeout(timer);
    }
  }

  function normalizeState(value){
    const state=String(value||'').trim().toLowerCase();
    return ['idle','starting','started','failed'].includes(state)?state:'idle';
  }

  function describeState(value){
    const state=normalizeState(value);
    if(state==='starting')return {state,label:'STARTER',className:'waiting'};
    if(state==='started')return {state,label:'STARTET',className:'ready'};
    if(state==='failed')return {state,label:'FEILET',className:'off'};
    return {state,label:'IKKE STARTET',className:'waiting'};
  }

  return Object.freeze({requestJson,timeoutMessage,normalizeState,describeState});
});
