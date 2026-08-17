(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v2.0.js'):(root&&root.RAHCommandCenterCoreV20);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterFleetSnapshotCandidate=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center 2.0 Stable core is required');
if(base.CC_VERSION!=='2.0.0'||base.NODE_ACTIONS_PROTOCOL!=='rah-node-actions-v7'||base.NODE_AUTH_PROTOCOL!=='rah-node-auth-v2'||base.ALLOWLIST_POLICY_ID!=='rah-capability-allowlist-v1'||base.PRECOMMITTED_REQUESTER_CONTEXT_VERSION!=='rah-cc-precommitted-requester-context-v1')throw new Error('Unexpected CC 2.0 Stable contract');

const CC_VERSION='2.1.0-candidate';
const FLEET_SNAPSHOT_VERSION='rah-cc-fleet-snapshot-v1';

function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function cleanText(v,max){return typeof v==='string'?v.replace(/[\r\n\0]/g,' ').trim().slice(0,max||120):''}
function frozenStrings(values,allow){
  const out=[];
  for(const value of Array.isArray(values)?values:[]){
    if(typeof value!=='string')continue;
    if(allow&&!allow.includes(value))continue;
    if(!out.includes(value))out.push(value);
  }
  return Object.freeze(out);
}
function isFleetSnapshotEligibleDevice(record){
  return isPlainObject(record)&&record.enrolled===true&&base.isAllowedNodeIpv4(record.endpointIp)&&!!base.sanitizeSessionId(record.agentSessionId);
}
function createFleetSnapshotRow(record,healthPayload,catalogPayload,refreshedAt){
  if(!isFleetSnapshotEligibleDevice(record))return null;
  const health=base.sanitizeNodeHealth(healthPayload);
  if(!health||health.sessionId!==base.sanitizeSessionId(record.agentSessionId))return null;
  const catalog=base.sanitizeActionCatalog(catalogPayload,health.capabilities,health.sessionId);
  if(!catalog||catalog.sessionId!==health.sessionId)return null;
  const refreshed=Number(refreshedAt);
  if(!Number.isFinite(refreshed)||refreshed<=0)return null;
  const approved=frozenStrings(record.approvedActions,base.ACTION_IDS);
  return Object.freeze({
    snapshotVersion:FLEET_SNAPSHOT_VERSION,
    deviceId:cleanText(record.id,80),
    label:cleanText(record.label,120),
    endpointIp:base.normalizeNodeIpv4(record.endpointIp),
    hostname:cleanText(health.hostname,120),
    agentVersion:cleanText(health.agentVersion,40),
    platform:cleanText(health.platformRelease?(health.platform+' '+health.platformRelease):health.platform,120),
    sessionId:health.sessionId,
    capabilities:frozenStrings(health.capabilities,base.CAPABILITY_IDS),
    advertisedActions:frozenStrings(catalog.actions,base.ACTION_IDS),
    approvedActions:approved,
    refreshedAt:Math.floor(refreshed),
    online:true,
    persistent:false
  });
}
function fleetSnapshotSummary(rows){
  const safe=(Array.isArray(rows)?rows:[]).filter(row=>isPlainObject(row)&&row.snapshotVersion===FLEET_SNAPSHOT_VERSION&&row.online===true);
  const capabilities=new Set(),actions=new Set();
  for(const row of safe){
    for(const cap of Array.isArray(row.capabilities)?row.capabilities:[])if(base.CAPABILITY_IDS.includes(cap))capabilities.add(cap);
    for(const action of Array.isArray(row.advertisedActions)?row.advertisedActions:[])if(base.ACTION_IDS.includes(action))actions.add(action);
  }
  return Object.freeze({
    snapshotVersion:FLEET_SNAPSHOT_VERSION,
    onlineCount:safe.length,
    capabilityCount:capabilities.size,
    advertisedActionCount:actions.size,
    persistent:false,
    backgroundPolling:false,
    discovery:false
  });
}

return Object.freeze({...base,CC_VERSION,FLEET_SNAPSHOT_VERSION,isFleetSnapshotEligibleDevice,createFleetSnapshotRow,fleetSnapshotSummary});
});