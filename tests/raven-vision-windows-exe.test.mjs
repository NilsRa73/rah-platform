import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const tray = fs.readFileSync('desktop-bridge/tray_app.py', 'utf8');
const bridge = fs.readFileSync('desktop-bridge/raven_bridge.py', 'utf8');
const builder = fs.readFileSync('desktop-bridge/build-exe.bat', 'utf8');
const vision = fs.readFileSync('RAH-RAVEN-VISION-LOCAL.html', 'utf8');
const chatgptBridge = fs.readFileSync('RAH-RAVEN-CHATGPT.user.js', 'utf8');

const requiredAssets = [
  'RAH-RAVEN-VISION-LOCAL.html',
  'RAH-RAVEN-CHATGPT.user.js',
  'RAH-RAVEN-AGENT-RUNNER.html',
  'RAH-RAVEN-CHRONICLE-LIVE.html',
  'RAH-RAVEN-INSIGHTS.html',
  'RAH-RAVEN-DAILY-BRIEF.html',
];

test('tray EXE entrypoint is pinned to canonical Raven Bridge and local Vision', () => {
  assert.match(tray, /import raven_bridge as bridge_server/);
  assert.doesNotMatch(tray, /import server as bridge_server/);
  assert.doesNotMatch(tray, /import server_v15 as bridge_server/);
  assert.match(tray, /APP_VERSION = bridge_server\.APP_VERSION/);
  assert.match(tray, /VISION_URL = f"http:\/\/\{bridge_server\.HOST\}:\{bridge_server\.PORT\}\/vision\/ui"/);
  assert.match(tray, /CHATGPT_BRIDGE_URL = f"http:\/\/\{bridge_server\.HOST\}:\{bridge_server\.PORT\}\/vision\/chatgpt\.user\.js"/);
  assert.match(tray, /AGENT_RUNNER_PAGE = BASE_DIR \/ "RAH-RAVEN-AGENT-RUNNER\.html"/);
  assert.match(tray, /Open Raven Agent Runner/);
  assert.match(tray, /webbrowser\.open_new_tab\(AGENT_RUNNER_PAGE\.as_uri\(\)\)/);
  assert.match(tray, /Install \/ Update ChatGPT Bridge/);
  assert.match(tray, /webbrowser\.open_new_tab\(CHATGPT_BRIDGE_URL\)/);
  assert.match(tray, /webbrowser\.open\(VISION_URL\)/);
  assert.match(tray, /bridge_server\.PORT != 18765/);
  assert.match(tray, /health_data\.get\("council_proxy"\) is not True/);
  assert.match(tray, /"system-inventory" not in capability_ids/);
  assert.match(tray, /agent_data\.get\("arbitrary_commands"\) is not False/);
  assert.match(tray, /agent_data\.get\("file_writes"\) is not False/);
  assert.match(tray, /agent_data\.get\("automatic_execution"\) is not False/);
});

test('self-test runs before tray listener or GUI startup', () => {
  assert.match(tray, /if "--self-test" in sys\.argv\[1:\]:\s*return self_test\(\)/s);
  const selfTestIndex = tray.indexOf('if "--self-test" in sys.argv[1:]');
  const bridgeStartIndex = tray.indexOf('bridge = BridgeThread()');
  const iconRunIndex = tray.indexOf('icon.run()');
  assert.ok(selfTestIndex >= 0 && bridgeStartIndex > selfTestIndex && iconRunIndex > selfTestIndex);
});

test('canonical Bridge exposes monitor and bounded area capture', () => {
  assert.match(bridge, /getattr\(sys, "frozen", False\)/);
  assert.match(bridge, /hasattr\(sys, "_MEIPASS"\)/);
  assert.match(bridge, /pathlib\.Path\(sys\._MEIPASS\)\.resolve\(\)/);
  assert.match(bridge, /@app\.get\("\/vision\/ui"\)/);
  assert.match(bridge, /@app\.get\("\/vision\/chatgpt\.user\.js"\)/);
  assert.match(bridge, /@app\.get\("\/capture\/monitors"\)/);
  assert.match(bridge, /@app\.get\("\/capture\/monitor"\)/);
  assert.match(bridge, /@app\.get\("\/capture\/area"\)/);
  assert.match(bridge, /_capture_monitor\(index\)/);
  assert.match(bridge, /_capture_area\(left, top, width, height\)/);
  assert.match(bridge, /_validate_area/);
  assert.match(bridge, /vision_area_capture/);
});

