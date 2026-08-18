import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const lanLauncher = fs.readFileSync('desktop-bridge/START-RAH-LINK-LAN.bat','utf8');
const mainPcLauncher = fs.readFileSync('desktop-bridge/START-RAH-LINK-V1.5-HOVED-PC.bat','utf8');
const legacyServer = fs.readFileSync('desktop-bridge/server.py','utf8');
const legacyV15 = fs.readFileSync('desktop-bridge/server_v15.py','utf8');
const canonicalBridge = fs.readFileSync('desktop-bridge/raven_bridge.py','utf8');
const raven = JSON.parse(fs.readFileSync('RAH-RAVEN-VERSION.json','utf8'));

const launchers = [lanLauncher, mainPcLauncher];

for (const [index, launcher] of launchers.entries()) {
  test(`legacy RAH Link launcher ${index + 1} is fail-closed and side-effect-free`, () => {
    assert.match(launcher,/RETIRED LEGACY UTILITY/i);
    assert.match(launcher,/Ingen handling er utført\./i);
    assert.match(launcher,/desktop-bridge\\start-bridge\.bat/i);
    assert.match(launcher,/http:\/\/127\.0\.0\.1:18765/i);
    assert.match(launcher,/exit \/b 2/i);

    for (const forbidden of [
      /netsh\b/i,
      /advfirewall/i,
      /powershell(?:\.exe)?\b/i,
      /^\s*(?:call\s+)?py(?:\.exe)?(?:\s|$)/im,
      /^\s*(?:call\s+)?python(?:\.exe)?(?:\s|$)/im,
      /\.venv\\Scripts\\python\.exe/i,
      /^\s*where\s+(?:py|python)(?:\.exe)?\b/im,
      /\bpip\s+(?:install|uninstall)\b/i,
      /RAH_BRIDGE_HOST=0\.0\.0\.0/i,
      /RAH_BRIDGE_PORT=8765/i,
      /http:\/\/[^\s]+:8765/i,
      /^\s*start\s+"[^"]*"\s+\/min/im,
      /Stop-Process/i,
      /Get-CimInstance/i,
      /Invoke-RestMethod/i
    ]) {
      assert.doesNotMatch(launcher, forbidden, `retired launcher must not retain executable LAN authority: ${forbidden}`);
    }
  });
}

test('legacy server source remains readable but direct execution cannot open a listener', () => {
  assert.match(legacyServer,/RAH Link v1\.4\/v1\.5 is a retired legacy LAN utility\./);
  assert.match(legacyServer,/No network listener was started and no firewall rule was changed\./);
  assert.match(legacyServer,/Use raven_bridge\.py for the current local Raven Desktop Bridge on 127\.0\.0\.1:18765\./);
  assert.match(legacyServer,/raise SystemExit\(2\)/);
  assert.doesNotMatch(legacyServer,/app\.run\s*\(/, 'legacy server must not expose a direct Flask launch path');

  // Preserve historical source/routes for audit instead of deleting evidence.
  assert.match(legacyServer,/@app\.get\("\/link"\)/);
  assert.match(legacyServer,/@app\.get\("\/capture\/active-window"\)/);
  assert.match(legacyServer,/@app\.post\("\/lm\/analyze"\)/);
});

test('standalone Desktop Bridge v1.5 is a non-network retired stub', () => {
  assert.match(legacyV15,/APP_VERSION = "1\.5\.0-retired"/);
  assert.match(legacyV15,/DIRECT_RUN_DISABLED = True/);
  assert.match(legacyV15,/Use desktop-bridge\/raven_bridge\.py on 127\.0\.0\.1:18765/);
  assert.match(legacyV15,/No Flask listener, capture route, CORS policy or LM proxy was started\./);
  assert.match(legacyV15,/raise SystemExit\(main\(\)\)/);

  for (const forbidden of [
    /from flask import/,
    /flask_cors/,
    /CORS\s*\(/,
    /app\s*=\s*Flask\s*\(/,
    /app\.run\s*\(/,
    /@app\./,
    /urllib\.request/,
    /mss\b/,
    /RAH_BRIDGE_HOST/,
    /RAH_LM_BASE/
  ]) assert.doesNotMatch(legacyV15, forbidden, `retired v1.5 must not retain executable server authority: ${forbidden}`);
});

test('Raven 2.0.32 package excludes retired RAH Link LAN authority', () => {
  assert.equal(raven.version,'2.0.32');
  const manifestText = JSON.stringify(raven);
  for (const retired of [
    'desktop-bridge/server.py',
    'desktop-bridge/server_v15.py',
    'desktop-bridge/START-RAH-LINK-LAN.bat',
    'desktop-bridge/START-RAH-LINK-V1.5-HOVED-PC.bat'
  ]) assert.equal(manifestText.includes(retired),false,`${retired} must remain outside frozen Raven package`);
  assert.equal(manifestText.includes('desktop-bridge/raven_bridge.py'),true,'canonical raven_bridge.py must remain packaged');
});

test('canonical local Bridge remains separate from retired LAN utility', () => {
  assert.match(canonicalBridge,/from server_v17 import APP_VERSION, HOST, PORT, app/);
  assert.match(canonicalBridge,/@app\.post\("\/lm\/chat"\)/);
  assert.match(canonicalBridge,/"council_proxy": True/);
  assert.doesNotMatch(canonicalBridge,/from server import/);
  assert.doesNotMatch(canonicalBridge,/from server_v15 import/);
});

console.log('RAH Link and standalone v1.5 authority are retired fail-closed; canonical Raven Bridge remains separate and local.');
