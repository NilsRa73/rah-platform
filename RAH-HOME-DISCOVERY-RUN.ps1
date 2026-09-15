param(
    [string]$OutputPath = '',
    [string]$DiscoveryScriptPath = '',
    [switch]$NoOpen,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahRunnerVersion = '1.0.0'
$script:RahDiscoveryUrl = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-DISCOVERY.ps1'
$script:RahInboxUrl = 'https://nilsra73.github.io/rah-platform/RAH-HOME-DISCOVERY-INBOX.html'

function Get-RahRunnerRoot {
    if ($PSScriptRoot) { return $PSScriptRoot }
    return (Split-Path -Parent $MyInvocation.MyCommand.Path)
}

function Get-RahDefaultOutputPath {
    $downloads = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads'
    if (-not (Test-Path -LiteralPath $downloads)) {
        New-Item -ItemType Directory -Path $downloads -Force | Out-Null
    }
    return (Join-Path $downloads 'rah-home-discovery.json')
}

function Test-RahDiscoveryScriptContract {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $false }

    try {
        $text = [System.IO.File]::ReadAllText([System.IO.Path]::GetFullPath($Path))
    }
    catch {
        return $false
    }

    $required = @(
        "rah-home-discovery-cache",
        "passive-neighbor-cache",
        "Invoke-RahHomeDiscovery",
        "Get-NetNeighbor -AddressFamily IPv4"
    )

    foreach ($needle in $required) {
        if ($text.IndexOf($needle, [System.StringComparison]::OrdinalIgnoreCase) -lt 0) {
            return $false
        }
    }

    return $true
}

function Get-RahPreferredInstallDirectory {
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
        Write-Warning "Kunne ikke bruke C:\RAH\Home. Bruker $fallback i stedet."
        return $fallback
    }
}

function Install-RahDiscoveryScript {
    param([string]$DestinationDirectory = '')

    if (-not $DestinationDirectory) {
        $DestinationDirectory = Get-RahPreferredInstallDirectory
    }

    if (-not (Test-Path -LiteralPath $DestinationDirectory)) {
        New-Item -ItemType Directory -Path $DestinationDirectory -Force | Out-Null
    }

    $destination = Join-Path $DestinationDirectory 'RAH-HOME-DISCOVERY.ps1'
    $temp = "$destination.download"

    Write-Host 'RAH Discovery mangler lokalt. Henter stable versjon fra GitHub...' -ForegroundColor Yellow
    try {
        Invoke-WebRequest -Uri $script:RahDiscoveryUrl -OutFile $temp -UseBasicParsing -ErrorAction Stop
        if (-not (Test-RahDiscoveryScriptContract -Path $temp)) {
            throw 'Nedlastet discovery-script bestod ikke RAH-kontraktkontrollen.'
        }
        Move-Item -LiteralPath $temp -Destination $destination -Force
        Write-Host "Installert: $destination" -ForegroundColor Green
        return $destination
    }
    catch {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        throw "Kunne ikke hente RAH Home Discovery: $($_.Exception.Message)"
    }
}

function Resolve-RahDiscoveryScript {
    param([string]$RequestedPath = '')

    if ($RequestedPath) {
        $resolved = [System.IO.Path]::GetFullPath($RequestedPath)
        if (-not (Test-RahDiscoveryScriptContract -Path $resolved)) {
            throw "Discovery-scriptet er ugyldig eller inkompatibelt: $resolved"
        }
        return $resolved
    }

    $candidates = @(
        (Join-Path (Get-RahRunnerRoot) 'RAH-HOME-DISCOVERY.ps1'),
        'C:\RAH\Home\RAH-HOME-DISCOVERY.ps1'
    )

    if ($env:LOCALAPPDATA) {
        $candidates += (Join-Path $env:LOCALAPPDATA 'RAH\Home\RAH-HOME-DISCOVERY.ps1')
    }

    foreach ($candidate in $candidates | Select-Object -Unique) {
        if (Test-RahDiscoveryScriptContract -Path $candidate) {
            return [System.IO.Path]::GetFullPath($candidate)
        }
    }

    return (Install-RahDiscoveryScript)
}

