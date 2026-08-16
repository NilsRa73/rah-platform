(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core.js'):(root&&root.RAHCommandCenterCore);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterCandidateCore=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center Stable core is required');

const CC_VERSION='1.3.0-candidate';
const NODE_ACTIONS_PROTOCOL='rah-node-actions-v4';
const ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1';

function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}

function validateActionRow(raw,caps){
  if(!isPlainObject(raw))return null;
  const id=typeof raw.id==='string'?raw.id:'';
  const catalog=base.ACTION_CATALOG[id];
  if(!catalog||!caps.includes(catalog.capability))return null;
  if(raw.method!==catalog.method||raw.path!==catalog.path||raw.capability!==catalog.capability||raw.scope!==catalog.scope||raw.mutating!==catalog.mutating)return null;
  if(catalog.input&&raw.input!==catalog.input)return null;
  if(!catalog.input&&raw.input!==undefined)return null;
  const challenge=base.sanitizeActionChallenge(raw.challenge);
  if(!challenge||raw.challengeTtlSeconds!==base.ACTION_CHALLENGE_TTL_SECONDS)return null;
  return{id,catalog,challenge};
}

function sanitizeActionCatalog(payload,capabilities,expectedSessionId){
  if(!isPlainObject(payload)||payload.protocol!==NODE_ACTIONS_PROTOCOL||payload.status!=='ready'||payload.policyId!==ALLOWLIST_POLICY_ID||!Array.isArray(payload.actions))return null;
  const sessionId=base.sanitizeSessionId(payload.sessionId),expected=base.sanitizeSessionId(expectedSessionId),caps=base.sanitizeCapabilities(capabilities),actions=[];
  if(!sessionId||(expected&&sessionId!==expected))return null;
  for(const raw of payload.actions){const row=validateActionRow(raw,caps);if(row&&!actions.includes(row.id))actions.push(row.id)}
  return{protocol:NODE_ACTIONS_PROTOCOL,status:'ready',policyId:ALLOWLIST_POLICY_ID,sessionId,actions};
}

function actionChallengeFromCatalog(payload,capabilities,actionId,expectedSessionId){
  const catalog=sanitizeActionCatalog(payload,capabilities,expectedSessionId);
  if(!catalog)return'';
  const caps=base.sanitizeCapabilities(capabilities),wanted=typeof actionId==='string'?actionId:'';
  for(const raw of payload.actions){const row=validateActionRow(raw,caps);if(row&&row.id===wanted)return row.challenge}
  return'';
}

function normalizeVerifiedCatalog(value,capabilities){
  if(!isPlainObject(value)||value.protocol!==NODE_ACTIONS_PROTOCOL||value.status!=='ready'||value.policyId!==ALLOWLIST_POLICY_ID)return null;
  const sessionId=base.sanitizeSessionId(value.sessionId),caps=base.sanitizeCapabilities(capabilities),actions=base.sanitizeActionIds(value.actions).filter(id=>caps.includes(base.ACTION_CATALOG[id].capability));
  return sessionId?{protocol:NODE_ACTIONS_PROTOCOL,status:'ready',policyId:ALLOWLIST_POLICY_ID,sessionId,actions}:null;
}

function enrollDevice(records,id,ip,healthPayload,verifiedCatalog){
  const normalized=base.normalizeDeviceRegistry(records),endpointIp=base.normalizeNodeIpv4(ip),health=base.sanitizeNodeHealth(healthPayload),catalog=normalizeVerifiedCatalog(verifiedCatalog,health?health.capabilities:[]);
  if(!id||!endpointIp||!health||!catalog||catalog.sessionId!==health.sessionId)return normalized;
  return normalized.map(device=>{
    if(device.id!==id)return device;
    const sameSession=device.agentSessionId===health.sessionId;
    return{...device,enrolled:true,endpointIp,agentHostname:health.hostname,agentVersion:health.agentVersion,agentProtocol:base.NODE_AGENT_PROTOCOL,agentSessionId:health.sessionId,platform:health.platformRelease?(health.platform+' '+health.platformRelease).slice(0,80):health.platform,capabilities:health.capabilities,permissions:health.permissions,advertisedActions:catalog.actions,approvedActions:sameSession?base.sanitizeActionIds(device.approvedActions).filter(actionId=>catalog.actions.includes(actionId)):[],remoteControlEnabled:false,commandsEnabled:false};
  });
}

function actionChallengeRequest(record,actionId){
  if(!base.canExecuteAction(record,actionId))return null;
  const url=base.nodeActionsUrl(record.endpointIp);
  return url?{id:actionId,url,method:'GET',protocol:NODE_ACTIONS_PROTOCOL,policyId:ALLOWLIST_POLICY_ID}:null;
}

return Object.freeze({...base,CC_VERSION,NODE_ACTIONS_PROTOCOL,ALLOWLIST_POLICY_ID,sanitizeActionCatalog,actionChallengeFromCatalog,normalizeVerifiedCatalog,enrollDevice,actionChallengeRequest});
});
