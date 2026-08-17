import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);

const stable=require('../rah-command-center-core-v2.2.js');
const candidate=require('../rah-command-center-core-v2.3-candidate.js');
const manifest=JSON.parse(fs.readFileSync('RAH-CC23-FLEET-SNAPSHOT-REGISTRY-BINDING-CANDIDATE.json','utf8'));
const html=fs.readFileSync('RAH-COMMAND-CENTER-V2.3-CANDIDATE.html','utf8');
const source=fs.readFileSync('RAH-COMMAND-CENTER-V2.1-CANDIDATE.html','utf8');
const caps=['compute','storage','display','remote-desktop'];
const actions=['storage-summary.read','rustdesk.launch','rustdesk.connect'];
const routes=['/health','/actions','/storage','/launch/rustdesk','/handoff/rustdesk'];
const sessionA='Session_A_123456789012345678901234';
const sessionB='Session_B_123456789012345678901234';
function device(overrides={}){return {id:'node-a',label:'Node A',enrolled:true,endpointIp:'192.168.1.20',agentSessionId:sessionA,capabilities:['storage','remote-desktop'],advertisedActions:['storage-summary.read','rustdesk.launch','rustdesk.connect'],approvedActions:[],...overrides}}
function row(overrides={}){return {snapshotVersion:'rah-cc-fleet-snapshot-v1',deviceId:'node-a',endpointIp:'192.168.1.20',sessionId:sessionA,online:true,persistent:false,...overrides}}

test('2.3 Candidate extends exact CC2.2 Stable authority with no Node delta',()=>{
  assert.equal(stable.CC_VERSION,'2.2.0');
  assert.equal(candidate.CC_VERSION,'2.3.0-candidate');
  assert.equal(candidate.FLEET_SNAPSHOT_REGISTRY_BINDING_VERSION,'rah-cc-fleet-snapshot-registry-binding-v1');
  assert.equal(candidate.FLEET_SNAPSHOT_REGISTRY_POLICY,'prune-row-on-registry-identity-drift');
  assert.equal(candidate.FLEET_SNAPSHOT_FAILURE_POLICY,'invalidate-selected-row-on-refresh-failure');
  assert.deepEqual(candidate.CAPABILITY_IDS,caps);
  assert.deepEqual(candidate.ACTION_IDS,actions);
  assert.deepEqual(candidate.AUTHENTICATED_PATHS,routes);
  assert.equal(candidate.NODE_ACTIONS_PROTOCOL,'rah-node-actions-v7');
  assert.equal(candidate.NODE_AUTH_PROTOCOL,'rah-node-auth-v2');
  assert.equal(candidate.ALLOWLIST_POLICY_ID,'rah-capability-allowlist-v1');
});

test('registry identity map accepts only enrolled eligible normalized Node identities',()=>{
  const map=candidate.registryIdentityMap([device(),device({id:'node-b',enrolled:false,endpointIp:'192.168.1.21',agentSessionId:sessionB}),device({id:'node-c',endpointIp:'8.8.8.8'})]);
  assert.equal(map.size,1);
  assert.deepEqual(map.get('node-a'),{deviceId:'node-a',endpointIp:'192.168.1.20',sessionId:sessionA});
});

test('snapshot row stays only while exact registry id endpoint and session remain bound',()=>{
  const rows=new Map([['node-a',row()]]);
  let result=candidate.pruneFleetSnapshotRows(rows,[device()]);
  assert.equal(result.valid,true);assert.equal(result.removed,0);assert.equal(result.remaining,1);assert.equal(rows.has('node-a'),true);
  result=candidate.pruneFleetSnapshotRows(rows,[device({endpointIp:'192.168.1.21'})]);
  assert.equal(result.removed,1);assert.equal(rows.size,0);

  rows.set('node-a',row());
  result=candidate.pruneFleetSnapshotRows(rows,[device({agentSessionId:sessionB})]);
  assert.equal(result.removed,1);assert.equal(rows.size,0);

  rows.set('node-a',row());
  result=candidate.pruneFleetSnapshotRows(rows,[]);
  assert.equal(result.removed,1);assert.equal(rows.size,0);
});

