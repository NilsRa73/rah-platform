param(
    [string]$FacebookArchive,
    [switch]$NonInteractive,
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$App = Join-Path $Root 'apps\rah-raven-daily-driver'
$Installer = Join-Path $Root 'INSTALL-RAH-RAVEN.bat'
$RuntimeRunner = Join-Path $Root 'TEST-RAH-RAVEN-RUNTIME.bat'
$LmAcceptance = Join-Path $App 'owned_machine_acceptance.py'
$OwnedToolReview = Join-Path $App 'FINAL-OWNED-TOOL-REVIEW.py'
$StateDir = Join-Path $App 'runtime\state'
$LmSummary = Join-Path $StateDir 'owned-machine-lm-acceptance.json'
$FinalSummary = Join-Path $StateDir 'owned-machine-acceptance.json'
$StableGate = Join-Path $Root 'STABLE-GATE.md'
$BuildValidation = Join-Path $Root 'BUILD-VALIDATION.json'
$PackageManifest = Join-Path $Root 'RAH-RAVEN-DAILY-DRIVER-PACKAGE.json'
$Desktop = [Environment]::GetFolderPath('Desktop')
$DesktopEvidenceDir = Join-Path $Desktop 'RAH Daily Driver Evidence'
$OwnedToolSummary = Join-Path $DesktopEvidenceDir 'OWNED_TOOL_REVIEW_SUMMARY.json'
$HumanReport = Join-Path $DesktopEvidenceDir 'FINAL-ACCEPTANCE-SUMMARY.txt'
$script:CurrentPhase = 'precheck'

function Require-File([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label was not found: $Path"
    }
}

function Write-RunReport([string]$Status, [string]$Phase, [string]$Message) {
    if ([string]::IsNullOrWhiteSpace($Desktop)) { return }
    New-Item -ItemType Directory -Path $DesktopEvidenceDir -Force | Out-Null
    $lines = @(
        'RAH RAVEN DAILY DRIVER - FINAL ACCEPTANCE SUMMARY',
        ('Generated: ' + (Get-Date).ToUniversalTime().ToString('o')),
        ('Status: ' + $Status),
        ('Phase: ' + $Phase),
        ('Result: ' + $Message),
        'Stable promotion: BLOCKED',
        'Automatic promotion: NO',
        'Next: rerun the same ACCEPT-RAH-RAVEN-OWNED-MACHINE.bat after any printed prerequisite is fixed.'
    )
    $lines | Set-Content -LiteralPath $HumanReport -Encoding UTF8
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

function Test-LmStudioServer {
    try {
        $null = Invoke-RestMethod -Method Get -Uri 'http://127.0.0.1:1234/v1/models' -TimeoutSec 2
        return $true
    } catch {
        return $false
    }
}

function Start-LmStudioIfInstalled {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\LM Studio\LM Studio.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\lm-studio\LM Studio.exe'),
        (Join-Path $env:ProgramFiles 'LM Studio\LM Studio.exe')
    )
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $running = Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $candidate } | Select-Object -First 1
            if (-not $running) {
                Write-Host '[REPAIR] Starting installed LM Studio...' -ForegroundColor Cyan
                Start-Process -FilePath $candidate | Out-Null
            }
            for ($i = 0; $i -lt 20; $i++) {
                if (Test-LmStudioServer) { return $true }
                Start-Sleep -Seconds 1
            }
            return $false
        }
    }
    return $false
}

