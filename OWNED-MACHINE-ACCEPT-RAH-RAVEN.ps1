param(
    [string]$FacebookArchive,
    [switch]$NonInteractive
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$App = Join-Path $Root 'apps\rah-raven-daily-driver'
$RuntimeRunner = Join-Path $Root 'TEST-RAH-RAVEN-RUNTIME.bat'
$LmAcceptance = Join-Path $App 'owned_machine_acceptance.py'
$StateDir = Join-Path $App 'runtime\state'
$LmSummary = Join-Path $StateDir 'owned-machine-lm-acceptance.json'
$FinalSummary = Join-Path $StateDir 'owned-machine-acceptance.json'
$StableGate = Join-Path $Root 'STABLE-GATE.md'

function Require-File([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label was not found: $Path"
    }
}

function Confirm-ActuallyCompleted([string]$Prompt) {
    if ($NonInteractive) { return $false }
    $value = Read-Host "$Prompt Type YES only if this is actually completed"
    return $value.Trim().ToUpperInvariant() -eq 'YES'
}

function Select-OwnedArchive {
    if ($NonInteractive) {
        throw 'NonInteractive mode requires -FacebookArchive with an explicit owned path.'
    }
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = 'Select your own Facebook/archive ZIP for RAH Raven Runtime Gate'
    $dialog.Filter = 'ZIP archives (*.zip)|*.zip|All files (*.*)|*.*'
    $dialog.Multiselect = $false
    if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        throw 'No archive selected. Acceptance remains incomplete.'
    }
    return $dialog.FileName
}

Require-File $RuntimeRunner 'Runtime Acceptance runner'
Require-File $LmAcceptance 'LM Studio acceptance helper'
Require-File $StableGate 'Stable Gate document'

$Python = Join-Path $App '.venv\Scripts\python.exe'
if (-not (Test-Path -LiteralPath $Python -PathType Leaf)) {
    $PythonCommand = Get-Command python -ErrorAction SilentlyContinue
    if (-not $PythonCommand) {
        throw 'Daily Driver venv is missing and Python was not found. Run INSTALL-RAH-RAVEN.bat first.'
    }
    $Python = $PythonCommand.Source
}

New-Item -ItemType Directory -Path $StateDir -Force | Out-Null

Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'RAH RAVEN - OWNED WINDOWS MACHINE ACCEPTANCE' -ForegroundColor Yellow
Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'This runner never promotes Stable or Frozen.' -ForegroundColor Yellow
Write-Host 'Use only your own archive and representative tool exports.'
Write-Host ''

