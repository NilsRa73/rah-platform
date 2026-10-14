@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>nul
title RAH WORKER GEMMA PROOF v1

set "RAH_SELF=%~f0"
if /I "%~1"=="__RAH_ADMIN__" goto :ADMIN_OK
fltmc >nul 2>&1
if not errorlevel 1 goto :ADMIN_OK
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';Start-Process -FilePath $env:RAH_SELF -Verb RunAs -ArgumentList '__RAH_ADMIN__'"
if errorlevel 1 exit /b 18
exit /b 0

:ADMIN_OK
set "RAH_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$t=Get-Content -LiteralPath $env:RAH_SELF -Raw;$p=($t -split '(?m)^### RAH_WORKER_PROOF_PS ###\r?\n',2)[1];Invoke-Expression $p"
set "RC=%ERRORLEVEL%"

echo.
echo ============================================================
if "%RC%"=="0" echo RAH WORKER GEMMA PROOF: PASS
if not "%RC%"=="0" echo RAH WORKER GEMMA PROOF: GATE OPEN
echo Report: C:\RAH\Logs\RAH-WORKER-GEMMA-PROOF-v1-LATEST.txt
echo ============================================================
pause
exit /b %RC%

### RAH_WORKER_PROOF_PS ###
Set-StrictMode -Version Latest
$ErrorActionPreference='Continue'

$Pinned='3611e51a952570cfd83ab08dbf57b5cc686ba57d'
$Root='C:\RAH'
$Logs=Join-Path $Root 'Logs'
$RunRoot=Join-Path $Root ('Tools\WorkerGemmaProof\Run-'+[guid]::NewGuid().ToString('N'))
$Source=Join-Path $RunRoot 'rah_agent_worker.py'
$State=Join-Path $RunRoot 'worker-state.json'
$Report=Join-Path $Logs 'RAH-WORKER-GEMMA-PROOF-v1-LATEST.txt'
$Json=Join-Path $Logs 'RAH-WORKER-GEMMA-PROOF-v1-LATEST.json'
$TokenFile='C:\RAH\AgentBridge\token.txt'
$BusRoot='C:\RAH\AgentBus'
$pass=0;$fail=0;$pending=0

New-Item -ItemType Directory -Force -Path $Logs,$RunRoot|Out-Null

function L([string]$s=''){Write-Host $s;Add-Content -LiteralPath $Report -Value $s -Encoding UTF8}
function P([string]$s){$script:pass++;L "[PASS] $s"}
function F([string]$s){$script:fail++;L "[FAIL] $s"}
function N([string]$s){$script:pending++;L "[PENDING] $s"}
function J([string]$u,[hashtable]$h=$null){
 try{
  if($h){return Invoke-RestMethod -Uri $u -Headers $h -TimeoutSec 6 -ErrorAction Stop}
  return Invoke-RestMethod -Uri $u -TimeoutSec 6 -ErrorAction Stop
 }catch{return $null}
}
function Find-Python {
 foreach($p in @(
  'C:\RAH\Tools\RavenBridgeKnownGood\venv\Scripts\python.exe',
  "$env:USERPROFILE\Desktop\RAH AI Studios\desktop-bridge\.venv\Scripts\python.exe",
  'C:\RAH\AI-Fabric\venv\Scripts\python.exe',
  'C:\RAH\Runtime\Python\Scripts\python.exe'
 )){
  if(Test-Path -LiteralPath $p -PathType Leaf){
   try{& $p -c "import sys" 1>$null 2>$null;if($LASTEXITCODE -eq 0){return $p}}catch{}
  }
 }
 return $null
}
function Find-LocalWorker {
 foreach($p in @(
  'C:\RAH\AI-Fabric\rah-platform\rah_agent_worker.py',
  'C:\RAH\Runtime\RavenElevated\rah-platform\rah_agent_worker.py',
  "$env:USERPROFILE\Desktop\RAH AI Studios\rah_agent_worker.py",
  'C:\RAH\AgentWorker\rah_agent_worker.py'
 )){
  if(Test-Path -LiteralPath $p -PathType Leaf){
   $t=Get-Content -LiteralPath $p -Raw
   if($t -match 'VERSION = "1\.0\.0"' -and $t -match 'DEFAULT_BRIDGE = "http://127\.0\.0\.1:18781"' -and $t -notmatch 'subprocess'){
    return $p
   }
  }
 }
 return $null
}

@(
 'RAH WORKER -> PRODUCTION 18781 -> LOCAL GEMMA PROOF v1',
 ('Computer: '+$env:COMPUTERNAME),
 ('UTC: '+(Get-Date).ToUniversalTime().ToString('o')),
 ('Pinned source ref: '+$Pinned),
 'One fixed text.task only. No shell, no arbitrary path, no service restart.',
 ''
)|Set-Content -LiteralPath $Report -Encoding UTF8

$state=[ordered]@{
 ravenBefore=$false
 gemmaBefore=$false
 agent18781=$false
 source=$false
 python=$false
 queued=$false
 workerState=$false
 completed=$false
 gemmaReply=$false
 ravenAfter=$false
 gemmaAfter=$false
 workerProof=$false
}

