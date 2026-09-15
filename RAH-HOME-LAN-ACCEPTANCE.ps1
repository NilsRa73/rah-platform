param(
    [string]$WorkerAddress = '',
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [string]$OutputPath = '',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahLanAcceptanceVersion = '1.0.0'
$script:RahProtocolVersion = 2
$script:RahMaxClientOutputChars = 1048576

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

function Get-RahNodeClientPath {
    $candidates = @(
        (Join-Path $PSScriptRoot 'RAH-HOME-NODE-CLIENT.ps1')
    )
    if (-not [string]::IsNullOrWhiteSpace($env:SystemDrive)) { $candidates += (Join-Path $env:SystemDrive 'RAH\Home\RAH-HOME-NODE-CLIENT.ps1') }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { $candidates += (Join-Path $env:LOCALAPPDATA 'RAH\Home\RAH-HOME-NODE-CLIENT.ps1') }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return (Resolve-Path -LiteralPath $candidate).Path }
    }
    throw 'RAH Home Leader er ikke installert. Kjør RAH-HOME-INSTALL.ps1 -Mode Leader først.'
}

function Invoke-RahClient {
    param([Parameter(Mandatory)][string]$Client,[Parameter(Mandatory)][string]$Address,[Parameter(Mandatory)][string]$Action,[string]$PairCode='')
    $exe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Fant ikke Windows PowerShell under PSHOME.' }
    $args = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$Client,'-NodeAddress',$Address,'-Port',[string]$Port,'-Action',$Action)
    if ($Action -eq 'pair') { $args += @('-PairCode',$PairCode) }
    $old = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $raw = & $exe @args 2>&1
        $exitCode = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $old }
    $text = ($raw | Out-String).Trim()
    if ($text.Length -gt $script:RahMaxClientOutputChars) { throw 'Node Client-resultatet er for stort.' }
    return [pscustomobject]@{ ExitCode=$exitCode; Text=$text }
}

function ConvertFrom-RahJsonResult {
    param([Parameter(Mandatory)]$Invocation,[Parameter(Mandatory)][string]$Context)
    if ($Invocation.ExitCode -ne 0) { throw "$Context feilet: $($Invocation.Text)" }
    try { return $Invocation.Text | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "$Context returnerte ikke gyldig JSON." }
}

function Test-RahActionResponse {
    param([Parameter(Mandatory)]$Response,[Parameter(Mandatory)][string]$Action)
    if ($null -eq $Response -or $Response.ok -ne $true) { return $false }
    if ($Action -eq 'hello') {
        return ([string]$Response.product -eq 'RAH Home Node Agent' -and [int]$Response.version -eq $script:RahProtocolVersion -and -not [string]::IsNullOrWhiteSpace([string]$Response.computerName))
    }
    return ($null -ne $Response.result)
}

function Write-RahAcceptanceResult {
    param([Parameter(Mandatory)]$Document,[Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $dir = [IO.Path]::GetDirectoryName($full)
    if ([string]::IsNullOrWhiteSpace($dir)) { throw 'OutputPath mangler mappe.' }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    $tmp = "$full.tmp"
    [IO.File]::WriteAllText($tmp,($Document | ConvertTo-Json -Depth 10),(New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $tmp -Destination $full -Force
    return $full
}

function Invoke-RahLanAcceptanceSelfTest {
    foreach ($good in @('10.0.0.8','172.31.2.7','192.168.50.4')) {
        if (-not (Test-RahPrivateIPv4 -Address $good)) { throw "SelfTest: privat IP avvist: $good" }
    }
    foreach ($bad in @('127.0.0.1','8.8.8.8','0.0.0.0','192.168.001.1')) {
        if (Test-RahPrivateIPv4 -Address $bad) { throw "SelfTest: ugyldig IP tillatt: $bad" }
    }
    $hello = [pscustomobject]@{ok=$true;product='RAH Home Node Agent';version=2;computerName='WORKER'}
    if (-not (Test-RahActionResponse -Response $hello -Action 'hello')) { throw 'SelfTest: hello-kontrakt feilet.' }
    Write-Host "RAH Home LAN Acceptance $script:RahLanAcceptanceVersion SelfTest OK" -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-RahLanAcceptanceSelfTest
    return
}

$worker = $WorkerAddress.Trim()
if (-not (Test-RahPrivateIPv4 -Address $worker)) { throw 'WorkerAddress må være en privat RFC1918 IPv4-adresse.' }
if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path ([Environment]::GetFolderPath('Desktop')) 'rah-home-lan-acceptance.json' }
$client = Get-RahNodeClientPath

Write-Host "RAH HOME 2-PC LAN ACCEPTANCE v$script:RahLanAcceptanceVersion" -ForegroundColor Yellow
Write-Host "Worker: $worker`:$Port"
Write-Host 'Forutsetning: RAH Home Worker kjører på den andre PC-en.'

$results = @()
$helloCall = Invoke-RahClient -Client $client -Address $worker -Action 'hello'
$hello = ConvertFrom-RahJsonResult -Invocation $helloCall -Context 'HELLO'
$helloOk = Test-RahActionResponse -Response $hello -Action 'hello'
$results += [pscustomobject]@{action='hello';ok=[bool]$helloOk;result=$hello}
if (-not $helloOk) { throw 'HELLO svarte, men Agent-identitet/protokoll var ugyldig.' }
Write-Host 'HELLO OK' -ForegroundColor Green

$pairCode = (Read-Host 'Skriv den seks-sifrede PAIR CODE som vises på Worker-PC-en').Trim()
if ($pairCode -notmatch '^\d{6}$') { throw 'Pair code må være nøyaktig seks sifre.' }
$pairCall = Invoke-RahClient -Client $client -Address $worker -Action 'pair' -PairCode $pairCode
$pairOk = ($pairCall.ExitCode -eq 0)
$results += [pscustomobject]@{action='pair';ok=[bool]$pairOk;result=$null;raw=$pairCall.Text}
if (-not $pairOk) { throw "PAIR feilet: $($pairCall.Text)" }
Write-Host 'PAIR OK' -ForegroundColor Green

foreach ($action in @('health','systemInfo','benchmark')) {
    $started = (Get-Date).ToUniversalTime().ToString('o')
    $call = Invoke-RahClient -Client $client -Address $worker -Action $action
    $parsed = ConvertFrom-RahJsonResult -Invocation $call -Context $action
    $ok = Test-RahActionResponse -Response $parsed -Action $action
    $results += [pscustomobject]@{action=$action;ok=[bool]$ok;startedAt=$started;finishedAt=(Get-Date).ToUniversalTime().ToString('o');result=$parsed}
    Write-Host ("{0}: {1}" -f $action,$(if($ok){'OK'}else{'FEIL'})) -ForegroundColor $(if($ok){'Green'}else{'Red'})
}

$pass = ($results.Count -eq 5 -and @($results | Where-Object { -not $_.ok }).Count -eq 0)
$document = [pscustomobject]@{
    schema='rah-home-lan-acceptance'
    version=1
    helperVersion=$script:RahLanAcceptanceVersion
    workerAddress=$worker
    port=$Port
    createdAt=(Get-Date).ToUniversalTime().ToString('o')
    pass=$pass
    results=$results
}
$out = Write-RahAcceptanceResult -Document $document -Path $OutputPath
if ($pass) {
    Write-Host 'PASS: RAH Home fysisk 2-PC LAN acceptance' -ForegroundColor Green
    Write-Host "Resultat: $out"
    exit 0
}
Write-Host 'FAIL: RAH Home fysisk 2-PC LAN acceptance' -ForegroundColor Red
Write-Host "Resultat: $out"
exit 1
