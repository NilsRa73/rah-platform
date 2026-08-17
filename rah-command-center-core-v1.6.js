(function(root,factory){
  const candidate=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.6-candidate.js'):(root&&root.RAHCommandCenterRequesterContextCandidate);
  const api=factory(candidate);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterCoreV16=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(candidate){
'use strict';
if(!candidate)throw new Error('RAH Command Center 1.6 Candidate implementation is required');
if(candidate.CC_VERSION!=='1.6.0-candidate'||candidate.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v6'||candidate.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1'||candidate.REQUESTER_CONTEXT_HEADER!=='X-RAH-Requester-Context')throw new Error('Unexpected CC 1.6 Candidate contract');
return Object.freeze({...candidate,CC_VERSION:'1.6.0'});
});
