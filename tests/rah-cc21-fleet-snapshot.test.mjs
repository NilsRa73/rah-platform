import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const stable=require('../rah-command-center-core-v2.0.js');
const candidate=require('../rah-command-center-core-v2.1-candidate.js');
const manifest=JSON.parse(fs.readFileSync('RAH-CC21-FLEET-SNAPSHOT-CANDIDATE.json','utf8'));
const html=fs.readFileSync('RAH-COMMAND-CENTER-V2.1-CANDIDATE.html','utf8');

const health={
  protocol: stable.NODE_AGENT_PROTOCOL,
  status:'ready',
  hostname:'node-one',
  agentVersion:'1.3.0',
  sessionId:'ABCDEFGHIJKLMNOPQRSTUVWX',
  platform:'Windows',
  platformRelease:'11',
  capabilities:['compute','storage','display','remote-desktop'],
  permissions:{remoteControl:false,commands:false,fileAccess:false,shell:false}
};
function actionRow(id){
  const c=stable.ACTION_CATALOG[id];
  const row={id:c.id,method:c.method,path:c.path,capability:c.capability,scope:c.scope,mutating:c.mutating};
  if(c.input)row.input=c.input;
  if(c.mutating)row.localApprovalRequired=true;
  return row;
}
const catalog={
  protocol:stable.NODE_ACTIONS_PROTOCOL,
  status:'ready',
  policyId:stable.ALLOWLIST_POLICY_ID,
  approvalMode:'command-center-ephemeral-plus-node-local',
  sessionId:health.sessionId,
  actions:[actionRow('storage-summary.read'),actionRow('rustdesk.launch')]
};
const record={
  id:'node-1',label:'Node 1',enrolled:true,endpointIp:'192.168.1.25',
  agentSessionId:health.sessionId,approvedActions:['storage-summary.read'],
  advertisedActions:['storage-summary.read','rustdesk.launch'],capabilities:health.capabilities
};

test('2.1 Candidate extends exact 2.0 Stable authority',()=>{
  assert.equal(stable.CC_VERSION,'2.0.0');
  assert.equal(candidate.CC_VERSION,'2.1.0-candidate');
  assert.equal(candidate.FLEET_SNAPSHOT_VERSION,'rah-cc-fleet-snapshot-v1');
  assert.deepEqual(candidate.CAPABILITY_IDS,['compute','storage','display','remote-desktop']);
  assert.deepEqual(candidate.ACTION_IDS,['storage-summary.read','rustdesk.launch','rustdesk.connect']);
  assert.deepEqual(candidate.AUTHENTICATED_PATHS,['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk']);
});

test('fleet rows require enrolled private endpoint and exact Node session',()=>{
  assert.equal(candidate.isFleetSnapshotEligibleDevice(record),true);
  const row=candidate.createFleetSnapshotRow(record,health,catalog,1786950000000);
  assert.ok(row);
  assert.equal(row.deviceId,'node-1');
  assert.equal(row.endpointIp,'192.168.1.25');
  assert.equal(row.sessionId,health.sessionId);
  assert.equal(row.persistent,false);
  assert.deepEqual(row.capabilities,health.capabilities);
  assert.deepEqual(row.advertisedActions,['storage-summary.read','rustdesk.launch']);
  assert.deepEqual(row.approvedActions,['storage-summary.read']);
  assert.equal(candidate.createFleetSnapshotRow({...record,agentSessionId:'ZYXWVUTSRQPONMLKJIHGFEDC'},health,catalog,1786950000000),null);
  assert.equal(candidate.isFleetSnapshotEligibleDevice({...record,endpointIp:'8.8.8.8'}),false);
});

test('fleet summary is memory-only and explicitly non-discovering',()=>{
  const row=candidate.createFleetSnapshotRow(record,health,catalog,1786950000000);
  const summary=candidate.fleetSnapshotSummary([row]);
  assert.deepEqual(summary,{
    snapshotVersion:'rah-cc-fleet-snapshot-v1',
    onlineCount:1,
    capabilityCount:4,
    advertisedActionCount:2,
    persistent:false,
    backgroundPolling:false,
    discovery:false
  });
});

test('candidate manifest preserves Node 1.3 and exact 4/3/5 authority',()=>{
  assert.equal(manifest.stage,'candidate');
  assert.equal(manifest.stable_runtime_modified,false);
  assert.equal(manifest.authority_surface_changed,false);
  assert.equal(manifest.node_agent_runtime_changed,false);
  assert.equal(manifest.fleet_snapshot.background_polling,false);
  assert.equal(manifest.fleet_snapshot.network_discovery,false);
  assert.deepEqual(manifest.fleet_snapshot.new_business_routes,[]);
  assert.deepEqual(manifest.fleet_snapshot.new_actions,[]);
  assert.deepEqual(manifest.fleet_snapshot.new_capabilities,[]);
  assert.equal(manifest.preserved_authority.capabilities.length,4);
  assert.equal(manifest.preserved_authority.actions.length,3);
  assert.equal(manifest.preserved_authority.business_routes.length,5);
  assert.equal(manifest.preserved_authority.node_agent_version,'1.3.0');
});

test('Candidate UI is explicit refresh only and does not persist token or snapshot',()=>{
  for(const marker of ['MANUAL FLEET SNAPSHOT','fleetRefreshBtn','Fresh Node token for this refresh','rah-command-center-core-v2.1-candidate.js','window.RAHCommandCenterFleetSnapshotCandidate'])assert.match(html,new RegExp(marker.replace(/[.*+?^${}()|[\]\\]/g,'\\$&')));
  assert.doesNotMatch(html,/setInterval\s*\(/);
  assert.doesNotMatch(html,/setTimeout\s*\(\s*refreshFleet/);
  assert.doesNotMatch(html,/localStorage\.setItem\([^)]*fleet/i);
  assert.doesNotMatch(html,/localStorage\.setItem\([^)]*token/i);
  assert.doesNotMatch(html,/\/scan|\/discover|\/command|\/shell|\/files/);
});
