import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const core = require('../rah-command-center-core.js');

assert.equal(core.CC_VERSION, '0.5.0');
assert.equal(core.RAVEN_VERSION, '2.0.32');
assert.equal(core.DEVICE_STORAGE_KEY, 'rah.cc.devices.v1');
assert.equal(core.NODE_AGENT_PORT, 18766);
assert.equal(core.NODE_AGENT_PROTOCOL, 'rah-node-health-v1');

const fallback = core.buildCoreSnapshot(null);
assert.equal(fallback.stableCount, 9);
assert.equal(fallback.totalCount, 9);
const live = core.buildCoreSnapshot({version:'2.0.32',release_gate:{stage:'temporary-stable',stable_components:{
  raven_vision:'0.6',raven_council:'0.3',agent_runner:'0.3',memory_sync:'0.2',mission_control:'2.9',project_focus:'2.4',raven_core:'1.12',raven_now:'2.17',raven_studio:'2.8'
}}}, 'manifest');
assert.equal(live.stableCount, 9);

assert.equal(core.isAllowedNodeIpv4('127.0.0.1'), true);
assert.equal(core.isAllowedNodeIpv4('10.1.2.3'), true);
assert.equal(core.isAllowedNodeIpv4('172.16.0.1'), true);
assert.equal(core.isAllowedNodeIpv4('172.31.255.254'), true);
assert.equal(core.isAllowedNodeIpv4('192.168.50.10'), true);
assert.equal(core.isAllowedNodeIpv4('172.32.0.1'), false);
assert.equal(core.isAllowedNodeIpv4('169.254.1.1'), false);
assert.equal(core.isAllowedNodeIpv4('8.8.8.8'), false);
assert.equal(core.isAllowedNodeIpv4('localhost'), false);
assert.equal(core.isAllowedNodeIpv4('192.168.1.2.example.com'), false);
assert.equal(core.nodeHealthUrl('192.168.1.25'), 'http://192.168.1.25:18766/health');
assert.equal(core.nodeHealthUrl('8.8.8.8'), '');
assert.equal(core.nodeHealthUrl('http://192.168.1.25'), '');

const goodHealth = core.sanitizeNodeHealth({
  protocol:'rah-node-health-v1',status:'ready',agentVersion:'0.1.0',hostname:'LENOVO',platform:'Linux',platformRelease:'6.8',machine:'x86_64',nodeName:'Lab',nodeRole:'Security'
});
assert.equal(goodHealth.hostname, 'LENOVO');
assert.equal(core.sanitizeNodeHealth({protocol:'wrong',status:'ready'}), null);
assert.equal(core.sanitizeNodeHealth({protocol:'rah-node-health-v1',status:'command-ready'}), null);

const defaultDevices = core.normalizeDeviceRegistry(null);
assert.equal(defaultDevices.length, 4);
assert.equal(defaultDevices.every(d => d.remoteControlEnabled === false), true);
assert.equal(defaultDevices.every(d => d.commandsEnabled === false), true);

const hostileSavedDevice = core.normalizeDeviceRegistry([{
  id:'../My PC',label:' Test\u0000 PC ',role:'Node',platform:'Windows',kind:'desktop',status:'online',
  endpointIp:'8.8.8.8',enrolled:true,agentHostname:'bad',remoteControlEnabled:true,commandsEnabled:true,token:'secret'
}]);
assert.equal(hostileSavedDevice[0].id, 'my-pc');
assert.equal(hostileSavedDevice[0].status, 'unverified');
assert.equal(hostileSavedDevice[0].enrolled, false);
assert.equal(hostileSavedDevice[0].endpointIp, '');
assert.equal(hostileSavedDevice[0].remoteControlEnabled, false);
assert.equal(hostileSavedDevice[0].commandsEnabled, false);
assert.equal(Object.hasOwn(hostileSavedDevice[0], 'token'), false);

const enrolled = core.enrollDevice(defaultDevices, 'lenovo-kali', '192.168.1.44', goodHealth);
const lenovo = enrolled.find(d => d.id === 'lenovo-kali');
assert.equal(lenovo.enrolled, true);
assert.equal(lenovo.endpointIp, '192.168.1.44');
assert.equal(lenovo.agentHostname, 'LENOVO');
assert.equal(lenovo.agentVersion, '0.1.0');
assert.equal(lenovo.remoteControlEnabled, false);
assert.equal(lenovo.commandsEnabled, false);
assert.equal(Object.hasOwn(lenovo, 'token'), false);

const rejected = core.enrollDevice(defaultDevices, 'lenovo-kali', '8.8.8.8', goodHealth);
assert.equal(rejected.find(d => d.id === 'lenovo-kali').enrolled, false);
const forgotten = core.forgetEnrollment(enrolled, 'lenovo-kali');
assert.equal(forgotten.find(d => d.id === 'lenovo-kali').enrolled, false);
assert.equal(forgotten.find(d => d.id === 'lenovo-kali').endpointIp, '');

const marked = core.markThisDevice(enrolled, 'main-pc');
const snapshot = core.buildDeviceSnapshot(marked);
assert.equal(snapshot.totalCount, 4);
assert.equal(snapshot.enrolledCount, 1);
assert.equal(snapshot.thisDeviceCount, 1);
assert.equal(snapshot.remoteControlCount, 0);
assert.equal(snapshot.commandCount, 0);

assert.equal(core.PACKAGE_COMPONENTS.length, 6);
assert.equal(core.isCanonicalBridgeUrl('http://127.0.0.1:18765'), true);
assert.equal(core.isCanonicalBridgeUrl('http://localhost:18765'), false);
assert.equal(core.bridgeHealthUrl('http://evil.example'), 'http://127.0.0.1:18765/health');
assert.equal(core.isSafeRelativeEntry('../secret.txt'), false);
assert.equal(core.isSafeRelativeEntry('https://example.com'), false);
console.log('RAH Command Center core v0.5 enrollment tests passed');
