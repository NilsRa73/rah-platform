param(
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [string]$NodeAddress = '',
    [string]$PairCode = '',
    [string]$OutputPath = '',
    [switch]$NoOpen,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahPairWizardVersion = '1.0.0'
$script:RahProtocolVersion = 2
$script:RahMaxClientOutputChars = 1048576
$script:RahReceiptSource = 'explicit-pair-code-and-authenticated-system-info'
$script:RahTrustUrl = 'https://nilsra73.github.io/rah-platform/RAH-HOME-TRUST.html'

function Test-RahPrivateIPv4 {
    param([Parameter(Mandatory)][string]$Address)
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

function Normalize-RahPairTarget {
    param([Parameter(Mandatory)][string]$Address)
    $value = $Address.Trim()
    if (-not (Test-RahPrivateIPv4 -Address $value)) {
        throw 'Kun privat RFC1918 IPv4 er tillatt for Pair Wizard.'
    }
    return $value
}

function Test-RahSafeText {
    param([string]$Value,[int]$MaxLength = 120)
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

function Get-RahNodeClientPath {
    $candidates = @(
        (Join-Path $PSScriptRoot 'RAH-HOME-NODE-CLIENT.ps1'),
        (Join-Path $env:LOCALAPPDATA 'RAH\Home\RAH-HOME-NODE-CLIENT.ps1'),
        (Join-Path $env:LOCALAPPDATA 'RAH\HomeNode\RAH-HOME-NODE-CLIENT.ps1')
    )
    foreach ($candidate in $candidates) {
        if (-not (Test-Path -LiteralPath $candidate -PathType Leaf)) { continue }
        $resolved = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
        if ([IO.Path]::GetFileName($resolved) -eq 'RAH-HOME-NODE-CLIENT.ps1') { return $resolved }
    }
    throw 'Fant ikke RAH-HOME-NODE-CLIENT.ps1. Installer RAH Home i Leader-modus først.'
}

function Invoke-RahNodeClient {
    param(
        [Parameter(Mandatory)][string]$ClientPath,
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][int]$TargetPort,
        [Parameter(Mandatory)][ValidateSet('hello','pair','systemInfo')][string]$Action,
        [string]$Code = ''
    )
    $powerShellExe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) { throw 'Fant ikke Windows PowerShell under PSHOME.' }

    $arguments = @(
        '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
        '-File',$ClientPath,
        '-NodeAddress',$Address,
        '-Port',[string]$TargetPort,
        '-Action',$Action
    )
    if ($Action -eq 'pair') { $arguments += @('-PairCode',$Code) }

    $previousPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = & $powerShellExe @arguments 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $previousPreference }

    $text = ($output | Out-String).Trim()
    if ($text.Length -gt $script:RahMaxClientOutputChars) { throw 'Node Client-resultatet er for stort.' }
    return [pscustomobject]@{ ExitCode = $exitCode; Text = $text }
}

function ConvertFrom-RahClientJson {
    param([Parameter(Mandatory)]$Invocation,[Parameter(Mandatory)][string]$Context)
    if ($Invocation.ExitCode -ne 0) {
        $message = $Invocation.Text
        if ([string]::IsNullOrWhiteSpace($message)) { $message = "exit-code-$($Invocation.ExitCode)" }
        if ($message.Length -gt 500) { $message = $message.Substring(0,500) }
        throw "$Context feilet: $message"
    }
    if ([string]::IsNullOrWhiteSpace($Invocation.Text)) { throw "$Context returnerte tomt svar." }
    try { return $Invocation.Text | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "$Context returnerte ikke gyldig JSON." }
}

function Assert-RahHelloResponse {
    param([Parameter(Mandatory)]$Response)
    if (-not (Test-RahObjectProperties -Object $Response -Required @('ok','product','version','computerName','pairingRequired'))) {
        throw 'Ugyldig hello-svar fra Node Agent.'
    }
    if ($Response.ok -ne $true -or [string]$Response.product -ne 'RAH Home Node Agent' -or [int]$Response.version -ne $script:RahProtocolVersion -or $Response.pairingRequired -ne $true -or -not (Test-RahSafeText -Value ([string]$Response.computerName))) {
        throw 'Node-identitet/protokoll stemmer ikke med RAH Home Node Agent.'
    }
    return $Response
}

