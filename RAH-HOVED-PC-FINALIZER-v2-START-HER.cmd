@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>nul
title RAH HOVED-PC FINALIZER v2 - PINNED RUNTIME CLOSEOUT

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
echo   RAH HOVED-PC FINALIZER v2 - PINNED RUNTIME CLOSEOUT
echo ============================================================
echo Pinned source ^> Elevated Raven ^> Real Job ^> Gemma ^> OS
echo One large repair. Stable v0.4 untouched.
echo ============================================================
echo.

set "RAH_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$t=Get-Content -LiteralPath $env:RAH_SELF -Raw;$p=($t -split '(?m)^### RAH_FINALIZER_V2_PS ###\r?\n',2)[1];Invoke-Expression $p"
set "RC=%ERRORLEVEL%"

echo.
echo ============================================================
if "%RC%"=="0" echo RAH HOVED-PC FINALIZER v2: CORE PASS
if not "%RC%"=="0" echo RAH HOVED-PC FINALIZER v2: GATES STILL OPEN
echo Report: C:\RAH\Logs\RAH-HOVED-PC-FINALIZER-v2-LATEST.txt
echo JSON  : C:\RAH\Logs\RAH-HOVED-PC-FINALIZER-v2-LATEST.json
echo ============================================================
echo.
pause
exit /b %RC%

### RAH_FINALIZER_V2_PS ###
Set-StrictMode -Version Latest
$ErrorActionPreference='Continue'

$Pinned='c05e11ad7a6d15153efff50dd982295469980091'
$ArchiveUrl='https://github.com/NilsRa73/rah-platform/archive/'+$Pinned+'.zip'
$Root='C:\RAH'
$Logs=Join-Path $Root 'Logs'
$Backups=Join-Path $Root 'Backups\HOVED-PC-Finalizer-v2'
$Runtime=Join-Path $Root 'Runtime\RavenElevated'
$Cache=Join-Path $Root 'Cache'
$Source=Join-Path $Runtime 'rah-platform'
$Marker=Join-Path $Runtime 'PINNED-COMMIT.txt'
$LauncherPs=Join-Path $Runtime 'START-RAH-ELEVATED.ps1'
$RavenOS=Join-Path $Root 'RavenOS'
$Core=Join-Path $Root 'RavenCore7'
$Report=Join-Path $Logs 'RAH-HOVED-PC-FINALIZER-v2-LATEST.txt'
$Json=Join-Path $Logs 'RAH-HOVED-PC-FINALIZER-v2-LATEST.json'
$JobProof=Join-Path $Core 'state\job-executor-proof.json'
$OsAcceptance=Join-Path $RavenOS 'state\RAH-OS-v0.8-ACCEPTANCE.json'
$WorkerProof=Join-Path $Core 'state\worker-proof.json'
$Archive=Join-Path $Cache ('rah-platform-'+$Pinned+'.zip')
$TaskName='RAH Raven Bridge'
$Utf8=New-Object Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force -Path $Logs,$Backups,$Runtime,$Cache,$RavenOS,(Join-Path $Core 'state')|Out-Null
$pass=0;$pending=0;$fail=0
$state=[ordered]@{
 source=$false
 python=$false
 task=$false
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
 cloud=$false
}

function L([string]$s=''){Write-Host $s;Add-Content -LiteralPath $Report -Value $s -Encoding UTF8}
function P([string]$s){$script:pass++;L "[PASS] $s"}
function N([string]$s){$script:pending++;L "[PENDING] $s"}
function F([string]$s){$script:fail++;L "[FAIL] $s"}
function S([string]$s){L '';L '============================================================';L $s;L '============================================================'}
function J([string]$u,[int]$t=5){try{Invoke-RestMethod -Uri $u -TimeoutSec $t -ErrorAction Stop}catch{$null}}
function Backup-File([string]$Path){
 if(Test-Path -LiteralPath $Path -PathType Leaf){
  $name=[IO.Path]::GetFileName($Path)
  Copy-Item -LiteralPath $Path -Destination (Join-Path $Backups ($name+'.before-v2')) -Force
 }
}

