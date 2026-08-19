param([string]$ArchivePath = "")

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $AppDir)
$ManifestPath = Join-Path $RepoRoot "RAH-RAVEN-DAILY-DRIVER-VERSION.json"
$Desktop = [Environment]::GetFolderPath("Desktop")
$EvidenceDir = Join-Path $Desktop "RAH Daily Driver Evidence"
$RuntimeOut = Join-Path $EvidenceDir "runtime-gate.json"
$LmOut = Join-Path $EvidenceDir "owned-machine-lm-acceptance.json"
$SummaryOut = Join-Path $EvidenceDir "FINAL_GATE_SUMMARY.json"

function Find-Python {
    $Venv = Join-Path $AppDir ".venv\Scripts\python.exe"
    if (Test-Path -LiteralPath $Venv -PathType Leaf) { return $Venv }

    if (Get-Command py.exe -ErrorAction SilentlyContinue) { return "py.exe" }
    if (Get-Command python.exe -ErrorAction SilentlyContinue) { return "python.exe" }

    $Patterns = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Python\Python*\python.exe"),
        (Join-Path $env:LOCALAPPDATA "Python\pythoncore-*\python.exe"),
        (Join-Path $env:ProgramFiles "Python*\python.exe")
    )
    foreach ($Pattern in $Patterns) {
        $Hit = Get-ChildItem -Path $Pattern -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($Hit) { return $Hit.FullName }
    }
    return $null
}

function Choose-Archive {
    Add-Type -AssemblyName System.Windows.Forms
    $Dialog = New-Object System.Windows.Forms.OpenFileDialog
    $Dialog.Title = "Select your own Facebook archive ZIP for the Daily Driver runtime gate"
    $Dialog.Filter = "ZIP archive (*.zip)|*.zip|All files (*.*)|*.*"
    $Dialog.Multiselect = $false
    if ($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $Dialog.FileName
    }
    return ""
}

function Run-Python([string]$Python, [string[]]$ArgList) {
    Push-Location $AppDir
    try {
        if ($Python -eq "py.exe") {
            & py.exe -3 @ArgList
        } else {
            & $Python @ArgList
        }
        return $LASTEXITCODE
    } finally {
        Pop-Location
    }
}

Write-Host ""
Write-Host "RAH Raven Daily Driver 1.0 - Final Windows Gate" -ForegroundColor Yellow
Write-Host "=================================================" -ForegroundColor DarkYellow
Write-Host "Stable promotion: BLOCKED" -ForegroundColor Yellow
Write-Host ""

if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Write-Host "ERROR: Daily Driver version manifest was not found." -ForegroundColor Red
    exit 10
}

$Manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Manifest.product -ne "RAH Raven Daily Driver" -or
    $Manifest.version -ne "1.0.0" -or
    $Manifest.stage -ne "candidate" -or
    $Manifest.authority_delta -ne "none") {
    Write-Host "ERROR: Expected Daily Driver 1.0.0 Candidate with authority_delta=none." -ForegroundColor Red
    exit 11
}

$Python = Find-Python
if (-not $Python) {
    Write-Host "ERROR: Python 3 was not found." -ForegroundColor Red
    exit 12
}

New-Item -ItemType Directory -Path $EvidenceDir -Force | Out-Null

if ([string]::IsNullOrWhiteSpace($ArchivePath)) {
    $ArchivePath = Choose-Archive
}
$ArchiveSelected = -not [string]::IsNullOrWhiteSpace($ArchivePath)
$ArchiveExists = $ArchiveSelected -and (Test-Path -LiteralPath $ArchivePath)

Write-Host "[1/3] Runtime gate" -ForegroundColor Yellow
if ($ArchiveExists) {
    $RuntimeRc = Run-Python $Python @("runtime_check.py", "--facebook", $ArchivePath, "--output", $RuntimeOut)
} else {
    Write-Host "No archive selected. The real archive check will remain PENDING." -ForegroundColor DarkYellow
    $RuntimeRc = Run-Python $Python @("runtime_check.py", "--output", $RuntimeOut)
}

Write-Host ""
Write-Host "[2/3] Local LM Studio owned-machine acceptance" -ForegroundColor Yellow
$LmRc = Run-Python $Python @("owned_machine_acceptance.py", "--output", $LmOut)

Write-Host ""
Write-Host "[3/3] Desktop shortcut install and visual launch confirmation" -ForegroundColor Yellow
$Installer = Join-Path $AppDir "install_windows.ps1"
$Shortcut = Join-Path $Desktop "RAH Raven Daily Driver.lnk"
$ShortcutExists = $false
$ShortcutTargetValid = $false
$ShortcutLaunchConfirmed = $false

if (Test-Path -LiteralPath $Installer -PathType Leaf) {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Installer
    $ShortcutExists = Test-Path -LiteralPath $Shortcut -PathType Leaf
}

