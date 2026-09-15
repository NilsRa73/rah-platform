param(
    [Parameter(Mandatory=$true)][string]$NodeAddress,
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [ValidateSet('health','systemInfo','benchmark')][string]$Job = 'health',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahClusterRunnerVersion = '1.0.0'
$script:RahMaxRunnerOutputChars = 1048576

function Test-RahPrivateIPv4 {
    param([Parameter(Mandatory)][string]$Address)
    if ($Address -eq '127.0.0.1' -or $Address -ieq 'localhost') { return $true }
    $parts = $Address.Split('.')
    if ($parts.Count -ne 4) { return $false }
    $numbers = @()
    foreach ($part in $parts) {
        if ($part -notmatch '^\d{1,3}$') { return $false }
        $number = [int]$part
        if ($number -lt 0 -or $number -gt 255 -or [string]$number -ne $part) { return $false }
        $numbers += $number
    }
    return (
        $numbers[0] -eq 10 -or
        ($numbers[0] -eq 192 -and $numbers[1] -eq 168) -or
        ($numbers[0] -eq 172 -and $numbers[1] -ge 16 -and $numbers[1] -le 31)
    )
}

function Normalize-RahNodeAddress {
    param([Parameter(Mandatory)][string]$Address)
    $value = $Address.Trim()
    if ($value -ieq 'localhost') { return '127.0.0.1' }
    if (-not (Test-RahPrivateIPv4 -Address $value)) {
        throw 'NodeAddress ma vaere localhost eller en privat RFC1918 IPv4-adresse.'
    }
    return $value
}

function Test-RahObjectProperties {
    param([Parameter(Mandatory)]$Object,[Parameter(Mandatory)][string[]]$Required)
    if ($null -eq $Object -or $Object -is [Array]) { return $false }
    $names = @($Object.PSObject.Properties.Name)
    foreach ($name in $Required) { if ($names -notcontains $name) { return $false } }
    return $true
}

function Assert-RahClusterResult {
    param(
        [Parameter(Mandatory)]$Response,
        [Parameter(Mandatory)][ValidateSet('health','systemInfo','benchmark')][string]$RequestedJob
    )
    if (-not (Test-RahObjectProperties -Object $Response -Required @('ok')) -or -not ($Response.ok -is [bool])) {
        throw 'Node Job returnerte ugyldig resultat uten boolsk ok.'
    }
    if ($Response.ok -ne $true) { throw 'Node Job returnerte ok=false.' }
    switch ($RequestedJob) {
        'health' {
            if (-not (Test-RahObjectProperties -Object $Response -Required @('status','computerName','utc')) -or [string]$Response.status -ne 'ready') {
                throw 'Cluster Runner mottok ugyldig health-resultat.'
            }
        }
        'systemInfo' {
            if (-not (Test-RahObjectProperties -Object $Response -Required @('result')) -or $null -eq $Response.result -or [string]::IsNullOrWhiteSpace([string]$Response.result.computerName)) {
                throw 'Cluster Runner mottok ugyldig systemInfo-resultat.'
            }
        }
        'benchmark' {
            if (-not (Test-RahObjectProperties -Object $Response -Required @('result')) -or $null -eq $Response.result -or [int64]$Response.result.iterations -ne 2000000 -or [int64]$Response.result.durationMs -lt 0) {
                throw 'Cluster Runner mottok ugyldig benchmark-resultat.'
            }
        }
    }
    return $Response
}

function Get-RahNodeJobPath {
    $candidate = Join-Path $PSScriptRoot 'RAH-HOME-NODE-JOB.ps1'
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw 'RAH-HOME-NODE-JOB.ps1 mangler i samme mappe.'
    }
    $resolved = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
    if ([IO.Path]::GetFileName($resolved) -ne 'RAH-HOME-NODE-JOB.ps1') { throw 'Node Job-stien er ugyldig.' }
    return $resolved
}

function Invoke-RahClusterRunner {
    param(
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][int]$TargetPort,
        [Parameter(Mandatory)][ValidateSet('health','systemInfo','benchmark')][string]$RequestedJob
    )
    $normalized = Normalize-RahNodeAddress -Address $Address
    $runner = Get-RahNodeJobPath
    $powerShellExe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) { throw 'Fant ikke Windows PowerShell under PSHOME.' }

    $output = & $powerShellExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $runner -NodeAddress $normalized -Port $TargetPort -Job $RequestedJob 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()
    if ($text.Length -gt $script:RahMaxRunnerOutputChars) { throw 'Node Job-resultatet er for stort.' }
    if ($exitCode -ne 0) {
        if ([string]::IsNullOrWhiteSpace($text)) { $text = "exit-code-$exitCode" }
        if ($text.Length -gt 500) { $text = $text.Substring(0,500) }
        throw "Cluster Runner feilet i Node Job: $text"
    }
    if ([string]::IsNullOrWhiteSpace($text)) { throw 'Node Job returnerte tomt resultat.' }
    try { $response = $text | ConvertFrom-Json -ErrorAction Stop }
    catch { throw 'Node Job returnerte ikke gyldig JSON.' }
    return Assert-RahClusterResult -Response $response -RequestedJob $RequestedJob
}

function Invoke-RahClusterRunnerSelfTest {
    if ((Normalize-RahNodeAddress -Address 'localhost') -ne '127.0.0.1') { throw 'SelfTest: localhost-normalisering feilet.' }
    if (-not (Test-RahPrivateIPv4 -Address '192.168.10.20') -or (Test-RahPrivateIPv4 -Address '1.1.1.1')) { throw 'SelfTest: privat IPv4 guard feilet.' }
    Assert-RahClusterResult -Response ([pscustomobject]@{ok=$true;status='ready';computerName='WORKER';utc='2026-09-15T12:00:00Z'}) -RequestedJob 'health' | Out-Null
    Assert-RahClusterResult -Response ([pscustomobject]@{ok=$true;result=[pscustomobject]@{computerName='WORKER'}}) -RequestedJob 'systemInfo' | Out-Null
    Assert-RahClusterResult -Response ([pscustomobject]@{ok=$true;result=[pscustomobject]@{iterations=2000000;durationMs=10}}) -RequestedJob 'benchmark' | Out-Null
    $rejected = $false
    try { Assert-RahClusterResult -Response ([pscustomobject]@{ok=$false}) -RequestedJob 'health' | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'SelfTest: ok=false ble akseptert.' }
    Write-Host "RAH Home Cluster Runner $script:RahClusterRunnerVersion SelfTest OK" -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-RahClusterRunnerSelfTest
    return
}

$normalizedAddress = Normalize-RahNodeAddress -Address $NodeAddress
Write-Host ''
Write-Host "RAH HOME CLUSTER RUNNER v$script:RahClusterRunnerVersion" -ForegroundColor Yellow
Write-Host "Node: $normalizedAddress`:$Port"
Write-Host "Tillatt jobb: $Job"
$result = Invoke-RahClusterRunner -Address $normalizedAddress -TargetPort $Port -RequestedJob $Job
$result | ConvertTo-Json -Depth 8