@(
 'RAH HOVED-PC FINALIZER v2',
 ('Computer: '+$env:COMPUTERNAME),
 ('UTC: '+(Get-Date).ToUniversalTime().ToString('o')),
 ('Pinned runtime source: '+$Pinned),
 'Safety: side-by-side runtime; backups before candidate acceptance refresh; stable v0.4 untouched.',
 ''
)|Set-Content -LiteralPath $Report -Encoding UTF8

S '1/8 PINNED SOURCE CACHE + LOCAL RUNTIME'
$sourceOk=$false
if((Test-Path -LiteralPath $Marker -PathType Leaf) -and
   ((Get-Content -LiteralPath $Marker -Raw).Trim() -eq $Pinned) -and
   (Test-Path -LiteralPath (Join-Path $Source 'desktop-bridge\raven_bridge_agent.py') -PathType Leaf) -and
   (Test-Path -LiteralPath (Join-Path $Source 'RAVEN-JOB-EXECUTOR-PROOF.ps1') -PathType Leaf)){
  $sourceOk=$true
  P 'Existing pinned runtime cache validated.'
}
if(-not$sourceOk){
  try{
    L ('Downloading one pinned green source archive: '+$Pinned)
    & curl.exe -L --fail --silent --show-error --max-time 120 -o $Archive $ArchiveUrl
    if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $Archive -PathType Leaf)){throw 'Pinned archive download failed.'}
    if((Get-Item -LiteralPath $Archive).Length -lt 100000){throw 'Pinned archive is unexpectedly small.'}
    $extract=Join-Path $Runtime '_extract'
    if(Test-Path -LiteralPath $extract){Remove-Item -LiteralPath $extract -Recurse -Force}
    New-Item -ItemType Directory -Force -Path $extract|Out-Null
    Expand-Archive -LiteralPath $Archive -DestinationPath $extract -Force
    $folder=Get-ChildItem -LiteralPath $extract -Directory|Select-Object -First 1
    if(-not$folder){throw 'Archive did not contain a source folder.'}
    if(Test-Path -LiteralPath $Source){Remove-Item -LiteralPath $Source -Recurse -Force}
    Move-Item -LiteralPath $folder.FullName -Destination $Source
    Remove-Item -LiteralPath $extract -Recurse -Force
    [IO.File]::WriteAllText($Marker,$Pinned+[Environment]::NewLine,$Utf8)
    $sourceOk=$true
  }catch{F ('Pinned source preparation failed: '+$_.Exception.Message)}
}
$required=@(
 'desktop-bridge\raven_bridge_agent.py',
 'desktop-bridge\raven_bridge.py',
 'desktop-bridge\raven_jobs.py',
 'desktop-bridge\raven_ai_fabric.py',
 'desktop-bridge\raven_project_memory.py',
 'desktop-bridge\raven_council.py',
 'desktop-bridge\agent_runner.py',
 'RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1',
 'RAH-OS-v0.8-SELFTEST.ps1',
 'RAVEN-CORE-7.ps1',
 'RAVEN-AI-SELF-CHECK.ps1',
 'TEST-ANYTHINGLLM-APPROVAL.ps1',
 'RAVEN-CORE-7-WORKER-PROOF.ps1',
 'RAVEN-JOB-EXECUTOR-PROOF.ps1'
)
if($sourceOk){
  $missing=@($required|Where-Object{-not(Test-Path -LiteralPath (Join-Path $Source $_) -PathType Leaf)})
  if($missing.Count -eq 0){$state.source=$true;P 'Pinned source contains all required Raven/RAH OS closeout files.'}
  else{F ('Pinned source is incomplete: '+($missing -join ', '))}
}

