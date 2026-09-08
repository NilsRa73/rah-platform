import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const tray = fs.readFileSync('desktop-bridge/tray_app.py', 'utf8');

test('frozen Raven refreshes Desktop and Start menu shortcuts without autostart', () => {
  assert.match(tray, /def ensure_user_shortcuts\(\)/);
  assert.match(tray, /getattr\(sys, "frozen", False\)/);
  assert.match(tray, /Path\(sys\.executable\)\.resolve\(\)/);
  assert.match(tray, /GetFolderPath\('Desktop'\)/);
  assert.match(tray, /GetFolderPath\('Programs'\)/);
  assert.match(tray, /RAH Raven\.lnk/);
  assert.match(tray, /WScript\.Shell/);
  assert.match(tray, /ensure_user_shortcuts\(\)\s*\n\s*logger\.info/s);
  assert.doesNotMatch(tray, /GetFolderPath\('Startup'\)/);
  assert.doesNotMatch(tray, /CurrentVersion\\Run/i);
  assert.doesNotMatch(tray, /schtasks/i);
  assert.doesNotMatch(tray, /New-Service/i);
});

test('self-test returns before shortcut creation', () => {
  const selfTestGuard = tray.indexOf('if "--self-test" in sys.argv[1:]');
  const shortcutCall = tray.indexOf('ensure_user_shortcuts()', selfTestGuard);
  assert.ok(selfTestGuard >= 0 && shortcutCall > selfTestGuard);
});
