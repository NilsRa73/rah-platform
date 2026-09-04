(() => {
'use strict';

const VERSION='1.2.0';
const MARKER_RE=/\[\[RAH_V1_TOOL\s+(\{[\s\S]*?\})\s*\]\]/g;
const AUTO_TOOLS=new Set([
  'agent.status','system.snapshot','system.cpu','system.memory','system.gpu',
  'system.disks','system.network','system.displays',
  'fs.list','fs.read_text','fs.read_bytes','fs.search','fs.hash',
  'fs.write_text','fs.write_bytes','fs.mkdir','fs.copy','fs.move',
  'process.list','service.list'
]);

let busy=false, badgeEl=null, panelEl=null, lastError='', agentOnline=false, pendingCount=0;
const attemptAt=new Map();

function hash(s){
  let h=2166136261;
  for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}
  return (h>>>0).toString(16);
}
function sendRuntime(msg){
  return new Promise(resolve=>{
    chrome.runtime.sendMessage(msg,r=>{
      if(chrome.runtime.lastError) resolve({ok:false,error:chrome.runtime.lastError.message});
      else resolve(r||{ok:false,error:'no response'});
    });
  });
}
const log=(stage,detail={})=>sendRuntime({type:'log',stage,detail});

async function storageGet(key, def){
  const o=await chrome.storage.local.get(key);
  return o[key] ?? def;
}
async function storageSet(key,val){await chrome.storage.local.set({[key]:val});}
async function seenHas(k){return (await storageGet('rah_seen_v12',[])).includes(k);}
async function seenAdd(k){
  const a=await storageGet('rah_seen_v12',[]);
  if(!a.includes(k))a.push(k);
  await storageSet('rah_seen_v12',a.slice(-600));
}

function findComposer(){
  return document.querySelector('#prompt-textarea') ||
    document.querySelector('textarea[data-testid="prompt-textarea"]') ||
    document.querySelector('div[contenteditable="true"][role="textbox"]') ||
    document.querySelector('main div[contenteditable="true"]') ||
    document.querySelector('form textarea');
}
function findSendButton(){
  return document.querySelector('button[data-testid="send-button"]') ||
    document.querySelector('button[aria-label="Send prompt"]') ||
    document.querySelector('button[aria-label="Send message"]') ||
    document.querySelector('button[aria-label*="Send"]') ||
    document.querySelector('form button[type="submit"]');
}
function domProbe(){
  const e=findComposer(), b=findSendButton();
  const probe={
    url:location.href,
    title:document.title,
    composer_found:!!e,
    composer_tag:e?.tagName || null,
    composer_id:e?.id || null,
    composer_role:e?.getAttribute?.('role') || null,
    send_button_found:!!b,
    send_button_disabled:!!b?.disabled,
    assistant_messages:document.querySelectorAll('[data-message-author-role="assistant"]').length,
    user_messages:document.querySelectorAll('[data-message-author-role="user"]').length,
    version:VERSION
  };
  log('DOM_PROBE',probe);
  return probe;
}

async function setComposerText(e,text,requestId){
  if(e.tagName==='TEXTAREA'){
    const setter=Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value')?.set;
    if(setter) setter.call(e,text); else e.value=text;
    e.dispatchEvent(new Event('input',{bubbles:true}));
    e.dispatchEvent(new Event('change',{bubbles:true}));
    await log('COMPOSER_TEXT_SET',{request_id:requestId,strategy:'textarea-native-setter'});
    return;
  }

  let usedExec=false;
  try{
    e.focus();
    document.execCommand('selectAll',false,null);
    usedExec=document.execCommand('insertText',false,text);
  }catch(_){}

  if(!usedExec){
    e.replaceChildren();
    const p=document.createElement('p');
    p.textContent=text;
    e.appendChild(p);
    e.dispatchEvent(new InputEvent('beforeinput',{
      bubbles:true,cancelable:true,inputType:'insertText',data:text
    }));
    e.dispatchEvent(new InputEvent('input',{
      bubbles:true,inputType:'insertText',data:text
    }));
    await log('COMPOSER_TEXT_SET',{request_id:requestId,strategy:'contenteditable-dom'});
  }else{
    await log('COMPOSER_TEXT_SET',{request_id:requestId,strategy:'execCommand-insertText'});
  }
}

async function injectAndSend(text, requestId){
  const e=findComposer();
  if(!e){
    await log('COMPOSER_NOT_FOUND',{request_id:requestId,probe:domProbe()});
    throw new Error('ChatGPT composer not found');
  }
  await log('COMPOSER_FOUND',{request_id:requestId,tag:e.tagName,id:e.id||'',role:e.getAttribute('role')||''});
  e.focus();
  await setComposerText(e,text,requestId);
  await new Promise(r=>setTimeout(r,800));

  let send=findSendButton();
  if(send && !send.disabled){
    await log('SEND_STRATEGY',{request_id:requestId,strategy:'button-click'});
    send.click();
    return;
  }

  const form=e.closest('form') || document.querySelector('form');
  if(form && typeof form.requestSubmit==='function'){
    try{
      await log('SEND_STRATEGY',{request_id:requestId,strategy:'form-requestSubmit'});
      form.requestSubmit();
      return;
    }catch(_){}
  }

  await log('SEND_STRATEGY',{request_id:requestId,strategy:'enter-fallback'});
  e.dispatchEvent(new KeyboardEvent('keydown',{
    key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true
  }));
  e.dispatchEvent(new KeyboardEvent('keyup',{
    key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true
  }));
}

function userMessageContains(requestId){
  const els=document.querySelectorAll(
    '[data-message-author-role="user"], main [data-testid^="conversation-turn-"]'
  );
  for(const el of els){
    const t=el.innerText || el.textContent || '';
    if(t.includes('RAH_AGENT_RESULT') && t.includes(requestId)) return true;
  }
  return false;
}
async function waitForDelivery(requestId, timeoutMs=10000){
  const started=Date.now();
  while(Date.now()-started < timeoutMs){
    if(userMessageContains(requestId)){
      await log('DELIVERY_CONFIRMED_IN_DOM',{request_id:requestId,elapsed_ms:Date.now()-started});
      return true;
    }
    await new Promise(r=>setTimeout(r,350));
  }
  await log('DELIVERY_NOT_CONFIRMED',{request_id:requestId,timeout_ms:timeoutMs,probe:domProbe()});
  return false;
}

function stateColor(){
  if(lastError) return '#a54b4b';
  if(agentOnline) return '#3f8b4e';
  return '#8a742f';
}
function updateBadge(){
  if(!badgeEl)return;
  badgeEl.textContent=lastError?'RAH Bridge ERROR':
    agentOnline?`RAH ONLINE · queue ${pendingCount}`:'RAH Bridge checking';
  badgeEl.style.borderColor=stateColor();
}
function ensureBadge(){
  if(badgeEl)return;
  badgeEl=document.createElement('button');
  badgeEl.type='button';
  badgeEl.id='rah-browser-bridge-v12';
  Object.assign(badgeEl.style,{
    position:'fixed',right:'14px',bottom:'14px',zIndex:'2147483647',
    padding:'9px 12px',borderRadius:'10px',background:'#111',
    color:'#d7b65a',border:'1px solid #8a742f',
    font:'600 12px Segoe UI,sans-serif',cursor:'pointer',
    boxShadow:'0 5px 20px rgba(0,0,0,.45)'
  });
  badgeEl.onclick=togglePanel;
  document.documentElement.appendChild(badgeEl);
  updateBadge();
}
function togglePanel(){
  if(panelEl){panelEl.remove();panelEl=null;return;}
  panelEl=document.createElement('div');
  Object.assign(panelEl.style,{
    position:'fixed',right:'14px',bottom:'58px',zIndex:'2147483647',
    width:'400px',background:'#0d0d0d',color:'#eee',
    border:'1px solid #6d5a22',borderRadius:'12px',padding:'14px',
    boxShadow:'0 10px 35px rgba(0,0,0,.55)',
    font:'12px/1.45 Segoe UI,sans-serif'
  });
  panelEl.innerHTML=`
    <div style="font-weight:800;color:#d7b65a;font-size:14px">RAH BROWSER BRIDGE v${VERSION}</div>
    <div id="rah-v12-status" style="margin-top:8px;color:#bbb"></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:12px">
      <button id="rah-v12-health">HEALTH</button>
      <button id="rah-v12-dom">DOM PROBE</button>
      <button id="rah-v12-cpu">END-TO-END CPU</button>
      <button id="rah-v12-retry">RETRY QUEUE</button>
      <button id="rah-v12-diag" style="grid-column:1 / span 2">SHOW DIAGNOSTICS</button>
    </div>
    <pre id="rah-v12-out" style="display:none;max-height:260px;overflow:auto;white-space:pre-wrap;background:#080808;padding:8px;border-radius:7px;margin-top:9px"></pre>
    <div id="rah-v12-error" style="margin-top:10px;color:#d77;word-break:break-word"></div>`;
  panelEl.querySelectorAll('button').forEach(b=>Object.assign(b.style,{
    background:'#171717',color:'#d7b65a',border:'1px solid #5b4c22',
    borderRadius:'7px',padding:'8px',cursor:'pointer',fontWeight:'700'
  }));
  panelEl.querySelector('#rah-v12-health').onclick=health;
  panelEl.querySelector('#rah-v12-dom').onclick=()=>{
    const out=panelEl.querySelector('#rah-v12-out');out.style.display='block';
    out.textContent=JSON.stringify(domProbe(),null,2);
  };
  panelEl.querySelector('#rah-v12-cpu').onclick=cpuTest;
  panelEl.querySelector('#rah-v12-retry').onclick=()=>flushPending(true);
  panelEl.querySelector('#rah-v12-diag').onclick=showDiag;
  document.documentElement.appendChild(panelEl);
  updatePanel();
}
function updatePanel(){
  if(!panelEl)return;
  panelEl.querySelector('#rah-v12-status').textContent=
    `${agentOnline?'Agent ONLINE':'Agent not online'} | queue ${pendingCount} | extension v${VERSION}`;
  panelEl.querySelector('#rah-v12-error').textContent=lastError?`Last error: ${lastError}`:'';
}
async function showDiag(){
  const r=await sendRuntime({type:'diag'});
  const out=panelEl?.querySelector('#rah-v12-out');
  if(!out)return;
  out.style.display='block';
  out.textContent=r?.ok?JSON.stringify((r.rows||[]).slice(-40),null,2):(r?.error||'diagnostic read failed');
}

async function health(){
  const r=await sendRuntime({type:'health'});
  agentOnline=!!r?.ok;
  lastError=r?.ok?'':(r?.error||'Agent health check failed');
  await refreshPendingCount();
  updateBadge();updatePanel();
  return r;
}
async function refreshPendingCount(){
  const r=await sendRuntime({type:'pending'});
  pendingCount=r?.ok&&Array.isArray(r.items)?r.items.length:0;
}
async function cpuTest(){
  const request={request_id:'e2e-cpu-'+Date.now(),tool:'system.cpu',args:{}};
  await log('E2E_TEST_BEGIN',{request_id:request.request_id,probe:domProbe()});
  const r=await sendRuntime({type:'tool',request});
  if(!r?.ok){
    lastError=r?.error||'CPU test failed';
    await log('E2E_TEST_AGENT_FAILED',{request_id:request.request_id,error:lastError});
    updateBadge();updatePanel();
    return;
  }
  lastError='';
  await refreshPendingCount();
  updateBadge();updatePanel();
  await flushPending(true);
}

async function execute(req,key){
  if(busy||await seenHas(key))return;
  busy=true;
  try{
    const tool=String(req.tool||''),args=req.args||{};
    if(!tool)throw new Error('Missing tool');
    await log('MARKER_FOUND',{request_id:req.request_id||key,tool});
    if(!AUTO_TOOLS.has(tool)){
      const ok=confirm(`RAH requests a local action:\n\n${tool}\n${JSON.stringify(args,null,2).slice(0,1600)}\n\nAllow this action?`);
      if(!ok){await log('USER_DENIED_TOOL',{request_id:req.request_id||key,tool});await seenAdd(key);return;}
    }
    const r=await sendRuntime({type:'tool',request:{request_id:req.request_id||key,tool,args}});
    if(!r?.ok)throw new Error(r?.error||'Agent tool failed');
    await seenAdd(key);
    lastError='';
    await refreshPendingCount();updateBadge();updatePanel();
  }catch(e){
    lastError=String(e?.message||e);
    await log('CONTENT_EXEC_ERROR',{error:lastError});
    updateBadge();updatePanel();
  }finally{busy=false;}
  await flushPending();
}

function assistantTexts(){
  let els=document.querySelectorAll('[data-message-author-role="assistant"]');
  if(!els.length)els=document.querySelectorAll('main article, main [data-testid^="conversation-turn-"]');
  return [...els].map(e=>e.innerText||e.textContent||'');
}
async function scan(){
  if(busy)return;
  for(const text of assistantTexts()){
    MARKER_RE.lastIndex=0;
    let m;
    while((m=MARKER_RE.exec(text))!==null){
      const key=hash(m[0]);
      if(await seenHas(key))continue;
      try{await execute(JSON.parse(m[1]),key);}catch(_){await seenAdd(key);}
      return;
    }
  }
}

async function flushPending(force=false){
  if(busy)return;
  const r=await sendRuntime({type:'pending'});
  if(!r?.ok||!Array.isArray(r.items)){
    lastError=r?.error||'Cannot read result queue';updateBadge();return;
  }
  pendingCount=r.items.length;updateBadge();updatePanel();
  if(!r.items.length)return;

  const item=r.items[0];
  if(userMessageContains(item.request_id)){
    await sendRuntime({type:'ack',request_id:item.request_id});
    attemptAt.delete(item.request_id);
    await log('QUEUE_ALREADY_DELIVERED',{request_id:item.request_id});
    await refreshPendingCount();updateBadge();updatePanel();
    return;
  }

  const last=attemptAt.get(item.request_id)||0;
  if(!force&&Date.now()-last<15000)return;
  attemptAt.set(item.request_id,Date.now());

  try{
    busy=true;
    await log('DELIVERY_ATTEMPT',{request_id:item.request_id,tool:item.tool,probe:domProbe()});
    await injectAndSend('RAH_AGENT_RESULT '+JSON.stringify(item),item.request_id);
    const confirmed=await waitForDelivery(item.request_id,10000);
    if(confirmed){
      await sendRuntime({type:'ack',request_id:item.request_id});
      attemptAt.delete(item.request_id);
      lastError='';
      await log('E2E_DELIVERY_SUCCESS',{request_id:item.request_id});
    }else{
      lastError=`Result ${item.request_id} not confirmed; kept in queue`;
      await log('E2E_DELIVERY_PENDING',{request_id:item.request_id});
    }
  }catch(e){
    lastError=String(e?.message||e);
    await log('DELIVERY_ERROR',{request_id:item.request_id,error:lastError});
  }finally{
    busy=false;
    await refreshPendingCount();updateBadge();updatePanel();
  }
}

chrome.runtime.onMessage.addListener((msg,sender,sendResponse)=>{
  (async()=>{
    if(msg?.type==='rah_dom_probe'){sendResponse({ok:true,probe:domProbe()});return;}
    if(msg?.type==='rah_flush_now'){await flushPending(true);sendResponse({ok:true});return;}
    sendResponse({ok:false,error:'unknown content message'});
  })();
  return true;
});

ensureBadge();
log('CONTENT_SCRIPT_READY',{version:VERSION,url:location.href,probe:domProbe()});
health().then(()=>{setTimeout(scan,700);setTimeout(flushPending,1400);});

new MutationObserver(()=>{
  clearTimeout(window.__rahExtScanV12);
  window.__rahExtScanV12=setTimeout(()=>{scan();flushPending();},400);
}).observe(document.documentElement,{subtree:true,childList:true,characterData:true});

setInterval(health,15000);
setInterval(scan,1800);
setInterval(flushPending,4500);
})();
