@echo off
setlocal EnableExtensions
set "ROOT=C:\RAH\RavenOS"
set "REF=main"
title RAH Raven OS - Front Door Installer

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent(); if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 42}"
if "%ERRORLEVEL%"=="42" (
  echo Requesting Administrator permission for C:\RAH installation...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>&1
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo           RAH RAVEN OS - FRONT DOOR INSTALLER
echo ============================================================
echo  Destination: %ROOT%
echo  Source ref : %REF%
echo  Flow       : INSTALL - SELFTEST - SHORTCUTS - START
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$root='C:\RAH\RavenOS';" ^
  "$ref='%REF%';" ^
  "$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/'+$ref;" ^
  "$files=@('START-HER-RAH-OS.cmd','INSTALL-RAH-OS.cmd','REPAIR-RAH-OS.cmd','RAH-OS-CONTROL.ps1','RAH-OS-SELFTEST.ps1','ACCEPT-RAH-OS-v0.6.cmd','ACCEPT-RAH-OS-v0.6.ps1','RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd','RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1','RAH-OS.md');" ^
  "New-Item -ItemType Directory -Force -Path $root,(Join-Path $root 'logs'),(Join-Path $root 'state')|Out-Null;" ^
  "foreach($f in $files){$dst=Join-Path $root $f;$tmp=$dst+'.download';Write-Host ('GET  '+$f) -ForegroundColor DarkYellow;Invoke-WebRequest -UseBasicParsing -Uri ($base+'/'+$f) -OutFile $tmp;if((Get-Item -LiteralPath $tmp).Length -lt 20){throw ('Invalid download: '+$f)};Move-Item -LiteralPath $tmp -Destination $dst -Force};" ^
  "[IO.File]::WriteAllText((Join-Path $root 'RAH-OS-SOURCE-REF.txt'),$ref,[Text.UTF8Encoding]::new($false));" ^
  "Write-Host 'PASS: RAH Raven OS Front Door files installed.' -ForegroundColor Green"
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ROOT%\RAH-OS-SELFTEST.ps1"
if errorlevel 1 goto :fail

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$target='C:\RAH\RavenOS\START-HER-RAH-OS.cmd';" ^
  "$ws=New-Object -ComObject WScript.Shell;" ^
  "$desktop=[Environment]::GetFolderPath('Desktop');" ^
  "$start=[Environment]::GetFolderPath('StartMenu');" ^
  "$links=@((Join-Path $desktop 'RAH Raven OS.lnk'),(Join-Path $start 'Programs\RAH Raven OS.lnk'));" ^
  "foreach($link in $links){$dir=Split-Path -Parent $link;New-Item -ItemType Directory -Force -Path $dir|Out-Null;$s=$ws.CreateShortcut($link);$s.TargetPath=$target;$s.WorkingDirectory='C:\RAH\RavenOS';$s.Description='RAH Raven OS Front Door';$s.Save()};" ^
  "Write-Host 'PASS: Desktop and Start Menu shortcuts created.' -ForegroundColor Green"
if errorlevel 1 goto :fail

cd /d "%ROOT%"
call "%ROOT%\START-HER-RAH-OS.cmd"
exit /b %ERRORLEVEL%

:fail
echo.
echo ============================================================
echo RAH RAVEN OS FRONT DOOR: FAIL
echo ============================================================
echo Installation stopped before launching the control panel.
echo No Node Agent was auto-started.
pause
exit /b 1
