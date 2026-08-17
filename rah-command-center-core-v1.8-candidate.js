(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.7.js'):(root&&root.RAHCommandCenterCoreV17);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterOneShotCandidate=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center 1.7 Stable core is required');
if(base.CC_VERSION!=='1.7.0'||base.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v7'||base.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2')throw new Error('Unexpected CC 1.7 Stable contract');

const CC_VERSION='1.8.0-candidate';
const ONE_SHOT_APPROVAL_TTL_MS=90000;
const ONE_SHOT_APPROVAL_MAX_OUTSTANDING=32;
const EMPTY_TARGET_DIGEST='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
const MUTATING_ACTION_IDS=Object.freeze(['rustdesk.launch','rustdesk.connect']);

function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function sanitizeApprovalId(v){return typeof v==='string'&&v===v.trim()&&/^[A-Za-z0-9_-]{32,96}$/.test(v)?v:''}
function sanitizeTargetDigest(v){return typeof v==='string'&&/^[0-9a-f]{64}$/.test(v)?v:''}
function sanitizeDeviceId(v){return typeof v==='string'&&v===v.trim()&&/^[a-z0-9][a-z0-9-]{0,63}$/.test(v)?v:''}
function isOneShotApprovalRequired(actionId){return MUTATING_ACTION_IDS.includes(actionId)}
function validTargetDigestForAction(actionId,targetDigest){const d=sanitizeTargetDigest(targetDigest);if(!d)return false;if(actionId==='rustdesk.launch')return d===EMPTY_TARGET_DIGEST;if(actionId==='rustdesk.connect')return d!==EMPTY_TARGET_DIGEST;return false}
function defaultApprovalIdFactory(){
  const cryptoObj=typeof globalThis!=='undefined'?globalThis.crypto:null;
  if(!cryptoObj||typeof cryptoObj.getRandomValues!=='function')return'';
  const bytes=new Uint8Array(32);cryptoObj.getRandomValues(bytes);let binary='';for(const b of bytes)binary+=String.fromCharCode(b);
  if(typeof btoa==='function')return btoa(binary).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'');
  if(typeof Buffer!=='undefined')return Buffer.from(bytes).toString('base64url');
  return'';
}
function approvalBinding(record,actionId,targetDigest){
  if(!isPlainObject(record)||!isOneShotApprovalRequired(actionId)||!validTargetDigestForAction(actionId,targetDigest)||!base.canExecuteAction(record,actionId))return null;
  const deviceId=sanitizeDeviceId(record.id),agentSessionId=base.sanitizeSessionId(record.agentSessionId);
  if(!deviceId||!agentSessionId)return null;
  return Object.freeze({deviceId,agentSessionId,actionId,targetDigest:sanitizeTargetDigest(targetDigest)});
}
class OneShotMutatingApprovalLedger{
  constructor(options={}){
    this._now=typeof options.now==='function'?options.now:()=>Date.now();
    this._idFactory=typeof options.idFactory==='function'?options.idFactory:defaultApprovalIdFactory;
    this._ttlMs=Number.isFinite(options.ttlMs)&&options.ttlMs>0?Math.min(Math.floor(options.ttlMs),ONE_SHOT_APPROVAL_TTL_MS):ONE_SHOT_APPROVAL_TTL_MS;
    this._max=Number.isInteger(options.maxOutstanding)&&options.maxOutstanding>0?Math.min(options.maxOutstanding,ONE_SHOT_APPROVAL_MAX_OUTSTANDING):ONE_SHOT_APPROVAL_MAX_OUTSTANDING;
    this._tickets=new Map();
  }
  _prune(){const now=this._now();for(const[id,ticket]of this._tickets){if(now>ticket.expiresAt)this._tickets.delete(id)}}
  approve(record,actionId,targetDigest){
    this._prune();if(this._tickets.size>=this._max)return null;
    const binding=approvalBinding(record,actionId,targetDigest);if(!binding)return null;
    const approvalId=sanitizeApprovalId(this._idFactory());if(!approvalId||this._tickets.has(approvalId))return null;
    const approvedAt=this._now(),ticket=Object.freeze({...binding,approvalId,approvedAt,expiresAt:approvedAt+this._ttlMs});this._tickets.set(approvalId,ticket);return ticket;
  }
  consume(approvalId,record,actionId,targetDigest){
    this._prune();const id=sanitizeApprovalId(approvalId);if(!id)return false;const ticket=this._tickets.get(id);if(!ticket)return false;
    this._tickets.delete(id);
    if(this._now()>ticket.expiresAt)return false;
    const binding=approvalBinding(record,actionId,targetDigest);if(!binding)return false;
    return ticket.deviceId===binding.deviceId&&ticket.agentSessionId===binding.agentSessionId&&ticket.actionId===binding.actionId&&ticket.targetDigest===binding.targetDigest;
  }
  revoke(approvalId){const id=sanitizeApprovalId(approvalId);return id?this._tickets.delete(id):false}
  clear(){this._tickets.clear()}
  snapshot(){this._prune();return Object.freeze({outstandingCount:this._tickets.size,ttlMs:this._ttlMs,maxOutstanding:this._max,rawTargetsStored:false,persistent:false})}
}

return Object.freeze({...base,CC_VERSION,ONE_SHOT_APPROVAL_TTL_MS,ONE_SHOT_APPROVAL_MAX_OUTSTANDING,EMPTY_TARGET_DIGEST,MUTATING_ACTION_IDS,sanitizeApprovalId,sanitizeTargetDigest,isOneShotApprovalRequired,validTargetDigestForAction,approvalBinding,OneShotMutatingApprovalLedger});
});
