function send(msg){
  return new Promise(resolve=>{
    chrome.runtime.sendMessage(msg,r=>{
      if(chrome.runtime.lastError)resolve({ok:false,error:chrome.runtime.lastError.message});
      else resolve(r||{ok:false,error:'no response'});
    });
  });
}
async function activeChatTab(){
  const tabs=await chrome.tabs.query({active:true,currentWindow:true});
  return tabs[0] || null;
}
async function tabSend(msg){
  const tab=await activeChatTab();
  if(!tab?.id)return {ok:false,error:'No active tab'};
  return new Promise(resolve=>{
    chrome.tabs.sendMessage(tab.id,msg,r=>{
      if(chrome.runtime.lastError)resolve({ok:false,error:chrome.runtime.lastError.message});
      else resolve(r||{ok:false,error:'no content response'});
    });
  });
}
async function status(){
  const h=await send({type:'health'});
  const p=await send({type:'pending'});
  const d=await tabSend({type:'rah_dom_probe'});
  document.getElementById('status').innerHTML=h.ok
    ?'<span class="good">LOCAL AGENT ONLINE</span>'
    :'<span class="bad">LOCAL AGENT OFFLINE</span>';
  document.getElementById('queue').textContent='Pending results: '+(p.ok&&Array.isArray(p.items)?p.items.length:'?');
  document.getElementById('dom').innerHTML=d.ok&&d.probe?.composer_found
    ?'<span class="good">CHATGPT COMPOSER FOUND</span>'
    :'<span class="bad">CHATGPT COMPOSER NOT CONFIRMED</span>';
  document.getElementById('out').textContent=JSON.stringify({health:h,pending:p,dom:d},null,2);
}
document.getElementById('health').onclick=status;
document.getElementById('probe').onclick=async()=>{
  const r=await tabSend({type:'rah_dom_probe'});
  document.getElementById('out').textContent=JSON.stringify(r,null,2);
};
document.getElementById('e2e').onclick=async()=>{
  const rid='popup-e2e-'+Date.now();
  const r=await send({type:'tool',request:{request_id:rid,tool:'system.cpu',args:{}}});
  document.getElementById('out').textContent=JSON.stringify(r,null,2);
  if(r.ok){
    const f=await tabSend({type:'rah_flush_now'});
    document.getElementById('out').textContent += '\n\nFLUSH:\n'+JSON.stringify(f,null,2);
  }
  await status();
};
document.getElementById('diag').onclick=async()=>{
  const r=await send({type:'diag'});
  document.getElementById('out').textContent=r.ok
    ?JSON.stringify((r.rows||[]).slice(-60),null,2)
    :JSON.stringify(r,null,2);
};
status();
