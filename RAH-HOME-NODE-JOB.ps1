param(
    [Parameter(Mandatory=$true)][string]$NodeAddress,
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [ValidateSet('health','systemInfo','benchmark')][string]$Job = 'health',
    [switch]$SelfTest,
    [switch]$JsonOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahNodeJobVersion = '1.0.0'
$script:RahProtocolActions = @('health','systemInfo','benchmark')
$script:RahMaxClientOutputChars = 1048576

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

function Test-RahSafeText {
    param([string]$Value,[int]$MaxLength = 160)
    return (-not [string]::IsNullOrWhiteSpace($Value) -and $Value.Length -le $MaxLength -and $Value -notmatch '[<>\x00-\x1f\x7f]')
}

function Test-RahIsoTimestamp {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -gt 64) { return $false }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse(
        $Value,
        [Globalization.CultureInfo]::InvariantCulture,
        [Globalization.DateTimeStyles]::RoundtripKind,
        [ref]$parsed
    )
}

function Test-RahObjectProperties {
    param([Parameter(Mandatory)]$Object,[Parameter(Mandatory)][string[]]$Required)
    if ($null -eq $Object -or $Object -is [Array]) { return $false }
    $names = @($Object.PSObject.Properties.Name)
    foreach ($name in $Required) {
        if ($names -notcontains $name) { return $false }
    }
    return $true
}

function Assert-RahJobResponse {
    param(
        [Parameter(Mandatory)]$Response,
        [Parameter(Mandatory)][ValidateSet('health','systemInfo','benchmark')][string]$RequestedJob
    )

    if (-not (Test-RahObjectProperties -Object $Response -Required @('ok')) -or -not ($Response.ok -is [bool])) {
        throw 'Node Client returnerte ugyldig svar uten boolsk ok.'
    }
    if ($Response.ok -ne $true) {
        $errorName = ''
        if ($Response.PSObject.Properties.Name -contains 'error') { $errorName = [string]$Response.error }
        if ([string]::IsNullOrWhiteSpace($errorName)) { $errorName = 'node-job-failed' }
        throw "Node-jobben ble avvist: $errorName"
    }

    switch ($RequestedJob) {
        'health' {
            if (-not (Test-RahObjectProperties -Object $Response -Required @('status','computerName','utc')) -or
                [string]$Response.status -ne 'ready' -or
                -not (Test-RahSafeText -Value ([string]$Response.computerName)) -or
                -not (Test-RahIsoTimestamp -Value ([string]$Response.utc))) {
                throw 'Ugyldig health-resultat fra Node Client.'
            }
        }
        'systemInfo' {
            if (-not (Test-RahObjectProperties -Object $Response -Required @('result')) -or $null -eq $Response.result -or
                -not (Test-RahSafeText -Value ([string]$Response.result.computerName))) {
                throw 'Ugyldig systemInfo-resultat fra Node Client.'
            }
        }
        'benchmark' {
            if (-not (Test-RahObjectProperties -Object $Response -Required @('result')) -or $null -eq $Response.result) {
                throw 'Ugyldig benchmark-resultat fra Node Client.'
            }
            $iterations = [int64]$Response.result.iterations
            $durationMs = [int64]$Response.result.durationMs
            if ($iterations -ne 2000000 -or $durationMs -lt 0) {
                throw 'Benchmark-resultatet har ugyldige verdier.'
            }
        }
    }

    return $Response
}

function Get-RahNodeClientPath {
    $candidate = Join-Path $PSScriptRoot 'RAH-HOME-NODE-CLIENT.ps1'
    if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) {
        throw 'RAH-HOME-NODE-CLIENT.ps1 mangler i samme mappe.'
    }
    $resolved = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
    if ([IO.Path]::GetFileName($resolved) -ne 'RAH-HOME-NODE-CLIENT.ps1') {
        throw 'Node Client-stien er ugyldig.'
    }
    return $resolved
}

function Invoke-RahNodeJob {
    param(
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][int]$TargetPort,
        [Parameter(Mandatory)][ValidateSet('health','systemInfo','benchmark')][string]$RequestedJob
    )

    $normalizedAddress = Normalize-RahNodeAddress -Address $Address
    $clientPath = Get-RahNodeClientPath
    $powerShellExe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) {
        throw 'Fant ikke Windows PowerShell under PSHOME.'
    }

    $output = & $powerShellExe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $clientPath -NodeAddress $normalizedAddress -Port $TargetPort -Action $RequestedJob 2>&1
    $exitCode = $LASTEXITCODE
    $text = ($output | Out-String).Trim()

    if ($text.Length -gt $script:RahMaxClientOutputChars) {
        throw 'Node Client-resultatet er for stort.'
    }
    if ($exitCode -ne 0) {
        if ([string]::IsNullOrWhiteSpace($text)) { $text = "exit-code-$exitCode" }
        if ($text.Length -gt 500) { $text = $text.Substring(0,500) }
        throw "Node-jobben feilet i Node Client: $text"
    }
    if ([string]::IsNullOrWhiteSpace($text)) {
        throw 'Node Client returnerte tomt resultat.'
    }

    try { $response = $text | ConvertFrom-Json -ErrorAction Stop }
    catch { throw 'Node Client returnerte ikke gyldig JSON.' }

    return Assert-RahJobResponse -Response $response -RequestedJob $RequestedJob
}

function Invoke-RahNodeJobSelfTest {
    if ((Normalize-RahNodeAddress -Address 'localhost') -ne '127.0.0.1') { throw 'SelfTest: localhost-normalisering feilet.' }
    if (-not (Test-RahPrivateIPv4 -Address '10.1.2.3') -or -not (Test-RahPrivateIPv4 -Address '172.16.0.1') -or -not (Test-RahPrivateIPv4 -Address '192.168.1.5')) { throw 'SelfTest: privat IPv4 ble avvist.' }
    if (Test-RahPrivateIPv4 -Address '8.8.8.8') { throw 'SelfTest: offentlig IPv4 ble tillatt.' }

    $health = [pscustomobject]@{ok=$true;status='ready';computerName='WORKER';utc='2026-09-15T12:00:00.000Z'}
    Assert-RahJobResponse -Response $health -RequestedJob 'health' | Out-Null
    $systemInfo = [pscustomobject]@{ok=$true;result=[pscustomobject]@{computerName='WORKER'}}
    Assert-RahJobResponse -Response $systemInfo -RequestedJob 'systemInfo' | Out-Null
    $benchmark = [pscustomobject]@{ok=$true;result=[pscustomobject]@{iterations=2000000;durationMs=123}}
    Assert-RahJobResponse -Response $benchmark -RequestedJob 'benchmark' | Out-Null

    $rejected = $false
    try { Assert-RahJobResponse -Response ([pscustomobject]@{ok=$false;error='unauthorized'}) -RequestedJob 'health' | Out-Null }
    catch { $rejected = $true }
    if (-not $rejected) { throw 'SelfTest: avvist node-resultat ble akseptert.' }

    Write-Host "RAH Home Node Job $script:RahNodeJobVersion SelfTest OK" -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-RahNodeJobSelfTest
    return
}

$normalized = Normalize-RahNodeAddress -Address $NodeAddress
if (-not $JsonOnly) {
    Write-Host "RAH HOME NODE JOB v$script:RahNodeJobVersion -> $normalized`:$Port / $Job" -ForegroundColor Yellow
}
$result = Invoke-RahNodeJob -Address $normalized -TargetPort $Port -RequestedJob $Job
$result | ConvertTo-Json -Depth 8
