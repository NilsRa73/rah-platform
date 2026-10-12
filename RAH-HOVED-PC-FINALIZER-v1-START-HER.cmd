@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>nul
title RAH HOVED-PC FINALIZER v1

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
echo             RAH HOVED-PC FINALIZER v1
echo ============================================================
echo Raven ^> Elevated Jobs ^> Real Job ^> Gemma ^> RAH OS ^> Gates
echo One file. Local-first. One final report.
echo ============================================================
echo.

set "RAH_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$t=Get-Content -LiteralPath $env:RAH_SELF -Raw;$p=($t -split '(?m)^### RAH_FINALIZER_PS ###\r?\n',2)[1];Invoke-Expression $p"
set "RC=%ERRORLEVEL%"

echo.
echo ============================================================
if "%RC%"=="0" echo RAH HOVED-PC FINALIZER: CORE PASS
if not "%RC%"=="0" echo RAH HOVED-PC FINALIZER: GATES STILL OPEN
echo Report: C:\RAH\Logs\RAH-HOVED-PC-FINALIZER-v1-LATEST.txt
echo JSON  : C:\RAH\Logs\RAH-HOVED-PC-FINALIZER-v1-LATEST.json
echo ============================================================
echo.
pause
exit /b %RC%

### RAH_FINALIZER_PS ###
Set-StrictMode -Version Latest
$ErrorActionPreference='Continue'

$Root='C:\RAH'
$Logs=Join-Path $Root 'Logs'
$RavenOS=Join-Path $Root 'RavenOS'
$Core=Join-Path $Root 'RavenCore7'
$Report=Join-Path $Logs 'RAH-HOVED-PC-FINALIZER-v1-LATEST.txt'
$Json=Join-Path $Logs 'RAH-HOVED-PC-FINALIZER-v1-LATEST.json'
$JobProof=Join-Path $Core 'state\job-executor-proof.json'
$OsAcceptance=Join-Path $RavenOS 'state\RAH-OS-v0.8-ACCEPTANCE.json'
$WorkerProof=Join-Path $Core 'state\worker-proof.json'
New-Item -ItemType Directory -Force -Path $Logs,(Join-Path $Core 'state')|Out-Null

$pass=0;$pending=0;$fail=0
$state=[ordered]@{
 raven=$false
 jobs=$false
 realJob=$false
 ai=$false
 rahOsCore=$false
 rahOsFull=$false
 anything=$false
 worker=$false
 popupStructure=$false
 popupReboot='PENDING'
 cloudHandoff=$false
}

function L([string]$s=''){Write-Host $s;Add-Content -LiteralPath $Report -Value $s -Encoding UTF8}
function P([string]$s){$script:pass++;L "[PASS] $s"}
function N([string]$s){$script:pending++;L "[PENDING] $s"}
function F([string]$s){$script:fail++;L "[FAIL] $s"}
function S([string]$s){L '';L '============================================================';L $s;L '============================================================'}
function J([string]$u,[int]$t=5){try{Invoke-RestMethod -Uri $u -TimeoutSec $t -ErrorAction Stop}catch{$null}}

@(
 'RAH HOVED-PC FINALIZER v1',
 ('Computer: '+$env:COMPUTERNAME),
 ('UTC: '+(Get-Date).ToUniversalTime().ToString('o')),
 'Safety: local-only runtime checks; no downloads; no disk/USB/BIOS/boot/GPU-CUDA changes.',
 ''
)|Set-Content -LiteralPath $Report -Encoding UTF8

S '1/7 RAVEN CANDIDATE.4 + ELEVATED JOB EXECUTOR'
$h=J 'http://127.0.0.1:18765/health' 3
$apps=J 'http://127.0.0.1:18765/apps/status' 3
if($h -and $h.ok -eq $true -and [string]$h.name -eq 'RAH Raven Desktop Bridge' -and
   $h.app_launcher -eq $true -and [string]$h.app_launcher_mode -eq 'fixed-allowlist-explicit-launch' -and
   $h.agent_runner -eq $true -and [string]$h.agent_runner_mode -eq 'read-only-allowlist' -and
   $null-ne$apps.apps.PSObject.Properties['world-media'] -and
   $null-ne$apps.apps.PSObject.Properties['rah-os'] -and
   $null-ne$apps.apps.PSObject.Properties['raven-browser']){
  $state.raven=$true;P 'Candidate.4 Bridge/App Launcher/Agent Runner PASS.'
}else{F 'Candidate.4 Raven readiness is not PASS.'}

