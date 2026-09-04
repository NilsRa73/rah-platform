// ==UserScript==
// @name         RAH ChatGPT Local Agent Bridge
// @namespace    rah.ai.studios
// @version      0.1.0
// @description  Bridges explicit RAH tool requests in ChatGPT to the local RAH agent and returns results automatically.
// @match        https://chatgpt.com/*
// @match        https://chat.openai.com/*
// @grant        GM_xmlhttpRequest
// @connect      127.0.0.1
// @run-at       document-idle
// ==/UserScript==

(() => {
  'use strict';
  const AGENT = 'http://127.0.0.1:18779';
  const TOKEN = '__RAH_TOKEN__';
  const MARKER_RE = /\[\[RAH_TOOL\s+(\{[^\n]*\})\s*\]\]/g;
  const seen = new Set(JSON.parse(sessionStorage.getItem('rah_bridge_seen') || '[]'));
  let busy = false;
  const readOnly = new Set(['agent.status','system.snapshot','system.cpu','system.memory','system.gpu','system.disks','system.network','system.displays','fs.list','fs.read_text','fs.read_bytes','fs.search','fs.hash','process.list','service.list']);
  function saveSeen(){sessionStorage.setItem('rah_bridge_seen',JSON.stringify(Array.from(seen).slice(-200)));}
  function gm(method,url,body){return new Promise((resolve,reject)=>{GM_xmlhttpRequest({method,url,headers:{'Authorization':'Bearer '+TOKEN,'Content-Type':'application/json'},data:body?JSON.stringify(body):undefined,timeout:120000,onload:r=>{try{resolve(JSON.parse(r.responseText));}catch(e){reject(new Error('Invalid JSON from RAH Agent: '+r.responseText.slice(0,300)));}},onerror:()=>reject(new Error('RAH Agent connection failed')),ontimeout:()=>reject(new Error('RAH Agent timed out'))});});}
  function hash(s){let h=2166136261;for(let i=0;i<s.length;i++){h^=s.charCodeAt(i);h=Math.imul(h,16777619);}return(h>>>0).toString(16);}
  async function setComposer(text){
    const editor=document.querySelector('#prompt-textarea')||document.querySelector('textarea[data-testid="prompt-textarea"]')||document.querySelector('form textarea')||document.querySelector('div[contenteditable="true"]');
    if(!editor)throw new Error('ChatGPT composer not found');
    editor.focus();
    if(editor.tagName==='TEXTAREA'){const setter=Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype,'value').set;setter.call(editor,text);editor.dispatchEvent(new Event('input',{bubbles:true}));}
    else{editor.innerHTML='';const p=document.createElement('p');p.textContent=text;editor.appendChild(p);editor.dispatchEvent(new InputEvent('input',{bubbles:true,inputType:'insertText',data:text}));}
    await new Promise(r=>setTimeout(r,350));
    const send=document.querySelector('button[data-testid="send-button"]')||document.querySelector('button[aria-label="Send prompt"]')||document.querySelector('button[aria-label="Send message"]')||document.querySelector('form button[type="submit"]');
    if(send&&!send.disabled){send.click();return;}
    editor.dispatchEvent(new KeyboardEvent('keydown',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));
    editor.dispatchEvent(new KeyboardEvent('keyup',{key:'Enter',code:'Enter',keyCode:13,which:13,bubbles:true}));
  }
  async function execute(req,key){
    if(busy||seen.has(key))return;busy=true;
    try{
      const tool=String(req.tool||'');const args=req.args||{};if(!tool)throw new Error('Missing RAH tool name');
      if(!readOnly.has(tool)){const ok=confirm(`RAH Agent: allow local action?\n\n${tool}\n${JSON.stringify(args,null,2).slice(0,1200)}`);if(!ok){seen.add(key);saveSeen();busy=false;return;}}
      badge('working',`RAH: ${tool}`);const data=await gm('POST',AGENT+'/v1/tool',{tool,args});seen.add(key);saveSeen();
      const result={protocol:'RAH_AGENT_RESULT_V1',request_id:req.request_id||key,tool,ok:!!data.ok,result:data.result,error:data.error||null,duration_ms:data.duration_ms};
      badge(data.ok?'online':'error',data.ok?'RAH Agent online':'RAH Agent error');await setComposer('RAH_AGENT_RESULT '+JSON.stringify(result));
    }catch(e){seen.add(key);saveSeen();badge('error','RAH Agent error');try{await setComposer('RAH_AGENT_RESULT '+JSON.stringify({protocol:'RAH_AGENT_RESULT_V1',request_id:key,ok:false,error:String(e)}));}catch(_){} }
    finally{busy=false;}
  }
  function scan(){
    if(busy)return;const messages=document.querySelectorAll('[data-message-author-role="assistant"]');
    for(const el of messages){const text=el.innerText||el.textContent||'';MARKER_RE.lastIndex=0;let m;while((m=MARKER_RE.exec(text))!==null){const raw=m[0],key=hash(raw);if(seen.has(key))continue;try{execute(JSON.parse(m[1]),key);}catch(_){seen.add(key);saveSeen();}return;}}
  }
  let badgeEl;function badge(state,text){if(!badgeEl){badgeEl=document.createElement('div');Object.assign(badgeEl.style,{position:'fixed',right:'12px',bottom:'12px',zIndex:'2147483647',padding:'7px 10px',borderRadius:'9px',font:'12px/1.2 Segoe UI, sans-serif',background:'#111',color:'#d6b85a',border:'1px solid #6d5a22',opacity:'0.92',boxShadow:'0 4px 16px rgba(0,0,0,.35)'});document.documentElement.appendChild(badgeEl);}badgeEl.textContent=text;badgeEl.style.borderColor=state==='online'?'#4b8d56':state==='error'?'#a54b4b':'#6d5a22';}
  async function health(){try{const data=await gm('GET',AGENT+'/health');badge(data.ok?'online':'error',data.ok?'RAH Agent online':'RAH Agent error');}catch(_){badge('error','RAH Agent offline');}}
  new MutationObserver(()=>{clearTimeout(window.__rahScanTimer);window.__rahScanTimer=setTimeout(scan,250);}).observe(document.documentElement,{subtree:true,childList:true,characterData:true});
  health();setInterval(health,30000);setTimeout(scan,1000);
})();
