'use strict';

const assert=require('node:assert/strict');
const client=require('../raven-studio-launch-client.js');

async function main(){
  const okFetch=async(_url,options)=>{
    assert.equal(options.method,'POST');
    assert.equal(options.signal.aborted,false);
    return {
      ok:true,
      status:200,
      json:async()=>({ok:true,state:'started',id:'world-media',last_error:null})
    };
  };
  const ok=await client.requestJson(okFetch,'http://127.0.0.1:18765/apps/launch',{id:'world-media',confirm:true},100);
  assert.equal(ok.state,'started');

  const bridgeFailure=async()=>({
    ok:false,
    status:409,
    json:async()=>({ok:false,state:'failed',error:'Launcher mangler.',last_error:'Launcher mangler.'})
  });
  await assert.rejects(
    async()=>client.requestJson(bridgeFailure,'http://127.0.0.1:18765/apps/launch',{id:'world-media',confirm:true},100),
    error=>{
      assert.equal(error.message,'Launcher mangler.');
      assert.equal(error.bridgeData.state,'failed');
      assert.equal(error.httpStatus,409);
      return true;
    }
  );

  const timeoutFetch=async(_url,options)=>new Promise((_resolve,reject)=>{
    options.signal.addEventListener('abort',()=>{
      const error=new Error('aborted');
      error.name='AbortError';
      reject(error);
    },{once:true});
  });
  await assert.rejects(
    async()=>client.requestJson(timeoutFetch,'http://127.0.0.1:18765/apps/launch',{id:'rah-os',confirm:true},20),
    error=>{
      assert.equal(error.code,'BRIDGE_TIMEOUT');
      assert.equal(error.timeoutMs,20);
      assert.match(error.message,/Bridge timeout etter/);
      return true;
    }
  );

  assert.deepEqual(client.describeState('starting'),{state:'starting',label:'STARTER',className:'waiting'});
  assert.deepEqual(client.describeState('started'),{state:'started',label:'STARTET',className:'ready'});
  assert.deepEqual(client.describeState('failed'),{state:'failed',label:'FEILET',className:'off'});
  console.log('RAH Raven Studio launch client Bridge response / timeout contract: PASS');
}

main().catch(error=>{console.error(error);process.exit(1)});