function Test-ShortcutContract {
    param([string]$ShortcutPath)
    if (-not (Test-Path -LiteralPath $ShortcutPath -PathType Leaf)) { return $false }
    try {
        $Shell = New-Object -ComObject WScript.Shell
        $Shortcut = $Shell.CreateShortcut($ShortcutPath)
        $ExpectedTarget = [IO.Path]::GetFullPath((Join-Path $App 'START-RAH-RAVEN.bat'))
        $ExpectedWork = [IO.Path]::GetFullPath($App).TrimEnd('\')
        $ActualTarget = [IO.Path]::GetFullPath($Shortcut.TargetPath)
        $ActualWork = [IO.Path]::GetFullPath($Shortcut.WorkingDirectory).TrimEnd('\')
        return ($ActualTarget -eq $ExpectedTarget -and $ActualWork -eq $ExpectedWork)
    } catch {
        return $false
    }
}

function Invoke-RepairInstall {
    Require-File $Installer 'Daily Driver installer'
    $old = $env:RAH_RAVEN_INSTALL_NO_START
    try {
        $env:RAH_RAVEN_INSTALL_NO_START = '1'
        Write-Host '[REPAIR] Running existing Daily Driver installer in no-start mode...' -ForegroundColor Cyan
        & $Installer
        if ($LASTEXITCODE -ne 0) {
            throw "Installer failed with exit code $LASTEXITCODE."
        }
    } finally {
        if ($null -eq $old) {
            Remove-Item Env:RAH_RAVEN_INSTALL_NO_START -ErrorAction SilentlyContinue
        } else {
            $env:RAH_RAVEN_INSTALL_NO_START = $old
        }
    }
}

function Test-ToolReviewPass($Data, [string]$ToolId) {
    if (-not $Data) { return $false }
    $matches = @($Data.reviews | Where-Object { $_.tool -eq $ToolId })
    if ($matches.Count -ne 1) { return $false }
    return ($matches[0].status -eq 'PASS')
}

function Assert-StaticContract {
    foreach ($pair in @(
        @($Installer, 'Daily Driver installer'),
        @($RuntimeRunner, 'Runtime Acceptance runner'),
        @($LmAcceptance, 'LM Studio acceptance helper'),
        @($OwnedToolReview, 'Owned-tool export review helper'),
        @($StableGate, 'Stable Gate document'),
        @($BuildValidation, 'Build validation metadata'),
        @($PackageManifest, 'Daily Driver package manifest')
    )) {
        Require-File $pair[0] $pair[1]
    }

    $build = Get-Content -LiteralPath $BuildValidation -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($build.product -ne 'RAH Raven Daily Driver' -or $build.stage -ne 'candidate') {
        throw 'Build validation no longer describes the Daily Driver Candidate.'
    }
    if ($build.runtime_gate.stable_promotion -ne 'not-passed') {
        throw 'Stable gate is not fail-closed in BUILD-VALIDATION.json.'
    }

    $package = Get-Content -LiteralPath $PackageManifest -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($package.packageFileCount -ne 37 -or @($package.packageFiles).Count -ne 37) {
        throw 'Immutable Candidate package closure is not exactly 37 files.'
    }
    if (-not $package.runtimePolicy.candidateOnly -or $package.runtimePolicy.stablePromotionIncluded) {
        throw 'Candidate lifecycle boundary drift detected.'
    }

    $selfText = Get-Content -LiteralPath $MyInvocation.MyCommand.Path -Raw -Encoding UTF8
    foreach ($marker in @("stablePromotion = 'BLOCKED'", 'stablePromotionAutomated = $false', 'archivePathPersisted = $false')) {
        if (-not $selfText.Contains($marker)) { throw "Required fail-closed marker missing: $marker" }
    }
}

trap {
    $message = $_.Exception.Message
    try { Write-RunReport 'FAIL' $script:CurrentPhase $message } catch {}
    Write-Host "[FAIL] $message" -ForegroundColor Red
    Write-Host 'Stable promotion remains BLOCKED.' -ForegroundColor Yellow
    exit 1
}

Assert-StaticContract
if ($SelfTest) {
    Write-Host '[PASS] Owned-machine acceptance static self-test.' -ForegroundColor Green
    Write-Host '[PASS] Candidate package remains 37 files and Stable promotion remains BLOCKED.' -ForegroundColor Green
    exit 0
}

Require-File (Join-Path $App 'main.py') 'Daily Driver app entry point'
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
New-Item -ItemType Directory -Path $DesktopEvidenceDir -Force | Out-Null

Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'RAH RAVEN - OWNED WINDOWS MACHINE ACCEPTANCE' -ForegroundColor Yellow
Write-Host 'PRECHECK -> SAFE REPAIR -> RUNTIME TEST -> FINAL REPORT' -ForegroundColor Yellow
Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'This runner never promotes Stable or Frozen.' -ForegroundColor Yellow
Write-Host 'Use only your own archive and representative owned tool exports.'
Write-Host ''

$script:CurrentPhase = 'python-and-install'
$Python = Find-Python
if (-not $Python) {
    throw 'Python 3 was not found. Install Python 3 once, then rerun this same BAT.'
}

$ShortcutPath = Join-Path $Desktop 'RAH Raven Daily Driver.lnk'
$VenvPython = Join-Path $App '.venv\Scripts\python.exe'
$needsRepair = (-not (Test-Path -LiteralPath $VenvPython -PathType Leaf)) -or (-not (Test-ShortcutContract $ShortcutPath))
if ($needsRepair) {
    Invoke-RepairInstall
}

$Python = Find-Python
if (-not $Python) { throw 'Python disappeared after installer repair.' }
if (-not (Test-ShortcutContract $ShortcutPath)) {
    throw 'Desktop shortcut is still missing or incorrect after automatic repair.'
}
Write-Host '[PASS] Python/venv and desktop shortcut contract.' -ForegroundColor Green

$ShortcutInteractiveConfirmed = $false
if (-not $NonInteractive) {
    $script:CurrentPhase = 'desktop-shortcut-ui'
    Write-Host '[CHECK] Launching the verified Daily Driver desktop shortcut...' -ForegroundColor Cyan
    Start-Process -FilePath $ShortcutPath
    Start-Sleep -Seconds 2
    $ShortcutInteractiveConfirmed = Confirm-ActuallyCompleted 'Did Daily Driver open correctly from the desktop shortcut?'
    if (-not $ShortcutInteractiveConfirmed) {
        Write-Host '[PENDING] Shortcut UI launch was not confirmed; remaining diagnostics will still run.' -ForegroundColor Yellow
    }
}

$script:CurrentPhase = 'lm-studio'
if (-not (Test-LmStudioServer)) {
    $started = $false
    if (-not $NonInteractive) { $started = Start-LmStudioIfInstalled }
    if (-not $started -and -not (Test-LmStudioServer)) {
        $msg = 'LM Studio local server is offline. Start LM Studio, load a model, enable the local server on 127.0.0.1:1234, then rerun the same BAT.'
        Write-RunReport 'PENDING' $script:CurrentPhase $msg
        Write-Host "[PENDING] $msg" -ForegroundColor Yellow
        exit 2
    }
}
Write-Host '[PASS] LM Studio loopback endpoint is reachable.' -ForegroundColor Green

Write-Host ''
Write-Host 'Testing configured local LM Studio Council roles...' -ForegroundColor Cyan
& $Python $LmAcceptance --output $LmSummary
if ($LASTEXITCODE -ne 0) {
    $msg = 'LM Studio role-response acceptance is not ready. Verify a loaded model and at least two enabled local LM Studio Council roles, then rerun.'
    Write-RunReport 'PENDING' $script:CurrentPhase $msg
    Write-Host "[PENDING] $msg" -ForegroundColor Yellow
    exit 2
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

$script:CurrentPhase = 'owned-archive-runtime'
if ([string]::IsNullOrWhiteSpace($FacebookArchive)) {
    $FacebookArchive = Select-OwnedArchive
}
if (-not (Test-Path -LiteralPath $FacebookArchive)) {
    throw 'Selected Facebook/archive path does not exist.'
}
$ResolvedArchive = (Resolve-Path -LiteralPath $FacebookArchive).Path
Write-Host '[INFO] Owned archive selected. Its path/content will not be copied into the acceptance summary.'

Write-Host ''
Write-Host 'Running Runtime Gate + privacy-safe Evidence + validator...' -ForegroundColor Cyan
& $RuntimeRunner $ResolvedArchive
$RuntimeRc = $LASTEXITCODE
$RuntimePass = ($RuntimeRc -eq 0)
if ($RuntimeRc -eq 2) {
    $msg = 'Runtime Acceptance is valid but still pending one or more required runtime checks. Review its printed report and rerun the same BAT.'
    Write-RunReport 'PENDING' $script:CurrentPhase $msg
    Write-Host "[PENDING] $msg" -ForegroundColor Yellow
    exit 2
}
if (-not $RuntimePass) {
    throw "Runtime Acceptance failed with exit code $RuntimeRc."
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

$script:CurrentPhase = 'owned-tool-review'
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

$finalStatus = $(if ($EligibleForStableReview) { 'PASS' } else { 'PENDING' })
$finalMessage = $(if ($EligibleForStableReview) {
    'All required owned-machine checks passed. Eligible for separate manual Stable review.'
} else {
    'Machine diagnostics passed, but one or more explicit UI/export confirmations remain incomplete.'
})
Write-RunReport $finalStatus 'complete' $finalMessage

Write-Host ''
Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host 'RAH RAVEN - OWNED MACHINE ACCEPTANCE SUMMARY' -ForegroundColor Yellow
Write-Host '================================================================' -ForegroundColor DarkYellow
Write-Host "Summary                : $FinalSummary"
Write-Host "Human report           : $HumanReport"
Write-Host "Owned-tool evidence    : $OwnedToolSummary"
Write-Host "Eligible Stable review : $EligibleForStableReview"
Write-Host 'Stable promotion       : BLOCKED'
Write-Host 'Automatic promotion    : NO'
Write-Host ''
Write-Host 'See STABLE-GATE.md for the authoritative manual review boundary.'

if ($EligibleForStableReview) { exit 0 }
exit 2
