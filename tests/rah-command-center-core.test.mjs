import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const core = require('../rah-command-center-core.js');

assert.equal(core.CC_VERSION, '0.3.1');
assert.equal(core.RAVEN_VERSION, '2.0.32');

const fallback = core.buildCoreSnapshot(null);
assert.equal(fallback.stableCount, 9);
assert.equal(fallback.totalCount, 9);
assert.equal(fallback.source, 'embedded-fallback');
assert.equal(fallback.components.find(c => c.id === 'raven_council').version, '0.3');

const live = core.buildCoreSnapshot({
  version: '2.0.32',
  release_gate: {
    stage: 'temporary-stable',
    stable_components: {
      raven_vision: '0.6', raven_council: '0.3', agent_runner: '0.3', memory_sync: '0.2',
      mission_control: '2.9', project_focus: '2.4', raven_core: '1.12', raven_now: '2.17', raven_studio: '2.8'
    }
  }
}, 'manifest');
assert.equal(live.source, 'manifest');
assert.equal(live.components.find(c => c.id === 'mission_control').version, '2.9');

assert.equal(core.PACKAGE_COMPONENTS.length, 6);
for (const item of core.PACKAGE_COMPONENTS) {
  assert.equal(Object.hasOwn(item, 'version'), false, `${item.id} must not hardcode a version`);
  assert.equal(Object.hasOwn(item, 'stable'), false, `${item.id} must not hardcode stable status`);
  assert.equal(core.isSafeRelativeEntry(item.entry), true);
}
assert.equal(core.EXTRA_COMPONENTS, undefined);

assert.equal(core.isCanonicalBridgeUrl('http://127.0.0.1:18765'), true);
assert.equal(core.isCanonicalBridgeUrl('http://localhost:18765'), false);
assert.equal(core.isCanonicalBridgeUrl('https://127.0.0.1:18765'), false);
assert.equal(core.isCanonicalBridgeUrl('http://127.0.0.1:9999'), false);
assert.equal(core.bridgeHealthUrl('http://evil.example'), 'http://127.0.0.1:18765/health');

assert.equal(core.isSafeRelativeEntry('RAH-RAVEN-NOW-V2.html'), true);
assert.equal(core.isSafeRelativeEntry('../secret.txt'), false);
assert.equal(core.isSafeRelativeEntry('https://example.com'), false);

const ready = core.summarizeBridgeHealth({case_center:true, chronicle:true, council_proxy:true, agent_runner:true});
assert.equal(ready.ok, true);
const partial = core.summarizeBridgeHealth({case_center:true, chronicle:true, council_proxy:false, agent_runner:true});
assert.equal(partial.ok, false);

console.log('RAH Command Center core v0.3.1 tests passed');
