@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>nul
title RAH - FORTSETT MED AUTO v1

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
echo             RAH - FORTSETT MED AUTO v1
echo ============================================================
echo Ett klikk. Riktig neste steg velges automatisk.
echo ============================================================
echo.

set "RAH_SELF=%~f0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$t=Get-Content -LiteralPath $env:RAH_SELF -Raw;$p=($t -split '(?m)^### RAH_AUTO_CONTINUE_PS ###\r?\n',2)[1];Invoke-Expression $p"
set "RC=%ERRORLEVEL%"

echo.
echo ============================================================
if "%RC%"=="0" echo RAH AUTO CONTINUE: FERDIG FOR DENNE RUNDEN
if "%RC%"=="20" echo RAH AUTO CONTINUE: REBOOT-KONTROLL GJENSTAR
if "%RC%"=="2" echo RAH AUTO CONTINUE: NESTE GATE ER FORTSATT APEN
if not "%RC%"=="0" if not "%RC%"=="20" if not "%RC%"=="2" echo RAH AUTO CONTINUE: KONTROLLER RAPPORT
echo Report: C:\RAH\Logs\RAH-AUTO-CONTINUE-v1-LATEST.txt
echo ============================================================
echo.
pause
exit /b %RC%

### RAH_AUTO_CONTINUE_PS ###
Set-StrictMode -Version Latest
$ErrorActionPreference='Continue'

$Pinned='492e6543b443cfb5b4a126a82555a6e08fc5503b'
$Root='C:\RAH'
$ToolRoot=Join-Path $Root 'Tools\AutoContinue'
$Payload=Join-Path $ToolRoot 'payload'
$Cache=Join-Path $Root 'Cache\AutoContinue'
$Logs=Join-Path $Root 'Logs'
$Report=Join-Path $Logs 'RAH-AUTO-CONTINUE-v1-LATEST.txt'
$Json=Join-Path $Logs 'RAH-AUTO-CONTINUE-v1-LATEST.json'
$Installed=Join-Path $ToolRoot 'RAH-AUTO-CONTINUE-v1.cmd'
$Archive=Join-Path $Cache ('rah-platform-'+$Pinned+'.zip')
$ArchiveUrl='https://github.com/NilsRa73/rah-platform/archive/'+$Pinned+'.zip'
$Finalizer=Join-Path $Payload 'RAH-HOVED-PC-FINALIZER-v2-START-HER.cmd'
$Closeout=Join-Path $Payload 'RAH-HOVED-PC-FULL-GATE-CLOSEOUT-v1-START-HER.cmd'
$FinalizerJson=Join-Path $Logs 'RAH-HOVED-PC-FINALIZER-v2-LATEST.json'
$CloseoutJson=Join-Path $Logs 'RAH-HOVED-PC-FULL-GATE-CLOSEOUT-v1-LATEST.json'
$Utf8=New-Object Text.UTF8Encoding($false)

New-Item -ItemType Directory -Force -Path $ToolRoot,$Payload,$Cache,$Logs|Out-Null

