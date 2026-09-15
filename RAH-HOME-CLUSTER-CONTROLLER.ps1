param(
    [string]$PlanPath = '',
    [string]$OutputPath = (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'rah-home-cluster-results.json'),
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahClusterControllerVersion = '1.0.0'
$script:RahAllowedJobs = @('health','systemInfo','benchmark')
$script:RahMaxNodes = 16
$script:RahMaxPlanBytes = 1048576
$script:RahMaxNodeResponseChars = 1048576

function Test-PrivateIPv4 {
    param([Parameter(Mandatory)][string]$Ip)

    if ($Ip -eq '127.0.0.1') { return $true }
    $parts = $Ip.Split('.')
    if ($parts.Count -ne 4) { return $false }
    $numbers = @()
    foreach ($part in $parts) {
        if ($part -notmatch '^\d{1,3}$') { return $false }
        $n = [int]$part
        if ($n -lt 0 -or $n -gt 255 -or [string]$n -ne $part) { return $false }
        $numbers += $n
    }
    return (
        $numbers[0] -eq 10 -or
        ($numbers[0] -eq 192 -and $numbers[1] -eq 168) -or
        ($numbers[0] -eq 172 -and $numbers[1] -ge 16 -and $numbers[1] -le 31)
    )
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
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string[]]$Allowed,
        [Parameter(Mandatory)][string[]]$Required
    )

    if ($null -eq $Object) { return $false }
    $names = @($Object.PSObject.Properties.Name)
    foreach ($name in $names) {
        if ($Allowed -notcontains [string]$name) { return $false }
    }
    foreach ($name in $Required) {
        if ($names -notcontains $name) { return $false }
    }
    return $true
}

function ConvertTo-RahValidatedPlanNode {
    param([Parameter(Mandatory)]$Node)

    if (-not (Test-RahObjectProperties -Object $Node -Allowed @('nodeAddress','port','job') -Required @('nodeAddress','port','job'))) {
        throw 'Cluster-plan inneholder ukjente eller manglende nodefelt.'
    }

    $ip = [string]$Node.nodeAddress
    if (-not (Test-PrivateIPv4 $ip)) { throw "Avviser ikke-privat node: $ip" }

    $portText = [string]$Node.port
    $port = 0
    if (-not [int]::TryParse($portText, [ref]$port) -or $port -lt 1024 -or $port -gt 65535) {
        throw "Ugyldig port for $ip"
    }

    $job = [string]$Node.job
    if ($script:RahAllowedJobs -notcontains $job) { throw "Ikke tillatt cluster-jobb: $job" }

    return [pscustomobject]@{
        nodeAddress = $ip
        port = $port
        job = $job
    }
}

function ConvertTo-RahValidatedPlan {
    param([Parameter(Mandatory)]$Plan)

    if (-not (Test-RahObjectProperties -Object $Plan -Allowed @('schema','version','createdAt','nodes') -Required @('schema','version','nodes'))) {
        throw 'Ugyldige eller manglende toppfelt i cluster-plan.'
    }
    if ([string]$Plan.schema -ne 'rah-home-cluster-plan' -or [int]$Plan.version -ne 1) {
        throw 'Ugyldig cluster-plan schema/version.'
    }
    if ($Plan.PSObject.Properties.Name -contains 'createdAt') {
        if (-not (Test-RahIsoTimestamp ([string]$Plan.createdAt))) { throw 'Ugyldig createdAt i cluster-plan.' }
    }

    $nodes = @($Plan.nodes)
    if ($nodes.Count -lt 1 -or $nodes.Count -gt $script:RahMaxNodes) {
        throw 'Planen ma inneholde 1-16 noder.'
    }

    $validated = @()
    foreach ($node in $nodes) {
        $validated += ConvertTo-RahValidatedPlanNode -Node $node
    }

    return [pscustomobject]@{
        schema = 'rah-home-cluster-plan'
        version = 1
        nodes = $validated
    }
}

function Read-RahClusterPlan {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Cluster-planfil finnes ikke.' }
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -lt 2 -or $item.Length -gt $script:RahMaxPlanBytes) {
        throw 'Cluster-planfil ma vaere mellom 2 byte og 1 MB.'
    }

    $raw = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
    try { $plan = $raw | ConvertFrom-Json -ErrorAction Stop }
    catch { throw 'Cluster-planfil er ikke gyldig JSON.' }
    return ConvertTo-RahValidatedPlan -Plan $plan
}

