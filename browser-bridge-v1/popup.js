function send(msg){return new Promise(resolve=>chrome.runtime.sendMessage(msg,r=>resolve(r||{ok:false,error:'no response'})))}
async function status(){
 const h=await send({type:'health'});
 const p=await send({type:'pending'});
 document.getElementById('status').innerHTML=h.ok?'<span class="good">LOCAL AGENT ONLINE</span>':'<span class="bad">LOCAL AGENT OFFLINE</span>';
 document.getElementById('queue').textContent='Pending results: '+(p.ok&&Array.isArray(p.items)?p.items.length:'?');
 document.getElementById('out').textContent=JSON.stringify(h,null,2);
}
document.getElementById('health').onclick=status;
document.getElementById('cpu').onclick=async()=>{
 const r=await send({type:'tool',request:{request_id:'popup-cpu-'+Date.now(),tool:'system.cpu',args:{}}});
 document.getElementById('out').textContent=JSON.stringify(r,null,2);
 await status();
};
status();
