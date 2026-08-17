(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.8.js'):(root&&root.RAHCommandCenterCoreV18);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterIntentBindingCandidate=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center 1.8 Stable core is required');
if(base.CC_VERSION!=='1.8.0'||base.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v7'||base.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||base.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1'||base.ONE_SHOT_APPROVAL_TTL_MS!==90000||base.ONE_SHOT_APPROVAL_MAX_OUTSTANDING!==32)throw new Error('Unexpected CC 1.8 Stable contract');

const CC_VERSION='1.9.0-candidate';
const MUTATING_INTENT_BINDING_VERSION='rah-cc-mutating-intent-v1';

function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function sanitizeDeviceId(v){return typeof v==='string'&&v===v.trim()&&/^[a-z0-9][a-z0-9-]{0,63}$/.test(v)?v:''}
function sorted(values){return Object.freeze([...values].sort())}
function secureApprovalId(){
  const cryptoObj=typeof globalThis!=='undefined'?globalThis.crypto:null;
  if(!cryptoObj||typeof cryptoObj.getRandomValues!=='function')return'';
  const bytes=new Uint8Array(32);cryptoObj.getRandomValues(bytes);let binary='';for(const b of bytes)binary+=String.fromCharCode(b);
  if(typeof btoa==='function')return btoa(binary).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
  if(typeof Buffer!=='undefined')return Buffer.from(bytes).toString('base64url');
  return'';
}
function mutatingAuthoritySnapshot(record,actionId){
  if(!isPlainObject(record)||!base.isOneShotApprovalRequired(actionId)||!base.canExecuteAction(record,actionId))return null;
  const deviceId=sanitizeDeviceId(record.id),endpointIp=base.normalizeNodeIpv4(record.endpointIp),agentSessionId=base.sanitizeSessionId(record.agentSessionId),catalog=base.ACTION_CATALOG[actionId];
  if(!deviceId||!endpointIp||!agentSessionId||!catalog)return null;
  const capabilities=sorted(base.sanitizeCapabilities(record.capabilities));
  const advertisedActions=sorted(base.sanitizeActionIds(record.advertisedActions));
  const approvedActions=sorted(base.sanitizeActionIds(record.approvedActions));
  if(!capabilities.includes(catalog.capability)||!advertisedActions.includes(actionId)||!approvedActions.includes(actionId))return null;
  return Object.freeze({
    bindingVersion:MUTATING_INTENT_BINDING_VERSION,
    deviceId,endpointIp,agentSessionId,
    policyId:base.ALLOWLIST_POLICY_ID,
    nodeHealthProtocol:base.NODE_AGENT_PROTOCOL,
    nodeActionsProtocol:base.NODE_ACTIONS_PROTOCOL,
    nodeAuthProtocol:base.NODE_AUTH_PROTOCOL,
    actionId,requiredCapability:catalog.capability,
    capabilities:Object.freeze(capabilities),
    advertisedActions:Object.freeze(advertisedActions),
    approvedActions:Object.freeze(approvedActions)
  });
}
function mutatingIntentBinding(record,actionId,targetDigest){
  const snapshot=mutatingAuthoritySnapshot(record,actionId),digest=base.sanitizeTargetDigest(targetDigest);
  if(!snapshot||!base.validTargetDigestForAction(actionId,digest))return null;
  return Object.freeze({...snapshot,targetDigest:digest});
}
function bindingKey(binding){
  if(!isPlainObject(binding)||binding.bindingVersion!==MUTATING_INTENT_BINDING_VERSION)return'';
  return [binding.bindingVersion,binding.deviceId,binding.endpointIp,binding.agentSessionId,binding.policyId,binding.nodeHealthProtocol,binding.nodeActionsProtocol,binding.nodeAuthProtocol,binding.actionId,binding.requiredCapability,(binding.capabilities||[]).join(','),(binding.advertisedActions||[]).join(','),(binding.approvedActions||[]).join(','),binding.targetDigest].join('\n');
}
class IntentBoundMutatingApprovalLedger{
  constructor(options={}){
    this._now=typeof options.now==='function'?options.now:()=>Date.now();
    this._idFactory=typeof options.idFactory==='function'?options.idFactory:secureApprovalId;
    this._ttlMs=Number.isFinite(options.ttlMs)&&options.ttlMs>0?Math.min(Math.floor(options.ttlMs),base.ONE_SHOT_APPROVAL_TTL_MS):base.ONE_SHOT_APPROVAL_TTL_MS;
    this._max=Number.isInteger(options.maxOutstanding)&&options.maxOutstanding>0?Math.min(options.maxOutstanding,base.ONE_SHOT_APPROVAL_MAX_OUTSTANDING):base.ONE_SHOT_APPROVAL_MAX_OUTSTANDING;
    this._tickets=new Map();
  }
  _prune(){const now=this._now();for(const[id,ticket]of this._tickets){if(now>ticket.expiresAt)this._tickets.delete(id)}}
  approve(record,actionId,targetDigest){
    this._prune();if(this._tickets.size>=this._max)return null;
    const binding=mutatingIntentBinding(record,actionId,targetDigest);if(!binding)return null;
    const approvalId=base.sanitizeApprovalId(this._idFactory());if(!approvalId||this._tickets.has(approvalId))return null;
    const approvedAt=this._now(),ticket=Object.freeze({...binding,approvalId,approvedAt,expiresAt:approvedAt+this._ttlMs});
    this._tickets.set(approvalId,ticket);return ticket;
  }
  consume(approvalId,record,actionId,targetDigest){
    this._prune();const id=base.sanitizeApprovalId(approvalId);if(!id)return false;
    const ticket=this._tickets.get(id);if(!ticket)return false;
    this._tickets.delete(id);
    if(this._now()>ticket.expiresAt)return false;
    const binding=mutatingIntentBinding(record,actionId,targetDigest);if(!binding)return false;
    return bindingKey(ticket)===bindingKey(binding);
  }
  revoke(approvalId){const id=base.sanitizeApprovalId(approvalId);return id?this._tickets.delete(id):false}
  clear(){this._tickets.clear()}
  snapshot(){this._prune();return Object.freeze({outstandingCount:this._tickets.size,ttlMs:this._ttlMs,maxOutstanding:this._max,endpointBound:true,authoritySnapshotBound:true,rawTargetsStored:false,persistent:false})}
}

return Object.freeze({...base,CC_VERSION,MUTATING_INTENT_BINDING_VERSION,mutatingAuthoritySnapshot,mutatingIntentBinding,bindingKey,IntentBoundMutatingApprovalLedger});
});
