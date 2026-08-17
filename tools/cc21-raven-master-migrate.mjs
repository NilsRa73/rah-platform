import fs from 'node:fs';
const path='RAH-RAVEN-VERSION.json';
const raven=JSON.parse(fs.readFileSync(path,'utf8'));
if(raven.product!=='RAH Raven'||raven.version!=='2.0.32')throw new Error('Unexpected Raven master identity');
if(raven.release_gate?.stage!=='temporary-stable'||raven.release_gate?.temporary_stable_target!=='2.0.32'||raven.release_gate?.development_paused!==true)throw new Error('Raven 2.0.32 freeze is not exact');
const p=raven.privacy||{};
if(p.command_center_canonical_version!=='2.0.0'||p.command_center_canonical_package_generation!==5||p.command_center_canonical_package_dependency_count!==43)throw new Error('Unexpected pre-sync canonical CC metadata');
if(p.command_center_node_agent_version!=='1.3.0'||p.command_center_capability_count!==4||p.command_center_action_count!==3||p.command_center_business_route_count!==5)throw new Error('Unexpected authority baseline');
const oldA='RAH Raven Command Center v2.0.0 is Stable and canonical.';
const oldB='Command Center v2.0 keeps the exact four capabilities compute, storage, display and remote-desktop;';
if(!raven.summary.includes(oldA)||!raven.summary.includes(oldB))throw new Error('Expected CC 2.0 summary markers missing');
raven.summary=raven.summary.replace(oldA,'RAH Raven Command Center v2.1.0 is Stable and canonical.').replace(oldB,'Command Center v2.1 keeps the exact four capabilities compute, storage, display and remote-desktop;');
const anchor='Existing advertised-action, capability, ephemeral Command Center approval, requester-source validation, Node-local human confirmation, fresh action challenge and Node-local approval proof remain independent gates.';
if(!raven.summary.includes(anchor))throw new Error('Security-chain summary anchor missing');
const fleet='Command Center v2.1 additionally adds Manual Fleet Snapshot for already-enrolled private Nodes only: refresh is an explicit selected-device click, requires a fresh Node token with token-proof authentication and exact Node-session match, stores snapshot rows in browser memory only, and adds no discovery, background polling, automatic storage read, automatic remote control or mutating Fleet action. ';
raven.summary=raven.summary.replace(anchor,fleet+anchor);
const cc21=[
  'RAH-COMMAND-CENTER-V2.1.html',
  'RAH-COMMAND-CENTER-V2.1-CANDIDATE.html',
  'rah-command-center-core-v2.1-candidate.js',
  'rah-command-center-core-v2.1.js',
  'RAH-CC21-FLEET-SNAPSHOT-CANDIDATE.json',
  'RAH-CC21-NODE13-STABLE-RELEASE.json'
];
for(const f of cc21){if(raven.files.includes(f))throw new Error('CC 2.1 artifact already present: '+f);raven.files.push(f)}
p.command_center_canonical_version='2.1.0';
p.command_center_canonical_package_generation=6;
p.command_center_canonical_package_dependency_count=49;
p.command_center_manual_fleet_snapshot=true;
p.command_center_fleet_snapshot_version='rah-cc-fleet-snapshot-v1';
p.command_center_fleet_snapshot_scope='already-enrolled-devices-only';
p.command_center_fleet_snapshot_explicit_selected_device_refresh=true;
p.command_center_fleet_snapshot_fresh_node_token_per_refresh=true;
p.command_center_fleet_snapshot_token_proof_authentication=true;
p.command_center_fleet_snapshot_session_match_required=true;
p.command_center_fleet_snapshot_token_persistence=false;
p.command_center_fleet_snapshot_memory_only=true;
p.command_center_fleet_snapshot_persistence=false;
p.command_center_fleet_snapshot_background_polling=false;
p.command_center_fleet_snapshot_network_discovery=false;
p.command_center_fleet_snapshot_automatic_storage_read=false;
p.command_center_fleet_snapshot_automatic_remote_control=false;
p.command_center_fleet_snapshot_mutating_actions=false;
p.command_center_fleet_snapshot_cross_session_refresh_fails_closed=true;
fs.writeFileSync(path,JSON.stringify(raven,null,2)+'\n');
console.log('Raven 2.0.32 master metadata prepared for canonical CC 2.1; runtime and authority unchanged.');