function Assert-RahSystemInfoResponse {
    param([Parameter(Mandatory)]$Response,[Parameter(Mandatory)][string]$ExpectedComputerName)
    if (-not (Test-RahObjectProperties -Object $Response -Required @('ok','result')) -or $Response.ok -ne $true -or $null -eq $Response.result -or -not (Test-RahSafeText -Value ([string]$Response.result.computerName))) {
        throw 'Noden returnerte ugyldig autentisert systemInfo.'
    }
    if ([string]$Response.result.computerName -cne $ExpectedComputerName) {
        throw 'Node-identiteten endret seg mellom hello og autentisert systemInfo.'
    }
    return $Response
}

function New-RahPairingReceipt {
    param(
        [Parameter(Mandatory)][string]$Address,
        [Parameter(Mandatory)][int]$TargetPort,
        [Parameter(Mandatory)][string]$ComputerName,
        [string]$PairedAt = ''
    )
    $normalizedAddress = Normalize-RahPairTarget -Address $Address
    if (-not (Test-RahSafeText -Value $ComputerName)) { throw 'Ugyldig node-navn for pairing-evidens.' }
    if ([string]::IsNullOrWhiteSpace($PairedAt)) { $PairedAt = (Get-Date).ToUniversalTime().ToString('o') }
    if (-not (Test-RahIsoTimestamp -Value $PairedAt)) { throw 'Ugyldig pairedAt-tidspunkt.' }
    return [pscustomobject]@{
        schema = 'rah-home-pairing-receipt'
        version = 1
        nodeAddress = $normalizedAddress
        port = $TargetPort
        computerName = $ComputerName
        pairedAt = $PairedAt
        source = $script:RahReceiptSource
    }
}

function Write-RahPairingReceipt {
    param([Parameter(Mandatory)]$Receipt,[Parameter(Mandatory)][string]$Path)
    $fullPath = [IO.Path]::GetFullPath($Path)
    if ([IO.Path]::GetExtension($fullPath) -ine '.json') { throw 'OutputPath må være en .json-fil.' }
    $directory = [IO.Path]::GetDirectoryName($fullPath)
    if ([string]::IsNullOrWhiteSpace($directory)) { throw 'OutputPath mangler gyldig mappe.' }
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
    $json = $Receipt | ConvertTo-Json -Depth 4
    if ($json -match '"token"\s*:') { throw 'Pairing-evidens skal aldri inneholde token.' }
    $temp = Join-Path $directory ('.' + [IO.Path]::GetFileName($fullPath) + '.' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($temp,$json,(New-Object Text.UTF8Encoding($false)))
        Move-Item -LiteralPath $temp -Destination $fullPath -Force
    }
    finally { if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue } }
    return $fullPath
}

