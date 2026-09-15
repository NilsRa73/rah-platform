Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$runnerPath = Join-Path $repoRoot 'RAH-HOME-DISCOVERY-RUN.ps1'
$discoveryPath = Join-Path $repoRoot 'RAH-HOME-DISCOVERY.ps1'
. $runnerPath

function Assert-Rah {
    param(
        [Parameter(Mandatory)][bool]$Condition,
        [Parameter(Mandatory)][string]$Message
    )
    if (-not $Condition) { throw $Message }
}

Assert-Rah (Test-RahDiscoveryScriptContract -Path $discoveryPath) 'Stable discovery script should satisfy runner contract.'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("rah-runner-tests-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

try {
    $badScript = Join-Path $tempRoot 'bad.ps1'
    'Write-Host "not discovery"' | Set-Content -LiteralPath $badScript -Encoding UTF8
    Assert-Rah (-not (Test-RahDiscoveryScriptContract -Path $badScript)) 'Invalid script must be rejected.'

    $validOutput = Join-Path $tempRoot 'valid.json'
    @{
        schema = 'rah-home-discovery-cache'
        version = 1
        mode = 'passive-neighbor-cache'
        passive = $true
        devices = @()
    } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $validOutput -Encoding UTF8

    $doc = Test-RahDiscoveryOutput -Path $validOutput
    Assert-Rah ($doc.schema -eq 'rah-home-discovery-cache') 'Valid output should parse.'

    $invalidOutput = Join-Path $tempRoot 'invalid.json'
    '{"schema":"wrong","version":1,"mode":"passive-neighbor-cache","passive":true,"devices":[]}' | Set-Content -LiteralPath $invalidOutput -Encoding UTF8
    $rejected = $false
    try {
        Test-RahDiscoveryOutput -Path $invalidOutput | Out-Null
    }
    catch {
        $rejected = $true
    }
    Assert-Rah $rejected 'Invalid discovery output must be rejected.'

    Invoke-RahRunnerSelfTest
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'RAH-HOME-DISCOVERY-RUN tests OK' -ForegroundColor Green
