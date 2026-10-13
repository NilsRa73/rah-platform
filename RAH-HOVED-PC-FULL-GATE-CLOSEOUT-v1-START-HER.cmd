@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>nul
title RAH HOVED-PC FULL GATE CLOSEOUT v1

set "RAH_SELF=%~f0"
if /I "%~1"=="__RAH_ADMIN__" goto :ADMIN_OK
fltmc >nul 2>&1
if not errorlevel 1 goto :ADMIN_OK
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';Start-Process -FilePath $env:RAH_SELF -Verb RunAs -ArgumentList '__RAH_ADMIN__'"
if errorlevel 1 (
  echo UAC elevation failed.
  pause
  exit /b 18
)
exit /b 0

:ADMIN_OK
echo.
echo ============================================================
echo        RAH HOVED-PC FULL GATE CLOSEOUT v1
echo ============================================================
echo Requires Finalizer v2 CORE PASS first.
echo Then closes AnythingLLM + Worker Proof in one guided run.
echo ============================================================
echo.

set "RAH_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$t=Get-Content -LiteralPath $env:RAH_SELF -Raw;$p=($t -split '(?m)^### RAH_FULL_GATE_PS ###\r?\n',2)[1];Invoke-Expression $p"
set "RC=%ERRORLEVEL%"

echo.
echo ============================================================
if "%RC%"=="0" echo RAH FULL GATE CLOSEOUT: READY FOR REBOOT CHECK
if "%RC%"=="12" echo CORE PASS IS REQUIRED FIRST
if not "%RC%"=="0" if not "%RC%"=="12" echo FULL GATES STILL OPEN
echo Report: C:\RAH\Logs\RAH-HOVED-PC-FULL-GATE-CLOSEOUT-v1-LATEST.txt
echo ============================================================
echo.
pause
exit /b %RC%

### RAH_FULL_GATE_PS ###
Set-StrictMode -Version Latest
$ErrorActionPreference='Continue'

$Root='C:\RAH'
$Logs=Join-Path $Root 'Logs'
$RavenOS=Join-Path $Root 'RavenOS'
$Core=Join-Path $Root 'RavenCore7'
$V2Json=Join-Path $Logs 'RAH-HOVED-PC-FINALIZER-v2-LATEST.json'
$Report=Join-Path $Logs 'RAH-HOVED-PC-FULL-GATE-CLOSEOUT-v1-LATEST.txt'
$Json=Join-Path $Logs 'RAH-HOVED-PC-FULL-GATE-CLOSEOUT-v1-LATEST.json'
$OsAcceptance=Join-Path $RavenOS 'state\RAH-OS-v0.8-ACCEPTANCE.json'
$AnythingReport='C:\RAH\AI-Fabric\anythingllm-approval-test.json'
$WorkerProof=Join-Path $Core 'state\worker-proof.json'

New-Item -ItemType Directory -Force -Path $Logs|Out-Null
$pass=0;$pending=0;$fail=0

function L([string]$s=''){Write-Host $s;Add-Content -LiteralPath $Report -Value $s -Encoding UTF8}
function P([string]$s){$script:pass++;L "[PASS] $s"}
function N([string]$s){$script:pending++;L "[PENDING] $s"}
function F([string]$s){$script:fail++;L "[FAIL] $s"}
function S([string]$s){L '';L '============================================================';L $s;L '============================================================'}
function Find-Local([string]$Name){
 foreach($base in @(
   $RavenOS,
   $Core,
   'C:\RAH',
   'C:\RAH\AI-Fabric',
   'C:\RAH\AI-Fabric\rah-platform',
   'C:\RAH\Runtime\RavenElevated\rah-platform',
   "$env:USERPROFILE\Desktop\RAH AI Studios"
  )){
   if([string]::IsNullOrWhiteSpace($base)){continue}
   $p=Join-Path $base $Name
   if(Test-Path -LiteralPath $p -PathType Leaf){return $p}
 }
 return $null
}

@(
 'RAH HOVED-PC FULL GATE CLOSEOUT v1',
 ('Computer: '+$env:COMPUTERNAME),
 ('UTC: '+(Get-Date).ToUniversalTime().ToString('o')),
 'Policy: no token in ChatGPT; no arbitrary shell; no disk/USB/BIOS/boot/GPU-CUDA changes.',
 ''
)|Set-Content -LiteralPath $Report -Encoding UTF8

S '1/6 REQUIRE VERIFIED CORE PASS'
if(-not(Test-Path -LiteralPath $V2Json -PathType Leaf)){
 F 'Finalizer v2 JSON is missing. Run Finalizer v2 first.'
 exit 12
}
try{$v2=Get-Content -LiteralPath $V2Json -Raw|ConvertFrom-Json}catch{
 F ('Finalizer v2 JSON is invalid: '+$_.Exception.Message)
 exit 12
}
if([string]$v2.coreGate -ne 'PASS'){
 F ('Finalizer v2 coreGate='+[string]$v2.coreGate+'. CORE PASS is required first.')
 exit 12
}
P 'Finalizer v2 CORE PASS verified.'

