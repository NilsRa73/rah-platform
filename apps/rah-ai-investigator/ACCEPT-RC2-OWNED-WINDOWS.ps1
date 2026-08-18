param(
    [switch]$SelfTest,
    [switch]$NonInteractive,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ManifestPath = Join-Path $Root 'RAH-INVESTIGATOR-VERSION.json'
$NormalizerPath = Join-Path $Root 'rah_investigator.py'
$HtmlPath = Join-Path $Root 'RAH-AI-INVESTIGATOR.html'
$CheckerPath = Join-Path $Root 'CHECK-RAH-INVESTIGATOR.ps1'
$SupportedExtensions = @('.txt','.json','.html','.htm','.csv','.md','.log')

function Require-File([string]$Path,[string]$Label) {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "$Label missing: $Path" }
}

function Get-PythonInvocation {
    $Python = Get-Command python.exe -ErrorAction SilentlyContinue
    if ($Python) { return [PSCustomObject]@{Exe=$Python.Source;Prefix=@()} }
    $Py = Get-Command py.exe -ErrorAction SilentlyContinue
    if ($Py) { return [PSCustomObject]@{Exe=$Py.Source;Prefix=@('-3')} }
    throw 'Python 3 was not found on PATH.'
}

function Invoke-Normalize([string]$InputPath,[string]$OutputPath) {
    $Py = Get-PythonInvocation
    & $Py.Exe @($Py.Prefix) $NormalizerPath normalize $InputPath --out $OutputPath
    if ($LASTEXITCODE -ne 0) { throw "Investigator normalizer failed with exit code $LASTEXITCODE" }
    if (-not (Test-Path -LiteralPath $OutputPath -PathType Leaf)) { throw 'Normalizer did not create Case JSON.' }
    $Case = Get-Content -LiteralPath $OutputPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($Case.schema -ne 'rah-investigator-case-v1' -or $Case.version -ne '1.0-RC2') { throw 'Unexpected Case JSON contract.' }
    if (-not $Case.normalizer.localOnly -or $Case.normalizer.networkRequests -or $Case.normalizer.externalToolExecution -or $Case.normalizer.sourceMutation) { throw 'Normalizer safety contract drift.' }
    return $Case
}

