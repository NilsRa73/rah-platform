param(
    [ValidateSet('Leader','Worker')][string]$Mode = 'Leader',
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [string]$InstallRoot = '',
    [string]$DesktopPath = '',
    [string]$SourceDirectory = '',
    [string]$WorkerAddress = '',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahHomeInstallerVersion = '1.0.0'
$script:RahSourceBase = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
$script:RahNexusUrl = 'https://nilsra73.github.io/rah-platform/RAH-HOME-NEXUS.html'
$script:RahMaxComponentBytes = 4MB

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

function Get-RahComponentManifest {
    return @(
        [pscustomobject]@{ Name='RAH-HOME-NODE-AGENT.ps1'; Markers=@("RahNodeAgentVersion = '1.0.0'","RahProtocolVersion = 2","RahAllowedActions") },
        [pscustomobject]@{ Name='RAH-HOME-NODE-CLIENT.ps1'; Markers=@("RahNodeClientVersion = '1.0.0'","RahProtocolVersion = 2","RahMaxResponseBytes") },
        [pscustomobject]@{ Name='RAH-HOME-NODE-JOB.ps1'; Markers=@("RahNodeJobVersion = '1.0.0'","RahProtocolActions","JsonOnly") },
        [pscustomobject]@{ Name='RAH-HOME-CLUSTER-RUN.ps1'; Markers=@("RahClusterRunnerVersion = '1.0.0'","RahMaxRunnerOutputChars","RAH-HOME-NODE-JOB.ps1") },
        [pscustomobject]@{ Name='RAH-HOME-CLUSTER-CONTROLLER.ps1'; Markers=@("RahClusterControllerVersion = '1.0.0'","RahAllowedJobs","RahMaxNodes") },
        [pscustomobject]@{ Name='RAH-HOME-PAIR-WIZARD.ps1'; Markers=@("RahPairWizardVersion = '1.0.0'","RahProtocolVersion = 2","rah-home-pairing-receipt") },
        [pscustomobject]@{ Name='RAH-HOME-LAN-ACCEPTANCE.ps1'; Markers=@("RahLanAcceptanceVersion = '1.0.0'","rah-home-lan-acceptance","RAH-HOME-NODE-CLIENT.ps1") }
    )
}

function Assert-RahWritableDirectory {
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    New-Item -ItemType Directory -Path $full -Force | Out-Null
    $probe = Join-Path $full ('.rah-write-' + [Guid]::NewGuid().ToString('N') + '.tmp')
    try {
        [IO.File]::WriteAllText($probe,'ok',(New-Object Text.UTF8Encoding($false)))
        Remove-Item -LiteralPath $probe -Force
        return $full
    }
    catch {
        if (Test-Path -LiteralPath $probe) { Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue }
        throw "Mappen er ikke skrivbar: $full"
    }
}

function Resolve-RahInstallRoot {
    param([string]$Requested)
    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        return Assert-RahWritableDirectory -Path $Requested
    }

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:SystemDrive)) { $candidates += (Join-Path $env:SystemDrive 'RAH\Home') }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { $candidates += (Join-Path $env:LOCALAPPDATA 'RAH\Home') }
    foreach ($candidate in $candidates) {
        try { return Assert-RahWritableDirectory -Path $candidate } catch { }
    }
    throw 'Fant ingen skrivbar installasjonsmappe for RAH Home.'
}

function Resolve-RahDesktopPath {
    param([string]$Requested)
    $path = $Requested
    if ([string]::IsNullOrWhiteSpace($path)) { $path = [Environment]::GetFolderPath('Desktop') }
    if ([string]::IsNullOrWhiteSpace($path)) { throw 'Fant ikke skrivebordsmappen.' }
    return Assert-RahWritableDirectory -Path $path
}

