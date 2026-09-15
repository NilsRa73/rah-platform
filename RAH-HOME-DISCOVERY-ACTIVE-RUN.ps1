param(
    [string]$OutputPath = '',
    [string]$DiscoveryScriptPath = '',
    [int]$InterfaceIndex = 0,
    [int]$TimeoutMs = 250,
    [int]$DelayMs = 20,
    [int]$MaxHosts = 254,
    [switch]$NoOpen,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahActiveRunnerVersion = '1.0.0'
$script:RahActiveDiscoveryUrl = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-DISCOVERY-ACTIVE.ps1'
$script:RahInboxUrl = 'https://nilsra73.github.io/rah-platform/RAH-HOME-DISCOVERY-INBOX.html'

function Get-RahActiveRunnerRoot {
    if ($PSScriptRoot) { return $PSScriptRoot }
    return (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

function Get-RahActiveDefaultOutputPath {
    $downloads = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
    if (-not (Test-Path -LiteralPath $downloads)) {
        New-Item -ItemType Directory -Path $downloads -Force | Out-Null
    }
    return (Join-Path $downloads 'rah-home-discovery-active.json')
}

function Test-RahActiveDiscoveryScriptContract {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }
    try {
        $text = [System.IO.File]::ReadAllText([System.IO.Path]::GetFullPath($Path))
    }
    catch { return $false }

    $required = @(
        'RahActiveDiscoveryVersion',
        "mode = 'active-local-subnet'",
        "authorization = 'explicit-start-local-private-subnet'",
        "protocol = 'ICMP echo only'",
        '[switch]$Start'
    )
    foreach ($needle in $required) {
        if ($text.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) { return $false }
    }
    return $true
}

function Get-RahActivePreferredInstallDirectory {
    $preferred = 'C:\RAH\Home'
    try {
        if (-not (Test-Path -LiteralPath $preferred)) {
            New-Item -ItemType Directory -Path $preferred -Force -ErrorAction Stop | Out-Null
        }
        return $preferred
    }
    catch {
        $fallback = Join-Path $env:LOCALAPPDATA 'RAH\Home'
        if (-not (Test-Path -LiteralPath $fallback)) {
            New-Item -ItemType Directory -Path $fallback -Force | Out-Null
        }
        Write-Warning "Could not use C:\RAH\Home. Using $fallback instead."
        return $fallback
    }
}

function Install-RahActiveDiscoveryScript {
    param([string]$DestinationDirectory = '')

    if (-not $DestinationDirectory) { $DestinationDirectory = Get-RahActivePreferredInstallDirectory }
    if (-not (Test-Path -LiteralPath $DestinationDirectory)) {
        New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
    }

    $destination = Join-Path $DestinationDirectory 'RAH-HOME-DISCOVERY-ACTIVE.ps1'
    $temp = "$destination.download"
    Write-Host 'RAH Active Discovery is missing locally. Downloading stable version...' -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $script:RahActiveDiscoveryUrl -OutFile $temp -UseBasicParsing -ErrorAction Stop
        if (-not (Test-RahActiveDiscoveryScriptContract -Path $temp)) {
            throw 'Downloaded Active Discovery failed RAH contract validation.'
        }
        Move-Item -LiteralPath $temp -Destination $destination -Force
        Write-Host "Installed: $destination" -ForegroundColor Green
        return $destination
    }
    catch {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        throw "Could not download RAH Active Discovery: $($_.Exception.Message)"
    }
}

function Resolve-RahActiveDiscoveryScript {
    param([string]$RequestedPath = '')

    if ($RequestedPath) {
        $resolved = [System.IO.Path]::GetFullPath($RequestedPath)
        if (-not (Test-RahActiveDiscoveryScriptContract -Path $resolved)) {
            throw "Active Discovery script is invalid or incompatible: $resolved"
        }
        return $resolved
    }

    $candidates = @(
        (Join-Path (Get-RahActiveRunnerRoot) 'RAH-HOME-DISCOVERY-ACTIVE.ps1'),
        'C:\RAH\Home\RAH-HOME-DISCOVERY-ACTIVE.ps1'
    )
    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA 'RAH\Home\RAH-HOME-DISCOVERY-ACTIVE.ps1')
    }
    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-RahActiveDiscoveryScriptContract -Path $candidate) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }
    return (Install-RahActiveDiscoveryScript)
}

function Test-RahActiveConsent {
    param([AllowEmptyString()][string]$Answer)
    return ($Answer -ceq 'JA')
}

function Test-RahActiveDiscoveryOutput {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Active Discovery output was not created: $Path"
    }
    try {
        $doc = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Active Discovery output is not valid JSON: $($_.Exception.Message)"
    }

    if ($doc.schema -ne 'rah-home-discovery-cache' -or
        [int]$doc.version -ne 1 -or
        $doc.mode -ne 'active-local-subnet' -or
        $doc.passive -ne $false -or
        $doc.authorization -ne 'explicit-start-local-private-subnet' -or
        $null -eq $doc.scan -or
        $doc.scan.protocol -ne 'ICMP echo only' -or
        $null -eq $doc.devices) {
        throw 'Active Discovery output failed the RAH v1 contract check.'
    }
    return $doc
}

