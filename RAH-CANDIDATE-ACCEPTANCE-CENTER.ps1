[CmdletBinding()]
param(
    [switch]$SelfTest,
    [ValidateSet('studio','daily-driver','investigator')]
    [string]$Target
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = $PSScriptRoot
$Targets = @(
    [pscustomobject]@{
        Id = 'studio'
        Label = 'RAH Raven Studio 2.9 Candidate'
        Launcher = 'ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.bat'
        Manifest = 'RAH-RAVEN-STUDIO-V2.9-CANDIDATE.json'
        ExpectedVersion = '2.9.0'
        ExpectedStage = 'candidate'
    },
    [pscustomobject]@{
        Id = 'daily-driver'
        Label = 'RAH Raven Daily Driver 1.0 Candidate'
        Launcher = 'ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat'
        Manifest = 'RAH-RAVEN-DAILY-DRIVER-VERSION.json'
        ExpectedVersion = '1.0.0'
        ExpectedStage = 'candidate'
    },
    [pscustomobject]@{
        Id = 'investigator'
        Label = 'RAH AI Investigator 1.0 RC2 Candidate'
        Launcher = 'apps/rah-ai-investigator/ACCEPT-RC2-OWNED-WINDOWS.bat'
        Manifest = 'apps/rah-ai-investigator/RAH-INVESTIGATOR-VERSION.json'
        ExpectedVersion = '1.0-RC2'
        ExpectedStage = 'candidate'
    }
)

function Resolve-RahPath {
    param([Parameter(Mandatory=$true)][string]$RelativePath)
    $native = $RelativePath -replace '/', [IO.Path]::DirectorySeparatorChar
    return Join-Path $Root $native
}

function Ensure-DailyDriverReady {
    $pythonPath = Resolve-RahPath 'apps/rah-raven-daily-driver/.venv/Scripts/python.exe'
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shortcutPath = Join-Path $desktop 'RAH Raven Daily Driver.lnk'

    if ((Test-Path -LiteralPath $pythonPath -PathType Leaf) -and
        (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
        return
    }

    $installer = Resolve-RahPath 'INSTALL-RAH-RAVEN.bat'
    if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
        throw "Daily Driver installer is missing: $installer"
    }

    Write-Host ''
    Write-Host 'Daily Driver is not installed yet. Running target-specific setup now.' -ForegroundColor Cyan
    Write-Host 'No other Candidate is installed or launched by this setup.' -ForegroundColor Yellow

    $previousNoStart = $env:RAH_RAVEN_INSTALL_NO_START
    $rc = 1
    try {
        $env:RAH_RAVEN_INSTALL_NO_START = '1'
        & $installer
        $rc = $LASTEXITCODE
    } finally {
        if ($null -eq $previousNoStart) {
            Remove-Item Env:RAH_RAVEN_INSTALL_NO_START -ErrorAction SilentlyContinue
        } else {
            $env:RAH_RAVEN_INSTALL_NO_START = $previousNoStart
        }
    }

    if ($rc -ne 0) {
        throw "Daily Driver installation failed with exit code $rc."
    }
    if (-not (Test-Path -LiteralPath $pythonPath -PathType Leaf)) {
        throw 'Daily Driver setup completed without the expected local Python runtime.'
    }
    if (-not (Test-Path -LiteralPath $shortcutPath -PathType Leaf)) {
        throw 'Daily Driver setup completed without the expected desktop shortcut.'
    }
}

function Get-TargetState {
    param([Parameter(Mandatory=$true)]$Definition)

    $launcherPath = Resolve-RahPath $Definition.Launcher
    $manifestPath = Resolve-RahPath $Definition.Manifest
    if (-not (Test-Path -LiteralPath $launcherPath -PathType Leaf)) {
        throw "Missing acceptance launcher: $($Definition.Launcher)"
    }
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Missing candidate manifest: $($Definition.Manifest)"
    }

    $manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$manifest.version -ne $Definition.ExpectedVersion) {
        throw "Version drift for $($Definition.Id): expected $($Definition.ExpectedVersion), got $($manifest.version)"
    }
    if ([string]$manifest.stage -ne $Definition.ExpectedStage) {
        throw "Stage drift for $($Definition.Id): expected $($Definition.ExpectedStage), got $($manifest.stage)"
    }

    $promotionBlocked = switch ($Definition.Id) {
        'studio' {
            ($manifest.promotion_policy.requires_owned_windows_runtime_test -eq $true) -and
            ($manifest.promotion_policy.stable_promotion_included -eq $false) -and
            ($manifest.promotion_policy.candidate_can_promote_itself -eq $false)
        }
        'daily-driver' {
            ([string]$manifest.stable_gate.status -eq 'not_passed') -and
            ($manifest.stable_gate.requires_windows_runtime -eq $true) -and
            ($manifest.security_boundary.runtime_acceptance_can_promote_stable -eq $false)
        }
        'investigator' {
            ($manifest.owned_windows_acceptance.can_only_mark_eligible_for_stable_review -eq $true) -and
            ($manifest.owned_windows_acceptance.can_promote_stable -eq $false) -and
            ($manifest.validation.stable_release_gate -eq $false)
        }
        default { $false }
    }

    if (-not $promotionBlocked) {
        throw "Stable-promotion boundary is no longer fail-closed for $($Definition.Id). Review required."
    }

    return [pscustomobject]@{
        Id = $Definition.Id
        Label = $Definition.Label
        Version = [string]$manifest.version
        Stage = [string]$manifest.stage
        Launcher = $launcherPath
        Promotion = 'BLOCKED'
        Ready = $true
    }
}

