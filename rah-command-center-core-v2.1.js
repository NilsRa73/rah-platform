(function(root,factory){
  const candidate=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v2.1-candidate.js'):(root&&root.RAHCommandCenterFleetSnapshotCandidate);
  const api=factory(candidate);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterCoreV21=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(candidate){
'use strict';
if(!candidate)throw new Error('RAH Command Center 2.1 Candidate implementation is required');
if(candidate.CC_VERSION!=='2.1.0-candidate'||candidate.FLEET_SNAPSHOT_VERSION!=='rah-cc-fleet-snapshot-v1'||candidate.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v7'||candidate.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||candidate.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1'||candidate.PRECOMMITTED_REQUESTER_CONTEXT_VERSION!=='rah-cc-precommitted-requester-context-v1')throw new Error('Unexpected CC 2.1 Candidate contract');
return Object.freeze({...candidate,CC_VERSION:'2.1.0'});
});
