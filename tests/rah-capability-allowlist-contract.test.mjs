import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const contract = JSON.parse(fs.readFileSync('RAH-CAPABILITY-ALLOWLIST-CONTRACT.json', 'utf8'));
const cc = fs.readFileSync('rah-command-center-core.js', 'utf8');
const agent = fs.readFileSync('rah-node-agent.py', 'utf8');
const html = fs.readFileSync('RAH-COMMAND-CENTER-V1.2.html', 'utf8');

const expectedCapabilities = ['compute', 'storage', 'display', 'remote-desktop'];
const expectedActions = [
  {id:'storage-summary.read', capability:'storage', method:'GET', path:'/storage', scope:'system-volume', mutating:false},
  {id:'rustdesk.launch', capability:'remote-desktop', method:'POST', path:'/launch/rustdesk', scope:'fixed-app', mutating:true},
  {id:'rustdesk.connect', capability:'remote-desktop', method:'POST', path:'/handoff/rustdesk', scope:'fixed-app-peer-id', mutating:true}
];

function quoted(value) {
  return [`'${value}'`, `"${value}"`].some(token => cc.includes(token) || agent.includes(token));
}

function assertActionEncoded(source, action, language) {
  assert.ok(source.includes(action.id), `${language}: missing action ${action.id}`);
  assert.ok(source.includes(action.capability), `${language}: missing capability binding for ${action.id}`);
  assert.ok(source.includes(action.method), `${language}: missing method for ${action.id}`);
  assert.ok(source.includes(action.path), `${language}: missing path for ${action.id}`);
  assert.ok(source.includes(action.scope), `${language}: missing scope for ${action.id}`);
}

test('canonical contract pins the current Stable CC + Node Agent baseline', () => {
  assert.equal(contract.schemaVersion, 1);
  assert.equal(contract.policyId, 'rah-capability-allowlist-v1');
  assert.equal(contract.status, 'stable-baseline-guard');
  assert.deepEqual(contract.capabilities, expectedCapabilities);
  assert.deepEqual(
    contract.actions.map(({id, capability, method, path, scope, mutating}) => ({id, capability, method, path, scope, mutating})),
    expectedActions
  );
  assert.equal(contract.baseline.ravenVersion, '2.0.32');
  assert.equal(contract.baseline.commandCenterVersion, '1.2.0');
  assert.equal(contract.baseline.nodeAgentVersion, '0.8.0');
  assert.equal(contract.baseline.nodeHealthProtocol, 'rah-node-health-v2');
  assert.equal(contract.baseline.nodeActionsProtocol, 'rah-node-actions-v3');
});

test('Command Center and Node Agent expose only the pinned capability IDs', () => {
  assert.ok(cc.includes("const CAPABILITY_IDS=Object.freeze(['compute','storage','display','remote-desktop']);"));
  assert.ok(agent.includes('ALLOWED_CAPABILITIES=("compute","storage","display","remote-desktop")'));
  for (const capability of expectedCapabilities) assert.ok(quoted(capability));
});

test('Command Center and Node Agent encode exactly the three Stable action IDs', () => {
  assert.ok(cc.includes("const ACTION_IDS=Object.freeze(['storage-summary.read','rustdesk.launch','rustdesk.connect']);"));
  const ccIds = [...cc.matchAll(/(?:^|[,{\s])id:'([^']+)'/g)].map(m => m[1]).filter(id => id.includes('.') && expectedActions.some(a => a.id === id));
  for (const action of expectedActions) {
    assertActionEncoded(cc, action, 'Command Center');
    assertActionEncoded(agent, action, 'Node Agent');
  }
  assert.deepEqual([...new Set(ccIds)].sort(), expectedActions.map(a => a.id).sort());
});

test('execution remains advertisement + capability + local approval + session + fresh challenge gated', () => {
  assert.ok(cc.includes('d.capabilities.includes(a.capability)'));
  assert.ok(cc.includes('d.advertisedActions.includes(actionId)'));
  assert.ok(cc.includes('d.approvedActions.includes(actionId)'));
  assert.ok(cc.includes('a.sessionId!==h.sessionId'));
  assert.ok(cc.includes('freshActionChallenge'));
  assert.ok(cc.includes('actionChallengeFromCatalog'));
  assert.ok(agent.includes('consume_action_challenge'));
  assert.ok(agent.includes('ACTION_CHALLENGE_TTL_SECONDS=60'));
});

test('bearer token remains in-memory/session-bound and has no network renewal endpoint', () => {
  assert.equal(contract.tokenPolicy.storage, 'forbidden');
  assert.equal(contract.tokenPolicy.networkRenewalEndpoint, 'forbidden');
  assert.ok(agent.includes('token=secrets.token_urlsafe(32)'));
  assert.ok(agent.includes('is_authorized(self.headers.get("Authorization"),token)'));
  assert.ok(html.includes("document.getElementById('nodeToken').value=''"));
  assert.ok(html.includes("document.getElementById('actionToken').value=''"));
  assert.ok(html.includes("document.getElementById('handoffToken').value=''"));
  for (const source of [cc, agent]) {
    assert.doesNotMatch(source, /["']\/token(?:\/|["'?])/i);
    assert.doesNotMatch(source, /["']\/auth\/refresh(?:\/|["'?])/i);
  }
});

test('browser persistence stays limited to normalized device registry metadata', () => {
  const writes = html.match(/localStorage\.setItem\(/g) || [];
  assert.equal(writes.length, 1);
  assert.ok(html.includes('localStorage.setItem(core.DEVICE_STORAGE_KEY,JSON.stringify(devices))'));
  const normalizedRecord = cc.slice(cc.indexOf('function normalizeDeviceRecord'), cc.indexOf('function normalizeDeviceRegistry'));
  for (const forbidden of ['token:', 'challenge:', 'peerId:', 'password:', 'executablePath:', 'arguments:']) {
    assert.ok(!normalizedRecord.includes(forbidden), `persistent record must not contain ${forbidden}`);
  }
});

test('forbidden generic runtime endpoints and native remote-control authority stay absent', () => {
  const forbiddenEndpoint = /["']\/(?:shell|exec|command|commands|files|file|remote-control|remote_control)(?:\/|["'?])/i;
  assert.doesNotMatch(cc, forbiddenEndpoint);
  assert.doesNotMatch(agent, forbiddenEndpoint);
  assert.ok(agent.includes('"shell":False'));
  assert.ok(cc.includes('remoteControlEnabled:false'));
  assert.ok(cc.includes('commandsEnabled:false'));
  assert.ok(cc.includes('commands:false,files:false,shell:false,remoteControl:false'));
});

test('RustDesk handoff remains typed and does not accept caller-controlled path or generic arguments', () => {
  assert.ok(cc.includes("body:{peerId:id}"));
  assert.ok(agent.includes('set(payload.keys())!={"peerId"}'));
  assert.ok(agent.includes('subprocess.Popen([path,"--connect",peer_id]'));
  assert.ok(!html.includes('name="exePath"'));
  assert.ok(!html.includes('name="arguments"'));
  assert.ok(!html.includes('name="password"'));
});

test('contract forbids silent master-sync expansion of runtime authority', () => {
  for (const key of ['catalogExpansion', 'capabilityExpansion', 'endpointExpansion', 'tokenPolicyChange']) {
    assert.equal(contract.masterSyncBoundary[key], 'requires-explicit-new-version-and-stable-gate');
  }
  assert.equal(contract.masterSyncBoundary.stableRuntimeMutation, 'not-authorized-by-this-contract');
});
