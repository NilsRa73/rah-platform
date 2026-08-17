(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v2.2.js'):(root&&root.RAHCommandCenterCoreV22);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterFleetRegistryBindingCandidate=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center 2.2 Stable core is required');
if(base.CC_VERSION!=='2.2.0'||base.FLEET_SNAPSHOT_VERSION!=='rah-cc-fleet-snapshot-v1'||base.FLEET_SNAPSHOT_INVALIDATION_VERSION!=='rah-cc-fleet-snapshot-invalidation-v1'||base.FLEET_SNAPSHOT_FAILURE_POLICY!=='invalidate-selected-row-on-refresh-failure'||base.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v7'||base.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||base.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1')throw new Error('Unexpected CC 2.2 Stable contract');

const CC_VERSION='2.3.0-candidate';
const FLEET_SNAPSHOT_REGISTRY_BINDING_VERSION='rah-cc-fleet-snapshot-registry-binding-v1';
const FLEET_SNAPSHOT_REGISTRY_POLICY='prune-row-on-registry-identity-drift';

function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function cleanId(v){return typeof v==='string'?v.trim():''}
function registryIdentityMap(devices){
  const out=new Map();
  const normalized=base.normalizeDeviceRegistry(Array.isArray(devices)?devices:[]);
  for(const d of normalized){
    if(!base.isFleetSnapshotEligibleDevice(d))continue;
    const id=cleanId(d.id),ip=base.normalizeNodeIpv4(d.endpointIp),session=base.sanitizeSessionId(d.agentSessionId);
    if(id&&ip&&session)out.set(id,Object.freeze({deviceId:id,endpointIp:ip,sessionId:session}));
  }
  return out;
}
function fleetSnapshotRowMatchesRegistry(row,key,identity){
  if(!isPlainObject(row)||!isPlainObject(identity))return false;
  if(row.snapshotVersion!==base.FLEET_SNAPSHOT_VERSION||row.online!==true||row.persistent!==false)return false;
  const mapKey=cleanId(key),rowId=cleanId(row.deviceId),ip=base.normalizeNodeIpv4(row.endpointIp),session=base.sanitizeSessionId(row.sessionId);
  return !!mapKey&&mapKey===rowId&&rowId===identity.deviceId&&ip===identity.endpointIp&&session===identity.sessionId;
}
function pruneFleetSnapshotRows(rows,devices){
  if(!(rows instanceof Map))return Object.freeze({version:FLEET_SNAPSHOT_REGISTRY_BINDING_VERSION,policy:FLEET_SNAPSHOT_REGISTRY_POLICY,removed:0,remaining:0,valid:false});
  const identities=registryIdentityMap(devices);
  let removed=0;
  for(const [key,row] of [...rows.entries()]){
    const identity=identities.get(cleanId(key));
    if(!identity||!fleetSnapshotRowMatchesRegistry(row,key,identity)){rows.delete(key);removed++}
  }
  return Object.freeze({version:FLEET_SNAPSHOT_REGISTRY_BINDING_VERSION,policy:FLEET_SNAPSHOT_REGISTRY_POLICY,removed,remaining:rows.size,valid:true});
}

return Object.freeze({...base,CC_VERSION,FLEET_SNAPSHOT_REGISTRY_BINDING_VERSION,FLEET_SNAPSHOT_REGISTRY_POLICY,registryIdentityMap,fleetSnapshotRowMatchesRegistry,pruneFleetSnapshotRows});
});
