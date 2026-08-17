(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.5.js'):(root&&root.RAHCommandCenterCoreV15);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterRequesterContextCandidate=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center 1.5 Stable core is required');

const CC_VERSION='1.6.0-candidate';
const NODE_ACTIONS_PROTOCOL='rah-node-actions-v6';
const ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1';
const APPROVAL_MODE='command-center-ephemeral-plus-node-local-context';
const REQUESTER_CONTEXT_HEADER='X-RAH-Requester-Context';
const APPROVAL_ACTION_HEADER=base.APPROVAL_ACTION_HEADER;
const APPROVAL_TARGET_HEADER=base.APPROVAL_TARGET_HEADER;
const LOCAL_APPROVAL_HEADER=base.LOCAL_APPROVAL_HEADER;
const ACTION_CHALLENGE_HEADER=base.ACTION_CHALLENGE_HEADER;
const V6_CHALLENGE_TTL_SECONDS=30;
const LOCAL_APPROVAL_TTL_SECONDS=30;
const MUTATING_ACTION_IDS=Object.freeze(['rustdesk.launch','rustdesk.connect']);

function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function sanitizeRequesterContext(v){return typeof v==='string'&&v.length>=32&&v.length<=128&&/^[A-Za-z0-9_-]+$/.test(v)?v:''}
function sanitizeProof(v){return base.sanitizeActionChallenge(v)}
function validateActionRow(raw,caps){
  if(!isPlainObject(raw))return null;
  const id=typeof raw.id==='string'?raw.id:'';
  const catalog=base.ACTION_CATALOG[id];
  if(!catalog||!caps.includes(catalog.capability))return null;
  if(raw.method!==catalog.method||raw.path!==catalog.path||raw.capability!==catalog.capability||raw.scope!==catalog.scope||raw.mutating!==catalog.mutating)return null;
  if(catalog.input&&raw.input!==catalog.input)return null;
  if(!catalog.input&&raw.input!==undefined)return null;
  if(catalog.mutating){
    if(raw.localApprovalRequired!==true||raw.requesterContextRequired!==true)return null;
  }else if(raw.localApprovalRequired!==undefined||raw.requesterContextRequired!==undefined)return null;
  const challengePresent=raw.challenge!==undefined,proofPresent=raw.localApprovalProof!==undefined;
  const challenge=challengePresent?base.sanitizeActionChallenge(raw.challenge):'',proof=proofPresent?sanitizeProof(raw.localApprovalProof):'';
  if(challengePresent&&(!challenge||raw.challengeTtlSeconds!==V6_CHALLENGE_TTL_SECONDS))return null;
  if(!challengePresent&&raw.challengeTtlSeconds!==undefined)return null;
  if(proofPresent&&(!catalog.mutating||!proof||raw.localApprovalProofTtlSeconds!==LOCAL_APPROVAL_TTL_SECONDS))return null;
  if(!proofPresent&&raw.localApprovalProofTtlSeconds!==undefined)return null;
  if(catalog.mutating&&challengePresent!==proofPresent)return null;
  if(catalog.mutating&&challengePresent&&proofPresent&&challenge===proof)return null;
  if(!catalog.mutating&&proofPresent)return null;
  return{id,catalog,challenge,proof};
}
function sanitizeActionCatalog(payload,capabilities,expectedSessionId){
  if(!isPlainObject(payload)||payload.protocol!==NODE_ACTIONS_PROTOCOL||payload.status!=='ready'||payload.policyId!==ALLOWLIST_POLICY_ID||payload.approvalMode!==APPROVAL_MODE||!Array.isArray(payload.actions))return null;
  const sessionId=base.sanitizeSessionId(payload.sessionId),expected=base.sanitizeSessionId(expectedSessionId),caps=base.sanitizeCapabilities(capabilities),actions=[];
  if(!sessionId||(expected&&sessionId!==expected))return null;
  for(const raw of payload.actions){const row=validateActionRow(raw,caps);if(row&&!actions.includes(row.id))actions.push(row.id)}
  return{protocol:NODE_ACTIONS_PROTOCOL,status:'ready',policyId:ALLOWLIST_POLICY_ID,approvalMode:APPROVAL_MODE,sessionId,actions};
}
function actionChallengeFromCatalog(payload,capabilities,actionId,expectedSessionId){
  if(actionId!=='storage-summary.read')return'';
  const catalog=sanitizeActionCatalog(payload,capabilities,expectedSessionId);if(!catalog)return'';
  const caps=base.sanitizeCapabilities(capabilities);
  for(const raw of payload.actions){const row=validateActionRow(raw,caps);if(row&&row.id==='storage-summary.read'&&row.challenge)return row.challenge}
  return'';
}
function localApprovalGrantFromCatalog(payload,capabilities,actionId,expectedSessionId){
  if(!MUTATING_ACTION_IDS.includes(actionId))return null;
  const catalog=sanitizeActionCatalog(payload,capabilities,expectedSessionId);if(!catalog||!catalog.actions.includes(actionId))return null;
  const caps=base.sanitizeCapabilities(capabilities);
  for(const raw of payload.actions){const row=validateActionRow(raw,caps);if(row&&row.id===actionId&&row.challenge&&row.proof&&row.challenge!==row.proof)return Object.freeze({actionId,challenge:row.challenge,localApprovalProof:row.proof,challengeTtlSeconds:V6_CHALLENGE_TTL_SECONDS,localApprovalProofTtlSeconds:LOCAL_APPROVAL_TTL_SECONDS})}
  return null;
}
function normalizeVerifiedCatalog(value,capabilities){
  if(!isPlainObject(value)||value.protocol!==NODE_ACTIONS_PROTOCOL||value.status!=='ready'||value.policyId!==ALLOWLIST_POLICY_ID||value.approvalMode!==APPROVAL_MODE)return null;
  const sessionId=base.sanitizeSessionId(value.sessionId),caps=base.sanitizeCapabilities(capabilities),actions=base.sanitizeActionIds(value.actions).filter(id=>caps.includes(base.ACTION_CATALOG[id].capability));
  return sessionId?{protocol:NODE_ACTIONS_PROTOCOL,status:'ready',policyId:ALLOWLIST_POLICY_ID,approvalMode:APPROVAL_MODE,sessionId,actions}:null;
}
function enrollDevice(records,id,ip,healthPayload,verifiedCatalog){
  const normalized=base.normalizeDeviceRegistry(records),endpointIp=base.normalizeNodeIpv4(ip),health=base.sanitizeNodeHealth(healthPayload),catalog=normalizeVerifiedCatalog(verifiedCatalog,health?health.capabilities:[]);
  if(!id||!endpointIp||!health||!catalog||catalog.sessionId!==health.sessionId)return normalized;
  return normalized.map(device=>device.id!==id?device:{...device,enrolled:true,endpointIp,agentHostname:health.hostname,agentVersion:health.agentVersion,agentProtocol:base.NODE_AGENT_PROTOCOL,agentSessionId:health.sessionId,platform:health.platformRelease?(health.platform+' '+health.platformRelease).slice(0,80):health.platform,capabilities:health.capabilities,permissions:health.permissions,advertisedActions:catalog.actions,approvedActions:[],remoteControlEnabled:false,commandsEnabled:false});
}
function actionChallengeRequest(record,actionId){
  if(actionId!=='storage-summary.read'||!base.canExecuteAction(record,actionId))return null;
  const url=base.nodeActionsUrl(record.endpointIp);
  return url?{id:actionId,url,method:'GET',protocol:NODE_ACTIONS_PROTOCOL,policyId:ALLOWLIST_POLICY_ID,headers:Object.freeze({})}:null;
}
function localApprovalIntentRequest(record,actionId,target,requesterContext){
  if(!MUTATING_ACTION_IDS.includes(actionId)||!base.canExecuteAction(record,actionId))return null;
  const context=sanitizeRequesterContext(requesterContext),url=base.nodeActionsUrl(record.endpointIp);if(!context||!url)return null;
  const headers={[APPROVAL_ACTION_HEADER]:actionId,[REQUESTER_CONTEXT_HEADER]:context};
  if(actionId==='rustdesk.launch'){
    if(target!==undefined&&target!==null&&target!=='')return null;
  }else{
    const peerId=base.sanitizePeerId(target);if(!peerId)return null;headers[APPROVAL_TARGET_HEADER]=peerId;
  }
  return{id:actionId,url,method:'GET',protocol:NODE_ACTIONS_PROTOCOL,policyId:ALLOWLIST_POLICY_ID,headers:Object.freeze(headers)};
}
function sanitizeGrant(grant,actionId){
  if(!isPlainObject(grant)||grant.actionId!==actionId)return null;
  const challenge=base.sanitizeActionChallenge(grant.challenge),proof=sanitizeProof(grant.localApprovalProof);
  if(!challenge||!proof||challenge===proof||grant.challengeTtlSeconds!==V6_CHALLENGE_TTL_SECONDS||grant.localApprovalProofTtlSeconds!==LOCAL_APPROVAL_TTL_SECONDS)return null;
  return{challenge,localApprovalProof:proof};
}
function actionExecutionRequest(record,actionId,value,requesterContext){
  if(actionId==='rustdesk.connect'||!base.canExecuteAction(record,actionId))return null;
  const catalog=base.ACTION_CATALOG[actionId];
  if(actionId==='storage-summary.read'){
    if(requesterContext!==undefined&&requesterContext!==null&&requesterContext!=='')return null;
    const challenge=base.sanitizeActionChallenge(value),url=base.nodeStorageUrl(record.endpointIp);
    return challenge&&url?{id:actionId,url,method:'GET',mutating:false,scope:catalog.scope,headers:Object.freeze({[ACTION_CHALLENGE_HEADER]:challenge})}:null;
  }
  if(actionId!=='rustdesk.launch')return null;
  const context=sanitizeRequesterContext(requesterContext),grant=sanitizeGrant(value,actionId),url=base.nodeRustDeskLaunchUrl(record.endpointIp);
  return context&&grant&&url?{id:actionId,url,method:'POST',mutating:true,scope:catalog.scope,headers:Object.freeze({[ACTION_CHALLENGE_HEADER]:grant.challenge,[LOCAL_APPROVAL_HEADER]:grant.localApprovalProof,[REQUESTER_CONTEXT_HEADER]:context})}:null;
}
function rustDeskHandoffRequest(record,peerId,grantValue,requesterContext){
  if(!base.canExecuteAction(record,'rustdesk.connect'))return null;
  const id=base.sanitizePeerId(peerId),context=sanitizeRequesterContext(requesterContext),grant=sanitizeGrant(grantValue,'rustdesk.connect'),url=base.nodeRustDeskHandoffUrl(record.endpointIp);
  return id&&context&&grant&&url?{id:'rustdesk.connect',url,method:'POST',headers:Object.freeze({[ACTION_CHALLENGE_HEADER]:grant.challenge,[LOCAL_APPROVAL_HEADER]:grant.localApprovalProof,[REQUESTER_CONTEXT_HEADER]:context}),body:{peerId:id}}:null;
}
return Object.freeze({...base,CC_VERSION,NODE_ACTIONS_PROTOCOL,ALLOWLIST_POLICY_ID,APPROVAL_MODE,REQUESTER_CONTEXT_HEADER,APPROVAL_ACTION_HEADER,APPROVAL_TARGET_HEADER,LOCAL_APPROVAL_HEADER,ACTION_CHALLENGE_HEADER,V6_CHALLENGE_TTL_SECONDS,LOCAL_APPROVAL_TTL_SECONDS,MUTATING_ACTION_IDS,sanitizeRequesterContext,sanitizeActionCatalog,actionChallengeFromCatalog,localApprovalGrantFromCatalog,normalizeVerifiedCatalog,enrollDevice,actionChallengeRequest,localApprovalIntentRequest,actionExecutionRequest,rustDeskHandoffRequest});
});