function Assert-RahPowerShellFile {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)]$ManifestItem)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Mangler komponent: $($ManifestItem.Name)" }
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -le 0 -or $item.Length -gt $script:RahMaxComponentBytes) { throw "Ugyldig komponentstørrelse: $($ManifestItem.Name)" }
    if ([IO.Path]::GetFileName($item.FullName) -cne $ManifestItem.Name) { throw "Uventet komponentnavn: $($ManifestItem.Name)" }

    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($item.FullName,[ref]$tokens,[ref]$parseErrors) | Out-Null
    if (@($parseErrors).Count -ne 0) { throw "PowerShell-parser avviste $($ManifestItem.Name): $($parseErrors[0].Message)" }

    $text = [IO.File]::ReadAllText($item.FullName)
    foreach ($marker in @($ManifestItem.Markers)) {
        if (-not $text.Contains([string]$marker)) { throw "Komponentkontrakt mangler i $($ManifestItem.Name): $marker" }
    }
    return $true
}

function Get-RahPrivateLocalAddresses {
    if (-not (Get-Command Get-NetIPConfiguration -ErrorAction SilentlyContinue)) { return @() }
    $found = New-Object System.Collections.Generic.List[string]
    foreach ($cfg in @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter -and $_.NetAdapter.Status -eq 'Up' })) {
        foreach ($addr in @($cfg.IPv4Address)) {
            if ($null -eq $addr) { continue }
            $ip = [string]$addr.IPAddress
            if (Test-RahPrivateIPv4 -Address $ip) { [void]$found.Add($ip) }
        }
    }
    return @($found | Select-Object -Unique)
}

function Select-RahWorkerAddress {
    param([string]$Requested,[string[]]$Candidates)
    $privateCandidates = @($Candidates | Where-Object { $_ -and (Test-RahPrivateIPv4 -Address $_) } | Select-Object -Unique)
    if (-not [string]::IsNullOrWhiteSpace($Requested)) {
        $normalized = $Requested.Trim()
        if (-not (Test-RahPrivateIPv4 -Address $normalized)) { throw 'WorkerAddress må være en privat RFC1918 IPv4-adresse.' }
        if ($privateCandidates -notcontains $normalized) { throw 'WorkerAddress finnes ikke på en aktiv lokal adapter på denne PC-en.' }
        return $normalized
    }
    if ($privateCandidates.Count -eq 0) { throw 'Fant ingen aktiv privat IPv4-adresse. Koble PC-en til hjemmenettverket og kjør installasjonen igjen.' }
    if ($privateCandidates.Count -eq 1) { return $privateCandidates[0] }

    Write-Host 'Private adresser på denne PC-en:' -ForegroundColor Yellow
    for ($i=0; $i -lt $privateCandidates.Count; $i++) { Write-Host "[$($i+1)] $($privateCandidates[$i])" }
    $raw = Read-Host 'Velg adressen som tilhører RAH-hjemmenettverket'
    $choice = 0
    if (-not [int]::TryParse($raw,[ref]$choice) -or $choice -lt 1 -or $choice -gt $privateCandidates.Count) { throw 'Ugyldig adressevalg.' }
    return $privateCandidates[$choice-1]
}

function Copy-RahComponents {
    param([Parameter(Mandatory)][string]$TargetRoot,[string]$LocalSourceDirectory='')
    $manifest = @(Get-RahComponentManifest)
    $stage = Join-Path $TargetRoot ('.stage-' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    try {
        foreach ($entry in $manifest) {
            $stagePath = Join-Path $stage $entry.Name
            if (-not [string]::IsNullOrWhiteSpace($LocalSourceDirectory)) {
                $sourceRoot = [IO.Path]::GetFullPath($LocalSourceDirectory)
                $sourcePath = Join-Path $sourceRoot $entry.Name
                if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) { throw "SourceDirectory mangler $($entry.Name)." }
                Copy-Item -LiteralPath $sourcePath -Destination $stagePath -Force
            }
            else {
                $uri = "$script:RahSourceBase/$($entry.Name)"
                Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $stagePath -ErrorAction Stop
            }
            Assert-RahPowerShellFile -Path $stagePath -ManifestItem $entry | Out-Null
        }

        foreach ($entry in $manifest) {
            Copy-Item -LiteralPath (Join-Path $stage $entry.Name) -Destination (Join-Path $TargetRoot $entry.Name) -Force
        }
    }
    finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
    }
    return $manifest
}

