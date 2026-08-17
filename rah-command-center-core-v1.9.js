(function(root,factory){
  const candidate=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.9-candidate.js'):(root&&root.RAHCommandCenterIntentBindingCandidate);
  const api=factory(candidate);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterCoreV19=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(candidate){
'use strict';
if(!candidate)throw new Error('RAH Command Center 1.9 Candidate implementation is required');
if(candidate.CC_VERSION!=='1.9.0-candidate'||candidate.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v7'||candidate.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||candidate.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1'||candidate.MUTATING_INTENT_BINDING_VERSION!=='rah-cc-mutating-intent-v1'||candidate.ONE_SHOT_APPROVAL_TTL_MS!==90000||candidate.ONE_SHOT_APPROVAL_MAX_OUTSTANDING!==32)throw new Error('Unexpected CC 1.9 Candidate contract');
return Object.freeze({...candidate,CC_VERSION:'1.9.0'});
});