$jobs=J 'http://127.0.0.1:18765/agent/jobs/health' 3
if(-not($jobs -and $jobs.ready -eq $true -and $jobs.elevated -eq $true)){
  try{
    $task=Get-ScheduledTask -TaskName 'RAH Raven Bridge' -ErrorAction Stop
    if([string]$task.Principal.RunLevel -ne 'Highest'){throw 'RunLevel is not Highest.'}
    L 'ACTION: starting existing Highest RAH Raven Bridge task.'
    Start-ScheduledTask -TaskName 'RAH Raven Bridge' -ErrorAction Stop
    $end=(Get-Date).AddSeconds(45)
    do{
      Start-Sleep -Milliseconds 500
      $jobs=J 'http://127.0.0.1:18765/agent/jobs/health' 3
      if($jobs -and $jobs.ready -eq $true -and $jobs.elevated -eq $true){break}
    }while((Get-Date)-lt$end)
  }catch{L ('Elevation repair note: '+$_.Exception.Message)}
}
if($jobs -and $jobs.ready -eq $true -and $jobs.elevated -eq $true){
  $state.jobs=$true;P 'Job Executor ready + elevated.'
}else{F 'Job Executor is not ready + elevated.'}

# Re-check Candidate.4 after any elevated bridge switch.
$h=J 'http://127.0.0.1:18765/health' 3
$apps=J 'http://127.0.0.1:18765/apps/status' 3
if($h -and $h.app_launcher -eq $true -and $h.agent_runner -eq $true -and
   $null-ne$apps.apps.PSObject.Properties['world-media'] -and
   $null-ne$apps.apps.PSObject.Properties['rah-os'] -and
   $null-ne$apps.apps.PSObject.Properties['raven-browser']){
  $state.raven=$true;P 'Candidate.4 compatibility PASS after elevated bridge check.'
}else{$state.raven=$false;F 'Candidate.4 compatibility regressed after elevated bridge check.'}

S '2/7 REAL JOB EXECUTOR PROOF'
if($state.jobs){
  try{
    $client='finalizer-'+[guid]::NewGuid().ToString('N').Substring(0,12)
    $body=@{capability='system-inventory';confirm=$true;client_request_id=$client}|ConvertTo-Json
    $submit=Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:18765/agent/jobs' -ContentType 'application/json' -Body $body -TimeoutSec 15 -ErrorAction Stop
    if($submit.accepted -ne $true){throw 'Job not accepted.'}
    $id=[string]$submit.job.id
    $end=(Get-Date).AddSeconds(45)
    $poll=$null
    do{
      Start-Sleep -Milliseconds 300
      $poll=J ('http://127.0.0.1:18765/agent/jobs/'+$id) 8
      if($poll -and [string]$poll.job.status -in @('succeeded','failed')){break}
    }while((Get-Date)-lt$end)
    if(-not$poll -or [string]$poll.job.status -ne 'succeeded'){throw ('Job status='+[string]$poll.job.status)}
    $r=$poll.job.result
    if($r.ok -ne $true -or $r.read_only -ne $true -or $r.files_modified -ne $false -or
       $r.arbitrary_commands -ne $false -or [string]$r.execution_mode -ne 'queued-after-explicit-confirm' -or
       @($r.tools_executed) -notcontains 'system-inventory'){throw 'Read-only Job Executor safety contract failed.'}
    $state.realJob=$true
    $proof=[ordered]@{
      schema='rah-raven-job-executor-proof-v1';version='1.0.0';timestamp=(Get-Date).ToUniversalTime().ToString('o')
      computer=$env:COMPUTERNAME;overall='PASS';detail='Real system-inventory job succeeded under elevated Raven.'
      evidence=[ordered]@{jobId=$id;capability='system-inventory';readOnly=$true;filesModified=$false;arbitraryCommands=$false;executionMode=[string]$r.execution_mode}
      safety=[ordered]@{externalNetwork=$false;secretsRead=$false}
    }
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $JobProof)|Out-Null
    $proof|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $JobProof -Encoding UTF8
    P 'Real queued system-inventory job PASS with read-only safety contract.'
  }catch{F ('Real Job Executor proof failed: '+$_.Exception.Message)}
}else{F 'Real Job Executor proof skipped because executor is not elevated.'}