function Write-RahAsciiFile {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Content)
    [IO.File]::WriteAllText($Path,$Content,[Text.Encoding]::ASCII)
}

function New-RahLeaderShortcuts {
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Desktop,[Parameter(Mandatory)][int]$TargetPort)
    $pair = Join-Path $Root 'RAH-HOME-PAIR-WIZARD.ps1'
    $controller = Join-Path $Root 'RAH-HOME-CLUSTER-CONTROLLER.ps1'
    $accept = Join-Path $Root 'RAH-HOME-LAN-ACCEPTANCE.ps1'

    $pairCmd = "@echo off`r`ntitle RAH Pair Worker`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$pair`" -Port $TargetPort`r`nset `"RAH_EXIT=%ERRORLEVEL%`"`r`npause`r`nexit /b %RAH_EXIT%`r`n"
    Write-RahAsciiFile -Path (Join-Path $Desktop 'RAH Pair Worker.cmd') -Content $pairCmd

    $clusterCmd = "@echo off`r`ntitle RAH Run Cluster Plan`r`necho Dra eller lim inn banen til rah-home-cluster-plan.json:`r`nset /p `"PLAN=Plan: `"`r`nif not defined PLAN exit /b 2`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$controller`" -PlanPath `"%PLAN%`"`r`nset `"RAH_EXIT=%ERRORLEVEL%`"`r`npause`r`nexit /b %RAH_EXIT%`r`n"
    Write-RahAsciiFile -Path (Join-Path $Desktop 'RAH Run Cluster Plan.cmd') -Content $clusterCmd

    $acceptCmd = "@echo off`r`ntitle RAH Test Worker LAN`r`necho Skriv Worker sin private IPv4-adresse:`r`nset /p `"WORKER=Worker IP: `"`r`nif not defined WORKER exit /b 2`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$accept`" -WorkerAddress `"%WORKER%`" -Port $TargetPort`r`nset `"RAH_EXIT=%ERRORLEVEL%`"`r`npause`r`nexit /b %RAH_EXIT%`r`n"
    Write-RahAsciiFile -Path (Join-Path $Desktop 'RAH Test Worker LAN.cmd') -Content $acceptCmd

    $url = "[InternetShortcut]`r`nURL=$script:RahNexusUrl`r`n"
    Write-RahAsciiFile -Path (Join-Path $Desktop 'RAH Home Nexus.url') -Content $url
}

function New-RahWorkerShortcut {
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Desktop,[Parameter(Mandatory)][string]$Address,[Parameter(Mandatory)][int]$TargetPort)
    if (-not (Test-RahPrivateIPv4 -Address $Address)) { throw 'Nekter å lage Worker-shortcut for ikke-privat adresse.' }
    $agent = Join-Path $Root 'RAH-HOME-NODE-AGENT.ps1'
    $cmd = "@echo off`r`ntitle RAH Home Worker - $Address`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$agent`" -ListenAddress $Address -AllowLan -Port $TargetPort`r`nset `"RAH_EXIT=%ERRORLEVEL%`"`r`necho.`r`nif not `"%RAH_EXIT%`"==`"0`" echo RAH Home Worker stoppet med feil %RAH_EXIT%.`r`npause`r`nexit /b %RAH_EXIT%`r`n"
    Write-RahAsciiFile -Path (Join-Path $Desktop 'RAH Home Worker.cmd') -Content $cmd
}

