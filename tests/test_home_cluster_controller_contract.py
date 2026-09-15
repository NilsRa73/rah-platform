from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ps = (ROOT / 'RAH-HOME-CLUSTER-CONTROLLER.ps1').read_text(encoding='utf-8')
html = (ROOT / 'RAH-HOME-CLUSTER.html').read_text(encoding='utf-8')

required = [
    "RahClusterControllerVersion = '1.0.0'",
    "rah-home-cluster-plan",
    "rah-home-cluster-results",
    "RahAllowedJobs = @('health','systemInfo','benchmark')",
    'RahMaxNodes = 16',
    'RahMaxPlanBytes = 1048576',
    'RahMaxNodeResponseChars = 1048576',
    'Test-PrivateIPv4',
    'Test-RahObjectProperties',
    'ConvertTo-RahValidatedPlanNode',
    'ConvertTo-RahValidatedPlan',
    'Read-RahClusterPlan',
    'Invoke-RahClusterControllerSelfTest',
    "Allowed @('nodeAddress','port','job')",
    "Required @('nodeAddress','port','job')",
    'OutputPath kan ikke overskrive cluster-planfilen.',
    'RAH-HOME-NODE-CLIENT.ps1',
]
for needle in required:
    assert needle in ps, f'missing controller v1 contract marker: {needle}'

for forbidden in [
    'Invoke-Expression', 'iex ', 'ScriptBlock::Create', 'Start-Process cmd',
    '-Command $', '0.0.0.0', 'Invoke-WebRequest', 'Invoke-RestMethod',
    'curl ', 'wget ', 'TcpClient', 'UdpClient',
]:
    assert forbidden not in ps, f'forbidden controller capability: {forbidden}'

assert "-Action $job" in ps, 'controller must forward only validated allowlisted action'
assert '$script:RahAllowedJobs -notcontains $job' in ps, 'runtime allowlist guard missing'
assert '$nodes.Count -gt $script:RahMaxNodes' in ps, 'max 16 nodes guard missing'
assert '$item.Length -gt $script:RahMaxPlanBytes' in ps, 'plan size guard missing'
assert '$text.Length -gt $script:RahMaxNodeResponseChars' in ps, 'node response cap missing'
assert "command='whoami'" in ps, 'self-test must reject extra command field'
assert "job='shell'" in ps, 'self-test must reject non-allowlisted job'

# Browser and Controller must share the same semantic contract.
assert "schema:'rah-home-cluster-plan'" in html, 'browser plan schema missing'
assert "const SAFE_JOBS=['health','systemInfo','benchmark']" in html, 'browser fixed job allowlist missing'
assert 'MAX_PLAN_JOBS=16' in html and 'nodes.length>=MAX_PLAN_JOBS' in html, 'browser max 16 guard missing'
assert 'validResultsDocument' in html, 'result schema validation missing'
assert 'isPrivateIPv4' in html, 'browser private IPv4 guard missing'
assert 'fetch(' not in html and 'XMLHttpRequest' not in html and 'WebSocket' not in html, 'browser must not send network jobs'
print('PASS: RAH Home Cluster Controller v1 contract')
