Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$runnerPath = Join-Path $repoRoot 'RAH-HOME-DISCOVERY-ACTIVE-RUN.ps1'
$activePath = Join-Path $repoRoot 'RAH-HOME-DISCOVERY-ACTIVE.ps1'
. $runnerPath

function Assert-Rah {
    param([Parameter(Mandatory)][bool]$Condition,[Parameter(Mandatory)][string]$Message)
    if (-not $Condition) { throw $Message }
}

Assert-Rah (Test-RahActiveDiscoveryScriptContract -Path $activePath) 'Stable Active Discovery should satisfy runner contract.'
Assert-Rah (Test-RahActiveConsent -Answer 'JA') 'Exact JA must be accepted.'
Assert-Rah (-not (Test-RahActiveConsent -Answer 'ja')) 'Lowercase ja must not be accepted.'
Assert-Rah (-not (Test-RahActiveConsent -Answer 'YES')) 'YES must not be accepted.'
Assert-Rah (-not (Test-RahActiveConsent -Answer '')) 'Empty consent must not be accepted.'

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('rah-active-run-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $bad = Join-Path $tempRoot 'bad.ps1'
    'Write-Host bad' | Set-Content -LiteralPath $bad -Encoding UTF8
    Assert-Rah (-not (Test-RahActiveDiscoveryScriptContract -Path $bad)) 'Invalid active script should be rejected.'

    $valid = Join-Path $tempRoot 'valid.json'
    @{
        schema='rah-home-discovery-cache';version=1;mode='active-local-subnet';passive=$false;
        authorization='explicit-start-local-private-subnet';scan=@{protocol='ICMP echo only'};devices=@()
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $valid -Encoding UTF8
    $doc = Test-RahActiveDiscoveryOutput -Path $valid
    Assert-Rah ($doc.mode -eq 'active-local-subnet') 'Valid active output should parse.'

    $invalid = Join-Path $tempRoot 'invalid.json'
    '{"schema":"rah-home-discovery-cache","version":1,"mode":"active-local-subnet","passive":false,"authorization":"wrong","scan":{"protocol":"ICMP echo only"},"devices":[]}' | Set-Content -LiteralPath $invalid -Encoding UTF8
    $rejected = $false
    try { Test-RahActiveDiscoveryOutput -Path $invalid | Out-Null } catch { $rejected = $true }
    Assert-Rah $rejected 'Invalid authorization marker must be rejected.'

    Invoke-RahActiveRunnerSelfTest
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host 'RAH-HOME-DISCOVERY-ACTIVE-RUN tests OK' -ForegroundColor Green