S '3/7 GEMMA 3 4B REAL INFERENCE'
try{
  $m=Invoke-RestMethod -Uri 'http://127.0.0.1:1234/v1/models' -TimeoutSec 5 -ErrorAction Stop
  $model=if($m.data -and @($m.data).Count){[string]$m.data[0].id}else{''}
  if($model -notmatch 'gemma-3-4b'){throw ('Unexpected model='+$model)}
  $b=@{model=$model;messages=@(@{role='user';content='Reply with exactly RAH_OK'});temperature=0;max_tokens=12;stream=$false}|ConvertTo-Json -Depth 5
  $a=Invoke-RestMethod -Uri 'http://127.0.0.1:1234/v1/chat/completions' -Method Post -ContentType 'application/json' -Body $b -TimeoutSec 30 -ErrorAction Stop
  if([string]$a.choices[0].message.content -notmatch 'RAH_OK'){throw 'Inference did not return RAH_OK.'}
  $state.ai=$true;P ('Gemma real inference PASS: '+$model)
}catch{F ('Gemma inference FAIL: '+$_.Exception.Message)}

S '4/7 RAH OS v0.8 EVIDENCE-FIRST ACCEPTANCE'
$accept=Join-Path $RavenOS 'RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1'
if(Test-Path -LiteralPath $accept -PathType Leaf){
  & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $accept -JsonOnly 2>&1|ForEach-Object{L ([string]$_)}
  try{
    $o=Get-Content -LiteralPath $OsAcceptance -Raw|ConvertFrom-Json -ErrorAction Stop
    if([string]$o.coreOverall -eq 'PASS'){$state.rahOsCore=$true;P 'RAH OS coreOverall=PASS.'}
    else{F ('RAH OS coreOverall='+[string]$o.coreOverall)}
    if([string]$o.overall -eq 'PASS'){$state.rahOsFull=$true;P 'RAH OS full overall=PASS.'}
    else{N 'RAH OS full overall remains FAIL until deferred full gates are complete.'}
  }catch{F 'RAH OS acceptance JSON missing/invalid.'}
}else{F 'RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1 missing locally.'}

S '5/7 ANYTHINGLLM + WORKER PROOF'
$approval=J 'http://127.0.0.1:18765/agent/approval/status' 5
if($approval -and $approval.ok -eq $true -and $approval.configured -eq $true){
  $test=$null
  foreach($p in @(
    (Join-Path $RavenOS 'TEST-ANYTHINGLLM-APPROVAL.ps1'),
    'C:\RAH\AI-Fabric\rah-platform\TEST-ANYTHINGLLM-APPROVAL.ps1',
    'C:\RAH\TEST-ANYTHINGLLM-APPROVAL.ps1'
  )){if(Test-Path -LiteralPath $p -PathType Leaf){$test=$p;break}}
  if($test){
    & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $test 2>&1|ForEach-Object{L ([string]$_)}
    if($LASTEXITCODE -eq 0){$state.anything=$true;P 'AnythingLLM approval end-to-end PASS.'}
    else{N 'AnythingLLM configured but approval test is not PASS.'}
  }else{N 'AnythingLLM configured; approval test script not found locally.'}
}else{N 'AnythingLLM needs one-time local token/workspace configuration.'}

$workerScript=$null
foreach($p in @(
  (Join-Path $RavenOS 'RAVEN-CORE-7-WORKER-PROOF.ps1'),
  'C:\RAH\RavenCore7\RAVEN-CORE-7-WORKER-PROOF.ps1',
  'C:\RAH\RAVEN-CORE-7-WORKER-PROOF.ps1',
  'C:\RAH\AI-Fabric\rah-platform\RAVEN-CORE-7-WORKER-PROOF.ps1'
)){if(Test-Path -LiteralPath $p -PathType Leaf){$workerScript=$p;break}}
if($workerScript){
  & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $workerScript -Mode Validate -JsonOnly 2>&1|ForEach-Object{L ([string]$_)}
  if($LASTEXITCODE -eq 0){$state.worker=$true;P 'Worker Proof real-hardware evidence PASS.'}
  else{N 'Worker Proof real-hardware evidence remains pending.'}
}else{N 'Worker Proof validator not found locally.'}

