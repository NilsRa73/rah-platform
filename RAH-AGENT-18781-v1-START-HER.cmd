@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>nul
title RAH HOVED-PC AGENT 18781 v1

set "RAH_SELF=%~f0"
if /I "%~1"=="__RAH_ADMIN__" goto :ADMIN_OK
fltmc >nul 2>&1
if not errorlevel 1 goto :ADMIN_OK
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';Start-Process -FilePath $env:RAH_SELF -Verb RunAs -ArgumentList '__RAH_ADMIN__'"
if errorlevel 1 exit /b 18
exit /b 0

:ADMIN_OK
echo.
echo ============================================================
echo          RAH HOVED-PC AGENT 18781 v1
echo ============================================================
echo Uses the pinned, existing Agent Bridge installer.
echo Raven GOLD and Gemma are preserved and rechecked.
echo ============================================================
echo.

set "RAH_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command "$t=Get-Content -LiteralPath $env:RAH_SELF -Raw;$p=($t -split '(?m)^### RAH_AGENT_18781_PS ###\r?\n',2)[1];Invoke-Expression $p"
set "RC=%ERRORLEVEL%"

echo.
echo ============================================================
if "%RC%"=="0" echo RAH AGENT 18781: PASS
if not "%RC%"=="0" echo RAH AGENT 18781: GATE OPEN
echo Report: C:\RAH\Logs\RAH-AGENT-18781-v1-LATEST.txt
echo ============================================================
pause
exit /b %RC%

### RAH_AGENT_18781_PS ###
Set-StrictMode -Version Latest
$ErrorActionPreference='Continue'

$Pinned='17099d8125bccfc26d85ff6ef09d0352cb9cdbaf'
$Root='C:\RAH'
$Logs=Join-Path $Root 'Logs'
$Cache=Join-Path $Root 'Cache\Agent18781'
$Stage=Join-Path $Cache 'stage'
$Archive=Join-Path $Cache ('rah-platform-'+$Pinned+'.zip')
$ArchiveUrl='https://github.com/NilsRa73/rah-platform/archive/'+$Pinned+'.zip'
$Report=Join-Path $Logs 'RAH-AGENT-18781-v1-LATEST.txt'
$Json=Join-Path $Logs 'RAH-AGENT-18781-v1-LATEST.json'
$AgentRoot=Join-Path $Root 'AgentBridge'
$BusRoot=Join-Path $Root 'AgentBus'
$TaskName='RAH Agent Bridge'

New-Item -ItemType Directory -Force -Path $Logs,$Cache|Out-Null
$pass=0;$fail=0;$pending=0
$state=[ordered]@{
 ravenBefore=$false
 gemmaBefore=$false
 existingCredentialFile=$false
 pinnedSource=$false
 installer=$false
 health18781=$false
 authenticatedStatus=$false
 taskHighest=$false
 ravenAfter=$false
 gemmaAfter=$false
 cloud=$false
}