S '2/6 ANYTHINGLLM LOCAL CONFIG + APPROVAL PROOF'
$approval=$null
try{$approval=Invoke-RestMethod -Uri 'http://127.0.0.1:18765/agent/approval/status' -TimeoutSec 5}catch{}
if(-not($approval -and $approval.ok -eq $true -and $approval.configured -eq $true)){
 $configure=Find-Local 'CONFIGURE-RAH-PROJECT-MEMORY.ps1'
 if($configure){
   L 'AnythingLLM is not configured. Starting the existing local secure setup.'
   L 'Your token is entered only in this local console and is never sent to ChatGPT.'
   & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $configure
   L ('AnythingLLM configure exit='+$LASTEXITCODE)
 }else{
   N 'AnythingLLM is not configured and CONFIGURE-RAH-PROJECT-MEMORY.ps1 was not found.'
 }
}
$atest=Find-Local 'TEST-ANYTHINGLLM-APPROVAL.ps1'
if($atest){
 & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $atest 2>&1|ForEach-Object{L ([string]$_)}
 if($LASTEXITCODE -eq 0){
   try{
     $ar=Get-Content -LiteralPath $AnythingReport -Raw|ConvertFrom-Json
     if([string]$ar.overall -eq 'PASS' -and $ar.secretIncluded -eq $false){
       P 'AnythingLLM approval proof PASS; secretIncluded=false.'
     }else{F 'AnythingLLM approval report is not a valid PASS.'}
   }catch{F 'AnythingLLM approval report missing/invalid.'}
 }elseif($LASTEXITCODE -eq 10){
   N 'AnythingLLM is still not configured.'
 }else{F ('AnythingLLM approval test exit='+$LASTEXITCODE)}
}else{F 'TEST-ANYTHINGLLM-APPROVAL.ps1 not found.'}

S '3/6 WORKER REAL-HARDWARE PROOF'
$worker=Find-Local 'RAVEN-CORE-7-WORKER-PROOF.ps1'
if(-not$worker){
 F 'RAVEN-CORE-7-WORKER-PROOF.ps1 not found.'
}else{
 & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $worker -Mode Validate -JsonOnly 2>&1|ForEach-Object{L ([string]$_)}
 if($LASTEXITCODE -ne 0){
   $grid=Find-Local 'START-HER-RAH-2PC-GRID.cmd'
   if($grid){
     L 'Worker Proof needs fresh physical evidence. Opening the existing 2-PC Grid.'
     L 'Complete SYSTEM INVENTORY and FINAL REAL-HARDWARE ACCEPTANCE, then close the Grid window.'
     $p=Start-Process -FilePath $grid -WorkingDirectory (Split-Path -Parent $grid) -PassThru -Wait
     L ('2-PC Grid exit='+$p.ExitCode)
   }else{
     N '2-PC Grid launcher not found locally.'
   }
   & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $worker -Mode Validate -JsonOnly 2>&1|ForEach-Object{L ([string]$_)}
 }
 if($LASTEXITCODE -eq 0){
   try{
     $wp=Get-Content -LiteralPath $WorkerProof -Raw|ConvertFrom-Json
     if([string]$wp.state -eq 'PASS' -and $wp.accepted -eq $true){
       P ('Worker Proof PASS for '+[string]$wp.worker.hostname+'.')
     }else{F 'Worker Proof JSON is not an accepted PASS.'}
   }catch{F 'Worker Proof JSON missing/invalid.'}
 }else{
   N 'Worker Proof still pending after 2-PC Grid.'
 }
}

S '4/6 RERUN RAH OS FULL ACCEPTANCE'
$accept=Find-Local 'RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1'
$rahOsFull=$false
$coreStill=$false
if($accept){
 & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $accept -JsonOnly 2>&1|ForEach-Object{L ([string]$_)}
 try{
   $os=Get-Content -LiteralPath $OsAcceptance -Raw|ConvertFrom-Json
   if([string]$os.coreOverall -eq 'PASS'){$coreStill=$true;P 'RAH OS coreOverall remains PASS.'}
   else{F ('RAH OS coreOverall='+[string]$os.coreOverall)}
   if([string]$os.overall -eq 'PASS'){$rahOsFull=$true;P 'RAH OS full acceptance PASS.'}
   else{N 'RAH OS full acceptance remains open.'}
 }catch{F 'RAH OS acceptance JSON missing/invalid.'}
}else{F 'RAH OS acceptance script not found.'}