function L([string]$s=''){Write-Host $s;Add-Content -LiteralPath $Report -Value $s -Encoding UTF8}
function Read-Json([string]$Path){
 if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
 try{return Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json -ErrorAction Stop}catch{return $null}
}
function Get-CoreGate {
 $j=Read-Json $FinalizerJson
 if($j -and [string]$j.coreGate -eq 'PASS'){return 'PASS'}
 return 'OPEN'
}
function Get-CloseoutState {
 $j=Read-Json $CloseoutJson
 if($j -and [string]$j.closeout -eq 'READY-FOR-REBOOT-CHECK'){return 'READY-FOR-REBOOT-CHECK'}
 return 'OPEN'
}
function Test-Payload {
 if(-not(Test-Path -LiteralPath $Finalizer -PathType Leaf)){return $false}
 if(-not(Test-Path -LiteralPath $Closeout -PathType Leaf)){return $false}
 $a=Get-Content -LiteralPath $Finalizer -Raw
 $b=Get-Content -LiteralPath $Closeout -Raw
 return (
   $a -match 'RAH HOVED-PC FINALIZER v2' -and
   $a -match 'RAVEN-JOB-EXECUTOR-PROOF\.ps1' -and
   $b -match 'RAH HOVED-PC FULL GATE CLOSEOUT v1' -and
   $b -match 'READY-FOR-REBOOT-CHECK'
 )
}
function Ensure-Payload {
 if(Test-Payload){return $true}
 try{
   L ('Preparing pinned RAH payload '+$Pinned+'.')
   & curl.exe -L --fail --silent --show-error --max-time 120 -o $Archive $ArchiveUrl
   if($LASTEXITCODE -ne 0 -or -not(Test-Path -LiteralPath $Archive -PathType Leaf)){throw 'Pinned archive download failed.'}
   if((Get-Item -LiteralPath $Archive).Length -lt 100000){throw 'Pinned archive is unexpectedly small.'}

   $stage=Join-Path $Cache ('stage-'+[guid]::NewGuid().ToString('N'))
   New-Item -ItemType Directory -Force -Path $stage|Out-Null
   Expand-Archive -LiteralPath $Archive -DestinationPath $stage -Force
   $src=Get-ChildItem -LiteralPath $stage -Directory|Select-Object -First 1
   if(-not$src){throw 'Archive extraction produced no source folder.'}

   Copy-Item -LiteralPath (Join-Path $src.FullName 'RAH-HOVED-PC-FINALIZER-v2-START-HER.cmd') -Destination $Finalizer -Force
   Copy-Item -LiteralPath (Join-Path $src.FullName 'RAH-HOVED-PC-FULL-GATE-CLOSEOUT-v1-START-HER.cmd') -Destination $Closeout -Force
   Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue

   if(-not(Test-Payload)){throw 'Pinned payload marker validation failed.'}
   [IO.File]::WriteAllText((Join-Path $Payload 'PINNED-COMMIT.txt'),$Pinned+[Environment]::NewLine,$Utf8)
   return $true
 }catch{
   L ('[FAIL] Payload preparation failed: '+$_.Exception.Message)
   return $false
 }
}
function Install-Self {
 try{
   $current=[IO.Path]::GetFullPath($env:RAH_SELF)
   if($current -ne [IO.Path]::GetFullPath($Installed)){
     Copy-Item -LiteralPath $current -Destination $Installed -Force
   }
   $desktop=[Environment]::GetFolderPath('Desktop')
   $lnk=Join-Path $desktop 'RAH - Fortsett med auto.lnk'
   $w=New-Object -ComObject WScript.Shell
   $s=$w.CreateShortcut($lnk)
   $s.TargetPath=$Installed
   $s.WorkingDirectory=$ToolRoot
   $s.Description='RAH - Fortsett med auto'
   $s.IconLocation="$env:SystemRoot\System32\shell32.dll,167"
   $s.Save()
   return $lnk
 }catch{
   L ('[WARN] Desktop shortcut could not be created: '+$_.Exception.Message)
   return $null
 }
}

@(
 'RAH AUTO CONTINUE v1',
 ('Computer: '+$env:COMPUTERNAME),
 ('UTC: '+(Get-Date).ToUniversalTime().ToString('o')),
 ('Pinned workflow commit: '+$Pinned),
 'Authority: fixed workflow only; no arbitrary command, path or argument execution.',
 ''
)|Set-Content -LiteralPath $Report -Encoding UTF8

$shortcut=Install-Self
if($shortcut){L ('[PASS] Permanent desktop button: '+$shortcut)}

if(-not(Ensure-Payload)){
 $doc=[ordered]@{schema='rah-auto-continue-v1';timestamp=(Get-Date).ToUniversalTime().ToString('o');result='PAYLOAD_FAIL';coreGate=(Get-CoreGate);closeout=(Get-CloseoutState);stableGate='OPEN'}
 $doc|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $Json -Encoding UTF8
 exit 3
}
L '[PASS] Fixed pinned payload ready.'