$rh=J 'http://127.0.0.1:18765/health'
$gm=J 'http://127.0.0.1:1234/v1/models'
$ah=J 'http://127.0.0.1:18781/health'
$state.ravenBefore=[bool]($rh -and $rh.ok -eq $true)
$state.gemmaBefore=[bool]($gm -and @($gm.data|Where-Object{[string]$_.id -match 'gemma-3-4b-it'}).Count -gt 0)
$state.agent18781=[bool]($ah -and $ah.ok -eq $true -and [string]$ah.bind -eq '127.0.0.1' -and $ah.execCapability -eq $false)
if($state.ravenBefore){P 'Raven GOLD precheck PASS.'}else{F 'Raven GOLD precheck failed.'}
if($state.gemmaBefore){P 'Gemma model precheck PASS.'}else{F 'Gemma model precheck failed.'}
if($state.agent18781){P 'Production Agent Bridge 18781 PASS.'}else{F 'Production Agent Bridge 18781 failed.'}
if(-not($state.ravenBefore -and $state.gemmaBefore -and $state.agent18781)){exit 2}

$python=Find-Python
if($python){$state.python=$true;P ('Known-good Python: '+$python)}else{F 'Known-good Python not found.';exit 2}

$localWorker=Find-LocalWorker
if($localWorker){
 Copy-Item -LiteralPath $localWorker -Destination $Source -Force
 P ('Validated local Worker source: '+$localWorker)
}else{
 $url='https://raw.githubusercontent.com/NilsRa73/rah-platform/'+$Pinned+'/rah_agent_worker.py'
 & curl.exe -L --retry 3 --retry-delay 2 --fail --silent --show-error --max-time 120 -o $Source $url
 if($LASTEXITCODE -ne 0){F 'Pinned Worker source download failed.';exit 2}
}
try{
 $wt=Get-Content -LiteralPath $Source -Raw
 if($wt -notmatch 'VERSION = "1\.0\.0"' -or $wt -notmatch 'DEFAULT_BRIDGE = "http://127\.0\.0\.1:18781"' -or $wt -match 'subprocess'){
  throw 'Worker source contract mismatch.'
 }
 & $python -m py_compile $Source
 if($LASTEXITCODE -ne 0){throw 'Worker py_compile failed.'}
 & $python $Source --self-test 1>$null 2>$null
 if($LASTEXITCODE -ne 0){throw 'Worker self-test failed.'}
 $state.source=$true;P 'Pinned Worker source contract PASS.'
}catch{F ('Worker source validation failed: '+$_.Exception.Message);exit 2}

if(-not(Test-Path -LiteralPath $TokenFile -PathType Leaf)){F 'Production Agent Bridge credential file missing.';exit 2}

$nonce='RAH_WORKER_'+([guid]::NewGuid().ToString('N').Substring(0,12).ToUpper())
$jobId=$null
try{
 $localCredential=[IO.File]::ReadAllText($TokenFile).Trim()
 if($localCredential.Length -lt 24){throw 'Credential invalid.'}
 $headers=@{Authorization=('Bearer '+$localCredential)}
 $body=@{
  kind='text.task'
  source='rah-worker-gemma-proof-v1'
  payload=@{
   text=('Reply with exactly '+$nonce)
   provider='lmstudio'
   model='gemma-3-4b-it'
  }
 }|ConvertTo-Json -Depth 8
 $q=Invoke-RestMethod -Uri 'http://127.0.0.1:18781/v1/jobs/enqueue' -Method Post -Headers $headers -ContentType 'application/json' -Body $body -TimeoutSec 8 -ErrorAction Stop
 $jobId=[string]$q.job.id
 if(-not$q.ok -or -not$jobId){throw 'Queue did not return a job id.'}
 $state.queued=$true;P ('Fixed Worker proof job queued: '+$jobId)
}catch{F ('Queue failed: '+$_.Exception.Message);exit 2}
finally{Remove-Variable localCredential -ErrorAction SilentlyContinue}

$p=Start-Process -FilePath $python -ArgumentList @(
 $Source,'--bridge','http://127.0.0.1:18781','--fabric','http://127.0.0.1:18765',
 '--token-file',$TokenFile,'--state-file',$State,'--once'
) -WindowStyle Hidden -PassThru -Wait

if(Test-Path -LiteralPath $State -PathType Leaf){
 try{
  $ws=Get-Content -LiteralPath $State -Raw|ConvertFrom-Json
  $state.workerState=(
   [string]$ws.schema -eq 'rah-agent-worker' -and
   [string]$ws.version -eq '1.0.0' -and
   $ws.execCapability -eq $false -and
   [string]$ws.bridge -eq 'http://127.0.0.1:18781' -and
   [string]$ws.fabric -eq 'http://127.0.0.1:18765'
  )
  if($state.workerState){P 'Worker state contract PASS.'}else{F 'Worker state contract mismatch.'}
 }catch{F ('Worker state parse failed: '+$_.Exception.Message)}
}else{F 'Worker state file missing.'}

