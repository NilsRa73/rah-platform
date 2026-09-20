param(
    [switch]$NoSelfCheck
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Repo = "NilsRa73/rah-platform"
$ApiBase = "https://api.github.com/repos/$Repo"
$RawBase = "https://raw.githubusercontent.com/$Repo"
$StatusDir = "C:\RAH\Status"
$BaselineJson = Join-Path $StatusDir "RAVEN-BASELINE-LATEST.json"
$BaselineTxt = Join-Path $StatusDir "RAVEN-BASELINE-LATEST.txt"
$InstalledUpdater = "C:\RAH\UPDATE-RAH-LATEST.ps1"
$InstalledLauncher = "C:\RAH\START-HER-LATEST.cmd"
$SelfCheck = "C:\RAH\RAVEN-AI-SELF-CHECK.ps1"
$SelfCheckLatest = "C:\RAH\Status\AI-SELF-CHECK-LATEST.txt"
$UserAgent = "RAH-Raven-Latest-Sync/1.0"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$TempDir = Join-Path $env:TEMP "rah-latest-sync-$Stamp"
$Installer = Join-Path $TempDir "INSTALL-RAH-AI-FABRIC.ps1"

function Say([string]$Text,[ConsoleColor]$Color=[ConsoleColor]::Gray){
    Write-Host $Text -ForegroundColor $Color
}

function Is-Admin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=[Security.Principal.WindowsPrincipal]::new($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Elevate {
    if(Is-Admin){ return }
    Say "RAH LATEST SYNC trenger Administrator. Ber om UAC..." Yellow
    $args=@("-NoLogo","-NoProfile","-ExecutionPolicy","Bypass","-File",('"{0}"' -f $PSCommandPath))
    if($NoSelfCheck){ $args += "-NoSelfCheck" }
    $child=Start-Process powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList $args
    exit $child.ExitCode
}

function Api-Get([string]$Url){
    $headers=@{
        "User-Agent"=$UserAgent
        "Accept"="application/vnd.github+json"
        "X-GitHub-Api-Version"="2022-11-28"
    }
    Invoke-RestMethod -Method Get -Uri $Url -Headers $headers -TimeoutSec 30
}

function Get-MainSha {
    $commit=Api-Get "$ApiBase/commits/main"
    $sha=[string]$commit.sha
    if($sha.Length -ne 40 -or $sha -notmatch '^[0-9a-f]+
    return $sha
}

function Wait-GreenSha([string]$Sha){
    $bad=@("failure","cancelled","timed_out","action_required","startup_failure")
    for($attempt=1;$attempt -le 16;$attempt++){
        $runs=Api-Get "$ApiBase/actions/runs?branch=main&head_sha=$Sha&per_page=100"
        $items=@($runs.workflow_runs)

        if($items.Count -gt 0){
            $badRuns=@($items|Where-Object{[string]$_.conclusion -in $bad})
            if($badRuns.Count -gt 0){
                $names=($badRuns|ForEach-Object{"$($_.name)=$($_.conclusion)"}) -join ", "
                throw "Main-SHA $Sha har rod GitHub Actions-status: $names"
            }

            $active=@($items|Where-Object{
                [string]$_.status -ne "completed"
            })
            $completedGood=@($items|Where-Object{
                [string]$_.status -eq "completed" -and [string]$_.conclusion -in @("success","skipped","neutral")
            })

            if($active.Count -eq 0 -and $completedGood.Count -gt 0){
                return [pscustomobject]@{
                    run_count=$items.Count
                    successful_runs=$completedGood.Count
                    names=@($completedGood|ForEach-Object{[string]$_.name}|Sort-Object -Unique)
                }
            }

            Say ("Venter pa GitHub CI for "+$Sha.Substring(0,8)+"... aktive="+$active.Count) DarkGray
        } else {
            Say ("Venter pa CI-bevis for "+$Sha.Substring(0,8)+"...") DarkGray
        }
        Start-Sleep -Seconds 15
    }
    throw "GitHub CI for $Sha ble ikke ferdig innen sikker tidsgrense. Prov igjen senere."
}

function Resolve-LatestGreenMain {
    for($round=1;$round -le 3;$round++){
        $sha=Get-MainSha
        Say ("Fant main "+$sha.Substring(0,12)+". Verifiserer CI...") Cyan
        $ci=Wait-GreenSha $sha
        $after=Get-MainSha
        if($after -eq $sha){
            return [pscustomobject]@{ sha=$sha; ci=$ci }
        }
        Say ("main flyttet seg fra "+$sha.Substring(0,8)+" til "+$after.Substring(0,8)+". Starter kontrollen pa nytt.") Yellow
    }
    throw "main endret seg flere ganger under verifisering. Ingen lokal oppdatering ble utfort."
}

function Validate-Installer([string]$Path,[string]$Sha){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Pinned installer mangler."}
    if((Get-Item -LiteralPath $Path).Length -lt 1000){throw "Pinned installer er uventet liten."}

    $content=Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    foreach($marker in @(
        '[string]$Ref = "main"',
        'SOURCE-REF.txt',
        'RAVEN-AI-SELF-CHECK.ps1',
        'raven_project_memory.py',
        'raven_council.py',
        'anythingllm_approval.py'
    )){
        if(-not$content.Contains($marker)){throw "Pinned installer mangler kontrakt: $marker"}
    }

    $tokens=$null;$errors=$null
    [System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)|Out-Null
    if($errors.Count){
        throw "Pinned installer har PowerShell parse-feil."
    }

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Install-PersistentLauncher {
    Copy-Item -LiteralPath $PSCommandPath -Destination $InstalledUpdater -Force
    $cmd=@"
@echo off
setlocal EnableExtensions
title RAH Raven - LATEST GREEN MAIN SYNC
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\RAH\UPDATE-RAH-LATEST.ps1"
exit /b %ERRORLEVEL%
"@
    [IO.File]::WriteAllText($InstalledLauncher,$cmd,[Text.Encoding]::ASCII)
}

Elevate
New-Item -ItemType Directory -Force -Path $StatusDir,$TempDir|Out-Null

$result=[ordered]@{
    schema="rah-raven-latest-main-sync-v1"
    generated_at=(Get-Date).ToString("o")
    computer=$env:COMPUTERNAME
    repository=$Repo
    branch="main"
    resolved_sha=""
    ci_run_count=0
    ci_successful_runs=0
    ci_names=@()
    installer_sha256=""
    repair_exit_code=$null
    self_check_exit_code=$null
    self_check_status="NOT_RUN"
    overall="FAIL"
    source="github-main-resolved-to-immutable-sha"
}

try{
    Say ""
    Say "============================================================" Yellow
    Say " RAH RAVEN - LATEST GREEN MAIN SYNC" Yellow
    Say "============================================================" Yellow

    $resolved=Resolve-LatestGreenMain
    $sha=[string]$resolved.sha
    $result.resolved_sha=$sha
    $result.ci_run_count=[int]$resolved.ci.run_count
    $result.ci_successful_runs=[int]$resolved.ci.successful_runs
    $result.ci_names=@($resolved.ci.names)
    Say ("Green main: "+$sha) Green

    $installerUrl="$RawBase/$sha/INSTALL-RAH-AI-FABRIC.ps1"
    Invoke-WebRequest -UseBasicParsing -Uri $installerUrl -OutFile $Installer -TimeoutSec 60
    $installerHash=Validate-Installer $Installer $sha
    $result.installer_sha256=$installerHash
    Say ("Pinned installer SHA-256: "+$installerHash) DarkGray

    Say "Kjorer AI Fabric Repair mot immutable SHA..." Cyan
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Installer -Mode Repair -Ref $sha
    $repairCode=$LASTEXITCODE
    $result.repair_exit_code=$repairCode
    if($repairCode -ne 0){
        throw "AI Fabric Repair feilet med exit code $repairCode"
    }

    if(-not$NoSelfCheck){
        if(-not(Test-Path -LiteralPath $SelfCheck -PathType Leaf)){
            throw "Repair fullfort, men Raven AI Self-Check mangler."
        }
        Say "Kjorer read-only sluttverifikasjon..." Cyan
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $SelfCheck -NoRepair
        $selfCode=$LASTEXITCODE
        $result.self_check_exit_code=$selfCode
        if($selfCode -eq 0){$result.self_check_status="PASS"}
        elseif($selfCode -eq 2){$result.self_check_status="PARTIAL"}
        else{$result.self_check_status="FAIL"}
    } else {
        $result.self_check_status="SKIPPED"
    }

    Install-PersistentLauncher

    if($result.self_check_status -in @("PASS","SKIPPED")){
        $result.overall="PASS"
    } elseif($result.self_check_status -eq "PARTIAL"){
        $result.overall="PARTIAL"
    } else {
        $result.overall="FAIL"
    }
}
catch{
    $result.error=$_.Exception.Message
    Say ("SYNC STOPPET TRYGT: "+$_.Exception.Message) Red
}
finally{
    $result.generated_at=(Get-Date).ToString("o")
    if(Test-Path -LiteralPath $BaselineJson){
        Copy-Item -LiteralPath $BaselineJson -Destination ($BaselineJson+".previous") -Force -ErrorAction SilentlyContinue
    }
    $result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $BaselineJson -Encoding UTF8

    $lines=@(
        "RAH RAVEN LATEST GREEN MAIN",
        "===========================",
        "Timestamp      : $($result.generated_at)",
        "PC             : $($result.computer)",
        "Repository     : $($result.repository)",
        "Branch         : $($result.branch)",
        "Resolved SHA   : $($result.resolved_sha)",
        "CI runs        : $($result.ci_run_count)",
        "CI green       : $($result.ci_successful_runs)",
        "Repair exit    : $($result.repair_exit_code)",
        "Self-Check     : $($result.self_check_status)",
        "OVERALL        : $($result.overall)",
        "Baseline JSON  : $BaselineJson",
        "Self-Check TXT : $SelfCheckLatest"
    )
    if($result.Contains("error")){$lines += "Error          : $($result.error)"}
    [IO.File]::WriteAllLines($BaselineTxt,[string[]]$lines,[Text.UTF8Encoding]::new($false))

    Say ""
    foreach($line in $lines){Write-Host $line}
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

if($result.overall -eq "PASS"){exit 0}
elseif($result.overall -eq "PARTIAL"){exit 2}
else{exit 1}
){
        throw "GitHub returnerte ugyldig main-SHA."
    }
    return $sha
}

function Wait-GreenSha([string]$Sha){
    $bad=@("failure","cancelled","timed_out","action_required","startup_failure")
    for($attempt=1;$attempt -le 16;$attempt++){
        $runs=Api-Get "$ApiBase/actions/runs?branch=main&head_sha=$Sha&per_page=100"
        $items=@($runs.workflow_runs)

        if($items.Count -gt 0){
            $badRuns=@($items|Where-Object{[string]$_.conclusion -in $bad})
            if($badRuns.Count -gt 0){
                $names=($badRuns|ForEach-Object{"$($_.name)=$($_.conclusion)"}) -join ", "
                throw "Main-SHA $Sha har rod GitHub Actions-status: $names"
            }

            $active=@($items|Where-Object{
                [string]$_.status -ne "completed"
            })
            $completedGood=@($items|Where-Object{
                [string]$_.status -eq "completed" -and [string]$_.conclusion -in @("success","skipped","neutral")
            })

            if($active.Count -eq 0 -and $completedGood.Count -gt 0){
                return [pscustomobject]@{
                    run_count=$items.Count
                    successful_runs=$completedGood.Count
                    names=@($completedGood|ForEach-Object{[string]$_.name}|Sort-Object -Unique)
                }
            }

            Say ("Venter pa GitHub CI for "+$Sha.Substring(0,8)+"... aktive="+$active.Count) DarkGray
        } else {
            Say ("Venter pa CI-bevis for "+$Sha.Substring(0,8)+"...") DarkGray
        }
        Start-Sleep -Seconds 15
    }
    throw "GitHub CI for $Sha ble ikke ferdig innen sikker tidsgrense. Prov igjen senere."
}

function Resolve-LatestGreenMain {
    for($round=1;$round -le 3;$round++){
        $sha=Get-MainSha
        Say ("Fant main "+$sha.Substring(0,12)+". Verifiserer CI...") Cyan
        $ci=Wait-GreenSha $sha
        $after=Get-MainSha
        if($after -eq $sha){
            return [pscustomobject]@{ sha=$sha; ci=$ci }
        }
        Say ("main flyttet seg fra "+$sha.Substring(0,8)+" til "+$after.Substring(0,8)+". Starter kontrollen pa nytt.") Yellow
    }
    throw "main endret seg flere ganger under verifisering. Ingen lokal oppdatering ble utfort."
}

function Validate-Installer([string]$Path,[string]$Sha){
    if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){throw "Pinned installer mangler."}
    if((Get-Item -LiteralPath $Path).Length -lt 1000){throw "Pinned installer er uventet liten."}

    $content=Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    foreach($marker in @(
        '[string]$Ref = "main"',
        'SOURCE-REF.txt',
        'RAVEN-AI-SELF-CHECK.ps1',
        'raven_project_memory.py',
        'raven_council.py',
        'anythingllm_approval.py'
    )){
        if(-not$content.Contains($marker)){throw "Pinned installer mangler kontrakt: $marker"}
    }

    $tokens=$null;$errors=$null
    [System.Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)|Out-Null
    if($errors.Count){
        throw "Pinned installer har PowerShell parse-feil."
    }

    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Install-PersistentLauncher {
    Copy-Item -LiteralPath $PSCommandPath -Destination $InstalledUpdater -Force
    $cmd=@"
@echo off
setlocal EnableExtensions
title RAH Raven - LATEST GREEN MAIN SYNC
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "C:\RAH\UPDATE-RAH-LATEST.ps1"
exit /b %ERRORLEVEL%
"@
    [IO.File]::WriteAllText($InstalledLauncher,$cmd,[Text.Encoding]::ASCII)
}

Elevate
New-Item -ItemType Directory -Force -Path $StatusDir,$TempDir|Out-Null

$result=[ordered]@{
    schema="rah-raven-latest-main-sync-v1"
    generated_at=(Get-Date).ToString("o")
    computer=$env:COMPUTERNAME
    repository=$Repo
    branch="main"
    resolved_sha=""
    ci_run_count=0
    ci_successful_runs=0
    ci_names=@()
    installer_sha256=""
    repair_exit_code=$null
    self_check_exit_code=$null
    self_check_status="NOT_RUN"
    overall="FAIL"
    source="github-main-resolved-to-immutable-sha"
}

try{
    Say ""
    Say "============================================================" Yellow
    Say " RAH RAVEN - LATEST GREEN MAIN SYNC" Yellow
    Say "============================================================" Yellow

    $resolved=Resolve-LatestGreenMain
    $sha=[string]$resolved.sha
    $result.resolved_sha=$sha
    $result.ci_run_count=[int]$resolved.ci.run_count
    $result.ci_successful_runs=[int]$resolved.ci.successful_runs
    $result.ci_names=@($resolved.ci.names)
    Say ("Green main: "+$sha) Green

    $installerUrl="$RawBase/$sha/INSTALL-RAH-AI-FABRIC.ps1"
    Invoke-WebRequest -UseBasicParsing -Uri $installerUrl -OutFile $Installer -TimeoutSec 60
    $installerHash=Validate-Installer $Installer $sha
    $result.installer_sha256=$installerHash
    Say ("Pinned installer SHA-256: "+$installerHash) DarkGray

    Say "Kjorer AI Fabric Repair mot immutable SHA..." Cyan
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $Installer -Mode Repair -Ref $sha
    $repairCode=$LASTEXITCODE
    $result.repair_exit_code=$repairCode
    if($repairCode -ne 0){
        throw "AI Fabric Repair feilet med exit code $repairCode"
    }

    if(-not$NoSelfCheck){
        if(-not(Test-Path -LiteralPath $SelfCheck -PathType Leaf)){
            throw "Repair fullfort, men Raven AI Self-Check mangler."
        }
        Say "Kjorer read-only sluttverifikasjon..." Cyan
        & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $SelfCheck -NoRepair
        $selfCode=$LASTEXITCODE
        $result.self_check_exit_code=$selfCode
        if($selfCode -eq 0){$result.self_check_status="PASS"}
        elseif($selfCode -eq 2){$result.self_check_status="PARTIAL"}
        else{$result.self_check_status="FAIL"}
    } else {
        $result.self_check_status="SKIPPED"
    }

    Install-PersistentLauncher

    if($result.self_check_status -in @("PASS","SKIPPED")){
        $result.overall="PASS"
    } elseif($result.self_check_status -eq "PARTIAL"){
        $result.overall="PARTIAL"
    } else {
        $result.overall="FAIL"
    }
}
catch{
    $result.error=$_.Exception.Message
    Say ("SYNC STOPPET TRYGT: "+$_.Exception.Message) Red
}
finally{
    $result.generated_at=(Get-Date).ToString("o")
    if(Test-Path -LiteralPath $BaselineJson){
        Copy-Item -LiteralPath $BaselineJson -Destination ($BaselineJson+".previous") -Force -ErrorAction SilentlyContinue
    }
    $result|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $BaselineJson -Encoding UTF8

    $lines=@(
        "RAH RAVEN LATEST GREEN MAIN",
        "===========================",
        "Timestamp      : $($result.generated_at)",
        "PC             : $($result.computer)",
        "Repository     : $($result.repository)",
        "Branch         : $($result.branch)",
        "Resolved SHA   : $($result.resolved_sha)",
        "CI runs        : $($result.ci_run_count)",
        "CI green       : $($result.ci_successful_runs)",
        "Repair exit    : $($result.repair_exit_code)",
        "Self-Check     : $($result.self_check_status)",
        "OVERALL        : $($result.overall)",
        "Baseline JSON  : $BaselineJson",
        "Self-Check TXT : $SelfCheckLatest"
    )
    if($result.Contains("error")){$lines += "Error          : $($result.error)"}
    [IO.File]::WriteAllLines($BaselineTxt,[string[]]$lines,[Text.UTF8Encoding]::new($false))

    Say ""
    foreach($line in $lines){Write-Host $line}
    Remove-Item -LiteralPath $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

if($result.overall -eq "PASS"){exit 0}
elseif($result.overall -eq "PARTIAL"){exit 2}
else{exit 1}