if ($ShortcutExists) {
    try {
        $Wsh = New-Object -ComObject WScript.Shell
        $Sc = $Wsh.CreateShortcut($Shortcut)
        $ShortcutTargetValid = Test-Path -LiteralPath $Sc.TargetPath -PathType Leaf
    } catch {
        $ShortcutTargetValid = $false
    }
}

if ($ShortcutExists -and $ShortcutTargetValid) {
    Start-Process -FilePath $Shortcut
    Start-Sleep -Seconds 2
    $Answer = Read-Host "Did RAH Raven Daily Driver open normally? Type YES only if you actually saw the window"
    $ShortcutLaunchConfirmed = ($Answer.Trim().ToUpperInvariant() -eq "YES")
}

$RuntimeData = $null
$LmData = $null
if (Test-Path -LiteralPath $RuntimeOut -PathType Leaf) {
    try { $RuntimeData = Get-Content -LiteralPath $RuntimeOut -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}
if (Test-Path -LiteralPath $LmOut -PathType Leaf) {
    try { $LmData = Get-Content -LiteralPath $LmOut -Raw -Encoding UTF8 | ConvertFrom-Json } catch {}
}

$RuntimePass = $false
if ($RuntimeData) { $RuntimePass = ($RuntimeData.overall -eq "PASS") }

$LmPass = $false
if ($LmData) {
    $LmPass = ($LmData.status -eq "PASS" -and $LmData.stablePromotion -eq "BLOCKED")
}

$ReadyForOwnedToolReview = (
    $RuntimePass -and
    $LmPass -and
    $ShortcutExists -and
    $ShortcutTargetValid -and
    $ShortcutLaunchConfirmed
)

$Summary = [ordered]@{
    schemaVersion = 1
    product = "RAH Raven Daily Driver"
    candidateVersion = "1.0.0"
    generatedAt = (Get-Date).ToUniversalTime().ToString("o")
    authorityDelta = "none"
    stablePromotion = "BLOCKED"
    automaticStablePromotion = $false
    machineEvidence = [ordered]@{
        archiveSelected = [bool]$ArchiveExists
        archivePathPersisted = $false
        runtimeGatePass = [bool]$RuntimePass
        runtimeGateExitCode = [int]$RuntimeRc
        lmStudioAcceptancePass = [bool]$LmPass
        lmStudioExitCode = [int]$LmRc
        lmAnswerTextPersisted = $false
        desktopShortcutExists = [bool]$ShortcutExists
        desktopShortcutTargetValid = [bool]$ShortcutTargetValid
        desktopShortcutLaunchUserConfirmed = [bool]$ShortcutLaunchConfirmed
    }
    remainingOwnedReviews = @(
        "Sherlock owned CSV export review",
        "PhoneInfoga owned TXT/JSON export review",
        "SpiderFoot passive owned JSON/CSV export review"
    )
    readyForFinalOwnedToolReview = [bool]$ReadyForOwnedToolReview
}

$Summary | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $SummaryOut -Encoding UTF8

$ReadmeOut = Join-Path $EvidenceDir "READ_ME_RESULT.txt"
@"
RAH Raven Daily Driver 1.0 - Windows Evidence

Runtime gate PASS: $RuntimePass
LM Studio owned-machine acceptance PASS: $LmPass
Desktop shortcut exists: $ShortcutExists
Desktop shortcut target valid: $ShortcutTargetValid
Shortcut launch user-confirmed: $ShortcutLaunchConfirmed

Ready for final owned-tool review: $ReadyForOwnedToolReview

Still deliberately pending after this gate:
- Sherlock owned CSV export review
- PhoneInfoga owned TXT/JSON export review
- SpiderFoot passive owned JSON/CSV export review

Stable promotion remains BLOCKED.
No Stable files were changed and no Stable promotion was performed.
The Facebook archive path and LM model answer text are not persisted in this summary.
"@ | Set-Content -LiteralPath $ReadmeOut -Encoding UTF8

Write-Host ""
Write-Host "=================================================" -ForegroundColor DarkYellow
Write-Host "FINAL WINDOWS GATE RESULT" -ForegroundColor Yellow
Write-Host "=================================================" -ForegroundColor DarkYellow
Write-Host "Runtime gate PASS: $RuntimePass"
Write-Host "LM Studio PASS: $LmPass"
Write-Host "Shortcut launch PASS: $ShortcutLaunchConfirmed"
Write-Host "Ready for final owned-tool review: $ReadyForOwnedToolReview"
Write-Host "Evidence: $EvidenceDir" -ForegroundColor Cyan
Write-Host "Stable promotion: BLOCKED" -ForegroundColor Yellow

Start-Process explorer.exe $EvidenceDir

if ($ReadyForOwnedToolReview) { exit 0 }
exit 2
