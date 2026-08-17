(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v2.1.js'):(root&&root.RAHCommandCenterCoreV21);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterFleetSnapshotInvalidationCandidate=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center 2.1 Stable core is required');
if(base.CC_VERSION!=='2.1.0'||base.FLEET_SNAPSHOT_VERSION!=='rah-cc-fleet-snapshot-v1'||base.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v7'||base.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||base.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1'||base.PRECOMMITTED_REQUESTER_CONTEXT_VERSION!=='rah-cc-precommitted-requester-context-v1')throw new Error('Unexpected CC 2.1 Stable contract');

const CC_VERSION='2.2.0-candidate';
const FLEET_SNAPSHOT_INVALIDATION_VERSION='rah-cc-fleet-snapshot-invalidation-v1';
const FLEET_SNAPSHOT_FAILURE_POLICY='invalidate-selected-row-on-refresh-failure';

function cleanDeviceId(value){
  return typeof value==='string'?value.replace(/[\r\n\0]/g,' ').trim().slice(0,80):'';
}
function invalidateFleetSnapshotRow(rows,deviceId){
  if(!(rows instanceof Map))return false;
  const id=cleanDeviceId(deviceId);
  if(!id)return false;
  return rows.delete(id);
}

return Object.freeze({...base,CC_VERSION,FLEET_SNAPSHOT_INVALIDATION_VERSION,FLEET_SNAPSHOT_FAILURE_POLICY,invalidateFleetSnapshotRow});
});
