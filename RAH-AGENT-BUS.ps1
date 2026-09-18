param(
    [ValidateSet('Status','Enqueue','Claim','Complete','Fail','Recent')]
    [string]$Action = 'Status',
    [string]$Kind = 'text.task',
    [string]$Source = 'RAH',
    [string]$Worker = $env:COMPUTERNAME,
    [string]$JobId = '',
    [string]$PayloadJson = '{}',
    [string]$ResultJson = '{}',
    [ValidateSet('queued','running','completed','failed')]
    [string]$RecentStatus = 'completed',
    [string]$Root = 'C:\RAH\AgentBridge',
    [string]$BaseUrl = 'http://127.0.0.1:18781',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:RahAgentBusClientVersion = '1.0.0'

function Convert-RahJsonObject {
    param([string]$Json)
    if (-not $Json) { return @{} }
    $value = $Json | ConvertFrom-Json
    return $value
}

function Get-RahHeaders {
    $tokenPath = Join-Path $Root 'token.txt'
    if (-not (Test-Path -LiteralPath $tokenPath -PathType Leaf)) {
        throw "RAH Agent Bridge token not found: $tokenPath"
    }
    $token = (Get-Content -LiteralPath $tokenPath -Raw).Trim()
    if ($token.Length -lt 24) { throw 'RAH Agent Bridge token is invalid.' }
    return @{ Authorization = "Bearer $token" }
}

function Invoke-RahPost {
    param([string]$Path,[hashtable]$Body)
    $headers = Get-RahHeaders
    $json = $Body | ConvertTo-Json -Depth 12
    return Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + $Path) -Method Post -Headers $headers -ContentType 'application/json' -Body $json -TimeoutSec 15
}

if ($SelfTest) {
    if ($BaseUrl -notmatch '^http://127\.0\.0\.1:\d+$') { throw 'SelfTest: BaseUrl must be loopback HTTP.' }
    if ($script:RahAgentBusClientVersion -ne '1.0.0') { throw 'SelfTest: version mismatch.' }
    Write-Host 'PASS: RAH Agent Bus client v1 self-test' -ForegroundColor Green
    exit 0
}

switch ($Action) {
    'Status' {
        $health = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + '/health') -TimeoutSec 5
        $health | ConvertTo-Json -Depth 8
    }
    'Enqueue' {
        $payload = Convert-RahJsonObject $PayloadJson
        $r = Invoke-RahPost '/v1/jobs/enqueue' @{ kind=$Kind; source=$Source; payload=$payload }
        $r | ConvertTo-Json -Depth 12
    }
    'Claim' {
        $r = Invoke-RahPost '/v1/jobs/claim' @{ worker=$Worker }
        $r | ConvertTo-Json -Depth 12
    }
    'Complete' {
        if (-not $JobId) { throw 'JobId is required for Complete.' }
        $result = Convert-RahJsonObject $ResultJson
        $r = Invoke-RahPost ("/v1/jobs/$JobId/complete") @{ worker=$Worker; result=$result }
        $r | ConvertTo-Json -Depth 12
    }
    'Fail' {
        if (-not $JobId) { throw 'JobId is required for Fail.' }
        $result = Convert-RahJsonObject $ResultJson
        $r = Invoke-RahPost ("/v1/jobs/$JobId/fail") @{ worker=$Worker; error=$result }
        $r | ConvertTo-Json -Depth 12
    }
    'Recent' {
        $headers = Get-RahHeaders
        $r = Invoke-RestMethod -Uri ($BaseUrl.TrimEnd('/') + "/v1/jobs/recent/$RecentStatus") -Headers $headers -TimeoutSec 10
        $r | ConvertTo-Json -Depth 12
    }
}
