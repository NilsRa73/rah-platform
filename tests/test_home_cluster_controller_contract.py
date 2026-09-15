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

compact_ps = ps.replace(' ', '')
assert "allowed=@('health','systemInfo','benchmark')" in compact_ps, 'controller fixed job allowlist missing'
assert '$nodes.Count-gt16' in compact_ps, 'controller max 16 nodes guard missing'

# Browser and Controller must share the same semantic contract. Do not couple this
# test to one JavaScript collection type (Set vs Array); Cluster v1 behavior is
# exercised separately by test_home_cluster_contract.py.
assert "schema:'rah-home-cluster-plan'" in html, 'browser plan schema missing'
assert "const SAFE_JOBS=['health','systemInfo','benchmark']" in html, 'browser fixed job allowlist missing'
assert 'MAX_PLAN_JOBS=16' in html and 'nodes.length>=MAX_PLAN_JOBS' in html, 'browser max 16 guard missing'
assert "schema!=='rah-home-cluster-results'" in html or 'validResultsDocument' in html, 'result schema validation missing'
assert 'isPrivateIPv4' in html, 'browser private IPv4 guard missing'
assert 'fetch(' not in html and 'XMLHttpRequest' not in html and 'WebSocket' not in html, 'browser must not send network jobs'
print('PASS: RAH Home Cluster Controller contract')
