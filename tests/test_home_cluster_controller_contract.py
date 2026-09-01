from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ps = (ROOT / 'RAH-HOME-CLUSTER-CONTROLLER.ps1').read_text(encoding='utf-8')
html = (ROOT / 'RAH-HOME-CLUSTER.html').read_text(encoding='utf-8')

required = [
    "rah-home-cluster-plan",
    "rah-home-cluster-results",
    "health",
    "systemInfo",
    "benchmark",
    "1-16 noder",
    "Test-PrivateIPv4",
    "RAH-HOME-NODE-CLIENT.ps1",
]
for needle in required:
    assert needle in ps, f'missing controller contract marker: {needle}'

for forbidden in [
    'Invoke-Expression', 'iex ', 'ScriptBlock::Create', 'Start-Process cmd',
    '-Command $', '0.0.0.0', 'Invoke-WebRequest', 'curl ', 'wget ',
]:
    assert forbidden not in ps, f'forbidden controller capability: {forbidden}'

assert "allowed=@('health','systemInfo','benchmark')" in ps.replace(' ', ''), 'fixed job allowlist missing'
assert '$nodes.Count-gt16' in ps.replace(' ', ''), 'max 16 nodes guard missing'
assert "schema:'rah-home-cluster-plan'" in html, 'browser plan schema missing'
assert "new Set(['health','systemInfo','benchmark'])" in html, 'browser fixed job allowlist missing'
assert "nodes.length>16" in html, 'browser max 16 guard missing'
assert "rah-home-cluster-results" in html, 'result schema validation missing'
assert 'fetch(' not in html and 'XMLHttpRequest' not in html and 'WebSocket' not in html, 'browser must not send network jobs'
print('PASS: RAH Home Cluster Controller contract')
