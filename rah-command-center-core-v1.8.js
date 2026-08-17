(function(root,factory){
  const candidate=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.8-candidate.js'):(root&&root.RAHCommandCenterOneShotCandidate);
  const api=factory(candidate);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterCoreV18=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(candidate){
'use strict';
if(!candidate)throw new Error('RAH Command Center 1.8 Candidate implementation is required');
const expectedMutating=JSON.stringify(['rustdesk.launch','rustdesk.connect']);
if(candidate.CC_VERSION!=='1.8.0-candidate'||candidate.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v7'||candidate.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||candidate.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1'||candidate.ONE_SHOT_APPROVAL_TTL_MS!==90000||candidate.ONE_SHOT_APPROVAL_MAX_OUTSTANDING!==32||JSON.stringify(Array.from(candidate.MUTATING_ACTION_IDS||[]))!==expectedMutating)throw new Error('Unexpected CC 1.8 Candidate contract');
return Object.freeze({...candidate,CC_VERSION:'1.8.0'});
});
