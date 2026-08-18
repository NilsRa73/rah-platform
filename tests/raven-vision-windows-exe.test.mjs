import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const tray = fs.readFileSync('desktop-bridge/tray_app.py', 'utf8');
const bridge = fs.readFileSync('desktop-bridge/raven_bridge.py', 'utf8');
const builder = fs.readFileSync('desktop-bridge/build-exe.bat', 'utf8');

const requiredAssets = [
  'RAH-RAVEN-CHRONICLE-LIVE.html',
  'RAH-RAVEN-INSIGHTS.html',
  'RAH-RAVEN-DAILY-BRIEF.html',
];

test('tray EXE entrypoint is pinned to canonical Raven Bridge', () => {
  assert.match(tray, /import raven_bridge as bridge_server/);
  assert.doesNotMatch(tray, /import server as bridge_server/);
  assert.doesNotMatch(tray, /import server_v15 as bridge_server/);
  assert.match(tray, /APP_VERSION = bridge_server\.APP_VERSION/);
  assert.match(tray, /bridge_server\.PORT != 18765/);
  assert.match(tray, /health_data\.get\("council_proxy"\) is not True/);
});

test('self-test runs before tray listener or GUI startup', () => {
  assert.match(tray, /if "--self-test" in sys\.argv\[1:\]:\s*return self_test\(\)/s);
  const selfTestIndex = tray.indexOf('if "--self-test" in sys.argv[1:]');
  const bridgeStartIndex = tray.indexOf('bridge = BridgeThread()');
  const iconRunIndex = tray.indexOf('icon.run()');
  assert.ok(selfTestIndex >= 0 && bridgeStartIndex > selfTestIndex && iconRunIndex > selfTestIndex);
});

test('canonical Bridge resolves bundled local UI assets from PyInstaller extraction root', () => {
  assert.match(bridge, /getattr\(sys, "frozen", False\)/);
  assert.match(bridge, /hasattr\(sys, "_MEIPASS"\)/);
  assert.match(bridge, /pathlib\.Path\(sys\._MEIPASS\)\.resolve\(\)/);
  for (const asset of requiredAssets) assert.match(bridge, new RegExp(asset.replaceAll('.', '\\.')));
});

test('Windows builder is CI-capable and bundles canonical local UI assets', () => {
  assert.match(builder, /if \/I "%~1"=="--ci" set "CI_MODE=1"/i);
  assert.match(builder, /--onefile/);
  assert.match(builder, /--windowed/);
  assert.match(builder, /tray_app\.py/);
  for (const asset of requiredAssets) assert.match(builder, new RegExp(asset.replaceAll('.', '\\.')));
  assert.doesNotMatch(builder, /\bserver\.py\b/);
  assert.doesNotMatch(builder, /\bserver_v15\.py\b/);
  assert.doesNotMatch(builder, /:8765\b/);
});

console.log('Raven Vision Windows EXE contract is canonical-Bridge-only and self-testable.');