test('local Vision offers Monitor 1/2, active window, area and capture-only hotkeys', () => {
  assert.match(vision, /Monitor \$\{m\.index\}/);
  assert.match(vision, /Aktivt vindu \(3 sek byttetid\)/);
  assert.match(vision, /Område \(X\/Y\/bredde\/høyde\)/);
  assert.match(vision, /\/capture\/after-delay\?seconds=3/);
  assert.match(vision, /\/capture\/active-window/);
  assert.match(vision, /\/capture\/monitor\?index=/);
  assert.match(vision, /\/capture\/area\?left=/);
  assert.match(vision, /api\('\/capture\/monitors'\)/);
  assert.match(vision, /api\('\/lm\/models'\)/);
  assert.match(vision, /api\('\/lm\/analyze'/);
  assert.match(vision, /Alt\+Shift\+1 = Monitor 1/);
  assert.match(vision, /Alt\+Shift\+2 = Monitor 2/);
  assert.match(vision, /Alt\+Shift\+A = Aktivt vindu/);
  assert.match(vision, /Alt\+Shift\+O = Område/);
  assert.match(vision, /key === 'a'/);
  assert.match(vision, /key === 'o'/);
  const selectStart = vision.indexOf('async function selectAndCapture(value)');
  const hotkeyStart = vision.indexOf("document.addEventListener('keydown'", selectStart);
  assert.ok(selectStart >= 0 && hotkeyStart > selectStart, 'selectAndCapture hotkey helper must exist before keydown handler');
  const selectBody = vision.slice(selectStart, hotkeyStart);
  assert.match(selectBody, /await capture\(true\);/);
  assert.doesNotMatch(selectBody, /captureAndAnalyze/);
  assert.match(vision, /LM Studio er valgfritt/);
  assert.match(vision, /target="_blank" rel="noopener"/);
  assert.match(vision, /Installer \/ oppdater Raven ChatGPT Bridge/);
  assert.doesNotMatch(vision, /https?:\/\//i, 'local Vision UI must not contain an external network URL');
});

test('ChatGPT userscript supports monitor, active-window and area attachment without auto-send', () => {
  assert.match(chatgptBridge, /@version\s+0\.2\.0/);
  assert.match(chatgptBridge, /@match\s+https:\/\/chatgpt\.com\/\*/);
  assert.match(chatgptBridge, /@grant\s+GM_xmlhttpRequest/);
  assert.match(chatgptBridge, /@connect\s+127\.0\.0\.1/);
  assert.match(chatgptBridge, /const BRIDGE = 'http:\/\/127\.0\.0\.1:18765'/);
  assert.match(chatgptBridge, /\/capture\/monitors/);
  assert.match(chatgptBridge, /\/capture\/monitor\?index=/);
  assert.match(chatgptBridge, /\/capture\/after-delay\?seconds=3/);
  assert.match(chatgptBridge, /\/capture\/area\?/);
  assert.match(chatgptBridge, /Monitor 1/);
  assert.match(chatgptBridge, /Monitor 2/);
  assert.match(chatgptBridge, /Aktivt vindu/);
  assert.match(chatgptBridge, /Område/);
  assert.match(chatgptBridge, /key === 'a'/);
  assert.match(chatgptBridge, /key === 'o'/);
  assert.match(chatgptBridge, /new File\(/);
  assert.match(chatgptBridge, /DataTransfer/);
  assert.match(chatgptBridge, /Kontroller vedlegget og send/);
  assert.doesNotMatch(chatgptBridge, /click\(\).*send/i);
  assert.doesNotMatch(chatgptBridge, /dispatchEvent\(new KeyboardEvent/i);
  assert.doesNotMatch(chatgptBridge, /fetch\(['"]https?:\/\//i);
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

console.log('Raven Vision Windows EXE contract is local-first, monitor-aware and bundles the read-only Agent Runner proof UI.');