function Invoke-RahActiveDiscoveryRunner {
    param(
        [string]$RequestedOutputPath = '',
        [string]$RequestedDiscoveryScript = '',
        [int]$RequestedInterfaceIndex = 0,
        [int]$RequestedTimeoutMs = 250,
        [int]$RequestedDelayMs = 20,
        [int]$RequestedMaxHosts = 254,
        [switch]$SkipOpen
    )

    if ($RequestedInterfaceIndex -lt 0) { throw 'InterfaceIndex cannot be negative.' }
    if ($RequestedTimeoutMs -lt 50 -or $RequestedTimeoutMs -gt 2000) { throw 'TimeoutMs must be 50-2000.' }
    if ($RequestedDelayMs -lt 0 -or $RequestedDelayMs -gt 1000) { throw 'DelayMs must be 0-1000.' }
    if ($RequestedMaxHosts -lt 1 -or $RequestedMaxHosts -gt 254) { throw 'MaxHosts must be 1-254.' }

    $discoveryScript = Resolve-RahActiveDiscoveryScript -RequestedPath $RequestedDiscoveryScript
    $output = if ($RequestedOutputPath) { [System.IO.Path]::GetFullPath($RequestedOutputPath) } else { Get-RahActiveDefaultOutputPath }
    $outputDirectory = Split-Path -Parent $output
    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    Write-Host 'RAH HOME DISCOVERY - ACTIVE LOCAL NETWORK v1' -ForegroundColor Yellow
    Write-Host 'This sends ICMP echo only inside one private RFC1918 /24-/30 subnet.'
    Write-Host 'No port scanning or service probing is performed.'
    Write-Host "Maximum targets: $RequestedMaxHosts"
    if ($RequestedInterfaceIndex -gt 0) { Write-Host "InterfaceIndex: $RequestedInterfaceIndex" }
    Write-Host ''

    $answer = Read-Host 'Use only on your own/authorized network. Type JA to start'
    if (-not (Test-RahActiveConsent -Answer $answer)) {
        Write-Host 'Cancelled. No active discovery was run.' -ForegroundColor DarkYellow
        return [pscustomobject]@{ started=$false; outputPath=$output; candidateCount=0; openedUi=$false }
    }

    $args = @{
        Start = $true
        OutputPath = $output
        TimeoutMs = $RequestedTimeoutMs
        DelayMs = $RequestedDelayMs
        MaxHosts = $RequestedMaxHosts
    }
    if ($RequestedInterfaceIndex -gt 0) { $args.InterfaceIndex = $RequestedInterfaceIndex }

    & $discoveryScript @args
    $doc = Test-RahActiveDiscoveryOutput -Path $output

    Write-Host ''
    Write-Host "RAH Active Discovery Runner $script:RahActiveRunnerVersion completed." -ForegroundColor Green
    Write-Host "JSON file: $output"
    Write-Host "Candidates: $(@($doc.devices).Count)"

    if (-not $SkipOpen) {
        Write-Host 'Opening Discovery Inbox. Approve only devices you recognize.'
        Start-Process $script:RahInboxUrl
        Start-Process explorer.exe "/select,`"$output`""
    }

    return [pscustomobject]@{
        started = $true
        runnerVersion = $script:RahActiveRunnerVersion
        discoveryScript = $discoveryScript
        outputPath = $output
        candidateCount = @($doc.devices).Count
        openedUi = -not [bool]$SkipOpen
    }
}

function Invoke-RahActiveRunnerSelfTest {
    if (-not (Test-RahActiveConsent -Answer 'JA')) { throw 'SelfTest: JA consent rejected.' }
    if (Test-RahActiveConsent -Answer 'ja') { throw 'SelfTest: lowercase consent accepted.' }
    if (Test-RahActiveConsent -Answer 'YES') { throw 'SelfTest: non-JA consent accepted.' }

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('rah-active-runner-selftest-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    try {
        $fakeScript = Join-Path $tempRoot 'RAH-HOME-DISCOVERY-ACTIVE.ps1'
        @'
param([switch]$Start,[string]$OutputPath='')
$script:RahActiveDiscoveryVersion='1.0.0'
# mode = 'active-local-subnet'
# authorization = 'explicit-start-local-private-subnet'
# protocol = 'ICMP echo only'
'@ | Set-Content -LiteralPath $fakeScript -Encoding UTF8
        if (-not (Test-RahActiveDiscoveryScriptContract -Path $fakeScript)) {
            throw 'SelfTest: valid Active Discovery contract was rejected.'
        }

        $valid = Join-Path $tempRoot 'active.json'
        @{
            schema='rah-home-discovery-cache'; version=1; mode='active-local-subnet'; passive=$false;
            authorization='explicit-start-local-private-subnet'; scan=@{protocol='ICMP echo only'}; devices=@()
        } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $valid -Encoding UTF8
        $doc = Test-RahActiveDiscoveryOutput -Path $valid
        if ($doc.mode -ne 'active-local-subnet') { throw 'SelfTest: valid active JSON was rejected.' }

        Write-Host "RAH Active Discovery Runner $script:RahActiveRunnerVersion SelfTest OK" -ForegroundColor Green
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ($SelfTest) {
            Invoke-RahActiveRunnerSelfTest
        }
        else {
            Invoke-RahActiveDiscoveryRunner -RequestedOutputPath $OutputPath -RequestedDiscoveryScript $DiscoveryScriptPath -RequestedInterfaceIndex $InterfaceIndex -RequestedTimeoutMs $TimeoutMs -RequestedDelayMs $DelayMs -RequestedMaxHosts $MaxHosts -SkipOpen:$NoOpen | Out-Null
        }
    }
    catch {
        Write-Error "RAH Active Discovery Runner failed: $($_.Exception.Message)"
        exit 1
    }
}