function L([string]$s=''){Write-Host $s;Add-Content -LiteralPath $Report -Value $s -Encoding UTF8}
function P([string]$s){$script:pass++;L "[PASS] $s"}
function F([string]$s){$script:fail++;L "[FAIL] $s"}
function N([string]$s){$script:pending++;L "[PENDING] $s"}
function J([string]$u,[hashtable]$h=$null){try{if($h){Invoke-RestMethod -Uri $u -Headers $h -TimeoutSec 6 -ErrorAction Stop}else{Invoke-RestMethod -Uri $u -TimeoutSec 6 -ErrorAction Stop}}catch{$null}}
function RavenOk {$h=J 'http://127.0.0.1:18765/health';return [bool]($h -and $h.ok -eq $true)}
function GemmaOk {$m=J 'http://127.0.0.1:1234/v1/models';return [bool]($m -and @($m.data|Where-Object{[string]$_.id -match 'gemma-3-4b'}).Count -gt 0)}
function Find-Python {
 foreach($p in @(
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

@(
 'RAH HOVED-PC AGENT 18781 v1',
 ('Computer: '+$env:COMPUTERNAME),
 ('UTC: '+(Get-Date).ToUniversalTime().ToString('o')),
 ('Pinned repo: '+$Pinned),
 'Uses existing repository installer; credential value is never printed or copied to reports.',
 ''
)|Set-Content -LiteralPath $Report -Encoding UTF8

$state.ravenBefore=RavenOk
$state.gemmaBefore=GemmaOk
if($state.ravenBefore){P 'Raven GOLD 18765 precheck PASS.'}else{F 'Raven GOLD precheck failed.'}
if($state.gemmaBefore){P 'Gemma 3 4B precheck PASS.'}else{F 'Gemma precheck failed.'}
if(-not($state.ravenBefore -and $state.gemmaBefore)){exit 2}

$credPath=Join-Path $AgentRoot 'token.txt'
if(Test-Path -LiteralPath $credPath -PathType Leaf){$state.existingCredentialFile=$true;P 'Existing Agent Bridge credential file present.'}
else{F 'Existing Agent Bridge credential file missing; this repair will not create a new production credential.';exit 2}

try{
 if(Test-Path -LiteralPath $Stage){Remove-Item -LiteralPath $Stage -Recurse -Force}
 New-Item -ItemType Directory -Force -Path $Stage|Out-Null
 & curl.exe -L --fail --silent --show-error --max-time 120 -o $Archive $ArchiveUrl
 if($LASTEXITCODE -ne 0){throw 'Pinned source download failed.'}
 Expand-Archive -LiteralPath $Archive -DestinationPath $Stage -Force
 $src=Get-ChildItem -LiteralPath $Stage -Directory|Select-Object -First 1
 if(-not$src){throw 'Pinned source folder missing.'}
 foreach($n in @('INSTALL-RAH-AGENT-BRIDGE.ps1','rah_agent_bridge.py','RAH-AGENT-BUS.ps1')){
  if(-not(Test-Path -LiteralPath (Join-Path $src.FullName $n) -PathType Leaf)){throw ('Missing '+$n)}
 }
 $state.pinnedSource=$true;P 'Pinned Agent Bridge source PASS.'
}catch{F ('Pinned source failed: '+$_.Exception.Message);exit 2}

$python=Find-Python
if(-not$python){F 'Known-good local Python not found.';exit 2}
P ('Python found: '+$python)

$installer=Join-Path $src.FullName 'INSTALL-RAH-AGENT-BRIDGE.ps1'
& powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File $installer -InstallRoot $AgentRoot -BusRoot $BusRoot -SourceDirectory $src.FullName -PythonPath $python 2>&1|ForEach-Object{L ([string]$_)}
if($LASTEXITCODE -eq 0){$state.installer=$true;P 'Existing pinned Agent Bridge installer PASS.'}else{F ('Installer exit='+$LASTEXITCODE)}

$h=J 'http://127.0.0.1:18781/health'
if($h -and $h.ok -eq $true -and [string]$h.bind -eq '127.0.0.1' -and $h.execCapability -eq $false){
 $state.health18781=$true;P 'Production Agent Bridge 18781 health PASS; loopback-only; exec disabled.'
}else{F 'Production Agent Bridge 18781 health not verified.'}

if($state.health18781){
 try{
  $localCredential=[IO.File]::ReadAllText($credPath).Trim()
  if($localCredential.Length -lt 24){throw 'Local credential is structurally invalid.'}
  $headers=@{Authorization=('Bearer '+$localCredential)}
  $s=Invoke-RestMethod -Uri 'http://127.0.0.1:18781/v1/jobs/status' -Headers $headers -TimeoutSec 6 -ErrorAction Stop
  if($s.ok -eq $true){$state.authenticatedStatus=$true;P 'Authenticated production status PASS.'}else{throw 'status ok=false'}
 }catch{F ('Authenticated status failed: '+$_.Exception.Message)}
 finally{Remove-Variable localCredential -ErrorAction SilentlyContinue}
}

try{
 $xml=Export-ScheduledTask -TaskName $TaskName -ErrorAction Stop
 if($xml -match '<RunLevel>HighestAvailable</RunLevel>' -or $xml -match '<RunLevel>Highest</RunLevel>'){
  $state.taskHighest=$true;P 'Agent Bridge scheduled task is Highest.'
 }else{F 'Agent Bridge task is not Highest.'}
}catch{F ('Agent Bridge task check failed: '+$_.Exception.Message)}

$state.ravenAfter=RavenOk
$state.gemmaAfter=GemmaOk
if($state.ravenAfter){P 'Raven GOLD still PASS after Agent Bridge repair.'}else{F 'Raven GOLD postcheck failed.'}
if($state.gemmaAfter){P 'Gemma still PASS after Agent Bridge repair.'}else{F 'Gemma postcheck failed.'}

$prodPass=($state.ravenBefore -and $state.gemmaBefore -and $state.existingCredentialFile -and $state.pinnedSource -and $state.installer -and $state.health18781 -and $state.authenticatedStatus -and $state.taskHighest -and $state.ravenAfter -and $state.gemmaAfter)
$result=if($prodPass){'PASS_PRODUCTION_18781_AUTHENTICATED'}else{'OPEN_PRODUCTION_18781'}
L ('RESULT='+$result)
L 'NEXT_GATE=LENOVO_AUTHENTICATED_NODE_JOB'
L 'STABLE_GATE=OPEN'
L ("PASS=$pass PENDING=$pending FAIL=$fail")

$doc=[ordered]@{
 schema='rah-agent-18781-v1';timestamp=(Get-Date).ToUniversalTime().ToString('o');computer=$env:COMPUTERNAME;
 pinnedCommit=$Pinned;result=$result;production18781Pass=$prodPass;nextGate='LENOVO_AUTHENTICATED_NODE_JOB';stableGate='OPEN';
 state=$state;pass=$pass;pending=$pending;fail=$fail;
 safety=[ordered]@{credentialValueReported=$false;execCapability=$false;ravenRestarted=$false;gemmaRestarted=$false;usbChanges=$false;partitionChanges=$false;biosChanges=$false;bootloaderChanges=$false;gpuCudaChanges=$false}
}
$doc|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $Json -Encoding UTF8

$cloud=$null
foreach($p in @('G:\My Drive\RAH CLOUD\99_INBOX','G:\RAH CLOUD\99_INBOX',"$env:USERPROFILE\My Drive\RAH CLOUD\99_INBOX","$env:USERPROFILE\Google Drive\My Drive\RAH CLOUD\99_INBOX")){
 if(Test-Path -LiteralPath $p -PathType Container){$cloud=$p;break}
}
if($cloud){
 try{
  Copy-Item -LiteralPath $Report -Destination (Join-Path $cloud 'RAH-AGENT-18781-v1-LATEST.txt') -Force
  Copy-Item -LiteralPath $Json -Destination (Join-Path $cloud 'RAH-AGENT-18781-v1-LATEST.json') -Force
  $state.cloud=$true;P ('Cloud handoff staged: '+$cloud)
 }catch{F ('Cloud handoff failed: '+$_.Exception.Message)}
}

if($prodPass){exit 0}
exit 2