function Invoke-RahPairWizardSelfTest {
    if (-not (Test-RahPrivateIPv4 -Address '10.1.2.3') -or -not (Test-RahPrivateIPv4 -Address '172.16.2.3') -or -not (Test-RahPrivateIPv4 -Address '192.168.1.9')) { throw 'SelfTest: privat IPv4 ble avvist.' }
    if (Test-RahPrivateIPv4 -Address '127.0.0.1' -or Test-RahPrivateIPv4 -Address '8.8.8.8') { throw 'SelfTest: ikke-RFC1918-adresse ble tillatt.' }
    if ('123456' -notmatch '^\d{6}$' -or '12345x' -match '^\d{6}$') { throw 'SelfTest: PairCode-validering feilet.' }

    $hello = [pscustomobject]@{ok=$true;product='RAH Home Node Agent';version=2;computerName='WORKER';pairingRequired=$true}
    Assert-RahHelloResponse -Response $hello | Out-Null
    $info = [pscustomobject]@{ok=$true;result=[pscustomobject]@{computerName='WORKER'}}
    Assert-RahSystemInfoResponse -Response $info -ExpectedComputerName 'WORKER' | Out-Null
    $receipt = New-RahPairingReceipt -Address '192.168.1.9' -TargetPort 18766 -ComputerName 'WORKER' -PairedAt '2026-09-15T12:00:00.000Z'
    $keys = @($receipt.PSObject.Properties.Name)
    $expected = @('schema','version','nodeAddress','port','computerName','pairedAt','source')
    if (@($keys | Where-Object { $_ -notin $expected }).Count -ne 0 -or @($expected | Where-Object { $_ -notin $keys }).Count -ne 0) { throw 'SelfTest: receipt-feltsett feilet.' }
    if ($keys -contains 'token' -or $receipt.source -ne $script:RahReceiptSource) { throw 'SelfTest: receipt provenance/token guard feilet.' }

    Write-Host "RAH Home Pair Wizard $script:RahPairWizardVersion SelfTest OK" -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-RahPairWizardSelfTest
    return
}

Write-Host 'RAH HOME PAIR WIZARD v1.0.0' -ForegroundColor Yellow
Write-Host 'Kun for egne/autoriserte maskiner på privat RFC1918-lokalnett.'

$addressInput = $NodeAddress
if ([string]::IsNullOrWhiteSpace($addressInput)) { $addressInput = Read-Host 'Worker IP-adresse' }
$ip = Normalize-RahPairTarget -Address $addressInput

$client = Get-RahNodeClientPath
$helloCall = Invoke-RahNodeClient -ClientPath $client -Address $ip -TargetPort $Port -Action 'hello'
$hello = ConvertFrom-RahClientJson -Invocation $helloCall -Context 'Node hello'
Assert-RahHelloResponse -Response $hello | Out-Null

$code = $PairCode.Trim()
if ([string]::IsNullOrWhiteSpace($code)) { $code = (Read-Host 'Skriv PAIR CODE som vises på worker-PC').Trim() }
if ($code -notmatch '^\d{6}$') { throw 'Pair code må være nøyaktig seks sifre.' }

$pairCall = Invoke-RahNodeClient -ClientPath $client -Address $ip -TargetPort $Port -Action 'pair' -Code $code
if ($pairCall.ExitCode -ne 0) {
    $message = $pairCall.Text
    if ([string]::IsNullOrWhiteSpace($message)) { $message = "exit-code-$($pairCall.ExitCode)" }
    if ($message.Length -gt 500) { $message = $message.Substring(0,500) }
    throw "Pairing feilet: $message"
}

$infoCall = Invoke-RahNodeClient -ClientPath $client -Address $ip -TargetPort $Port -Action 'systemInfo'
$info = ConvertFrom-RahClientJson -Invocation $infoCall -Context 'Autentisert systemInfo'
Assert-RahSystemInfoResponse -Response $info -ExpectedComputerName ([string]$hello.computerName) | Out-Null

$receipt = New-RahPairingReceipt -Address $ip -TargetPort $Port -ComputerName ([string]$info.result.computerName)
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\rah-home-pairing.json'
}
$out = Write-RahPairingReceipt -Receipt $receipt -Path $OutputPath

Write-Host "FERDIG: $($receipt.computerName) ($ip) er paret og autentisert mot RAH Home Node Agent." -ForegroundColor Green
Write-Host "Pairing-evidens uten token (ikke signert): $out"
Write-Host 'Home Trust krever i tillegg eksplisitt lokal godkjenning før enheten blir klarert.'

if (-not $NoOpen) {
    try { Start-Process $script:RahTrustUrl } catch { Write-Warning 'Kunne ikke åpne RAH Home Trust automatisk.' }
    try { Start-Process explorer.exe -ArgumentList "/select,`"$out`"" } catch { Write-Warning 'Kunne ikke markere pairing-filen i Explorer automatisk.' }
}
