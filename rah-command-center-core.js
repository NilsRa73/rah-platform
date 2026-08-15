(function (root, factory) {
  const api = factory();
  if (typeof module === 'object' && module.exports) module.exports = api;
  if (root) root.RAHCommandCenterCore = api;
})(typeof globalThis !== 'undefined' ? globalThis : this, function () {
  'use strict';

  const CC_VERSION = '0.5.0';
  const RAVEN_VERSION = '2.0.32';
  const BRIDGE_BASE = 'http://127.0.0.1:18765';
  const DEVICE_STORAGE_KEY = 'rah.cc.devices.v1';
  const NODE_AGENT_PORT = 18766;
  const NODE_AGENT_PROTOCOL = 'rah-node-health-v1';

  const FALLBACK_STABLE_COMPONENTS = Object.freeze({
    raven_vision: '0.6', raven_council: '0.3', agent_runner: '0.3', memory_sync: '0.2',
    mission_control: '2.9', project_focus: '2.4', raven_core: '1.12', raven_now: '2.17', raven_studio: '2.8'
  });
  const COMPONENT_META = Object.freeze({
    raven_core:{label:'Raven Core',entry:'RAH-RAVEN-CORE-DEMO.html'},raven_now:{label:'Raven Now',entry:'RAH-RAVEN-NOW-V2.html'},raven_vision:{label:'Raven Vision',entry:'RAH-RAVEN-VISION-CORE.html'},raven_council:{label:'Raven Council',entry:'RAH-RAVEN-COUNCIL.html'},agent_runner:{label:'Agent Runner',entry:'RAH-RAVEN-AGENT-RUNNER.html'},memory_sync:{label:'Memory Sync',entry:'RAH-RAVEN-MEMORY-SYNC.html'},mission_control:{label:'Mission Control',entry:'RAH-RAVEN-MISSION-CONTROL.html'},project_focus:{label:'Project Focus',entry:'RAH-RAVEN-PROJECT.html'},raven_studio:{label:'Raven Studio',entry:'RAH-RAVEN-START.html'}
  });
  const PACKAGE_COMPONENTS=Object.freeze([{id:'mission_engine',label:'Mission Engine',entry:'index.html'},{id:'home_control',label:'Home Control',entry:'RAH-HOME-CONTROL.html'},{id:'ai_photos',label:'AI Photos · Golden Gallery',entry:'RAH-AI-PHOTOS.html'},{id:'system_health',label:'System Health',entry:'RAH-RAVEN-NOW-V2.html'},{id:'voice_control',label:'Voice Control',entry:'RAH-RAVEN-NOW-V2.html'},{id:'cloud_sync',label:'Project Brain Cloud Sync',entry:'index.html'}]);
  const DEFAULT_DEVICES=Object.freeze([Object.freeze({id:'main-pc',label:'Main PC',role:'Command Center host',platform:'Windows 11',kind:'desktop',status:'unverified',source:'seed'}),Object.freeze({id:'hp-omen',label:'HP Omen',role:'Secondary compute',platform:'Windows',kind:'laptop',status:'unverified',source:'seed'}),Object.freeze({id:'lenovo-kali',label:'Lenovo / Kali',role:'Security lab node',platform:'Kali Linux',kind:'laptop',status:'unverified',source:'seed'}),Object.freeze({id:'mobile-display',label:'Mobile / Display Node',role:'Remote control / extended display',platform:'Mobile',kind:'mobile',status:'unverified',source:'seed'})]);
  const DEVICE_KINDS=Object.freeze(['desktop','laptop','mobile','tv','projector','other']);
  const DEVICE_STATUSES=Object.freeze(['unverified','this-device']);
  function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v);}
  function cleanText(v,f,m){if(typeof v!=='string')return f;const t=v.replace(/[\u0000-\u001f\u007f]/g,' ').replace(/\s+/g,' ').trim();return t?t.slice(0,m||80):f;}
  function cleanDeviceId(v,f){const c=cleanText(v,'',64).toLowerCase().replace(/[^a-z0-9-]+/g,'-').replace(/^-+|-+$/g,'');return c||f;}
  function cloneDefaultDevices(){return DEFAULT_DEVICES.map(i=>({...i}));}
  function isSafeRelativeEntry(v){if(typeof v!=='string'||!v.trim())return false;const x=v.trim();if(/^[a-z][a-z0-9+.-]*:/i.test(x)||x.startsWith('//')||x.startsWith('\\\\')||x.includes('..'))return false;return /^[A-Za-z0-9 _./-]+$/.test(x);}
  function normalizeStableComponents(m){const c=m&&m.release_gate&&m.release_gate.stable_components,s=isPlainObject(c)?c:FALLBACK_STABLE_COMPONENTS,r={};for(const id of Object.keys(FALLBACK_STABLE_COMPONENTS)){const v=s[id];r[id]=typeof v==='string'&&v.trim()?v.trim():FALLBACK_STABLE_COMPONENTS[id];}return r;}
  function buildCoreSnapshot(m,n){const s=normalizeStableComponents(m),v=m&&typeof m.version==='string'?m.version:RAVEN_VERSION,stage=m&&m.release_gate&&typeof m.release_gate.stage==='string'?m.release_gate.stage:'temporary-stable',components=Object.keys(FALLBACK_STABLE_COMPONENTS).map(id=>({id,label:COMPONENT_META[id].label,version:s[id],entry:COMPONENT_META[id].entry,stable:true}));return{commandCenterVersion:CC_VERSION,ravenVersion:v,stage,source:n||(m?'manifest':'embedded-fallback'),stableCount:components.length,totalCount:components.length,components};}
  function parseIpv4(v){if(typeof v!=='string')return null;const t=v.trim();if(!/^\d{1,3}(?:\.\d{1,3}){3}$/.test(t))return null;const p=t.split('.').map(Number);return p.some(x=>!Number.isInteger(x)||x<0||x>255)?null:p;}
  function isAllowedNodeIpv4(v){const p=parseIpv4(v);if(!p)return false;return p[0]===127||p[0]===10||(p[0]===172&&p[1]>=16&&p[1]<=31)||(p[0]===192&&p[1]===168);}
  function normalizeNodeIpv4(v){const p=parseIpv4(v);return p&&isAllowedNodeIpv4(v)?p.join('.'):'';}
  function nodeHealthUrl(v){const ip=normalizeNodeIpv4(v);return ip?'http://'+ip+':'+NODE_AGENT_PORT+'/health':'';}
  function sanitizeNodeHealth(p){if(!isPlainObject(p)||p.protocol!==NODE_AGENT_PROTOCOL||p.status!=='ready')return null;return{protocol:NODE_AGENT_PROTOCOL,agentVersion:cleanText(p.agentVersion,'unknown',24),hostname:cleanText(p.hostname,'Unknown host',80),platform:cleanText(p.platform,'Unknown platform',80),platformRelease:cleanText(p.platformRelease,'',80),machine:cleanText(p.machine,'',40),nodeName:cleanText(p.nodeName,'',80),nodeRole:cleanText(p.nodeRole,'',100)};}
  function normalizeDeviceRecord(v,i){if(!isPlainObject(v))return null;const f='device-'+String((i||0)+1),kind=DEVICE_KINDS.includes(v.kind)?v.kind:'other',status=DEVICE_STATUSES.includes(v.status)?v.status:'unverified',endpointIp=normalizeNodeIpv4(v.endpointIp||''),enrolled=v.enrolled===true&&!!endpointIp;return{id:cleanDeviceId(v.id,f),label:cleanText(v.label,'Unnamed device',80),role:cleanText(v.role,'Unassigned role',100),platform:cleanText(v.platform,'Unknown platform',80),kind,status,source:v.source==='seed'?'seed':'local',enrolled,endpointIp:enrolled?endpointIp:'',agentHostname:enrolled?cleanText(v.agentHostname,'',80):'',agentVersion:enrolled?cleanText(v.agentVersion,'',24):'',agentProtocol:enrolled?NODE_AGENT_PROTOCOL:'',remoteControlEnabled:false,commandsEnabled:false};}
  function normalizeDeviceRegistry(v){const s=Array.isArray(v)?v:cloneDefaultDevices(),n=[],used=new Set();s.slice(0,32).forEach((item,i)=>{const r=normalizeDeviceRecord(item,i);if(!r)return;let id=r.id,k=2;while(used.has(id))id=r.id+'-'+k++;r.id=id;used.add(id);n.push(r);});return n;}
  function createDeviceRecord(input,existing){const c=normalizeDeviceRegistry(Array.isArray(existing)?existing:[]),b=normalizeDeviceRecord({id:isPlainObject(input)?input.id:'',label:isPlainObject(input)?input.label:'',role:isPlainObject(input)?input.role:'',platform:isPlainObject(input)?input.platform:'',kind:isPlainObject(input)?input.kind:'other',status:'unverified',source:'local'},c.length),used=new Set(c.map(x=>x.id));let id=b.id,k=2;while(used.has(id))id=b.id+'-'+k++;b.id=id;return b;}
  function markThisDevice(records,id){const n=normalizeDeviceRegistry(records),t=cleanDeviceId(id,'');return n.map(x=>({...x,status:x.id===t?'this-device':'unverified',remoteControlEnabled:false,commandsEnabled:false}));}
  function enrollDevice(records,id,ip,payload){const n=normalizeDeviceRegistry(records),t=cleanDeviceId(id,''),e=normalizeNodeIpv4(ip),h=sanitizeNodeHealth(payload);if(!t||!e||!h)return n;return n.map(x=>x.id!==t?x:{...x,enrolled:true,endpointIp:e,agentHostname:h.hostname,agentVersion:h.agentVersion,agentProtocol:NODE_AGENT_PROTOCOL,platform:h.platformRelease?(h.platform+' '+h.platformRelease).slice(0,80):h.platform,remoteControlEnabled:false,commandsEnabled:false});}
  function forgetEnrollment(records,id){const n=normalizeDeviceRegistry(records),t=cleanDeviceId(id,'');return n.map(x=>x.id!==t?x:{...x,enrolled:false,endpointIp:'',agentHostname:'',agentVersion:'',agentProtocol:'',remoteControlEnabled:false,commandsEnabled:false});}
  function buildDeviceSnapshot(records){const d=normalizeDeviceRegistry(records);return{devices:d,totalCount:d.length,enrolledCount:d.filter(x=>x.enrolled).length,thisDeviceCount:d.filter(x=>x.status==='this-device').length,remoteControlCount:0,commandCount:0};}
  function isCanonicalBridgeUrl(v){if(typeof v!=='string')return false;try{const u=new URL(v);return u.protocol==='http:'&&u.hostname==='127.0.0.1'&&u.port==='18765'&&(u.pathname==='/'||u.pathname==='');}catch(_){return false;}}
  function bridgeHealthUrl(b){const s=isCanonicalBridgeUrl(b)?b.replace(/\/$/,''):BRIDGE_BASE;return s+'/health';}
  function summarizeBridgeHealth(p){if(!isPlainObject(p))return{ok:false,services:[],detail:'Invalid health response'};const keys=['case_center','chronicle','council_proxy','agent_runner'],services=keys.map(k=>({id:k,ok:p[k]===true}));return{ok:services.every(x=>x.ok),services,detail:services.every(x=>x.ok)?'Bridge core services ready':'One or more Bridge services are unavailable'};}
  return{CC_VERSION,RAVEN_VERSION,BRIDGE_BASE,DEVICE_STORAGE_KEY,NODE_AGENT_PORT,NODE_AGENT_PROTOCOL,FALLBACK_STABLE_COMPONENTS,COMPONENT_META,PACKAGE_COMPONENTS,DEFAULT_DEVICES,DEVICE_KINDS,DEVICE_STATUSES,isSafeRelativeEntry,normalizeStableComponents,buildCoreSnapshot,parseIpv4,isAllowedNodeIpv4,normalizeNodeIpv4,nodeHealthUrl,sanitizeNodeHealth,normalizeDeviceRecord,normalizeDeviceRegistry,createDeviceRecord,markThisDevice,enrollDevice,forgetEnrollment,buildDeviceSnapshot,isCanonicalBridgeUrl,bridgeHealthUrl,summarizeBridgeHealth};
});
