(function(root,factory){
  const base=(typeof module==='object'&&module.exports)?require('./rah-command-center-core-v1.3.js'):(root&&root.RAHCommandCenterCoreV13);
  const api=factory(base);
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCommandCenterEphemeralCandidate=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(base){
'use strict';
if(!base)throw new Error('RAH Command Center 1.3 Stable core is required');

const CC_VERSION='1.4.0-candidate';
const APPROVAL_PERSISTENCE='ephemeral-browser-session';

function isPlainObject(v){return !!v&&typeof v==='object'&&!Array.isArray(v)}
function withoutApprovals(value){
  if(!isPlainObject(value))return value;
  return{...value,approvedActions:[],remoteControlEnabled:false,commandsEnabled:false};
}
function normalizeDeviceRecord(value,index){
  return base.normalizeDeviceRecord(withoutApprovals(value),index);
}
function normalizeDeviceRegistry(value){
  const source=Array.isArray(value)?value.map(withoutApprovals):value;
  return base.normalizeDeviceRegistry(source).map(device=>({...device,approvedActions:[],remoteControlEnabled:false,commandsEnabled:false}));
}
function persistableDeviceRegistry(records){
  return base.normalizeDeviceRegistry(Array.isArray(records)?records:[]).map(device=>({...device,approvedActions:[],remoteControlEnabled:false,commandsEnabled:false}));
}
function persistedApprovalCount(records){
  return persistableDeviceRegistry(records).reduce((count,device)=>count+device.approvedActions.length,0);
}

return Object.freeze({...base,CC_VERSION,APPROVAL_PERSISTENCE,normalizeDeviceRecord,normalizeDeviceRegistry,persistableDeviceRegistry,persistedApprovalCount});
});
