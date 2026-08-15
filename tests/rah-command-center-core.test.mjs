import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const core = require('../rah-command-center-core.js');

assert.equal(core.CC_VERSION, '0.4.0');
assert.equal(core.RAVEN_VERSION, '2.0.32');
assert.equal(core.DEVICE_STORAGE_KEY, 'rah.cc.devices.v1');

const fallback = core.buildCoreSnapshot(null);
assert.equal(fallback.stableCount, 9);
assert.equal(fallback.totalCount, 9);
assert.equal(fallback.source, 'embedded-fallback');

const live = core.buildCoreSnapshot({version:'2.0.32',release_gate:{stage:'temporary-stable',stable_components:{
  raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'
}}}, 'manifest');
assert.equal(live.source, 'manifest');
assert.equal(live.stableCount, 9);

assert.equal(core.PACKAGE_COMPONENTS.length, 6);
for (const item of core.PACKAGE_COMPONENTS) {
  assert.equal(Object.hasOwn(item, 'version'), false);
  assert.equal(Object.hasOwn(item, 'stable'), false);
  assert.equal(core.isSafeRelativeEntry(item.entry), true);
}
assert.equal(core.EXTRA_COMPONENTS, undefined);

const defaultDevices = core.normalizeDeviceRegistry(null);
assert.equal(defaultDevices.length, 4);
assert.equal(defaultDevices.find(d => d.id === 'main-pc').role, 'Command Center host');
assert.equal(defaultDevices.every(d => d.status === 'unverified'), true);
assert.equal(defaultDevices.every(d => d.remoteControlEnabled === false), true);
assert.equal(defaultDevices.every(d => d.commandsEnabled === false), true);

const hostileSavedDevice = core.normalizeDeviceRegistry([{
  id: '../My PC',
  label: '  Test\u0000 PC  ',
  role: 'Node',
  platform: 'Windows',
  kind: 'desktop',
  status: 'online',
  remoteControlEnabled: true,
  commandsEnabled: true
}]);
assert.equal(hostileSavedDevice[0].id, 'my-pc');
assert.equal(hostileSavedDevice[0].label, 'Test PC');
assert.equal(hostileSavedDevice[0].status, 'unverified');
assert.equal(hostileSavedDevice[0].remoteControlEnabled, false);
assert.equal(hostileSavedDevice[0].commandsEnabled, false);

const added = core.createDeviceRecord({
  id: 'living-room-tv',
  label: 'Living Room TV',
  role: 'Extended display',
  platform: 'Android TV',
  kind: 'tv'
}, defaultDevices);
assert.equal(added.id, 'living-room-tv');
assert.equal(added.status, 'unverified');
assert.equal(added.commandsEnabled, false);

const marked = core.markThisDevice([...defaultDevices, added], 'living-room-tv');
assert.equal(marked.find(d => d.id === 'living-room-tv').status, 'this-device');
assert.equal(marked.filter(d => d.status === 'this-device').length, 1);
assert.equal(marked.every(d => d.commandsEnabled === false), true);
const deviceSnapshot = core.buildDeviceSnapshot(marked);
assert.equal(deviceSnapshot.totalCount, 5);
assert.equal(deviceSnapshot.thisDeviceCount, 1);
assert.equal(deviceSnapshot.remoteControlCount, 0);
assert.equal(deviceSnapshot.commandCount, 0);

assert.equal(core.isCanonicalBridgeUrl('http://127.0.0.1:18765'), true);
assert.equal(core.isCanonicalBridgeUrl('http://localhost:18765'), false);
assert.equal(core.bridgeHealthUrl('http://evil.example'), 'http://127.0.0.1:18765/health');
assert.equal(core.isSafeRelativeEntry('../secret.txt'), false);
assert.equal(core.isSafeRelativeEntry('https://example.com'), false);
const ready = core.summarizeBridgeHealth({case_center:true,chronicle:true,council_proxy:true,agent_runner:true});
assert.equal(ready.ok, true);
console.log('RAH Command Center core v0.4 tests passed');