function Get-FolderFingerprint([string]$Path) {
    $Files = @(Get-ChildItem -LiteralPath $Path -File -Recurse -ErrorAction Stop | Where-Object { $SupportedExtensions -contains $_.Extension.ToLowerInvariant() } | Sort-Object FullName)
    if ($Files.Count -gt 500) { throw 'Selected folder has more than 500 supported evidence files.' }
    $Lines = foreach ($File in $Files) {
        $Relative = $File.FullName.Substring($Path.TrimEnd('\').Length).TrimStart('\')
        $Hash = (Get-FileHash -LiteralPath $File.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
        "$Relative|$($File.Length)|$Hash"
    }
    $Bytes = [Text.Encoding]::UTF8.GetBytes(($Lines -join "`n"))
    $Sha = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($Sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant() }
    finally { $Sha.Dispose() }
}

function Confirm-Completed([string]$Prompt) {
    if ($NonInteractive -or $SelfTest) { return $false }
    $Answer = Read-Host "$Prompt Type YES only if this was actually checked"
    return $Answer.Trim().ToUpperInvariant() -eq 'YES'
}

function Select-OwnedFolder {
    Add-Type -AssemblyName System.Windows.Forms
    $Dialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $Dialog.Description = 'Select a small folder containing data you own or are explicitly authorized to analyze'
    $Dialog.ShowNewFolderButton = $false
    if ($Dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return $Dialog.SelectedPath
}

function Select-OwnedZip {
    Add-Type -AssemblyName System.Windows.Forms
    $Dialog = New-Object System.Windows.Forms.OpenFileDialog
    $Dialog.Title = 'Select a ZIP containing data you own or are explicitly authorized to analyze'
    $Dialog.Filter = 'ZIP archives (*.zip)|*.zip'
    $Dialog.Multiselect = $false
    if ($Dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { return $null }
    return $Dialog.FileName
}

function Test-PathWithSpaces {
    $SpaceRoot = Join-Path $env:TEMP ("RAH Investigator Acceptance Path With Spaces " + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $SpaceRoot -Force | Out-Null
    try {
        Get-ChildItem -LiteralPath $Root -File | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $SpaceRoot $_.Name) -Force }
        & pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $SpaceRoot 'CHECK-RAH-INVESTIGATOR.ps1')
        if ($LASTEXITCODE -ne 0) { throw 'Path-with-spaces local checker failed.' }
        return $true
    }
    finally {
        if (Test-Path -LiteralPath $SpaceRoot) { Remove-Item -LiteralPath $SpaceRoot -Recurse -Force }
    }
}

function New-SelfTestInputs([string]$TempRoot) {
    $Folder = Join-Path $TempRoot 'owned folder'
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
    $Sample = "Owned test account https://example.com/Owned.Sample`nMail: owned.test@example.com`nPhone: +47 900 00 000`nSeen 2026-08-18`n"
    $SamplePath = Join-Path $Folder 'sample.txt'
    Set-Content -LiteralPath $SamplePath -Value $Sample -Encoding UTF8
    $Zip = Join-Path $TempRoot 'owned archive.zip'
    Compress-Archive -LiteralPath $SamplePath -DestinationPath $Zip -CompressionLevel Optimal
    return [PSCustomObject]@{Folder=$Folder;Zip=$Zip}
}

Require-File $ManifestPath 'Candidate manifest'
Require-File $NormalizerPath 'Python normalizer'
Require-File $HtmlPath 'Browser application'
Require-File $CheckerPath 'Windows checker'

$Manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($Manifest.product -ne 'RAH AI Investigator' -or $Manifest.version -ne '1.0-RC2' -or $Manifest.stage -ne 'candidate') { throw 'Investigator must remain RC2 Candidate.' }
if ($Manifest.authority_delta -ne 'none' -or $Manifest.validation.stable_release_gate -ne $false) { throw 'Candidate lifecycle/authority contract drift.' }
if ($Manifest.raven_reference -ne '2.0.32' -or $Manifest.stable_command_center_reference -ne '2.3.0' -or [int]$Manifest.stable_command_center_package_generation_reference -ne 8 -or $Manifest.stable_node_agent_reference -ne '1.3.0') { throw 'Current platform reference drift.' }
if ($Manifest.network_requests_in_core -or $Manifest.external_tool_auto_execution) { throw 'Investigator core authority drift.' }

$TempRoot = Join-Path $env:TEMP ("RAH Investigator Owned Acceptance " + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $TempRoot -Force | Out-Null
$FolderCasePath = Join-Path $TempRoot 'folder-case.json'
$ZipCasePath = Join-Path $TempRoot 'zip-case.json'

try {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $CheckerPath
    if ($LASTEXITCODE -ne 0) { throw 'Bundled Windows checker failed.' }
    $PathWithSpacesPass = Test-PathWithSpaces

    if ($SelfTest) {
        $Inputs = New-SelfTestInputs -TempRoot $TempRoot
        $FolderPath = $Inputs.Folder
        $ZipPath = $Inputs.Zip
        $Authorized = $true
    } else {
        if ($NonInteractive) { throw 'NonInteractive mode requires -SelfTest; real owned-data acceptance needs explicit selection and confirmation.' }
        $FolderPath = Select-OwnedFolder
        if ([string]::IsNullOrWhiteSpace($FolderPath)) { throw 'Owned folder selection was cancelled.' }
        $ZipPath = Select-OwnedZip
        if ([string]::IsNullOrWhiteSpace($ZipPath)) { throw 'Owned ZIP selection was cancelled.' }
        $Authorized = (Read-Host 'Confirm that BOTH selected inputs are your own data or explicitly authorized. Type YES').Trim().ToUpperInvariant() -eq 'YES'
        if (-not $Authorized) { throw 'Authorization confirmation is required.' }
    }

    $FolderBefore = Get-FolderFingerprint -Path $FolderPath
    $ZipBefore = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $FolderCase = Invoke-Normalize -InputPath $FolderPath -OutputPath $FolderCasePath
    $ZipCase = Invoke-Normalize -InputPath $ZipPath -OutputPath $ZipCasePath
    $FolderAfter = Get-FolderFingerprint -Path $FolderPath
    $ZipAfter = (Get-FileHash -LiteralPath $ZipPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $SourceUnchanged = ($FolderBefore -eq $FolderAfter -and $ZipBefore -eq $ZipAfter)
    if (-not $SourceUnchanged) { throw 'Selected source evidence changed during normalization.' }

    $FolderCounts = [ordered]@{
        emails=@($FolderCase.identifiers.emails).Count
        phones=@($FolderCase.identifiers.phones).Count
        urls=@($FolderCase.identifiers.urls).Count
        usernames=@($FolderCase.identifiers.usernames).Count
        sources=@($FolderCase.sources).Count
    }
    $ZipCounts = [ordered]@{
        emails=@($ZipCase.identifiers.emails).Count
        phones=@($ZipCase.identifiers.phones).Count
        urls=@($ZipCase.identifiers.urls).Count
        usernames=@($ZipCase.identifiers.usernames).Count
        sources=@($ZipCase.sources).Count
    }

    if ($SelfTest) {
        if ($FolderCounts.emails -lt 1 -or $ZipCounts.emails -lt 1) { throw 'Self-test fixture was not normalized as expected.' }
        Write-Host 'RAH Investigator RC2 owned-Windows acceptance automated self-test PASS' -ForegroundColor Green
        exit 0
    }

    Write-Host ''
    Write-Host 'Automated local checks PASS.' -ForegroundColor Green
    Write-Host 'Temporary Case JSON files for UI review:' -ForegroundColor Yellow
    Write-Host "  Folder Case: $FolderCasePath"
    Write-Host "  ZIP Case   : $ZipCasePath"
    Write-Host 'These temporary Case files are deleted when this acceptance script exits.' -ForegroundColor Yellow

    if (-not $NoLaunch) { Start-Process -FilePath $HtmlPath }

    $UiImport = Confirm-Completed 'Did the browser app load and import the temporary Case JSON from both the owned folder and owned ZIP with plausible identifiers?'
    $UiMatrix = Confirm-Completed 'Did you add a seed/alias and confirm Account Matrix, timeline and relationship graph render correctly?'
    $UiExports = Confirm-Completed 'Did you export and re-import Case JSON, then export identifiers CSV and confirm expected rows?'
    $UiJob = Confirm-Completed 'Did you export one authorized fixed Agent Job JSON and verify that it contains autoExecute:false?'

    $OptionalAnswer = (Read-Host 'Optional external tools: type NOTINSTALLED if Sherlock/PhoneInfoga/SpiderFoot are not installed, or YES only after separate owned username + owned phone + passive SpiderFoot result review').Trim().ToUpperInvariant()
    $OptionalStatus = if ($OptionalAnswer -eq 'YES') {'manually-reviewed'} elseif ($OptionalAnswer -eq 'NOTINSTALLED') {'not-installed'} else {'pending'}
    $OptionalSatisfied = $OptionalStatus -ne 'pending'

    $EligibleForStableReview = ($Authorized -and $SourceUnchanged -and $PathWithSpacesPass -and $UiImport -and $UiMatrix -and $UiExports -and $UiJob -and $OptionalSatisfied)

    $EvidenceRoot = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'RAH Raven\acceptance' } else { Join-Path $Root '.rah-local-evidence' }
    New-Item -ItemType Directory -Path $EvidenceRoot -Force | Out-Null
    $SummaryPath = Join-Path $EvidenceRoot 'rah-ai-investigator-rc2-owned-windows-acceptance.json'
    $Summary = [ordered]@{
        schemaVersion=1
        product='RAH AI Investigator'
        candidateVersion='1.0-RC2'
        acceptance='owned-windows-data-and-ui'
        generatedAt=(Get-Date).ToUniversalTime().ToString('o')
        contract=[ordered]@{
            stage='candidate'
            ravenVersion='2.0.32'
            commandCenterVersion='2.3.0'
            commandCenterPackageGeneration=8
            nodeAgentVersion='1.3.0'
            authorityDelta='none'
        }
        automatedChecks=[ordered]@{
            bundledChecker=$true
            pathWithSpaces=$PathWithSpacesPass
            folderNormalized=$true
            zipNormalized=$true
            selectedSourcesUnchanged=$SourceUnchanged
            folderIdentifierCounts=$FolderCounts
            zipIdentifierCounts=$ZipCounts
        }
        manualUiReview=[ordered]@{
            caseImportAndIdentifierReview=$UiImport
            seedAccountTimelineGraph=$UiMatrix
            caseRoundTripAndCsv=$UiExports
            authorizedJobAutoExecuteFalse=$UiJob
            optionalExternalTools=$OptionalStatus
        }
        privacy=[ordered]@{
            selectedPathsPersisted=$false
            identifiersPersistedInSummary=$false
            caseContentPersistedInSummary=$false
            externalToolTargetsPersisted=$false
            temporaryCaseFilesDeletedOnExit=$true
        }
        eligibleForStableReview=$EligibleForStableReview
        stablePromotion='BLOCKED'
        stablePromotionAutomated=$false
        stableFilesModifiedByAcceptance=$false
        nextAction=$(if($EligibleForStableReview){'Candidate may enter a separate Stable-readiness review. This acceptance does not promote it.'}else{'Complete the remaining explicit owned-data/UI checks and rerun. Stable remains blocked.'})
    }
    $Summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $SummaryPath -Encoding UTF8

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkYellow
    Write-Host 'INVESTIGATOR RC2 ACCEPTANCE RESULT' -ForegroundColor Yellow
    Write-Host '============================================================' -ForegroundColor DarkYellow
    Write-Host "Evidence: $SummaryPath"
    Write-Host "Eligible for Stable review: $EligibleForStableReview"
    Write-Host 'Stable promotion: BLOCKED'
    Write-Host 'Automatic promotion: NO'

    if ($EligibleForStableReview) { exit 0 }
    exit 2
}
finally {
    if (Test-Path -LiteralPath $TempRoot) { Remove-Item -LiteralPath $TempRoot -Recurse -Force }
}
