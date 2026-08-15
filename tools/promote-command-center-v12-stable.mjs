import fs from 'node:fs';
const read=p=>fs.readFileSync(p,'utf8');
const write=(p,s)=>fs.writeFileSync(p,s);

const manifestPath='RAH-COMMAND-CENTER-VERSION.json';
const ravenPath='RAH-RAVEN-VERSION.json';
const manifest=JSON.parse(read(manifestPath));
const raven=JSON.parse(read(ravenPath));
const stableCoreBefore=JSON.stringify(raven.release_gate?.stable_components||{});

if(manifest.version!=='1.2.0'||manifest.stage!=='feature-candidate'||manifest.release_gate?.status!=='candidate'||manifest.release_gate?.gate_version!=='1.8.0-candidate')throw new Error('CC v1.2 Candidate baseline mismatch');
if(manifest.node_agent?.agent_version!=='0.8.0'||manifest.node_agent?.protocol!=='rah-node-health-v2'||manifest.node_agent?.actions_protocol!=='rah-node-actions-v3')throw new Error('Node Agent v0.8 Candidate baseline mismatch');
if(raven.product!=='RAH Raven'||raven.version!=='2.0.32')throw new Error('Raven master baseline mismatch');

manifest.stage='stable';
manifest.stable_since='2026-08-15';
manifest.release_gate.status='passed';
manifest.release_gate.gate_version='1.8.0';
manifest.release_gate.runtime_files_frozen=true;
manifest.release_gate.change_policy='bugfix-only-until-explicit-reopen';
manifest.development_paused=true;
manifest.change_policy='bugfix-only-until-explicit-reopen';
write(manifestPath,JSON.stringify(manifest,null,2)+'\n');

let v12=read('tests/rah-command-center-v12.test.mjs');
const candidate="manifest:()=>{assert.equal(cc.version,'1.2.0');assert.equal(cc.stage,'feature-candidate');assert.equal(cc.previous_stable_version,'1.1.0');assert.equal(cc.release_gate.status,'candidate');assert.equal(cc.release_gate.gate_version,'1.8.0-candidate');";
const stable="manifest:()=>{assert.equal(cc.version,'1.2.0');assert.equal(cc.stage,'stable');assert.equal(cc.stable_since,'2026-08-15');assert.equal(cc.previous_stable_version,'1.1.0');assert.equal(cc.release_gate.status,'passed');assert.equal(cc.release_gate.gate_version,'1.8.0');assert.equal(cc.release_gate.runtime_files_frozen,true);assert.equal(cc.development_paused,true);assert.equal(cc.change_policy,'bugfix-only-until-explicit-reopen');";
if(!v12.includes(candidate))throw new Error('v1.2 integration Candidate expectation missing');
v12=v12.replace(candidate,stable);
write('tests/rah-command-center-v12.test.mjs',v12);

let pkg=read('tests/rah-command-center-packaging.test.mjs');
const candidatePkg="test('v1.2 candidate package',()=>{assert.equal(m.version,'1.2.0');assert.equal(m.stage,'feature-candidate');assert.equal(m.release_gate.status,'candidate');";
const stablePkg="test('v1.2 Stable package',()=>{assert.equal(m.version,'1.2.0');assert.equal(m.stage,'stable');assert.equal(m.stable_since,'2026-08-15');assert.equal(m.release_gate.status,'passed');assert.equal(m.release_gate.gate_version,'1.8.0');assert.equal(m.release_gate.runtime_files_frozen,true);assert.equal(m.development_paused,true);assert.equal(m.change_policy,'bugfix-only-until-explicit-reopen');";
if(!pkg.includes(candidatePkg))throw new Error('v1.2 packaging Candidate expectation missing');
pkg=pkg.replace(candidatePkg,stablePkg);
write('tests/rah-command-center-packaging.test.mjs',pkg);

