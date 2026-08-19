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
$OwnedToolReview = Join-Path $App 'FINAL-OWNED-TOOL-REVIEW.py'
$StateDir = Join-Path $App 'runtime\state'
$LmSummary = Join-Path $StateDir 'owned-machine-lm-acceptance.json'
$FinalSummary = Join-Path $StateDir 'owned-machine-acceptance.json'
$StableGate = Join-Path $Root 'STABLE-GATE.md'
$Desktop = [Environment]::GetFolderPath('Desktop')
$DesktopEvidenceDir = Join-Path $Desktop 'RAH Daily Driver Evidence'
$OwnedToolSummary = Join-Path $DesktopEvidenceDir 'OWNED_TOOL_REVIEW_SUMMARY.json'

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

function Find-Python {
    $Venv = Join-Path $App '.venv\Scripts\python.exe'
    if (Test-Path -LiteralPath $Venv -PathType Leaf) { return $Venv }

    $PythonCommand = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($PythonCommand) { return $PythonCommand.Source }

    $PyCommand = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($PyCommand) { return $PyCommand.Source }

    $Patterns = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Python\Python*\python.exe'),
        (Join-Path $env:LOCALAPPDATA 'Python\pythoncore-*\python.exe'),
        (Join-Path $env:ProgramFiles 'Python*\python.exe')
    )
    foreach ($Pattern in $Patterns) {
        $Hit = Get-ChildItem -Path $Pattern -ErrorAction SilentlyContinue |
            Sort-Object FullName -Descending |
            Select-Object -First 1
        if ($Hit) { return $Hit.FullName }
    }
    return $null
}

function Test-ToolReviewPass($Data, [string]$ToolId) {
    if (-not $Data) { return $false }
    $matches = @($Data.reviews | Where-Object { $_.tool -eq $ToolId })
    if ($matches.Count -ne 1) { return $false }
    return ($matches[0].status -eq 'PASS')
}

Require-File $RuntimeRunner 'Runtime Acceptance runner'
Require-File $LmAcceptance 'LM Studio acceptance helper'
Require-File $OwnedToolReview 'Owned-tool export review helper'
Require-File $StableGate 'Stable Gate document'

$Python = Find-Python
if (-not $Python) {
    throw 'Python 3 was not found. Run INSTALL-RAH-RAVEN.bat first or install Python 3.'
}

New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
New-Item -ItemType Directory -Path $DesktopEvidenceDir -Force | Out-Null

Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'RAH RAVEN - OWNED WINDOWS MACHINE ACCEPTANCE' -ForegroundColor Yellow
Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'This runner never promotes Stable or Frozen.' -ForegroundColor Yellow
Write-Host 'Use only your own archive and representative owned tool exports.'
Write-Host ''

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
Write-Host 'Testing configured local LM Studio Council roles...' -ForegroundColor Cyan
& $Python $LmAcceptance --output $LmSummary
if ($LASTEXITCODE -ne 0) {
    throw 'LM Studio role-response acceptance failed. Start LM Studio, load a model, and expose the local server on loopback only.'
}
$LmData = Get-Content -LiteralPath $LmSummary -Raw -Encoding UTF8 | ConvertFrom-Json
$LmPass = (
    $LmData.status -eq 'PASS' -and
    $LmData.stablePromotion -eq 'BLOCKED' -and
    $LmData.answerTextPersisted -eq $false
)
if (-not $LmPass) {
    throw 'LM Studio acceptance summary violated the privacy/lifecycle contract.'
}
Write-Host '[PASS] Local LM Studio roles returned non-empty answers; answer text was not persisted.' -ForegroundColor Green

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
$RuntimePass = ($RuntimeRc -eq 0)
if (-not $RuntimePass) {
    throw "Runtime Acceptance did not reach ELIGIBLE review state (exit code $RuntimeRc). Stable remains blocked."
}
Write-Host '[PASS] Runtime evidence is ELIGIBLE for Runtime Test review.' -ForegroundColor Green

$SherlockReviewed = $false
$PhoneInfogaReviewed = $false
$SpiderFootReviewed = $false
$OwnedToolEvidenceAvailable = $false
$OwnedToolExternalAutoExecution = $false
$OwnedToolSourcePathsPersisted = $false
$OwnedToolSourceHashesPersisted = $false
$OwnedToolIdentifierValuesPersisted = $false