$resultPath=Join-Path $BusRoot ('results\'+$jobId+'.json')
if(Test-Path -LiteralPath $resultPath -PathType Leaf){
 try{
  $jr=Get-Content -LiteralPath $resultPath -Raw|ConvertFrom-Json
  $state.completed=([string]$jr.status -eq 'completed')
  $txt=[string]$jr.result.text
  $provider=[string]$jr.result.provider
  $model=[string]$jr.result.model
  $state.gemmaReply=($txt.Trim() -eq $nonce -and $provider -match 'lmstudio' -and $model -match 'gemma-3-4b-it')
  if($state.completed){P 'Worker job completed.'}else{F ('Worker job status='+[string]$jr.status)}
  if($state.gemmaReply){P 'Worker -> local Gemma exact reply PASS.'}else{F 'Worker -> local Gemma result contract failed.'}
 }catch{F ('Worker result parse failed: '+$_.Exception.Message)}
}else{F 'Worker result file missing.'}

$state.ravenAfter=[bool]((J 'http://127.0.0.1:18765/health').ok -eq $true)
$gm2=J 'http://127.0.0.1:1234/v1/models'
$state.gemmaAfter=[bool]($gm2 -and @($gm2.data|Where-Object{[string]$_.id -match 'gemma-3-4b-it'}).Count -gt 0)
if($state.ravenAfter){P 'Raven GOLD postcheck PASS.'}else{F 'Raven GOLD postcheck failed.'}
if($state.gemmaAfter){P 'Gemma postcheck PASS.'}else{F 'Gemma postcheck failed.'}

$proofScript=$null
foreach($p2 in @(
 'C:\RAH\RavenCore7\RAVEN-CORE-7-WORKER-PROOF.ps1',
 'C:\RAH\AI-Fabric\rah-platform\RAVEN-CORE-7-WORKER-PROOF.ps1',
 "$env:USERPROFILE\Desktop\RAH AI Studios\RAVEN-CORE-7-WORKER-PROOF.ps1"
)){
 if(Test-Path -LiteralPath $p2 -PathType Leaf){$proofScript=$p2;break}
}
if($proofScript){
 & powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $proofScript -Mode Validate -JsonOnly 1>$null 2>$null
 if($LASTEXITCODE -eq 0){$state.workerProof=$true;P 'Existing physical Worker Proof PASS.'}
 else{N 'Physical second-PC Worker Proof still pending.'}
}else{N 'Physical Worker Proof validator not found locally.'}

$localPass=($state.ravenBefore -and $state.gemmaBefore -and $state.agent18781 -and $state.source -and $state.python -and $state.queued -and $state.workerState -and $state.completed -and $state.gemmaReply -and $state.ravenAfter -and $state.gemmaAfter)
$result=if($localPass){'PASS_WORKER_TO_LOCAL_GEMMA'}else{'OPEN_WORKER_LOCAL_PROOF'}
$next=if($localPass -and -not$state.workerProof){'LENOVO_AUTHENTICATED_NODE_JOB'}elseif($state.workerProof){'RAH_OS_FULL_ACCEPTANCE'}else{'REVIEW_WORKER_PROOF'}
L ('RESULT='+$result)
L ('NEXT_GATE='+$next)
L 'STABLE_GATE=OPEN'
L ("PASS=$pass PENDING=$pending FAIL=$fail")

$doc=[ordered]@{
 schema='rah-worker-gemma-proof-v1'
 timestamp=(Get-Date).ToUniversalTime().ToString('o')
 computer=$env:COMPUTERNAME
 pinnedCommit=$Pinned
 result=$result
 localWorkerGemmaPass=$localPass
 physicalWorkerProofPass=$state.workerProof
 nextGate=$next
 stableGate='OPEN'
 state=$state
 pass=$pass
 pending=$pending
 fail=$fail
 safety=[ordered]@{
  fixedJobOnly=$true
  arbitraryCommands=$false
  credentialValueReported=$false
  workerPersistentInstall=$false
  ravenRestarted=$false
  gemmaRestarted=$false
  usbChanges=$false
  partitionChanges=$false
  biosChanges=$false
  bootloaderChanges=$false
  gpuCudaChanges=$false
 }
}
$doc|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $Json -Encoding UTF8

$cloud=$null
foreach($cp in @('G:\My Drive\RAH CLOUD\99_INBOX','G:\RAH CLOUD\99_INBOX',"$env:USERPROFILE\My Drive\RAH CLOUD\99_INBOX","$env:USERPROFILE\Google Drive\My Drive\RAH CLOUD\99_INBOX")){
 if(Test-Path -LiteralPath $cp -PathType Container){$cloud=$cp;break}
}
if($cloud){
 Copy-Item -LiteralPath $Report -Destination (Join-Path $cloud 'RAH-WORKER-GEMMA-PROOF-v1-LATEST.txt') -Force
 Copy-Item -LiteralPath $Json -Destination (Join-Path $cloud 'RAH-WORKER-GEMMA-PROOF-v1-LATEST.json') -Force
}

if($localPass){exit 0}
exit 2
