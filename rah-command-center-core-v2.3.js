(function(root,factory){
  const candidate=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v2.3-candidate.js'):(root&&root.RAHCommandCenterFleetRegistryBindingCandidate);
  const api=factory(candidate);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterCoreV23=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(candidate){
'use strict';
if(!candidate)throw new Error('RAH Command Center 2.3 Candidate implementation is required');
if(candidate.CC_VERSION!=='2.3.0-candidate'||candidate.FLEET_SNAPSHOT_REGISTRY_BINDING_VERSION!=='rah-cc-fleet-snapshot-registry-binding-v1'||candidate.FLEET_SNAPSHOT_REGISTRY_POLICY!=='prune-row-on-registry-identity-drift'||candidate.FLEET_SNAPSHOT_FAILURE_POLICY!=='invalidate-selected-row-on-refresh-failure'||candidate.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v7'||candidate.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||candidate.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1')throw new Error('Unexpected CC 2.3 Candidate contract');
return Object.freeze({...candidate,CC_VERSION:'2.3.0'});
});