Write-Host ''
Write-Host 'Reviewing actual owned/authorized Sherlock, PhoneInfoga, and SpiderFoot-passive exports...' -ForegroundColor Cyan
if ($NonInteractive) {
    Write-Host '[INFO] NonInteractive mode cannot attest real export review. Tool review remains incomplete.' -ForegroundColor Yellow
} else {
    Remove-Item -LiteralPath $OwnedToolSummary -Force -ErrorAction SilentlyContinue
    & $Python $OwnedToolReview
    $ToolReviewRc = $LASTEXITCODE

    if (Test-Path -LiteralPath $OwnedToolSummary -PathType Leaf) {
        $ToolData = Get-Content -LiteralPath $OwnedToolSummary -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($ToolData.product -ne 'RAH Raven Daily Driver' -or
            $ToolData.candidateVersion -ne '1.0.0' -or
            $ToolData.stablePromotion -ne 'BLOCKED' -or
            $ToolData.automaticStablePromotion -ne $false -or
            $ToolData.externalToolsAutoExecuted -ne $false -or
            $ToolData.sourcePathsPersisted -ne $false -or
            $ToolData.sourceHashesPersisted -ne $false -or
            $ToolData.identifierValuesPersisted -ne $false) {
            throw 'Owned-tool review summary violated the privacy/lifecycle contract.'
        }

        $OwnedToolEvidenceAvailable = $true
        $OwnedToolExternalAutoExecution = [bool]$ToolData.externalToolsAutoExecuted
        $OwnedToolSourcePathsPersisted = [bool]$ToolData.sourcePathsPersisted
        $OwnedToolSourceHashesPersisted = [bool]$ToolData.sourceHashesPersisted
        $OwnedToolIdentifierValuesPersisted = [bool]$ToolData.identifierValuesPersisted
        $SherlockReviewed = Test-ToolReviewPass $ToolData 'sherlock'
        $PhoneInfogaReviewed = Test-ToolReviewPass $ToolData 'phoneinfoga'
        $SpiderFootReviewed = Test-ToolReviewPass $ToolData 'spiderfoot'
    } elseif ($ToolReviewRc -eq 0) {
        throw 'Owned-tool review reported PASS but did not write its machine-readable summary.'
    }

    if ($SherlockReviewed -and $PhoneInfogaReviewed -and $SpiderFootReviewed) {
        Write-Host '[PASS] All three owned-tool export reviews have machine-readable evidence.' -ForegroundColor Green
    } else {
        Write-Host '[INCOMPLETE] One or more owned-tool export reviews did not pass.' -ForegroundColor Yellow
    }
}

$EligibleForStableReview = (
    $ShortcutInteractiveConfirmed -and
    $LmPass -and
    $RuntimePass -and
    $SherlockReviewed -and
    $PhoneInfogaReviewed -and
    $SpiderFootReviewed
)

$Summary = [ordered]@{
    schemaVersion = 2
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
        ownedToolEvidenceAvailable = $OwnedToolEvidenceAvailable
        ownedToolExternalToolsAutoExecuted = $OwnedToolExternalAutoExecution
        ownedToolSourcePathsPersisted = $OwnedToolSourcePathsPersisted
        ownedToolSourceHashesPersisted = $OwnedToolSourceHashesPersisted
        ownedToolIdentifierValuesPersisted = $OwnedToolIdentifierValuesPersisted
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
        'Manual Stable review may now inspect this summary plus privacy-safe Runtime Evidence and owned-tool review evidence. No automatic promotion is permitted.'
    } else {
        'Complete every explicit owned-machine/export confirmation, then rerun this acceptance kit. Stable remains blocked.'
    })
}

$Summary | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $FinalSummary -Encoding UTF8

Write-Host ''
Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'RAH RAVEN - OWNED MACHINE ACCEPTANCE SUMMARY' -ForegroundColor Yellow
Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host "Summary                : $FinalSummary"
Write-Host "Owned-tool evidence    : $OwnedToolSummary"
Write-Host "Eligible Stable review : $EligibleForStableReview"
Write-Host 'Stable promotion       : BLOCKED'
Write-Host 'Automatic promotion    : NO'
Write-Host ''
Write-Host 'See STABLE-GATE.md for the authoritative manual review boundary.'

if ($EligibleForStableReview) { exit 0 }
exit 2