$core=Get-CoreGate
$close=Get-CloseoutState
L ('Initial CORE_GATE='+$core)
L ('Initial CLOSEOUT='+$close)

if($close -eq 'READY-FOR-REBOOT-CHECK'){
 L '[PASS] Full gate closeout is already ready for reboot verification.'
 L 'NEXT: reboot/observe popup behavior. Stable Gate remains OPEN until that evidence exists.'
 $doc=[ordered]@{schema='rah-auto-continue-v1';timestamp=(Get-Date).ToUniversalTime().ToString('o');result='READY_FOR_REBOOT_CHECK';coreGate=$core;closeout=$close;stableGate='OPEN';next='REBOOT_OBSERVATION'}
 $doc|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $Json -Encoding UTF8
 exit 20
}

if($core -ne 'PASS'){
 L 'ACTION: running HOVED-PC Finalizer v2.'
 $p=Start-Process -FilePath $Finalizer -WorkingDirectory $Payload -ArgumentList '__RAH_ADMIN__' -PassThru -Wait
 L ('Finalizer v2 exit='+$p.ExitCode)
 $core=Get-CoreGate
 L ('After Finalizer CORE_GATE='+$core)
 if($core -ne 'PASS'){
   L '[OPEN] Core Gate is still not PASS. Full-gate closeout will not run.'
   $doc=[ordered]@{schema='rah-auto-continue-v1';timestamp=(Get-Date).ToUniversalTime().ToString('o');result='CORE_OPEN';coreGate=$core;closeout=(Get-CloseoutState);stableGate='OPEN';next='REVIEW_FINALIZER_V2_REPORT'}
   $doc|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $Json -Encoding UTF8
   exit 2
 }
}

L '[PASS] Core Gate PASS.'
$close=Get-CloseoutState
if($close -ne 'READY-FOR-REBOOT-CHECK'){
 L 'ACTION: running Full Gate Closeout v1.'
 $p=Start-Process -FilePath $Closeout -WorkingDirectory $Payload -ArgumentList '__RAH_ADMIN__' -PassThru -Wait
 L ('Full Gate Closeout exit='+$p.ExitCode)
 $close=Get-CloseoutState
}

if($close -eq 'READY-FOR-REBOOT-CHECK'){
 L '[PASS] AnythingLLM / Worker / RAH OS full closeout reached READY-FOR-REBOOT-CHECK.'
 L 'NEXT: reboot/observe popup behavior. Stable Gate remains OPEN until verified.'
 $result='READY_FOR_REBOOT_CHECK'
 $next='REBOOT_OBSERVATION'
 $rc=20
}else{
 L '[OPEN] Full-gate closeout is still open.'
 $result='FULL_GATE_OPEN'
 $next='REVIEW_FULL_GATE_REPORT'
 $rc=2
}

$doc=[ordered]@{
 schema='rah-auto-continue-v1'
 timestamp=(Get-Date).ToUniversalTime().ToString('o')
 computer=$env:COMPUTERNAME
 pinnedCommit=$Pinned
 result=$result
 coreGate=(Get-CoreGate)
 closeout=(Get-CloseoutState)
 stableGate='OPEN'
 next=$next
 safety=[ordered]@{
  arbitraryCommands=$false
  arbitraryPaths=$false
  callerArguments=$false
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
  Copy-Item -LiteralPath $Report -Destination (Join-Path $cloud 'RAH-AUTO-CONTINUE-v1-LATEST.txt') -Force
  Copy-Item -LiteralPath $Json -Destination (Join-Path $cloud 'RAH-AUTO-CONTINUE-v1-LATEST.json') -Force
  L ('[PASS] Cloud handoff: '+$cloud)
 }catch{L ('[WARN] Cloud handoff failed: '+$_.Exception.Message)}
}

exit $rc
