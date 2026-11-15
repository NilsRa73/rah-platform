'use strict';
const assert=require('node:assert/strict'),fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const base=path.join(__dirname,'../config/includes.chroot/opt/raven-flash');
const html=fs.readFileSync(path.join(base,'network.html'),'utf8');
const start=fs.readFileSync(path.join(base,'start.html'),'utf8');
const hakoya=fs.readFileSync(path.join(base,'hakoya.html'),'utf8');
const r2=fs.readFileSync(path.join(base,'rah-os-r2.html'),'utf8');
const menu=fs.readFileSync(path.join(base,'menu.xml'),'utf8');
const script=html.match(/<script>([\s\S]*?)<\/script>/);
assert.ok(script,'Raven Network inline script');
new vm.Script(script[1]);
assert.match(html,/connect-src 'none'/);
assert.match(html,/https:\/\/remotedesktop\.google\.com\/access/);
assert.match(html,/https:\/\/rustdesk\.com\/docs\/en\/client\/android\//);
assert.match(html,/https:\/\/github\.com\/Genymobile\/scrcpy/);
assert.doesNotMatch(html,/<script\s+src=/i,'No online startup dependencies');
assert.doesNotMatch(html,/fetch\s*\(|XMLHttpRequest|WebSocket|navigator\.mediaDevices/,'No automatic network scanning or screen access');
assert.match(html,/IKKE TESTET/);
for(const s of [start,r2,menu])assert.ok(s.includes('network.html'),'Network entry accessible from R2 desktop');
assert.ok(start.includes('https://remotedesktop.google.com/access'),'Chrome Remote Desktop launcher link');
class El{
 constructor(tag='div'){this.tag=tag;this.children=[];this.textContent='';this.value='';this.dataset={};this.href='';this.rel='';this.onclick=null;this.onsubmit=null;this.onchange=null;this.oninput=null;}
 append(...els){this.children.push(...els)}
 replaceChildren(...els){this.children=[...els]}
 reset(){this.resetCalled=true}
}
const nodes={};for(const m of html.matchAll(/id="([^"]+)"/g))nodes[m[1]]=new El();
nodes.category.value='alle';nodes.filter.value='';
const store=new Map(),context={
 URL,Date,Math,JSON,Array,String,Error,document:{
  getElementById:id=>nodes[id],createElement:tag=>new El(tag),
  documentElement:{dataset:{}},body:new El('body')
 },
 localStorage:{getItem:k=>store.get(k)??null,setItem:(k,v)=>store.set(k,v)},
 window:{confirm:()=>false}
};
vm.runInNewContext(script[1],context);
assert.equal(context.document.documentElement.dataset.rahNetworkReady,'true');
assert.equal(nodes.devices.children.length,4,'Known PC records show only as unverified');
assert.ok(nodes.devices.children.every(d=>d.children.some(c=>c.children&&c.children.some(x=>x.textContent==='IKKE TESTET'))));
nodes.name.value='Telefon test';nodes.type.value='android';nodes.method.value='rustdesk';nodes.url.value='';
nodes.deviceForm.onsubmit({preventDefault(){}});
assert.equal(nodes.devices.children.length,5,'Android entry added without a network scan');
assert.match(nodes.message.textContent,/IKKE TESTET/);
assert.equal(JSON.parse(store.get('rah-network-commander-r1')).length,5);
nodes.name.value='Unsafe';nodes.url.value='javascript:alert(1)';
nodes.deviceForm.onsubmit({preventDefault(){}});
assert.equal(nodes.devices.children.length,5,'Unsafe protocol rejected');
assert.match(nodes.message.textContent,/http/);
nodes.filter.value='Telefon';nodes.filter.oninput();
assert.equal(nodes.devices.children.length,1,'Device list filter works');
const android=nodes.devices.children[0];
assert.ok(JSON.stringify(android,(k,v)=>k==='onclick'?undefined:v).includes('Telefon test'));
console.log('PASS: RAH Network Commander offline safety, 4 unverified PCs, Android registry, URL guard, local persistence and search');