$Desktop = [Environment]::GetFolderPath('Desktop')
$ShortcutPath = Join-Path $Desktop 'RAH Raven Daily Driver.lnk'
Require-File $ShortcutPath 'Daily Driver desktop shortcut'
$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut($ShortcutPath)
$ExpectedTarget = [IO.Path]::GetFullPath((Join-Path $App 'START-RAH-RAVEN.bat'))
$ExpectedWork = [IO.Path]::GetFullPath($App).TrimEnd('\')
$ActualTarget = [IO.Path]::GetFullPath($Shortcut.TargetPath)
$ActualWork = [IO.Path]::GetFullPath($Shortcut.WorkingDirectory).TrimEnd('\')
if ($ActualTarget -ne $ExpectedTarget) { throw "Shortcut target mismatch: $ActualTarget" }
if ($ActualWork -ne $ExpectedWork) { throw "Shortcut working directory mismatch: $ActualWork" }
Write-Host '[PASS] Desktop shortcut target and working directory.' -ForegroundColor Green

$ShortcutInteractiveConfirmed = $false
if (-not $NonInteractive) {
    $launch = Read-Host 'Type YES to launch the verified Daily Driver shortcut now'
    if ($launch.Trim().ToUpperInvariant() -eq 'YES') {
        Start-Process -FilePath $ShortcutPath
        $ShortcutInteractiveConfirmed = Confirm-ActuallyCompleted 'Did Daily Driver open correctly from the desktop shortcut?'
    }
}

Write-Host ''
Write-Host 'Testing both configured local LM Studio Council roles...' -ForegroundColor Cyan
& $Python $LmAcceptance --output $LmSummary
if ($LASTEXITCODE -ne 0) {
    throw 'LM Studio role-response acceptance failed. Start LM Studio, load a model, and expose the local server on loopback only.'
}
$LmData = Get-Content -LiteralPath $LmSummary -Raw -Encoding UTF8 | ConvertFrom-Json
if ($LmData.status -ne 'PASS' -or $LmData.stablePromotion -ne 'BLOCKED' -or $LmData.answerTextPersisted -ne $false) {
    throw 'LM Studio acceptance summary violated the privacy/lifecycle contract.'
}
Write-Host '[PASS] Both local LM Studio roles returned non-empty answers; answer text was not persisted.' -ForegroundColor Green

if ([string]::IsNullOrWhiteSpace($FacebookArchive)) {
    $FacebookArchive = Select-OwnedArchive
}
if (-not (Test-Path -LiteralPath $FacebookArchive)) {
    throw 'Selected Facebook/archive path does not exist.'
}
$ResolvedArchive = (Resolve-Path -LiteralPath $FacebookArchive).Path
Write-Host '[INFO] Owned archive selected. Its path/content will not be copied into this acceptance summary.'

Write-Host ''
Write-Host 'Running the existing Runtime Gate + privacy-safe Evidence + validator...' -ForegroundColor Cyan
& $RuntimeRunner $ResolvedArchive
$RuntimeRc = $LASTEXITCODE
if ($RuntimeRc -ne 0) {
    throw "Runtime Acceptance did not reach ELIGIBLE review state (exit code $RuntimeRc). Stable remains blocked."
}
Write-Host '[PASS] Runtime evidence is ELIGIBLE for Runtime Test review.' -ForegroundColor Green

$SherlockReviewed = Confirm-ActuallyCompleted 'Have you imported and reviewed a representative OWNED Sherlock CSV in Daily Driver?'
$PhoneInfogaReviewed = Confirm-ActuallyCompleted 'Have you imported and reviewed a representative OWNED PhoneInfoga TXT/JSON result?'
$SpiderFootReviewed = Confirm-ActuallyCompleted 'Have you imported and reviewed a representative OWNED SpiderFoot PASSIVE JSON/CSV result?'

$EligibleForStableReview = (
    $ShortcutInteractiveConfirmed -and
    $SherlockReviewed -and
    $PhoneInfogaReviewed -and
    $SpiderFootReviewed
)

$Summary = [ordered]@{
    schemaVersion = 1
    product = 'RAH Raven Daily Driver'
    acceptance = 'owned-windows-machine'
    generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    machineEvidence = [ordered]@{
        desktopShortcutContract = 'PASS'
        desktopShortcutInteractiveConfirmed = $ShortcutInteractiveConfirmed
        lmStudioRoleResponses = 'PASS'
        lmStudioAnswerTextPersisted = $false
        realOwnedArchiveRuntimeGate = 'PASS'
        runtimeEvidenceEligibility = 'ELIGIBLE'
        archivePathPersisted = $false
        archiveContentsPersistedInAcceptanceSummary = $false
    }
    manualUiReview = [ordered]@{
        ownedSherlock = $SherlockReviewed
        ownedPhoneInfoga = $PhoneInfogaReviewed
        ownedSpiderFootPassive = $SpiderFootReviewed
    }
    eligibleForStableReview = $EligibleForStableReview
    stablePromotion = 'BLOCKED'
    stablePromotionAutomated = $false
    nextAction = $(if ($EligibleForStableReview) {
        'Manual Stable review may now inspect this summary plus privacy-safe Runtime Evidence. No automatic promotion is permitted.'
    } else {
        'Complete every explicit owned-machine/UI confirmation, then rerun this acceptance kit. Stable remains blocked.'
    })
}

$Summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $FinalSummary -Encoding UTF8

Write-Host ''
Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'RAH RAVEN - OWNED MACHINE ACCEPTANCE SUMMARY' -ForegroundColor Yellow
Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host "Summary                : $FinalSummary"
Write-Host "Eligible Stable review : $EligibleForStableReview"
Write-Host 'Stable promotion       : BLOCKED'
Write-Host 'Automatic promotion    : NO'
Write-Host ''
Write-Host 'See STABLE-GATE.md for the authoritative manual review boundary.'

if ($EligibleForStableReview) { exit 0 }
exit 2