S '2/8 REFRESH CANDIDATE ACCEPTANCE FILES WITH BACKUP'
if($state.source){
  foreach($name in @(
   'RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1',
   'RAH-OS-v0.8-SELFTEST.ps1',
   'RAVEN-CORE-7.ps1',
   'RAVEN-AI-SELF-CHECK.ps1',
   'TEST-ANYTHINGLLM-APPROVAL.ps1',
   'RAVEN-CORE-7-WORKER-PROOF.ps1'
  )){
    $dst=Join-Path $RavenOS $name
    Backup-File $dst
    Copy-Item -LiteralPath (Join-Path $Source $name) -Destination $dst -Force
  }
  $proofDst=Join-Path $Core 'RAVEN-JOB-EXECUTOR-PROOF.ps1'
  Backup-File $proofDst
  Copy-Item -LiteralPath (Join-Path $Source 'RAVEN-JOB-EXECUTOR-PROOF.ps1') -Destination $proofDst -Force
  try{
    $raw=Get-Content -LiteralPath (Join-Path $RavenOS 'RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1') -Raw
    if($raw -notmatch 'coreOverall'){throw 'Refreshed acceptance does not expose coreOverall.'}
    P 'RAH OS v0.8 candidate acceptance refreshed from pinned source; backups preserved.'
  }catch{F ('Candidate acceptance refresh validation failed: '+$_.Exception.Message)}
}

S '3/8 PYTHON RUNTIME + ELEVATED RAVEN TASK'
$python=$null
$candidates=@(
 "$env:USERPROFILE\Desktop\RAH AI Studios\desktop-bridge\.venv\Scripts\python.exe",
 'C:\RAH\AI-Fabric\venv\Scripts\python.exe',
 'C:\RAH\Runtime\Python\Scripts\python.exe',
 (Join-Path $Source 'desktop-bridge\.venv\Scripts\python.exe')
)
foreach($p in $candidates){
 if(-not$p -or -not(Test-Path -LiteralPath $p -PathType Leaf)){continue}
 try{
  & $p -c "import flask,flask_cors,PIL,mss,pypdf" 2>$null
  if($LASTEXITCODE -eq 0){$python=$p;break}
 }catch{}
}
if($python){$state.python=$true;P ('Working Raven Python runtime: '+$python)}
else{F 'No working local Python runtime with Raven dependencies was found.'}

