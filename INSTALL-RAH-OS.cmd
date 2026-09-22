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
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$root='C:\RAH\RavenOS';" ^
  "$ref='%REF%';" ^
  "$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/'+$ref;" ^
  "$files=@('START-HER-RAH-OS.cmd','RAH-OS-CONTROL.ps1','RAH-OS.md');" ^
  "New-Item -ItemType Directory -Force -Path $root,(Join-Path $root 'logs')|Out-Null;" ^
  "foreach($f in $files){$dst=Join-Path $root $f;$tmp=$dst+'.download';Write-Host ('GET  '+$f) -ForegroundColor DarkYellow;Invoke-WebRequest -UseBasicParsing -Uri ($base+'/'+$f) -OutFile $tmp;if((Get-Item -LiteralPath $tmp).Length -lt 20){throw ('Invalid download: '+$f)};Move-Item -LiteralPath $tmp -Destination $dst -Force};" ^
  "[IO.File]::WriteAllText((Join-Path $root 'RAH-OS-SOURCE-REF.txt'),$ref,[Text.UTF8Encoding]::new($false));" ^
  "Write-Host 'PASS: RAH Raven OS Front Door installed.' -ForegroundColor Green"
if errorlevel 1 goto :fail

cd /d "%ROOT%"
call "%ROOT%\START-HER-RAH-OS.cmd"
exit /b %ERRORLEVEL%

:fail
echo.
echo ============================================================
echo RAH RAVEN OS FRONT DOOR: FAIL
echo ============================================================
pause
exit /b 1
