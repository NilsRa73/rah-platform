(() => {
'use strict';

const VERSION='1.0.0';
const MARKER_RE=/\[\[RAH_V1_TOOL\s+(\{[\s\S]*?\})\s*\]\]/g;
const AUTO_TOOLS=new Set([
  'agent.status','system.snapshot','system.cpu','system.memory','system.gpu',
  'system.disks','system.network','system.displays',
  'fs.list','fs.read_text','fs.read_bytes','fs.search','fs.hash',
  'fs.write_text','fs.write_bytes','fs.mkdir','fs.copy','fs.move',
  'process.list','service.list'
]);
let busy=false;
let badgeEl=null;
let panelEl=null;
let lastError='';
let agentOnline=false;
let pendingCount=0;

function hash(s){
  let h=2166136261;
  for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}
  return (h>>>0).toString(16);
}
async function storageGet(key, def){
  const o=await chrome.storage.local.get(key);
  return o[key] ?? def;
}
async function storageSet(key,val){await chrome.storage.local.set({[key]:val});}
async function seenHas(k){return (await storageGet('rah_seen_v1',[])).includes(k);}
async function seenAdd(k){
  const a=await storageGet('rah_seen_v1',[]);
  if(!a.includes(k))a.push(k);
  await storageSet('rah_seen_v1',a.slice(-500));
}
function sendRuntime(msg){
  return new Promise(resolve=>{
    chrome.runtime.sendMessage(msg,r=>{
      if(chrome.runtime.lastError) resolve({ok:false,error:chrome.runtime.lastError.message});
      else resolve(r||{ok:false,error:'no response'});
    });
  });
}

function findComposer(){
  return document.querySelector('#prompt-textarea') ||
    document.querySelector('textarea[data-testid="prompt-textarea"]') ||
    document.querySelector('div[contenteditable="true"][role="textbox"]') ||
    document.querySelector('main div[contenteditable="true"]') ||
    document.querySelector('form textarea');
}
async function injectAndSend(text){
  const e=findComposer();
  if(!e) throw new Error('ChatGPT composer not found');
  e.focus();

  if(e.tagName==='TEXTAREA'){
    const setter=Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value')?.set;
    if(setter) setter.call(e,text); else e.value=text;
    e.dispatchEvent(new Event('input',{bubbles:true}));
    e.dispatchEvent(new Event('change',{bubbles:true}));
  }else{
    e.replaceChildren();
    const p=document.createElement('p');
    p.textContent=text;
    e.appendChild(p);
    e.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText',data:text}));
  }

  await new Promise(r=>setTimeout(r,650));

  const send=document.querySelector('button[data-testid="send-button"]') ||
    document.querySelector('button[aria-label="Send prompt"]') ||
    document.querySelector('button[aria-label="Send message"]') ||
    document.querySelector('form button[type="submit"]');

  if(send && !send.disabled){
    send.click();
  }else{
    e.dispatchEvent(new KeyboardEvent('keydown',{
      key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true
    }));
    e.dispatchEvent(new KeyboardEvent('keyup',{
      key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true
    }));
  }
}

function stateColor(){
  if(lastError) return '#a54b4b';
  if(agentOnline) return '#3f8b4e';
  return '#8a742f';
}
function updateBadge(){
  if(!badgeEl)return;
  badgeEl.textContent = lastError ? 'RAH Bridge ERROR' :
    agentOnline ? `RAH ONLINE · queue ${pendingCount}` : 'RAH Bridge checking';
  badgeEl.style.borderColor=stateColor();
}
function ensureBadge(){
  if(badgeEl)return;
  badgeEl=document.createElement('button');
  badgeEl.type='button';
  badgeEl.id='rah-browser-bridge-v1';
  Object.assign(badgeEl.style,{
    position:'fixed',right:'14px',bottom:'14px',zIndex:'2147483647',
    padding:'9px 12px',borderRadius:'10px',background:'#111',
    color:'#d7b65a',border:'1px solid #8a742f',
    font:'600 12px Segoe UI, sans-serif',cursor:'pointer',
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
    width:'360px',background:'#0d0d0d',color:'#eee',
    border:'1px solid #6d5a22',borderRadius:'12px',padding:'14px',
    boxShadow:'0 10px 35px rgba(0,0,0,.55)',
    font:'12px/1.45 Segoe UI,sans-serif'
  });
  panelEl.innerHTML=`
    <div style="font-weight:800;color:#d7b65a;font-size:14px">RAH BROWSER BRIDGE v${VERSION}</div>
    <div id="rah-v1-status" style="margin-top:8px;color:#bbb"></div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:8px;margin-top:12px">
      <button id="rah-v1-health">HEALTH</button>
      <button id="rah-v1-cpu">CPU TEST</button>
      <button id="rah-v1-retry" style="grid-column:1 / span 2">RETRY PENDING RESULTS</button>
    </div>
    <div id="rah-v1-error" style="margin-top:10px;color:#d77;word-break:break-word"></div>`;
  panelEl.querySelectorAll('button').forEach(b=>Object.assign(b.style,{
    background:'#171717',color:'#d7b65a',border:'1px solid #5b4c22',
    borderRadius:'7px',padding:'8px',cursor:'pointer',fontWeight:'700'
  }));
  panelEl.querySelector('#rah-v1-health').onclick=health;
  panelEl.querySelector('#rah-v1-cpu').onclick=cpuTest;
  panelEl.querySelector('#rah-v1-retry').onclick=flushPending;
  document.documentElement.appendChild(panelEl);
  updatePanel();
}
function updatePanel(){
  if(!panelEl)return;
  panelEl.querySelector('#rah-v1-status').textContent =
    `${agentOnline?'Agent ONLINE':'Agent not online'} | queue ${pendingCount} | extension v${VERSION}`;
  panelEl.querySelector('#rah-v1-error').textContent = lastError ? `Last error: ${lastError}` : '';
}

async function health(){
  const r=await sendRuntime({type:'health'});
  agentOnline=!!r?.ok;
  lastError=r?.ok?'':(r?.error || 'Agent health check failed');
  await refreshPendingCount();
  updateBadge(); updatePanel();
  return r;
}
async function refreshPendingCount(){
  const r=await sendRuntime({type:'pending'});
  pendingCount=r?.ok && Array.isArray(r.items)?r.items.length:0;
}
async function cpuTest(){
  const request={request_id:'manual-cpu-'+Date.now(),tool:'system.cpu',args:{}};
  const r=await sendRuntime({type:'tool',request});
  if(!r?.ok){lastError=r?.error||'CPU test failed';updateBadge();updatePanel();return;}
  lastError='';
  await refreshPendingCount();
  updateBadge(); updatePanel();
  await flushPending();
}

async function execute(req,key){
  if(busy || await seenHas(key))return;
  busy=true;
  try{
    const tool=String(req.tool||'');
    const args=req.args||{};
    if(!tool)throw new Error('Missing tool');
    if(!AUTO_TOOLS.has(tool)){
      const ok=confirm(`RAH requests a local action:\n\n${tool}\n${JSON.stringify(args,null,2).slice(0,1600)}\n\nAllow this action?`);
      if(!ok){await seenAdd(key);return;}
    }
    const r=await sendRuntime({type:'tool',request:{
      request_id:req.request_id||key,tool,args
    }});
    if(!r?.ok)throw new Error(r?.error||'Agent tool failed');
    await seenAdd(key);
    lastError='';
    await refreshPendingCount();
    updateBadge();updatePanel();
    await flushPending();
  }catch(e){
    lastError=String(e?.message||e);
    updateBadge();updatePanel();
  }finally{busy=false;}
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
      try{await execute(JSON.parse(m[1]),key);}
      catch(_){await seenAdd(key);}
      return;
    }
  }
}
async function flushPending(){
  if(busy)return;
  const r=await sendRuntime({type:'pending'});
  if(!r?.ok || !Array.isArray(r.items)){lastError=r?.error||'Cannot read result queue';updateBadge();return;}
  pendingCount=r.items.length;updateBadge();updatePanel();
  if(!r.items.length)return;

  const item=r.items[0];
  try{
    busy=true;
    await injectAndSend('RAH_AGENT_RESULT '+JSON.stringify(item));
    await new Promise(r=>setTimeout(r,900));
    await sendRuntime({type:'ack',request_id:item.request_id});
    lastError='';
  }catch(e){
    lastError=String(e?.message||e);
  }finally{
    busy=false;
    await refreshPendingCount();
    updateBadge();updatePanel();
  }
}

ensureBadge();
health().then(()=>{setTimeout(scan,700);setTimeout(flushPending,1200);});

new MutationObserver(()=>{
  clearTimeout(window.__rahExtScan);
  window.__rahExtScan=setTimeout(()=>{scan();flushPending();},350);
}).observe(document.documentElement,{subtree:true,childList:true,characterData:true});

setInterval(health,15000);
setInterval(scan,1800);
setInterval(flushPending,3500);
})();
