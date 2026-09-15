param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-PrivateIPv4 {
    param([string]$Address)
    $p = $Address.Split('.')
    if ($p.Count -ne 4) { return $false }
    $n = @()
    foreach ($part in $p) {
        if ($part -notmatch '^\d{1,3}$') { return $false }
        $v = [int]$part
        if ($v -lt 0 -or $v -gt 255 -or [string]$v -ne $part) { return $false }
        $n += $v
    }
    return ($n[0] -eq 10 -or ($n[0] -eq 172 -and $n[1] -ge 16 -and $n[1] -le 31) -or ($n[0] -eq 192 -and $n[1] -eq 168))
}

function Assert-Parse {
    param([string]$Path)
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors) | Out-Null
    if (@($errors).Count -ne 0) { throw "Parser failure in $Path : $($errors[0].Message)" }
}

function Invoke-CheckedPowerShell {
    param([string[]]$CommandArgs)
    $exe = Join-Path $PSHOME 'powershell.exe'
    $old = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $exe @CommandArgs
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $old }
    if ($code -ne 0) { throw "Child PowerShell failed with exit code $code: $($CommandArgs -join ' ')" }
}

$repo = [IO.Path]::GetFullPath($RepoRoot)
$installer = Join-Path $repo 'RAH-HOME-INSTALL.ps1'
$acceptance = Join-Path $repo 'RAH-HOME-LAN-ACCEPTANCE.ps1'
Assert-Parse $installer
Assert-Parse $acceptance

Invoke-CheckedPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$installer,'-SelfTest')
Invoke-CheckedPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$acceptance,'-SelfTest')

$temp = Join-Path $env:TEMP ('rah-home-install-v1-' + [Guid]::NewGuid().ToString('N'))
$leaderRoot = Join-Path $temp 'leader-root'
$leaderDesktop = Join-Path $temp 'leader-desktop'
$workerRoot = Join-Path $temp 'worker-root'
$workerDesktop = Join-Path $temp 'worker-desktop'

$components = @(
    'RAH-HOME-NODE-AGENT.ps1',
    'RAH-HOME-NODE-CLIENT.ps1',
    'RAH-HOME-NODE-JOB.ps1',
    'RAH-HOME-CLUSTER-RUN.ps1',
    'RAH-HOME-CLUSTER-CONTROLLER.ps1',
    'RAH-HOME-PAIR-WIZARD.ps1',
    'RAH-HOME-LAN-ACCEPTANCE.ps1'
)

try {
    Invoke-CheckedPowerShell @(
        '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$installer,
        '-Mode','Leader','-InstallRoot',$leaderRoot,'-DesktopPath',$leaderDesktop,'-SourceDirectory',$repo
    )

    foreach ($name in $components) {
        $path = Join-Path $leaderRoot $name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Leader install missing $name" }
        Assert-Parse $path
    }
    if (-not (Test-Path -LiteralPath (Join-Path $leaderRoot 'RAH-HOME-INSTALL.ps1') -PathType Leaf)) { throw 'Leader install did not retain installer.' }

    foreach ($name in @('RAH Pair Worker.cmd','RAH Run Cluster Plan.cmd','RAH Test Worker LAN.cmd','RAH Home Nexus.url')) {
        if (-not (Test-Path -LiteralPath (Join-Path $leaderDesktop $name) -PathType Leaf)) { throw "Leader shortcut missing: $name" }
    }
    $leaderState = Get-Content -Raw -LiteralPath (Join-Path $leaderRoot 'rah-home-install-state.json') | ConvertFrom-Json
    if ($leaderState.schema -ne 'rah-home-install-state' -or $leaderState.version -ne 1 -or $leaderState.mode -ne 'Leader' -or [int]$leaderState.port -ne 18766) { throw 'Leader install state contract failed.' }
    $pairCmd = Get-Content -Raw -LiteralPath (Join-Path $leaderDesktop 'RAH Pair Worker.cmd')
    if ($pairCmd -notmatch 'RAH-HOME-PAIR-WIZARD\.ps1' -or $pairCmd -notmatch '-Port 18766') { throw 'Leader pair shortcut contract failed.' }
    $clusterCmd = Get-Content -Raw -LiteralPath (Join-Path $leaderDesktop 'RAH Run Cluster Plan.cmd')
    if ($clusterCmd -notmatch 'RAH-HOME-CLUSTER-CONTROLLER\.ps1' -or $clusterCmd -notmatch '-PlanPath') { throw 'Leader cluster shortcut contract failed.' }
    $nexusUrl = Get-Content -Raw -LiteralPath (Join-Path $leaderDesktop 'RAH Home Nexus.url')
    if ($nexusUrl -notmatch 'https://nilsra73\.github\.io/rah-platform/RAH-HOME-NEXUS\.html') { throw 'Nexus shortcut contract failed.' }

    Invoke-CheckedPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $leaderRoot 'RAH-HOME-LAN-ACCEPTANCE.ps1'),'-SelfTest')

    $candidate = $null
    if (Get-Command Get-NetIPConfiguration -ErrorAction SilentlyContinue) {
        foreach ($cfg in @(Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.NetAdapter -and $_.NetAdapter.Status -eq 'Up' })) {
            foreach ($addr in @($cfg.IPv4Address)) {
                if ($addr -and (Test-PrivateIPv4 ([string]$addr.IPAddress))) { $candidate = [string]$addr.IPAddress; break }
            }
            if ($candidate) { break }
        }
    }

    if ($candidate) {
        Invoke-CheckedPowerShell @(
            '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$installer,
            '-Mode','Worker','-Port','18766','-InstallRoot',$workerRoot,'-DesktopPath',$workerDesktop,
            '-SourceDirectory',$repo,'-WorkerAddress',$candidate
        )
        $workerCmdPath = Join-Path $workerDesktop 'RAH Home Worker.cmd'
        if (-not (Test-Path -LiteralPath $workerCmdPath -PathType Leaf)) { throw 'Worker shortcut missing.' }
        $workerCmd = Get-Content -Raw -LiteralPath $workerCmdPath
        if ($workerCmd -notmatch [regex]::Escape("-ListenAddress $candidate -AllowLan -Port 18766")) { throw 'Worker shortcut is not bound to selected private address.' }
        if ($workerCmd -match '0\.0\.0\.0') { throw 'Worker shortcut contains wildcard bind.' }
        $workerState = Get-Content -Raw -LiteralPath (Join-Path $workerRoot 'rah-home-install-state.json') | ConvertFrom-Json
        if ($workerState.mode -ne 'Worker' -or $workerState.workerAddress -ne $candidate) { throw 'Worker install state contract failed.' }
        Write-Host "PASS: Worker staging install bound to $candidate" -ForegroundColor Green
    }
    else {
        Write-Host 'INFO: no active RFC1918 adapter on runner; Worker live-bind staging was skipped after SelfTest/static contract.' -ForegroundColor Yellow
    }

    Write-Host 'PASS: RAH Home Unified Installer v1 Windows staging runtime' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