test('map-key mismatch and malformed/untrusted rows fail closed',()=>{
  const rows=new Map([
    ['node-b',row()],
    ['node-a',{...row(),endpointIp:'8.8.8.8'}],
    ['node-c',{deviceId:'node-c',endpointIp:'192.168.1.22',sessionId:'bad',online:true,persistent:false,snapshotVersion:'rah-cc-fleet-snapshot-v1'}]
  ]);
  const result=candidate.pruneFleetSnapshotRows(rows,[device(),device({id:'node-b'}),device({id:'node-c',endpointIp:'192.168.1.22'})]);
  assert.equal(result.removed,3);assert.equal(rows.size,0);
  assert.equal(candidate.pruneFleetSnapshotRows({},[device()]).valid,false);
});

test('Candidate manifest is event-driven, memory-only and authority-neutral',()=>{
  assert.equal(manifest.candidate,'2.3.0-candidate');
  assert.equal(manifest.released_from_stable,'2.2.0');
  assert.equal(manifest.authority_surface_changed,false);
  assert.equal(manifest.node_agent_runtime_changed,false);
  const r=manifest.registry_binding;
  assert.equal(r.policy,'prune-row-on-registry-identity-drift');
  assert.deepEqual(r.identity_fields,['deviceId','endpointIp','sessionId']);
  assert.equal(r.prune_removed_device,true);assert.equal(r.prune_endpoint_change,true);assert.equal(r.prune_node_session_change,true);
  assert.equal(r.same_page_signal,'device-grid-mutation-observer');
  assert.equal(r.cross_tab_signal,'storage-event-exact-device-registry-key');
  assert.equal(r.timers,false);assert.equal(r.polling,false);assert.equal(r.network_calls,false);
  assert.equal(r.snapshot_memory_only,true);assert.equal(r.snapshot_persistence,false);assert.equal(r.token_persistence,false);
  assert.deepEqual(r.new_business_routes,[]);assert.deepEqual(r.new_actions,[]);assert.deepEqual(r.new_capabilities,[]);
  assert.deepEqual(manifest.preserved_authority.capabilities,caps);assert.deepEqual(manifest.preserved_authority.actions,actions);assert.deepEqual(manifest.preserved_authority.business_routes,routes);
});

test('UI preserves CC2.2 failed-refresh invalidation and adds event-driven registry reconciliation',()=>{
  const oldPicker="function renderPicker(){const sel=q('fleetDevice'),old=sel.value,devices=loadDevices().filter(core.isFleetSnapshotEligibleDevice);sel.innerHTML='';for(const d of devices){const o=document.createElement('option');o.value=d.id;o.textContent=d.label+' · '+d.endpointIp;sel.appendChild(o)}if(devices.some(d=>d.id===old))sel.value=old;q('fleetRefreshBtn').disabled=!devices.length}";
  assert.ok(source.includes(oldPicker),'Pinned Fleet picker marker drifted');
  for(const marker of [
    "SOURCE='RAH-COMMAND-CENTER-V2.1-CANDIDATE.html'",
    "rah-command-center-core-v2.2.js",
    "rah-command-center-core-v2.3-candidate.js",
    "window.RAHCommandCenterFleetRegistryBindingCandidate",
    "core.invalidateFleetSnapshotRow(fleetRows,selectedId);renderRows();out.className='result bad'",
    "core.pruneFleetSnapshotRows(fleetRows,devices)",
    "new MutationObserver(reconcileFleetRegistry).observe(deviceGrid,{childList:true})",
    "e.storageArea===localStorage&&e.key===core.DEVICE_STORAGE_KEY",
    "reconcileFleetRegistry();"
  ])assert.ok(html.includes(marker),marker);
  assert.doesNotMatch(html,/setInterval\s*\(/);
  assert.doesNotMatch(html,/setTimeout\s*\(\s*reconcileFleetRegistry/);
  assert.doesNotMatch(html,/localStorage\.setItem\([^)]*fleet/i);
  assert.doesNotMatch(html,/Authorization\s*:\s*['"]Bearer/i);
});

test('outer Candidate loader parses and adds no authority endpoint',()=>{
  const script=html.match(/<script>\s*([\s\S]*?)<\/script>\s*<\/body>/)?.[1];assert.ok(script);new Function(script);
  assert.doesNotMatch(html,/\/scan|\/discover|\/command|\/shell|\/files|\/process|\/execute/);
});
