(function(root,factory){
  const candidate=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v2.4-candidate.js'):(root&&root.RAHCommandCenterRavenCommanderCandidate);
  const api=factory(candidate);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterCoreV24=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(candidate){
'use strict';
if(!candidate)throw new Error('RAH Command Center 2.4 Candidate implementation is required');
if(candidate.CC_VERSION!=='2.4.0-candidate'||candidate.RAVEN_COMMANDER_VERSION!=='rah-cc-raven-commander-v1'||candidate.RAVEN_STATUS_PROTOCOL!=='rah-node-raven-status-v1'||candidate.RAVEN_STATUS_ROUTE!=='/raven/status'||candidate.RAVEN_STATUS_CAPABILITY!=='system-inventory'||candidate.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||candidate.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1')throw new Error('Unexpected CC 2.4 Candidate contract');
return Object.freeze({...candidate,CC_VERSION:'2.4.0'});
});
