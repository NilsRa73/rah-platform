(function(root,factory){
  const candidate=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.5-candidate.js'):(root&&root.RAHCommandCenterLocalProofCandidate);
  const api=factory(candidate);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterCoreV15=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(candidate){
'use strict';
if(!candidate)throw new Error('RAH Command Center 1.5 Candidate implementation is required');
if(candidate.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v5'||candidate.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1')throw new Error('Unexpected CC 1.5 Candidate protocol/policy');
return Object.freeze({...candidate,CC_VERSION:'1.5.0'});
});