function Invoke-RahClusterControllerSelfTest {
    $valid = [pscustomobject]@{
        schema = 'rah-home-cluster-plan'
        version = 1
        createdAt = '2026-09-15T12:00:00.000Z'
        nodes = @(
            [pscustomobject]@{ nodeAddress='192.168.1.20'; port=18766; job='health' },
            [pscustomobject]@{ nodeAddress='10.0.0.8'; port=18766; job='systemInfo' },
            [pscustomobject]@{ nodeAddress='127.0.0.1'; port=28767; job='benchmark' }
        )
    }
    $normalized = ConvertTo-RahValidatedPlan -Plan $valid
    if (@($normalized.nodes).Count -ne 3) { throw 'SelfTest: valid plan count mismatch.' }
    if (-not (Test-PrivateIPv4 '172.16.0.1') -or (Test-PrivateIPv4 '8.8.8.8')) {
        throw 'SelfTest: private IPv4 guard failed.'
    }

    $badJob = [pscustomobject]@{ nodeAddress='192.168.1.2'; port=18766; job='shell' }
    $rejected = $false
    try { ConvertTo-RahValidatedPlanNode -Node $badJob | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'SelfTest: non-allowlisted job was accepted.' }

    $extra = [pscustomobject]@{ nodeAddress='192.168.1.2'; port=18766; job='health'; command='whoami' }
    $rejected = $false
    try { ConvertTo-RahValidatedPlanNode -Node $extra | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'SelfTest: extra node field was accepted.' }

    Write-Host "RAH Home Cluster Controller $script:RahClusterControllerVersion SelfTest OK" -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-RahClusterControllerSelfTest
    return
}

if ([string]::IsNullOrWhiteSpace($PlanPath)) { throw 'PlanPath er pakrevd.' }
$client = Join-Path $PSScriptRoot 'RAH-HOME-NODE-CLIENT.ps1'
if (-not (Test-Path -LiteralPath $client -PathType Leaf)) {
    throw 'RAH-HOME-NODE-CLIENT.ps1 mangler ved siden av controlleren.'
}

$fullPlanPath = [IO.Path]::GetFullPath($PlanPath)
$fullOutputPath = [IO.Path]::GetFullPath($OutputPath)
if ([string]::Equals($fullPlanPath, $fullOutputPath, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'OutputPath kan ikke overskrive cluster-planfilen.'
}

$plan = Read-RahClusterPlan -Path $fullPlanPath
$results = @()
foreach ($node in @($plan.nodes)) {
    $ip = [string]$node.nodeAddress
    $port = [int]$node.port
    $job = [string]$node.job
    $started = (Get-Date).ToUniversalTime().ToString('o')
    $text = ''
    $exitCode = 1

    try {
        $text = & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $ip -Port $port -Action $job 2>&1 | Out-String
        $exitCode = $LASTEXITCODE
    }
    catch {
        $text = $_.Exception.Message
        $exitCode = 1
    }

    if ($text.Length -gt $script:RahMaxNodeResponseChars) {
        $text = $text.Substring(0, $script:RahMaxNodeResponseChars)
        $exitCode = 1
    }

    $parsed = $null
    try { $parsed = $text | ConvertFrom-Json -ErrorAction Stop } catch { }
    $parsedOk = $false
    if ($parsed -and $parsed.PSObject.Properties.Name -contains 'ok') {
        $parsedOk = [bool]$parsed.ok
    }
    $message = $null
    if (-not $parsed) {
        $message = $text.Trim()
        if ($message.Length -gt 4000) { $message = $message.Substring(0,4000) }
    }

    $results += [pscustomobject]@{
        nodeAddress = $ip
        port = $port
        job = $job
        ok = ($exitCode -eq 0 -and $parsedOk)
        startedAt = $started
        finishedAt = (Get-Date).ToUniversalTime().ToString('o')
        result = $parsed
        message = $message
    }
}

$out = [pscustomobject]@{
    schema = 'rah-home-cluster-results'
    version = 1
    controllerVersion = $script:RahClusterControllerVersion
    createdAt = (Get-Date).ToUniversalTime().ToString('o')
    results = $results
}

$parent = Split-Path -Parent $fullOutputPath
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
}
$json = $out | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText($fullOutputPath, $json, [Text.UTF8Encoding]::new($false))
Write-Host "RAH Cluster Controller v$script:RahClusterControllerVersion ferdig: $($results.Count) node-jobber. Resultat: $fullOutputPath" -ForegroundColor Green
