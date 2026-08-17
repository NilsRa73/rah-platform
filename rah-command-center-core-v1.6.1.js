(function(root,factory){
  const promoted=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.6-promoted.js'):(root&&root.RAHCommandCenterRequesterContextCandidate);
  const api=factory(promoted);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterCoreV161=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(promoted){
'use strict';
if(!promoted)throw new Error('RAH Command Center 1.6 promoted implementation is required');
if(promoted.CC_VERSION!=='1.6.0-candidate'||promoted.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v6'||promoted.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1'||promoted.REQUESTER_CONTEXT_HEADER!=='X-RAH-Requester-Context')throw new Error('Unexpected promoted CC 1.6 contract');
return Object.freeze({...promoted,CC_VERSION:'1.6.1'});
});