function Get-AllTargetStates {
    $states = @()
    foreach ($definition in $Targets) {
        $states += Get-TargetState $definition
    }
    return $states
}

function Invoke-TargetAcceptance {
    param([Parameter(Mandatory=$true)][string]$Id)
    $definition = $Targets | Where-Object { $_.Id -eq $Id } | Select-Object -First 1
    if (-not $definition) { throw "Unknown acceptance target: $Id" }
    $state = Get-TargetState $definition

    if ($Id -eq 'daily-driver') {
        Ensure-DailyDriverReady
    }

    Write-Host ''
    Write-Host "Starting: $($state.Label)" -ForegroundColor Cyan
    Write-Host 'Stable promotion remains BLOCKED. The child acceptance kit may only produce evidence for later manual review.' -ForegroundColor Yellow
    Write-Host ''

    & $state.Launcher
    return $LASTEXITCODE
}

if ($SelfTest) {
    try {
        $states = Get-AllTargetStates
        foreach ($state in $states) {
            Write-Host "PASS  $($state.Id)  version=$($state.Version) stage=$($state.Stage) promotion=$($state.Promotion)"
        }
        Write-Host 'PASS  Candidate Acceptance Center is fail-closed and launchers are present.'
        exit 0
    } catch {
        Write-Error $_
        exit 1
    }
}

if ($Target) {
    try {
        exit (Invoke-TargetAcceptance $Target)
    } catch {
        Write-Error $_
        exit 1
    }
}

try {
    $states = Get-AllTargetStates
} catch {
    Write-Error $_
    exit 1
}

while ($true) {
    Clear-Host
    Write-Host '==============================================================' -ForegroundColor DarkYellow
    Write-Host ' RAH CANDIDATE ACCEPTANCE CENTER' -ForegroundColor Yellow
    Write-Host '==============================================================' -ForegroundColor DarkYellow
    Write-Host 'Owned Windows acceptance only. Stable promotion is always BLOCKED.' -ForegroundColor Yellow
    Write-Host ''
    for ($i = 0; $i -lt $states.Count; $i++) {
        $s = $states[$i]
        Write-Host (" {0}) {1}  [{2} / {3}]" -f ($i + 1), $s.Label, $s.Stage, $s.Version)
    }
    Write-Host ' Q) Quit'
    Write-Host ''
    $choice = (Read-Host 'Choose acceptance kit').Trim()
    if ($choice -match '^[Qq]$') { exit 0 }

    $index = 0
    if ([int]::TryParse($choice, [ref]$index) -and $index -ge 1 -and $index -le $states.Count) {
        $selected = $states[$index - 1]
        try {
            $rc = Invoke-TargetAcceptance $selected.Id
            Write-Host ''
            Write-Host "Child acceptance exited with code $rc. Stable promotion remains BLOCKED." -ForegroundColor Yellow
        } catch {
            Write-Error $_
        }
        Write-Host ''
        Read-Host 'Press Enter to return to the Acceptance Center' | Out-Null
    }
}
