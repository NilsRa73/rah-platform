const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict'),path=require('node:path');
const html=fs.readFileSync(path.join(__dirname,'../config/includes.chroot/opt/raven-flash/hakoya.html'),'utf8');
assert.match(html,/R1\.5 CANDIDATE/);assert.match(html,/file:\/\/\/opt\/raven-flash\/start\.html/);assert.match(html,/status\.html/);
assert.match(html,/connect-src 'none'/);
const script=html.match(/<script>([\s\S]*?)<\/script>/)[1];
class El{constructor(){this.value='';this.textContent='';this.dataset={};this.onclick=null;}}
const nodes={};for(const m of html.matchAll(/id="([^"]+)"/g))nodes[m[1]]=new El();
const store=new Map();const root=new El();
const ctx={window:{},document:{getElementById:id=>nodes[id],documentElement:root},localStorage:{getItem:k=>store.get(k)??null,setItem:(k,v)=>store.set(k,v),removeItem:k=>store.delete(k)},Date};
vm.runInNewContext(script,ctx);
assert.equal(ctx.window.ravenHakoyaReady,true);
nodes.idea.value='R1.5 testidé';nodes.saveIdea.onclick();assert.equal(store.get('rah-r15-idea-v1'),'R1.5 testidé');assert.match(nodes.ideaState.textContent,/Lagret lokalt/);
nodes.clearIdea.onclick();assert.equal(store.has('rah-r15-idea-v1'),false);
console.log('PASS: Håkøya desktop opens local launcher/status and idea block saves/restores locally');