S '5/6 POPUP STRUCTURAL CHECK'
$popupStructure=$false
try{
 $bad=@()
 foreach($t in @(Get-ScheduledTask -ErrorAction Stop|Where-Object{($_.TaskPath+$_.TaskName) -match '(?i)RAH|RAVEN|STORM|NETLINK'})){
  foreach($a in @($t.Actions)){
   if($a.Execute -match '(?i)(powershell|pwsh)(\.exe)?$' -and $a.Arguments -notmatch '(?i)(^|\s)-WindowStyle\s+(Hidden|0)(\s|$)'){
    $bad+=($t.TaskPath+$t.TaskName)
   }
  }
 }
 if($bad.Count -eq 0){$popupStructure=$true;P 'Scheduled PowerShell structure is hidden.'}
 else{N ('Visible scheduled PowerShell actions remain: '+(($bad|Sort-Object -Unique)-join ', '))}
}catch{N ('Popup structure check warning: '+$_.Exception.Message)}
N 'Final runtime popup verification still requires one reboot/observation.'

S '6/6 FINAL STATUS + CLOUD HANDOFF'
$anythingPass=$false
if(Test-Path -LiteralPath $AnythingReport -PathType Leaf){
 try{$x=Get-Content -LiteralPath $AnythingReport -Raw|ConvertFrom-Json;$anythingPass=([string]$x.overall -eq 'PASS' -and $x.secretIncluded -eq $false)}catch{}
}
$workerPass=$false
if(Test-Path -LiteralPath $WorkerProof -PathType Leaf){
 try{$x=Get-Content -LiteralPath $WorkerProof -Raw|ConvertFrom-Json;$workerPass=([string]$x.state -eq 'PASS' -and $x.accepted -eq $true)}catch{}
}

$closeout=if($coreStill -and $rahOsFull -and $anythingPass -and $workerPass -and $popupStructure){'READY-FOR-REBOOT-CHECK'}else{'OPEN'}
$stable='OPEN'

L ('CORE_STILL_PASS='+$coreStill)
L ('ANYTHINGLLM_PASS='+$anythingPass)
L ('WORKER_PASS='+$workerPass)
L ('RAH_OS_FULL_PASS='+$rahOsFull)
L ('POPUP_STRUCTURE_PASS='+$popupStructure)
L ('CLOSEOUT='+$closeout)
L ('FULL_STABLE_GATE='+$stable)
L ("PASS=$pass PENDING=$pending FAIL=$fail")

$doc=[ordered]@{
 schema='rah-hoved-pc-full-gate-closeout-v1'
 timestamp=(Get-Date).ToUniversalTime().ToString('o')
 computer=$env:COMPUTERNAME
 coreStillPass=$coreStill
 anythingLlmPass=$anythingPass
 workerPass=$workerPass
 rahOsFullPass=$rahOsFull
 popupStructurePass=$popupStructure
 popupRebootVerification='PENDING'
 closeout=$closeout
 fullStableGate='OPEN'
 pass=$pass
 pending=$pending
 fail=$fail
 safety=[ordered]@{
  tokenIncluded=$false
  arbitraryShell=$false
  usbChanges=$false
  partitionChanges=$false
  biosChanges=$false
  bootloaderChanges=$false
  gpuCudaChanges=$false
 }
}
$doc|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $Json -Encoding UTF8

$cloud=$null
foreach($p in @(
 'G:\My Drive\RAH CLOUD\99_INBOX',
 'G:\RAH CLOUD\99_INBOX',
 "$env:USERPROFILE\My Drive\RAH CLOUD\99_INBOX",
 "$env:USERPROFILE\Google Drive\My Drive\RAH CLOUD\99_INBOX",
 "$env:USERPROFILE\Google Drive\RAH CLOUD\99_INBOX"
)){if(Test-Path -LiteralPath $p -PathType Container){$cloud=$p;break}}
if($cloud){
 try{
  Copy-Item -LiteralPath $Report -Destination (Join-Path $cloud 'RAH-HOVED-PC-FULL-GATE-CLOSEOUT-v1-LATEST.txt') -Force
  Copy-Item -LiteralPath $Json -Destination (Join-Path $cloud 'RAH-HOVED-PC-FULL-GATE-CLOSEOUT-v1-LATEST.json') -Force
  if(Test-Path -LiteralPath $AnythingReport){Copy-Item -LiteralPath $AnythingReport -Destination (Join-Path $cloud 'ANYTHINGLLM-APPROVAL-LATEST.json') -Force}
  if(Test-Path -LiteralPath $WorkerProof){Copy-Item -LiteralPath $WorkerProof -Destination (Join-Path $cloud 'RAVEN-WORKER-PROOF-LATEST.json') -Force}
  if(Test-Path -LiteralPath $OsAcceptance){Copy-Item -LiteralPath $OsAcceptance -Destination (Join-Path $cloud 'RAH-OS-v0.8-ACCEPTANCE-LATEST.json') -Force}
  P ('Cloud handoff PASS: '+$cloud)
 }catch{F ('Cloud handoff failed: '+$_.Exception.Message)}
}else{N 'Cloud handoff path not found.'}

if($closeout -eq 'READY-FOR-REBOOT-CHECK'){exit 0}
exit 2
