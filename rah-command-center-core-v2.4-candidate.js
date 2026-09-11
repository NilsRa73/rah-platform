(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v2.3.js'):(root&&root.RAHCommandCenterCoreV23);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterRavenCommanderCandidate=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center 2.3 Stable core is required');
if(base.CC_VERSION!=='2.3.0'||base.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||base.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1')throw new Error('Unexpected CC 2.3 Stable contract');

const CC_VERSION='2.4.0-candidate';
const RAVEN_COMMANDER_VERSION='rah-cc-raven-commander-v1';
const RAVEN_STATUS_PROTOCOL='rah-node-raven-status-v1';
const RAVEN_STATUS_ROUTE='/raven/status';
const RAVEN_STATUS_CAPABILITY='system-inventory';
const RAVEN_STATUS_SOURCE='local-raven-job-executor';
const RAVEN_STATUS_MAX_STDOUT=12000;

function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function cleanText(v,max){return typeof v==='string'?v.replace(/[\r\0]/g,'').slice(0,max||240):''}
function nodeRavenStatusUrl(ip){
  const health=base.nodeHealthUrl(ip);
  if(!health)return'';
  try{const u=new URL(health);u.pathname=RAVEN_STATUS_ROUTE;u.search='';u.hash='';return u.toString()}catch(_){return''}
}
function nodeRavenStatusRequest(ip){
  const url=nodeRavenStatusUrl(ip);
  return url?Object.freeze({url,method:'GET',path:RAVEN_STATUS_ROUTE,headers:Object.freeze({})}):null;
}
function buildRavenStatusAuthCanonical(sessionId,nonce,request,bodySha256){
  if(!isPlainObject(request))return'';
  const session=base.sanitizeSessionId(sessionId),n=base.sanitizeAuthNonce(nonce),body=base.sanitizeBodySha256(bodySha256);
  if(!session||!n||body!==base.EMPTY_SHA256)return'';
  if(request.method!=='GET'||request.path!==RAVEN_STATUS_ROUTE||request.body!==undefined)return'';
  if(!isPlainObject(request.headers)||Object.keys(request.headers).length!==0)return'';
  if(request.url!==nodeRavenStatusUrl(new URL(request.url).hostname))return'';
  return [base.AUTH_CANONICAL_VERSION,session,n,'GET',RAVEN_STATUS_ROUTE,body,'','','','',''].join('\n');
}
function attachRavenStatusAuthProof(request,nonce,proof){
  if(!isPlainObject(request)||request.path!==RAVEN_STATUS_ROUTE||request.method!=='GET')return null;
  return base.attachAuthProof(request,nonce,proof);
}
function sanitizeRavenStatusPayload(payload){
  if(!isPlainObject(payload)||payload.ok!==true||payload.protocol!==RAVEN_STATUS_PROTOCOL||payload.source!==RAVEN_STATUS_SOURCE||payload.capability!==RAVEN_STATUS_CAPABILITY)return null;
  if(payload.arbitraryCommands!==false||payload.argumentsAllowed!==false||payload.localOnlyHop!==true)return null;
  const result=isPlainObject(payload.result)?payload.result:null;
  if(!result||result.ok!==true||result.read_only!==true||result.files_modified!==false||result.arbitrary_commands!==false)return null;
  const inventory=isPlainObject(result.inventory)?result.inventory:null;
  if(!inventory||!isPlainObject(inventory.os)||!isPlainObject(inventory.cpu)||!isPlainObject(inventory.raven_bridge)||!isPlainObject(inventory.safety))return null;
  if(inventory.safety.read_only!==true||inventory.safety.arbitrary_commands!==false||inventory.safety.file_writes!==false||inventory.safety.automatic_execution!==false)return null;
  const stdout=cleanText(result.stdout,RAVEN_STATUS_MAX_STDOUT);
  return Object.freeze({
    commanderVersion:RAVEN_COMMANDER_VERSION,
    protocol:RAVEN_STATUS_PROTOCOL,
    capability:RAVEN_STATUS_CAPABILITY,
    nodeJobId:cleanText(payload.nodeJobId,160),
    hostname:cleanText(inventory.hostname,120),
    os:Object.freeze({system:cleanText(inventory.os.system,80),release:cleanText(inventory.os.release,80),architecture:cleanText(inventory.os.architecture,80)}),
    cpu:Object.freeze({name:cleanText(inventory.cpu.name,200),logicalCores:Number.isInteger(inventory.cpu.logical_cores)?inventory.cpu.logical_cores:null}),
    ramGb:Number.isFinite(Number(inventory.ram_gb))?Number(inventory.ram_gb):null,
    gpus:Object.freeze((Array.isArray(inventory.gpus)?inventory.gpus:[]).filter(v=>typeof v==='string').slice(0,8).map(v=>cleanText(v,200))),
    monitorCount:Number.isInteger(inventory.monitor_count)&&inventory.monitor_count>=0?inventory.monitor_count:0,
    bridge:Object.freeze({version:cleanText(inventory.raven_bridge.version,40),port:Number(inventory.raven_bridge.port)||0,healthRoute:inventory.raven_bridge.health_route===true,agentRoute:inventory.raven_bridge.agent_route===true}),
    stdout,
    readOnly:true,
    arbitraryCommands:false,
    argumentsAllowed:false,
    localOnlyHop:true,
    persistent:false
  });
}
function ravenCommanderEligibleDevice(record){
  return base.isFleetSnapshotEligibleDevice(record)&&Array.isArray(record.capabilities)&&record.capabilities.includes('compute');
}

return Object.freeze({...base,CC_VERSION,RAVEN_COMMANDER_VERSION,RAVEN_STATUS_PROTOCOL,RAVEN_STATUS_ROUTE,RAVEN_STATUS_CAPABILITY,RAVEN_STATUS_SOURCE,RAVEN_STATUS_MAX_STDOUT,nodeRavenStatusUrl,nodeRavenStatusRequest,buildRavenStatusAuthCanonical,attachRavenStatusAuthProof,sanitizeRavenStatusPayload,ravenCommanderEligibleDevice});
});