function Test-RahDiscoveryOutput {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Discovery-resultatet ble ikke opprettet: $Path"
    }

    try {
        $doc = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        throw "Discovery-resultatet er ikke gyldig JSON: $($_.Exception.Message)"
    }

    if ($doc.schema -ne 'rah-home-discovery-cache' -or
        [int]$doc.version -ne 1 -or
        $doc.mode -ne 'passive-neighbor-cache' -or
        $doc.passive -ne $true -or
        $null -eq $doc.devices) {
        throw 'Discovery-resultatet bestod ikke RAH v1-kontraktkontrollen.'
    }

    return $doc
}

function Invoke-RahHomeDiscoveryRunner {
    param(
        [string]$RequestedOutputPath = '',
        [string]$RequestedDiscoveryScript = '',
        [switch]$SkipOpen
    )

    $discoveryScript = Resolve-RahDiscoveryScript -RequestedPath $RequestedDiscoveryScript
    $output = if ($RequestedOutputPath) {
        [System.IO.Path]::GetFullPath($RequestedOutputPath)
    }
    else {
        Get-RahDefaultOutputPath
    }

    $outputDirectory = Split-Path -Parent $output
    if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }

    Write-Host "Kjører: $discoveryScript" -ForegroundColor DarkGray
    & $discoveryScript -OutputPath $output

    $doc = Test-RahDiscoveryOutput -Path $output

    Write-Host ''
    Write-Host "RAH Home Discovery Runner $script:RahRunnerVersion er ferdig." -ForegroundColor Yellow
    Write-Host "JSON-fil: $output"
    Write-Host "Kandidater: $(@($doc.devices).Count)"

    if (-not $SkipOpen) {
        Write-Host 'Inbox åpnes i nettleseren. Godkjenn bare enhetene du kjenner igjen.'
        Start-Process $script:RahInboxUrl
        Start-Process explorer.exe "/select,`"$output`""
    }

    return [pscustomobject]@{
        runnerVersion = $script:RahRunnerVersion
        discoveryScript = $discoveryScript
        outputPath = $output
        candidateCount = @($doc.devices).Count
        openedUi = -not [bool]$SkipOpen
    }
}

function Invoke-RahRunnerSelfTest {
    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("rah-runner-selftest-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    try {
        $fakeScript = Join-Path $tempRoot 'RAH-HOME-DISCOVERY.ps1'
        @'
param([string]$OutputPath='')
function Invoke-RahHomeDiscovery {}
# Get-NetNeighbor -AddressFamily IPv4
# rah-home-discovery-cache
# passive-neighbor-cache
$doc = [ordered]@{schema='rah-home-discovery-cache';version=1;mode='passive-neighbor-cache';passive=$true;devices=@()}
$doc | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
'@ | Set-Content -LiteralPath $fakeScript -Encoding UTF8

        if (-not (Test-RahDiscoveryScriptContract -Path $fakeScript)) {
            throw 'SelfTest feilet: gyldig mock discovery ble avvist.'
        }

        $output = Join-Path $tempRoot 'result.json'
        $result = Invoke-RahHomeDiscoveryRunner -RequestedOutputPath $output -RequestedDiscoveryScript $fakeScript -SkipOpen
        if (-not (Test-Path -LiteralPath $output)) { throw 'SelfTest feilet: output mangler.' }
        if ($result.candidateCount -ne 0) { throw 'SelfTest feilet: feil kandidatantall.' }
        if ($result.openedUi) { throw 'SelfTest feilet: UI skulle ikke åpnes.' }

        Write-Host "RAH Home Discovery Runner $script:RahRunnerVersion SelfTest OK" -ForegroundColor Green
    }
    finally {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ($SelfTest) {
            Invoke-RahRunnerSelfTest
        }
        else {
            Invoke-RahHomeDiscoveryRunner -RequestedOutputPath $OutputPath -RequestedDiscoveryScript $DiscoveryScriptPath -SkipOpen:$NoOpen | Out-Null
        }
    }
    catch {
        Write-Error "RAH Home Discovery Runner feilet: $($_.Exception.Message)"
        exit 1
    }
}