if($state.source -and $state.python){
  $launchTemplate=@'
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$env:RAH_BRIDGE_HOST='127.0.0.1'
$env:RAH_BRIDGE_PORT='18765'
$env:RAH_JOB_DIR='C:\RAH\AgentJobs'
$env:RAH_JOB_REQUIRE_ADMIN='1'
$env:RAH_AI_AUTO_START_LMSTUDIO='1'
$env:RAH_AI_AUTO_START_ANYTHINGLLM='1'
$python='__PYTHON__'
$bridgeDir='__BRIDGE_DIR__'
$log='__LOG__'
$err='__ERR__'
$listeners=@(Get-NetTCPConnection -LocalPort 18765 -State Listen -ErrorAction SilentlyContinue)
if($listeners.Count){
 try{$h=Invoke-RestMethod -Uri 'http://127.0.0.1:18765/health' -TimeoutSec 2}catch{exit 6}
 if([string]$h.name -ne 'RAH Raven Desktop Bridge'){exit 6}
 foreach($owner in @($listeners|Select-Object -ExpandProperty OwningProcess -Unique)){
  Stop-Process -Id ([int]$owner) -Force -ErrorAction Stop
 }
}
Start-Sleep -Milliseconds 700
Start-Process -FilePath $python -ArgumentList 'raven_bridge_agent.py' -WorkingDirectory $bridgeDir -WindowStyle Hidden -RedirectStandardOutput $log -RedirectStandardError $err
exit 0
'@
  $launchText=$launchTemplate.Replace('__PYTHON__',$python.Replace("'","''")).Replace('__BRIDGE_DIR__',(Join-Path $Source 'desktop-bridge').Replace("'","''")).Replace('__LOG__',(Join-Path $Runtime 'bridge.log').Replace("'","''")).Replace('__ERR__',(Join-Path $Runtime 'bridge.err.log').Replace("'","''"))
  [IO.File]::WriteAllText($LauncherPs,$launchText,$Utf8)

  try{
    $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ('-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}"' -f $LauncherPs) -WorkingDirectory $Runtime
    $trigger=New-ScheduledTaskTrigger -AtLogOn -User $user
    $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
    $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 20 -RestartInterval (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description ('RAH Raven pinned elevated runtime '+$Pinned) -Force|Out-Null
    $state.task=$true
    P 'RAH Raven Bridge task repointed to pinned side-by-side runtime with RunLevel Highest.'
  }catch{F ('Scheduled task registration failed: '+$_.Exception.Message)}

  if($state.task){
    try{Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop}catch{F ('Could not start Raven task: '+$_.Exception.Message)}
    $end=(Get-Date).AddSeconds(60)
    do{
      Start-Sleep -Milliseconds 500
      $j=J 'http://127.0.0.1:18765/agent/jobs/health' 3
      $h=J 'http://127.0.0.1:18765/health' 3
      $a=J 'http://127.0.0.1:18765/apps/status' 3
      if($j -and $j.ready -eq $true -and $j.elevated -eq $true -and
         $h -and $h.app_launcher -eq $true -and $h.agent_runner -eq $true -and
         $null-ne$a.apps.PSObject.Properties['world-media'] -and
         $null-ne$a.apps.PSObject.Properties['rah-os'] -and
         $null-ne$a.apps.PSObject.Properties['raven-browser']){
        $state.jobs=$true;$state.raven=$true;break
      }
    }while((Get-Date)-lt$end)
  }
}
if($state.jobs){P 'Elevated Job Executor ready on pinned runtime.'}else{
 F 'Elevated Job Executor did not become ready.'
 if(Test-Path -LiteralPath (Join-Path $Runtime 'bridge.err.log')){Get-Content -LiteralPath (Join-Path $Runtime 'bridge.err.log') -Tail 40|ForEach-Object{L ('BRIDGE_ERR: '+[string]$_)}}
}
if($state.raven){P 'Candidate.4 App Launcher/Agent Runner remain compatible on pinned elevated runtime.'}else{F 'Candidate.4 compatibility not verified on pinned elevated runtime.'}

S '4/8 REAL JOB EXECUTOR PROOF'
$proofScript=Join-Path $Core 'RAVEN-JOB-EXECUTOR-PROOF.ps1'
if($state.jobs -and (Test-Path -LiteralPath $proofScript -PathType Leaf)){
  & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $proofScript -Mode Validate -JsonOnly 2>&1|ForEach-Object{L ([string]$_)}
  if($LASTEXITCODE -eq 0){
    try{
      $jp=Get-Content -LiteralPath $JobProof -Raw|ConvertFrom-Json
      if([string]$jp.overall -eq 'PASS' -and $jp.safety.readOnly -eq $true -and $jp.safety.arbitraryCommands -eq $false){
        $state.realJob=$true;P 'Canonical real Job Executor proof PASS.'
      }else{F 'Job Executor proof JSON did not satisfy safety contract.'}
    }catch{F 'Job Executor proof JSON missing/invalid.'}
  }else{F 'Canonical real Job Executor proof returned non-zero.'}
}else{F 'Job Executor proof could not run.'}

S '5/8 GEMMA 3 4B REAL INFERENCE'
try{
  $m=Invoke-RestMethod -Uri 'http://127.0.0.1:1234/v1/models' -TimeoutSec 5 -ErrorAction Stop
  $model=if($m.data -and @($m.data).Count){[string]$m.data[0].id}else{''}
  if($model -notmatch 'gemma-3-4b'){throw ('Unexpected model='+$model)}
  $body=@{model=$model;messages=@(@{role='user';content='Reply with exactly RAH_OK'});temperature=0;max_tokens=12;stream=$false}|ConvertTo-Json -Depth 5
  $ans=Invoke-RestMethod -Uri 'http://127.0.0.1:1234/v1/chat/completions' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 30 -ErrorAction Stop
  if([string]$ans.choices[0].message.content -notmatch 'RAH_OK'){throw 'Inference did not return RAH_OK.'}
  $state.ai=$true;P ('Gemma real inference PASS: '+$model)
}catch{F ('Gemma inference FAIL: '+$_.Exception.Message)}

S '6/8 RAH OS CORE + FULL ACCEPTANCE'
$accept=Join-Path $RavenOS 'RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1'
if(Test-Path -LiteralPath $accept -PathType Leaf){
  & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $accept -JsonOnly 2>&1|ForEach-Object{L ([string]$_)}
  try{
    $o=Get-Content -LiteralPath $OsAcceptance -Raw|ConvertFrom-Json
    if([string]$o.version -ne '0.8.2-evidence-first'){N ('Acceptance version='+[string]$o.version+'; expected 0.8.2-evidence-first')}
    if([string]$o.coreOverall -eq 'PASS'){$state.rahOsCore=$true;P 'RAH OS coreOverall=PASS.'}
    else{F ('RAH OS coreOverall='+[string]$o.coreOverall)}
    if([string]$o.overall -eq 'PASS'){$state.rahOsFull=$true;P 'RAH OS full overall=PASS.'}
    else{N 'RAH OS full overall remains FAIL until full gates are complete.'}
  }catch{F ('RAH OS acceptance JSON missing/invalid: '+$_.Exception.Message)}
}else{F 'Pinned RAH OS acceptance script is missing locally after refresh.'}

S '7/8 ANYTHINGLLM + WORKER + POPUP'
$approval=J 'http://127.0.0.1:18765/agent/approval/status' 5
if($approval -and $approval.ok -eq $true -and $approval.configured -eq $true){
  $test=Join-Path $RavenOS 'TEST-ANYTHINGLLM-APPROVAL.ps1'
  if(Test-Path -LiteralPath $test -PathType Leaf){
    & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $test 2>&1|ForEach-Object{L ([string]$_)}
    if($LASTEXITCODE -eq 0){$state.anything=$true;P 'AnythingLLM approval end-to-end PASS.'}
    else{N 'AnythingLLM configured but end-to-end approval is not PASS.'}
  }else{N 'AnythingLLM approval test missing.'}
}else{N 'AnythingLLM needs one-time local token/workspace configuration.'}

$workerScript=Join-Path $RavenOS 'RAVEN-CORE-7-WORKER-PROOF.ps1'
if(Test-Path -LiteralPath $workerScript -PathType Leaf){
  & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $workerScript -Mode Validate -JsonOnly 2>&1|ForEach-Object{L ([string]$_)}
  if($LASTEXITCODE -eq 0){$state.worker=$true;P 'Worker Proof real-hardware evidence PASS.'}
  else{N 'Worker Proof real-hardware evidence remains pending.'}
}else{N 'Worker Proof validator missing.'}

try{
 $bad=@()
 foreach($t in @(Get-ScheduledTask -ErrorAction Stop|Where-Object{($_.TaskPath+$_.TaskName) -match '(?i)RAH|RAVEN|STORM|NETLINK'})){
  foreach($a in @($t.Actions)){
   if($a.Execute -match '(?i)(powershell|pwsh)(\.exe)?$' -and $a.Arguments -notmatch '(?i)(^|\s)-WindowStyle\s+(Hidden|0)(\s|$)'){$bad+=($t.TaskPath+$t.TaskName)}
  }
 }
 if($bad.Count -eq 0){$state.popupStructure=$true;P 'RAH scheduled PowerShell actions structurally hidden.'}
 else{N ('Visible RAH PowerShell task actions remain: '+(($bad|Sort-Object -Unique)-join ', '))}
}catch{N ('Popup structure check warning: '+$_.Exception.Message)}
N 'Popup reboot observation remains PENDING.'

S '8/8 FINAL GATES + VERIFIED CLOUD HANDOFF'
$coreGate=if($state.source -and $state.python -and $state.task -and $state.raven -and $state.jobs -and $state.realJob -and $state.ai -and $state.rahOsCore){'PASS'}else{'OPEN'}
$fullStable=if($state.rahOsFull -and $state.anything -and $state.worker -and $state.popupStructure -and $state.popupReboot -eq 'PASS'){'PASS'}else{'OPEN'}

foreach($kv in [ordered]@{
 PINNED_SOURCE=$state.source;PYTHON_READY=$state.python;RAVEN_TASK=$state.task;RAVEN_READY=$state.raven;
 JOB_EXECUTOR_READY=$state.jobs;REAL_JOB_PROOF=$state.realJob;LOCAL_AI_READY=$state.ai;
 RAH_OS_CORE_READY=$state.rahOsCore;RAH_OS_FULL_READY=$state.rahOsFull;ANYTHINGLLM_READY=$state.anything;
 WORKER_READY=$state.worker;POPUP_STRUCTURE=$state.popupStructure;POPUP_REBOOT=$state.popupReboot;
 CORE_GATE=$coreGate;FULL_STABLE_GATE=$fullStable
}.GetEnumerator()){L ($kv.Key+'='+$kv.Value)}
L ("PASS=$pass PENDING=$pending FAIL=$fail")

$doc=[ordered]@{
 schema='rah-hoved-pc-finalizer-v2';timestamp=(Get-Date).ToUniversalTime().ToString('o');computer=$env:COMPUTERNAME;
 pinnedCommit=$Pinned;coreGate=$coreGate;fullStableGate=$fullStable;state=$state;pass=$pass;pending=$pending;fail=$fail;
 safety=[ordered]@{stableV04Touched=$false;usbChanges=$false;partitionChanges=$false;biosChanges=$false;bootloaderChanges=$false;gpuCudaChanges=$false;arbitraryCommands=$false;secretsRead=$false}
}
$doc|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $Json -Encoding UTF8

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
  Copy-Item -LiteralPath $Report -Destination (Join-Path $cloud 'RAH-HOVED-PC-FINALIZER-v2-LATEST.txt') -Force
  Copy-Item -LiteralPath $Json -Destination (Join-Path $cloud 'RAH-HOVED-PC-FINALIZER-v2-LATEST.json') -Force
  if(Test-Path -LiteralPath $JobProof){Copy-Item -LiteralPath $JobProof -Destination (Join-Path $cloud 'RAVEN-JOB-EXECUTOR-PROOF-LATEST.json') -Force}
  if(Test-Path -LiteralPath $OsAcceptance){Copy-Item -LiteralPath $OsAcceptance -Destination (Join-Path $cloud 'RAH-OS-v0.8-ACCEPTANCE-LATEST.json') -Force}
  if(Test-Path -LiteralPath $WorkerProof){Copy-Item -LiteralPath $WorkerProof -Destination (Join-Path $cloud 'RAVEN-WORKER-PROOF-LATEST.json') -Force}
  $state.cloud=$true;P ('Cloud handoff copied to '+$cloud)
 }catch{F ('Cloud handoff failed: '+$_.Exception.Message)}
}else{F 'RAH CLOUD\99_INBOX local sync path not found.'}

if($coreGate -eq 'PASS'){
 L 'CORE FINAL: PASS'
 L 'FULL FINAL: OPEN until AnythingLLM, Worker Proof and reboot popup evidence are all verified.'
 exit 0
}
L 'CORE FINAL: OPEN'
L 'FULL FINAL: OPEN'
exit 2