const oldStart='RAH Raven Command Center v1.1.0 is stable.';
const oldEnd='RustDesk handoff still claims only handoff-started, not a successful remote session.';
const start=raven.summary.indexOf(oldStart),end=raven.summary.indexOf(oldEnd,start);
if(start<0||end<0)throw new Error('Raven v1.1 Command Center summary baseline missing');
const replacement='RAH Raven Command Center v1.2.0 is stable. Command Center v1.2 keeps the exact fixed action allowlist storage-summary.read, rustdesk.launch and rustdesk.connect, keeps v1.1 one-time action challenges, and adds session-bound enrollment without adding new action authority. Each Node Agent v0.8 process creates a fresh non-secret session ID; authenticated /health and /actions must report the same session, and Command Center persists only that non-secret session ID as enrollment metadata. A fresh action catalogue must match the enrolled session before its one-time challenge can be used. Agent restart rotates both bearer token and session ID; previous enrollment becomes stale, and re-enrollment to a changed session clears prior local action approvals so each allowed action must be explicitly approved again. The enrollment flow retains only a sanitized challenge-free verified catalogue between the explicit Check and Enroll clicks, fixing the v1.1 enrollment no-op while keeping raw challenge values transient and unpersisted. Challenges, bearer tokens, RustDesk peer IDs and passwords are not persisted; passwords are not accepted or transported. User-supplied executable paths, arbitrary arguments, server/key/URL overrides, installation, generic process or action endpoints, shell access, file access, device commands, background polling, discovery and native Raven remote control remain disabled. RustDesk handoff still claims only handoff-started, not a successful remote session.';
raven.summary=raven.summary.slice(0,start)+replacement+raven.summary.slice(end+oldEnd.length);
if(!raven.files.includes('RAH-COMMAND-CENTER-V1.1.html'))throw new Error('Raven v1.1 file baseline missing');
if(raven.files.includes('RAH-COMMAND-CENTER-V1.2.html'))throw new Error('Raven v1.2 entry already listed');
const idx=raven.files.indexOf('RAH-COMMAND-CENTER-V1.1.html');
raven.files.splice(idx+1,0,'RAH-COMMAND-CENTER-V1.2.html');
Object.assign(raven.privacy,{
  command_center_version_synced:true,
  command_center_stable:true,
  command_center_runtime_frozen:true,
  command_center_node_agent_version_synced:true,
  command_center_node_health_protocol_v2:true,
  command_center_node_action_protocol_v3:true,
  command_center_session_bound_enrollment:true,
  command_center_agent_session_id_rotates_on_start:true,
  command_center_agent_session_id_node_memory_only:true,
  command_center_agent_session_id_secret:false,
  command_center_enrollment_session_id_persistence:true,
  command_center_enrollment_session_id_non_secret:true,
  command_center_enrollment_health_actions_session_match_required:true,
  command_center_enrollment_verified_catalog_sanitized_only:true,
  command_center_enrollment_pending_raw_action_challenge:false,
  command_center_enrollment_raw_action_challenge_persistence:false,
  command_center_agent_session_mismatch_blocks_action_challenge:true,
  command_center_agent_session_change_requires_reverification:true,
  command_center_agent_session_change_clears_approvals_on_reenroll:true,
  command_center_remote_control:false,
  command_center_device_commands:false,
  command_center_file_access:false,
  command_center_shell_access:false,
  command_center_credential_collection:false,
  command_center_generic_process_launch:false,
  command_center_generic_action_endpoint:false,
  command_center_node_native_remote_control_endpoints:false
});
if(JSON.stringify(raven.release_gate?.stable_components||{})!==stableCoreBefore)throw new Error('Stable Raven core components changed during v1.2 sync');
if(!raven.summary.includes('RAH Raven Command Center v1.2.0 is stable'))throw new Error('Raven v1.2 summary sync failed');
if(raven.files.filter(x=>x==='RAH-COMMAND-CENTER-V1.2.html').length!==1)throw new Error('Raven v1.2 entry sync failed');
write(ravenPath,JSON.stringify(raven,null,2)+'\n');
console.log('CC v1.2 Stable + Raven master metadata generated atomically; runtime files untouched.');
