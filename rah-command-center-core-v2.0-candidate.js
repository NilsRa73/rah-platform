(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.9.js'):(root&&root.RAHCommandCenterCoreV19);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterPrecommittedContextCandidate=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center 1.9 Stable core is required');
if(base.CC_VERSION!=='1.9.0'||base.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v7'||base.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||base.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1'||base.MUTATING_INTENT_BINDING_VERSION!=='rah-cc-mutating-intent-v1'||base.ONE_SHOT_APPROVAL_TTL_MS!==90000||base.ONE_SHOT_APPROVAL_MAX_OUTSTANDING!==32)throw new Error('Unexpected CC 1.9 Stable contract');

const CC_VERSION='2.0.0-candidate';
const PRECOMMITTED_REQUESTER_CONTEXT_VERSION='rah-cc-precommitted-requester-context-v1';

function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function secureApprovalId(){
  const cryptoObj=typeof globalThis!=='undefined'?globalThis.crypto:null;
  if(!cryptoObj||typeof cryptoObj.getRandomValues!=='function')return'';
  const bytes=new Uint8Array(32);cryptoObj.getRandomValues(bytes);let binary='';for(const b of bytes)binary+=String.fromCharCode(b);
  if(typeof btoa==='function')return btoa(binary).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
  if(typeof Buffer!=='undefined')return Buffer.from(bytes).toString('base64url');
  return'';
}
function sanitizeRequesterContextDigest(v){return base.sanitizeTargetDigest(v)}
function precommittedRequesterContextBinding(record,actionId,targetDigest,requesterContextDigest){
  const intent=base.mutatingIntentBinding(record,actionId,targetDigest),contextDigest=sanitizeRequesterContextDigest(requesterContextDigest);
  if(!intent||!contextDigest)return null;
  return Object.freeze({...intent,contextBindingVersion:PRECOMMITTED_REQUESTER_CONTEXT_VERSION,requesterContextDigest:contextDigest});
}
function precommittedBindingKey(binding){
  if(!isPlainObject(binding)||binding.contextBindingVersion!==PRECOMMITTED_REQUESTER_CONTEXT_VERSION)return'';
  const baseKey=base.bindingKey(binding),contextDigest=sanitizeRequesterContextDigest(binding.requesterContextDigest);
  return baseKey&&contextDigest?baseKey+'\n'+binding.contextBindingVersion+'\n'+contextDigest:'';
}
class PrecommittedRequesterContextLedger{
  constructor(options={}){
    this._now=typeof options.now==='function'?options.now:()=>Date.now();
    this._idFactory=typeof options.idFactory==='function'?options.idFactory:secureApprovalId;
    this._ttlMs=Number.isFinite(options.ttlMs)&&options.ttlMs>0?Math.min(Math.floor(options.ttlMs),base.ONE_SHOT_APPROVAL_TTL_MS):base.ONE_SHOT_APPROVAL_TTL_MS;
    this._max=Number.isInteger(options.maxOutstanding)&&options.maxOutstanding>0?Math.min(options.maxOutstanding,base.ONE_SHOT_APPROVAL_MAX_OUTSTANDING):base.ONE_SHOT_APPROVAL_MAX_OUTSTANDING;
    this._tickets=new Map();
  }
  _prune(){const now=this._now();for(const[id,ticket]of this._tickets){if(now>ticket.expiresAt)this._tickets.delete(id)}}
  approve(record,actionId,targetDigest,requesterContextDigest){
    this._prune();if(this._tickets.size>=this._max)return null;
    const binding=precommittedRequesterContextBinding(record,actionId,targetDigest,requesterContextDigest);if(!binding)return null;
    const approvalId=base.sanitizeApprovalId(this._idFactory());if(!approvalId||this._tickets.has(approvalId))return null;
    const approvedAt=this._now(),ticket=Object.freeze({...binding,approvalId,approvedAt,expiresAt:approvedAt+this._ttlMs});
    this._tickets.set(approvalId,ticket);return ticket;
  }
  consume(approvalId,record,actionId,targetDigest,requesterContextDigest){
    this._prune();const id=base.sanitizeApprovalId(approvalId);if(!id)return false;
    const ticket=this._tickets.get(id);if(!ticket)return false;
    this._tickets.delete(id);
    if(this._now()>ticket.expiresAt)return false;
    const binding=precommittedRequesterContextBinding(record,actionId,targetDigest,requesterContextDigest);if(!binding)return false;
    return precommittedBindingKey(ticket)===precommittedBindingKey(binding);
  }
  revoke(approvalId){const id=base.sanitizeApprovalId(approvalId);return id?this._tickets.delete(id):false}
  clear(){this._tickets.clear()}
  snapshot(){this._prune();return Object.freeze({outstandingCount:this._tickets.size,ttlMs:this._ttlMs,maxOutstanding:this._max,requesterContextDigestBound:true,rawRequesterContextsStored:false,persistent:false})}
}

return Object.freeze({...base,CC_VERSION,PRECOMMITTED_REQUESTER_CONTEXT_VERSION,sanitizeRequesterContextDigest,precommittedRequesterContextBinding,precommittedBindingKey,PrecommittedRequesterContextLedger});
});
