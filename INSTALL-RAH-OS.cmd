@echo off
setlocal EnableExtensions
set "ROOT=C:\RAH\RavenOS"
if defined RAH_OS_SOURCE_REF (set "REF=%RAH_OS_SOURCE_REF%") else (set "REF=rah-os-v0.8-consolidation")
title RAH OS v0.8 - Installer

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent();if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 42}"
if "%ERRORLEVEL%"=="42" (
  echo Requesting Administrator permission...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo.
echo ============================================================
echo                 RAH OS v0.8 INSTALLER
echo ============================================================
echo  Destination : %ROOT%
echo  Source ref  : %REF%
echo  Mode        : backup - install - verify
echo.

if exist "%ROOT%" (
  for /f "tokens=1-4 delims=/-. " %%a in ("%date%") do set "DS=%%d%%c%%b"
  for /f "tokens=1-3 delims=:,. " %%a in ("%time%") do set "TS=%%a%%b%%c"
  set "BACKUP=C:\RAH\_BACKUP\RavenOS-v0.8-%DS%-%TS%"
  mkdir "%BACKUP%" >nul 2>&1
  robocopy "%ROOT%" "%BACKUP%" /E /COPY:DAT /R:1 /W:1 /NFL /NDL /NJH /NJS >nul
  echo BACKUP    %BACKUP%
)

if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>&1
if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1
if not exist "%ROOT%\state" mkdir "%ROOT%\state" >nul 2>&1

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';" ^
 "$root='%ROOT%';$ref='%REF%';$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/'+$ref;" ^
 "$files=@('START-HER-RAH-OS.cmd','INSTALL-RAH-OS.cmd','REPAIR-RAH-OS.cmd','RAH-OS-CONTROL.ps1','RAH-OS-SELFTEST.ps1','RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.cmd','RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1','RAVEN-CORE-7.ps1','RAVEN-AI-SELF-CHECK.ps1','TEST-ANYTHINGLLM-APPROVAL.ps1','RAVEN-CORE-7-WORKER-PROOF.ps1','START-RAH-AI-FABRIC.cmd','WORKER-PROOF.cmd','DIAGNOSTICS.cmd','RAH-OS-v0.8-PLAN.md');" ^
 "foreach($f in $files){$dst=Join-Path $root $f;$tmp=$dst+'.download';Write-Host ('GET       '+$f) -ForegroundColor DarkYellow;Invoke-WebRequest -UseBasicParsing -Uri ($base+'/'+$f) -OutFile $tmp;if((Get-Item -LiteralPath $tmp).Length -lt 20){throw ('Invalid download: '+$f)};Move-Item -LiteralPath $tmp -Destination $dst -Force};" ^
 "[IO.File]::WriteAllText((Join-Path $root 'RAH-OS-SOURCE-REF.txt'),$ref,[Text.UTF8Encoding]::new($false))"
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\RAH-OS-SELFTEST.ps1"
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
 "$ErrorActionPreference='Stop';$ws=New-Object -ComObject WScript.Shell;$target='%ROOT%\START-HER-RAH-OS.cmd';" ^
 "$links=@((Join-Path ([Environment]::GetFolderPath('Desktop')) 'RAH OS v0.8.lnk'),(Join-Path ([Environment]::GetFolderPath('StartMenu')) 'Programs\RAH OS v0.8.lnk'));" ^
 "foreach($link in $links){New-Item -ItemType Directory -Force -Path (Split-Path -Parent $link)|Out-Null;$s=$ws.CreateShortcut($link);$s.TargetPath=$target;$s.WorkingDirectory='%ROOT%';$s.Description='RAH OS v0.8 Front Door';$s.Save()}"
if errorlevel 1 goto :fail

if /I "%RAH_OS_RUN_ACCEPTANCE%"=="1" (
  call "%ROOT%\RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.cmd"
  exit /b %ERRORLEVEL%
)

if /I "%RAH_OS_NO_LAUNCH%"=="1" exit /b 0
call "%ROOT%\START-HER-RAH-OS.cmd"
exit /b %ERRORLEVEL%

:fail
echo.
echo ============================================================
echo RAH OS v0.8 INSTALL: FAIL
echo ============================================================
echo Existing installation was backed up before replacement when present.
pause
exit /b 1
