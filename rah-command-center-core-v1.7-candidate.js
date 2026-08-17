(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.6.js'):(root&&root.RAHCommandCenterCoreV16);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterTokenProofCandidate=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center 1.6 Stable core is required');

const CC_VERSION='1.7.0-candidate';
const NODE_ACTIONS_PROTOCOL='rah-node-actions-v7';
const NODE_AUTH_PROTOCOL='rah-node-auth-v2';
const ALLOWLIST_POLICY_ID='rah-capability-allowlist-v1';
const AUTH_INIT_HEADER='X-RAH-Auth-Init';
const AUTH_NONCE_HEADER='X-RAH-Auth-Nonce';
const AUTH_PROOF_HEADER='X-RAH-Auth-Proof';
const AUTH_NONCE_TTL_SECONDS=30;
const AUTH_CANONICAL_VERSION='RAH-AUTH-V2';
const AUTHENTICATED_PATHS=Object.freeze(['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
const EMPTY_SHA256='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';

function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function sanitizeBase64Url(v,min,max){return typeof v==='string'&&v===v.trim()&&v.length>=(min||1)&&v.length<=(max||256)&&/^[A-Za-z0-9_-]+$/.test(v)?v:''}
function sanitizeAuthNonce(v){return sanitizeBase64Url(v,24,64)}
function sanitizeAuthProof(v){return sanitizeBase64Url(v,40,64)}
function sanitizeBodySha256(v){return typeof v==='string'&&/^[0-9a-f]{64}$/.test(v)?v:''}
function sanitizeAuthChallenge(payload,expectedSessionId){
  if(!isPlainObject(payload)||payload.protocol!==NODE_AUTH_PROTOCOL||payload.status!=='challenge'||payload.nonceTtlSeconds!==AUTH_NONCE_TTL_SECONDS)return null;
  const sessionId=base.sanitizeSessionId(payload.sessionId),expected=base.sanitizeSessionId(expectedSessionId||''),nonce=sanitizeAuthNonce(payload.nonce);
  if(!sessionId||!nonce||(expected&&sessionId!==expected))return null;
  const keys=Object.keys(payload).sort(),allowed=['nonce','nonceTtlSeconds','protocol','sessionId','status'].sort();
  if(keys.length!==allowed.length||keys.some((key,index)=>key!==allowed[index]))return null;
  return Object.freeze({protocol:NODE_AUTH_PROTOCOL,status:'challenge',sessionId,nonce,nonceTtlSeconds:AUTH_NONCE_TTL_SECONDS});
}
function nodeAuthInitRequest(ip){const url=base.nodeHealthUrl(ip);return url?Object.freeze({url,method:'GET',path:'/health',headers:Object.freeze({[AUTH_INIT_HEADER]:'1'})}):null}
function nodeHealthRequest(ip){const url=base.nodeHealthUrl(ip);return url?Object.freeze({url,method:'GET',path:'/health',headers:Object.freeze({})}):null}
function nodeActionsRequest(ip){const url=base.nodeActionsUrl(ip);return url?Object.freeze({url,method:'GET',path:'/actions',headers:Object.freeze({})}):null}
function fixedSecurityFields(headers){
  const h=isPlainObject(headers)?headers:{};
  const allowed=[base.APPROVAL_ACTION_HEADER,base.APPROVAL_TARGET_HEADER,base.REQUESTER_CONTEXT_HEADER,base.ACTION_CHALLENGE_HEADER,base.LOCAL_APPROVAL_HEADER];
  for(const key of Object.keys(h)){if(!allowed.includes(key))return null;const value=h[key];if(typeof value!=='string'||value.length>256||/[\r\n\0]/.test(value))return null}
  return {
    approvalAction:h[base.APPROVAL_ACTION_HEADER]||'',
    approvalTarget:h[base.APPROVAL_TARGET_HEADER]||'',
    requesterContext:h[base.REQUESTER_CONTEXT_HEADER]||'',
    actionChallenge:h[base.ACTION_CHALLENGE_HEADER]||'',
    nodeLocalApprovalProof:h[base.LOCAL_APPROVAL_HEADER]||''
  };
}
function requestShapeValid(method,path,fields,bodySha256){
  if(!AUTHENTICATED_PATHS.includes(path)||path.includes('?')||path.includes('#')||!sanitizeBodySha256(bodySha256))return false;
  const emptyBody=bodySha256===EMPTY_SHA256;
  if(path==='/health')return method==='GET'&&emptyBody&&Object.values(fields).every(v=>v==='');
  if(path==='/actions'){
    if(method!=='GET'||!emptyBody)return false;
    if(Object.values(fields).every(v=>v===''))return true;
    if(!['rustdesk.launch','rustdesk.connect'].includes(fields.approvalAction)||!base.sanitizeRequesterContext(fields.requesterContext)||fields.actionChallenge||fields.nodeLocalApprovalProof)return false;
    if(fields.approvalAction==='rustdesk.launch')return fields.approvalTarget==='';
    return !!base.sanitizePeerId(fields.approvalTarget);
  }
  if(path==='/storage')return method==='GET'&&emptyBody&&!!base.sanitizeActionChallenge(fields.actionChallenge)&&!fields.approvalAction&&!fields.approvalTarget&&!fields.requesterContext&&!fields.nodeLocalApprovalProof;
  if(path==='/launch/rustdesk')return method==='POST'&&emptyBody&&!!base.sanitizeRequesterContext(fields.requesterContext)&&!!base.sanitizeActionChallenge(fields.actionChallenge)&&!!base.sanitizeActionChallenge(fields.nodeLocalApprovalProof)&&!fields.approvalAction&&!fields.approvalTarget;
  if(path==='/handoff/rustdesk')return method==='POST'&&!emptyBody&&!!base.sanitizeRequesterContext(fields.requesterContext)&&!!base.sanitizeActionChallenge(fields.actionChallenge)&&!!base.sanitizeActionChallenge(fields.nodeLocalApprovalProof)&&!fields.approvalAction&&!fields.approvalTarget;
  return false;
}
function buildAuthCanonical(sessionId,nonce,method,path,bodySha256,headers){
  const session=base.sanitizeSessionId(sessionId),n=sanitizeAuthNonce(nonce),m=typeof method==='string'?method.toUpperCase():'',p=typeof path==='string'?path:'',body=sanitizeBodySha256(bodySha256),fields=fixedSecurityFields(headers);
  if(!session||!n||!fields||!requestShapeValid(m,p,fields,body))return'';
  return [AUTH_CANONICAL_VERSION,session,n,m,p,body,fields.approvalAction,fields.approvalTarget,fields.requesterContext,fields.actionChallenge,fields.nodeLocalApprovalProof].join('\n');
}
function buildAuthCanonicalFromRequest(sessionId,nonce,request,bodySha256){
  if(!isPlainObject(request))return'';
  return buildAuthCanonical(sessionId,nonce,request.method,request.path,bodySha256,request.headers||{});
}
function attachAuthProof(request,nonce,proof){
  if(!isPlainObject(request))return null;const n=sanitizeAuthNonce(nonce),p=sanitizeAuthProof(proof);if(!n||!p)return null;
  const headers=fixedSecurityFields(request.headers||{});if(!headers)return null;
  return Object.freeze({...request,headers:Object.freeze({...(request.headers||{}),[AUTH_NONCE_HEADER]:n,[AUTH_PROOF_HEADER]:p})});
}

function sanitizeProof(v){return base.sanitizeActionChallenge(v)}
function validateActionRow(raw,caps){
  if(!isPlainObject(raw))return null;const id=typeof raw.id==='string'?raw.id:'',catalog=base.ACTION_CATALOG[id];
  if(!catalog||!caps.includes(catalog.capability))return null;
  if(raw.method!==catalog.method||raw.path!==catalog.path||raw.capability!==catalog.capability||raw.scope!==catalog.scope||raw.mutating!==catalog.mutating)return null;
  if(catalog.input&&raw.input!==catalog.input)return null;if(!catalog.input&&raw.input!==undefined)return null;
  if(catalog.mutating){if(raw.localApprovalRequired!==true)return null}else if(raw.localApprovalRequired!==undefined)return null;
  const challengePresent=raw.challenge!==undefined,proofPresent=raw.localApprovalProof!==undefined,challenge=challengePresent?base.sanitizeActionChallenge(raw.challenge):'',proof=proofPresent?sanitizeProof(raw.localApprovalProof):'';
  if(challengePresent&&(!challenge||raw.challengeTtlSeconds!==base.V5_CHALLENGE_TTL_SECONDS))return null;if(!challengePresent&&raw.challengeTtlSeconds!==undefined)return null;
  if(proofPresent&&(!catalog.mutating||!proof||raw.localApprovalProofTtlSeconds!==base.LOCAL_APPROVAL_TTL_SECONDS))return null;if(!proofPresent&&raw.localApprovalProofTtlSeconds!==undefined)return null;
  if(catalog.mutating&&challengePresent!==proofPresent)return null;if(catalog.mutating&&challengePresent&&challenge===proof)return null;if(!catalog.mutating&&proofPresent)return null;
  return{id,catalog,challenge,proof};
}
function sanitizeActionCatalog(payload,capabilities,expectedSessionId){
  if(!isPlainObject(payload)||payload.protocol!==NODE_ACTIONS_PROTOCOL||payload.status!=='ready'||payload.policyId!==ALLOWLIST_POLICY_ID||payload.approvalMode!=='command-center-ephemeral-plus-node-local'||!Array.isArray(payload.actions))return null;
  const sessionId=base.sanitizeSessionId(payload.sessionId),expected=base.sanitizeSessionId(expectedSessionId||''),caps=base.sanitizeCapabilities(capabilities),actions=[];if(!sessionId||(expected&&sessionId!==expected))return null;
  for(const raw of payload.actions){const row=validateActionRow(raw,caps);if(row&&!actions.includes(row.id))actions.push(row.id)}
  return{protocol:NODE_ACTIONS_PROTOCOL,status:'ready',policyId:ALLOWLIST_POLICY_ID,approvalMode:'command-center-ephemeral-plus-node-local',sessionId,actions};
}
function actionChallengeFromCatalog(payload,capabilities,actionId,expectedSessionId){if(actionId!=='storage-summary.read')return'';const catalog=sanitizeActionCatalog(payload,capabilities,expectedSessionId);if(!catalog)return'';const caps=base.sanitizeCapabilities(capabilities);for(const raw of payload.actions){const row=validateActionRow(raw,caps);if(row&&row.id==='storage-summary.read'&&row.challenge)return row.challenge}return''}
function localApprovalGrantFromCatalog(payload,capabilities,actionId,expectedSessionId){if(!base.MUTATING_ACTION_IDS.includes(actionId))return null;const catalog=sanitizeActionCatalog(payload,capabilities,expectedSessionId);if(!catalog||!catalog.actions.includes(actionId))return null;const caps=base.sanitizeCapabilities(capabilities);for(const raw of payload.actions){const row=validateActionRow(raw,caps);if(row&&row.id===actionId&&row.challenge&&row.proof&&row.challenge!==row.proof)return Object.freeze({actionId,challenge:row.challenge,localApprovalProof:row.proof,challengeTtlSeconds:base.V5_CHALLENGE_TTL_SECONDS,localApprovalProofTtlSeconds:base.LOCAL_APPROVAL_TTL_SECONDS})}return null}
function normalizeVerifiedCatalog(value,capabilities){if(!isPlainObject(value)||value.protocol!==NODE_ACTIONS_PROTOCOL||value.status!=='ready'||value.policyId!==ALLOWLIST_POLICY_ID||value.approvalMode!=='command-center-ephemeral-plus-node-local')return null;const sessionId=base.sanitizeSessionId(value.sessionId),caps=base.sanitizeCapabilities(capabilities),actions=base.sanitizeActionIds(value.actions).filter(id=>caps.includes(base.ACTION_CATALOG[id].capability));return sessionId?{protocol:NODE_ACTIONS_PROTOCOL,status:'ready',policyId:ALLOWLIST_POLICY_ID,approvalMode:'command-center-ephemeral-plus-node-local',sessionId,actions}:null}
function enrollDevice(records,id,ip,healthPayload,verifiedCatalog){const normalized=base.normalizeDeviceRegistry(records),endpointIp=base.normalizeNodeIpv4(ip),health=base.sanitizeNodeHealth(healthPayload),catalog=normalizeVerifiedCatalog(verifiedCatalog,health?health.capabilities:[]);if(!id||!endpointIp||!health||!catalog||catalog.sessionId!==health.sessionId)return normalized;return normalized.map(device=>device.id!==id?device:{...device,enrolled:true,endpointIp,agentHostname:health.hostname,agentVersion:health.agentVersion,agentProtocol:base.NODE_AGENT_PROTOCOL,agentSessionId:health.sessionId,platform:health.platformRelease?(health.platform+' '+health.platformRelease).slice(0,80):health.platform,capabilities:health.capabilities,permissions:health.permissions,advertisedActions:catalog.actions,approvedActions:[],remoteControlEnabled:false,commandsEnabled:false})}
function actionChallengeRequest(record,actionId){if(actionId!=='storage-summary.read'||!base.canExecuteAction(record,actionId))return null;const url=base.nodeActionsUrl(record.endpointIp);return url?Object.freeze({id:actionId,url,method:'GET',path:'/actions',protocol:NODE_ACTIONS_PROTOCOL,policyId:ALLOWLIST_POLICY_ID,headers:Object.freeze({})}):null}
function localApprovalIntentRequest(record,actionId,target,requesterContext){if(!base.MUTATING_ACTION_IDS.includes(actionId)||!base.canExecuteAction(record,actionId))return null;const context=base.sanitizeRequesterContext(requesterContext),url=base.nodeActionsUrl(record.endpointIp);if(!context||!url)return null;const headers={[base.APPROVAL_ACTION_HEADER]:actionId,[base.REQUESTER_CONTEXT_HEADER]:context};if(actionId==='rustdesk.launch'){if(target!==undefined&&target!==null&&target!=='')return null}else{const peerId=base.sanitizePeerId(target);if(!peerId)return null;headers[base.APPROVAL_TARGET_HEADER]=peerId}return Object.freeze({id:actionId,url,method:'GET',path:'/actions',protocol:NODE_ACTIONS_PROTOCOL,policyId:ALLOWLIST_POLICY_ID,headers:Object.freeze(headers)})}
function sanitizeGrant(grant,actionId){if(!isPlainObject(grant)||grant.actionId!==actionId)return null;const challenge=base.sanitizeActionChallenge(grant.challenge),proof=sanitizeProof(grant.localApprovalProof);if(!challenge||!proof||challenge===proof||grant.challengeTtlSeconds!==base.V5_CHALLENGE_TTL_SECONDS||grant.localApprovalProofTtlSeconds!==base.LOCAL_APPROVAL_TTL_SECONDS)return null;return{challenge,localApprovalProof:proof}}
function actionExecutionRequest(record,actionId,value,requesterContext){if(actionId==='rustdesk.connect'||!base.canExecuteAction(record,actionId))return null;const catalog=base.ACTION_CATALOG[actionId];if(actionId==='storage-summary.read'){if(requesterContext!==undefined&&requesterContext!==null&&requesterContext!=='')return null;const challenge=base.sanitizeActionChallenge(value),url=base.nodeStorageUrl(record.endpointIp);return challenge&&url?Object.freeze({id:actionId,url,method:'GET',path:'/storage',mutating:false,scope:catalog.scope,headers:Object.freeze({[base.ACTION_CHALLENGE_HEADER]:challenge})}):null}if(actionId!=='rustdesk.launch')return null;const context=base.sanitizeRequesterContext(requesterContext),grant=sanitizeGrant(value,actionId),url=base.nodeRustDeskLaunchUrl(record.endpointIp);return context&&grant&&url?Object.freeze({id:actionId,url,method:'POST',path:'/launch/rustdesk',mutating:true,scope:catalog.scope,headers:Object.freeze({[base.ACTION_CHALLENGE_HEADER]:grant.challenge,[base.LOCAL_APPROVAL_HEADER]:grant.localApprovalProof,[base.REQUESTER_CONTEXT_HEADER]:context})}):null}
function rustDeskHandoffRequest(record,peerId,grantValue,requesterContext){if(!base.canExecuteAction(record,'rustdesk.connect'))return null;const id=base.sanitizePeerId(peerId),context=base.sanitizeRequesterContext(requesterContext),grant=sanitizeGrant(grantValue,'rustdesk.connect'),url=base.nodeRustDeskHandoffUrl(record.endpointIp);return id&&context&&grant&&url?Object.freeze({id:'rustdesk.connect',url,method:'POST',path:'/handoff/rustdesk',headers:Object.freeze({[base.ACTION_CHALLENGE_HEADER]:grant.challenge,[base.LOCAL_APPROVAL_HEADER]:grant.localApprovalProof,[base.REQUESTER_CONTEXT_HEADER]:context}),body:Object.freeze({peerId:id})}):null}

return Object.freeze({...base,CC_VERSION,NODE_ACTIONS_PROTOCOL,NODE_AUTH_PROTOCOL,ALLOWLIST_POLICY_ID,AUTH_INIT_HEADER,AUTH_NONCE_HEADER,AUTH_PROOF_HEADER,AUTH_NONCE_TTL_SECONDS,AUTH_CANONICAL_VERSION,AUTHENTICATED_PATHS,EMPTY_SHA256,sanitizeAuthNonce,sanitizeAuthProof,sanitizeBodySha256,sanitizeAuthChallenge,nodeAuthInitRequest,nodeHealthRequest,nodeActionsRequest,buildAuthCanonical,buildAuthCanonicalFromRequest,attachAuthProof,sanitizeActionCatalog,actionChallengeFromCatalog,localApprovalGrantFromCatalog,normalizeVerifiedCatalog,enrollDevice,actionChallengeRequest,localApprovalIntentRequest,actionExecutionRequest,rustDeskHandoffRequest});
});