S '6/7 POWERSHELL POPUP STRUCTURAL CHECK'
try{
  $bad=@()
  foreach($t in @(Get-ScheduledTask -ErrorAction Stop|Where-Object{($_.TaskPath+$_.TaskName) -match '(?i)RAH|RAVEN|STORM|NETLINK'})){
    foreach($a in @($t.Actions)){
      if($a.Execute -match '(?i)(powershell|pwsh)(\.exe)?$' -and $a.Arguments -notmatch '(?i)(^|\s)-WindowStyle\s+(Hidden|0)(\s|$)'){
        $bad+=($t.TaskPath+$t.TaskName)
      }
    }
  }
  if($bad.Count -eq 0){$state.popupStructure=$true;P 'All RAH/Raven/Storm/NetLink scheduled PowerShell actions are structurally hidden.'}
  else{N ('Visible PowerShell task actions remain: '+(($bad|Sort-Object -Unique)-join ', '))}
}catch{N ('Popup task structural check warning: '+$_.Exception.Message)}
N 'Popup runtime reboot verification remains PENDING until observed after reboot.'

S '7/7 FINAL GATES + CLOUD HANDOFF'
$coreGate=if($state.raven -and $state.jobs -and $state.realJob -and $state.ai -and $state.rahOsCore){'PASS'}else{'OPEN'}
$fullStable=if($state.rahOsFull -and $state.anything -and $state.worker -and $state.popupStructure -and $state.popupReboot -eq 'PASS'){'PASS'}else{'OPEN'}

L ('RAVEN_READY='+$state.raven)
L ('JOB_EXECUTOR_READY='+$state.jobs)
L ('REAL_JOB_PROOF='+$state.realJob)
L ('LOCAL_AI_READY='+$state.ai)
L ('RAH_OS_CORE_READY='+$state.rahOsCore)
L ('RAH_OS_FULL_READY='+$state.rahOsFull)
L ('ANYTHINGLLM_READY='+$state.anything)
L ('WORKER_READY='+$state.worker)
L ('POPUP_STRUCTURE='+$state.popupStructure)
L ('POPUP_REBOOT='+$state.popupReboot)
L ('CORE_GATE='+$coreGate)
L ('FULL_STABLE_GATE='+$fullStable)
L ("PASS=$pass PENDING=$pending FAIL=$fail")

$doc=[ordered]@{
 schema='rah-hoved-pc-finalizer-v1'
 timestamp=(Get-Date).ToUniversalTime().ToString('o')
 computer=$env:COMPUTERNAME
 coreGate=$coreGate
 fullStableGate=$fullStable
 ravenReady=$state.raven
 jobExecutorReady=$state.jobs
 realJobProof=$state.realJob
 localAiReady=$state.ai
 rahOsCoreReady=$state.rahOsCore
 rahOsFullReady=$state.rahOsFull
 anythingLlmReady=$state.anything
 workerReady=$state.worker
 popupStructure=$state.popupStructure
 popupRebootVerification=$state.popupReboot
 pass=$pass
 pending=$pending
 fail=$fail
 safety=[ordered]@{
  externalDownloads=$false
  usbChanges=$false
  partitionChanges=$false
  biosChanges=$false
  bootloaderChanges=$false
  gpuCudaChanges=$false
  arbitraryCommands=$false
  secretsRead=$false
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
)){
 if(Test-Path -LiteralPath $p -PathType Container){$cloud=$p;break}
}
if($cloud){
 try{
  Copy-Item -LiteralPath $Report -Destination (Join-Path $cloud 'RAH-HOVED-PC-FINALIZER-v1-LATEST.txt') -Force
  Copy-Item -LiteralPath $Json -Destination (Join-Path $cloud 'RAH-HOVED-PC-FINALIZER-v1-LATEST.json') -Force
  if(Test-Path -LiteralPath $JobProof){Copy-Item -LiteralPath $JobProof -Destination (Join-Path $cloud 'RAVEN-JOB-EXECUTOR-PROOF-LATEST.json') -Force}
  if(Test-Path -LiteralPath $OsAcceptance){Copy-Item -LiteralPath $OsAcceptance -Destination (Join-Path $cloud 'RAH-OS-v0.8-ACCEPTANCE-LATEST.json') -Force}
  if(Test-Path -LiteralPath $WorkerProof){Copy-Item -LiteralPath $WorkerProof -Destination (Join-Path $cloud 'RAVEN-WORKER-PROOF-LATEST.json') -Force}
  $state.cloudHandoff=$true
  L ('CLOUD_HANDOFF='+$cloud)
 }catch{L ('CLOUD_HANDOFF_ERROR='+$_.Exception.Message)}
}else{L 'CLOUD_HANDOFF=NOT_FOUND'}

if($coreGate -eq 'PASS'){
 L 'CORE FINAL: PASS'
 L 'FULL FINAL: OPEN until the remaining full gates are actually verified.'
 exit 0
}
L 'CORE FINAL: OPEN'
L 'FULL FINAL: OPEN'
exit 2