function Write-RahInstallState {
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$InstallMode,[string]$BoundAddress='')
    $state = [pscustomobject]@{
        schema = 'rah-home-install-state'
        version = 1
        installerVersion = $script:RahHomeInstallerVersion
        mode = $InstallMode
        installRoot = $Root
        workerAddress = if ([string]::IsNullOrWhiteSpace($BoundAddress)) { $null } else { $BoundAddress }
        port = $Port
        installedAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    $path = Join-Path $Root 'rah-home-install-state.json'
    $temp = "$path.tmp"
    [IO.File]::WriteAllText($temp,($state | ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
    Move-Item -LiteralPath $temp -Destination $path -Force
    return $path
}

function Invoke-RahInstallerSelfTest {
    foreach ($good in @('10.1.2.3','172.16.4.9','192.168.1.50')) {
        if (-not (Test-RahPrivateIPv4 -Address $good)) { throw "SelfTest: privat IP avvist: $good" }
    }
    foreach ($bad in @('127.0.0.1','8.8.8.8','192.168.001.5','0.0.0.0')) {
        if (Test-RahPrivateIPv4 -Address $bad) { throw "SelfTest: ikke-RFC1918 IP tillatt: $bad" }
    }
    $selected = Select-RahWorkerAddress -Requested '192.168.1.50' -Candidates @('10.0.0.2','192.168.1.50')
    if ($selected -ne '192.168.1.50') { throw 'SelfTest: eksplisitt WorkerAddress ble ikke valgt.' }
    $manifest = @(Get-RahComponentManifest)
    if ($manifest.Count -ne 7 -or @($manifest.Name | Select-Object -Unique).Count -ne 7) { throw 'SelfTest: komponentmanifest er ugyldig.' }
    if ($script:RahSourceBase -ne 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main') { throw 'SelfTest: uventet kildebase.' }
    Write-Host "RAH Home Unified Installer $script:RahHomeInstallerVersion SelfTest OK" -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-RahInstallerSelfTest
    return
}

$root = Resolve-RahInstallRoot -Requested $InstallRoot
$desktop = Resolve-RahDesktopPath -Requested $DesktopPath
$sourceRoot = $SourceDirectory
if (-not [string]::IsNullOrWhiteSpace($sourceRoot)) { $sourceRoot = [IO.Path]::GetFullPath($sourceRoot) }

Write-Host "RAH HOME UNIFIED INSTALLER v$script:RahHomeInstallerVersion" -ForegroundColor Yellow
Write-Host "Mode: $Mode"
Write-Host "Målmappe: $root"

$installedManifest = @(Copy-RahComponents -TargetRoot $root -LocalSourceDirectory $sourceRoot)
if ($PSCommandPath -and (Test-Path -LiteralPath $PSCommandPath -PathType Leaf)) {
    $selfDestination = Join-Path $root 'RAH-HOME-INSTALL.ps1'
    if ([IO.Path]::GetFullPath($PSCommandPath) -ine [IO.Path]::GetFullPath($selfDestination)) { Copy-Item -LiteralPath $PSCommandPath -Destination $selfDestination -Force }
}

$boundAddress = ''
if ($Mode -eq 'Worker') {
    $boundAddress = Select-RahWorkerAddress -Requested $WorkerAddress -Candidates @(Get-RahPrivateLocalAddresses)
    New-RahWorkerShortcut -Root $root -Desktop $desktop -Address $boundAddress -TargetPort $Port
    Write-Host 'WORKER READY' -ForegroundColor Green
    Write-Host "Bundet eksplisitt til $boundAddress`:$Port"
    Write-Host 'Start RAH Home Worker.cmd fra skrivebordet. Pair code vises i vinduet.'
}
else {
    New-RahLeaderShortcuts -Root $root -Desktop $desktop -TargetPort $Port
    Write-Host 'LEADER READY' -ForegroundColor Green
    Write-Host 'Skrivebord: RAH Home Nexus + RAH Pair Worker + RAH Run Cluster Plan + RAH Test Worker LAN.'
}

$statePath = Write-RahInstallState -Root $root -InstallMode $Mode -BoundAddress $boundAddress
Write-Host "Installert og validert: $($installedManifest.Count) komponenter i $root"
Write-Host "Install state: $statePath"
Write-Host 'Ingen wildcard-binding eller vilkårlig fjern-shell. LAN, pairing og cluster-plan må godkjennes eksplisitt.'
