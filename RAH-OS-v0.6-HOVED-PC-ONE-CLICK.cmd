@echo off
setlocal EnableExtensions
title RAH OS v0.6 - HOVED-PC ONE CLICK

set "REF=main"
set "ROOT=C:\RAH\RavenOS"
set "TEMPINSTALL=%TEMP%\RAH-OS-v0.6-INSTALL-%RANDOM%%RANDOM%.cmd"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent(); if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 42}"
if "%ERRORLEVEL%"=="42" (
  echo Requesting Administrator permission...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo.
echo ============================================================
echo       RAH OS v0.6 - HOVED-PC ONE CLICK
echo ============================================================
echo  1 Download current fixed installer
echo  2 Install/update C:\RAH\RavenOS
echo  3 Run Front Door self-test
echo  4 Run HOVED-PC acceptance sequence
echo  5 Write PASS / PENDING / FAIL JSON
echo.
echo  Source : NilsRa73/rah-platform @ %REF%
echo  No Node token is read or stored by this launcher.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$uri='https://raw.githubusercontent.com/NilsRa73/rah-platform/%REF%/INSTALL-RAH-OS.cmd';" ^
  "$dst='%TEMPINSTALL%';" ^
  "Invoke-WebRequest -UseBasicParsing -Uri $uri -OutFile $dst;" ^
  "if((Get-Item -LiteralPath $dst).Length -lt 200){throw 'Downloaded installer is unexpectedly small.'};" ^
  "Write-Host 'PASS: Installer downloaded.' -ForegroundColor Green"
if errorlevel 1 goto :fail

set "RAH_OS_NO_LAUNCH=1"
call "%TEMPINSTALL%"
set "INSTALL_EC=%ERRORLEVEL%"
del /q "%TEMPINSTALL%" >nul 2>&1
if not "%INSTALL_EC%"=="0" goto :fail

if not exist "%ROOT%\RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd" (
  echo FAIL: HOVED-PC acceptance launcher was not installed.
  goto :fail
)

echo.
echo ============================================================
echo       INSTALL PASS - STARTING HOVED-PC ACCEPTANCE
echo ============================================================
echo.

call "%ROOT%\RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.cmd"
set "EC=%ERRORLEVEL%"

echo.
if "%EC%"=="0" echo FINAL: PASS
if "%EC%"=="2" echo FINAL: PENDING
if not "%EC%"=="0" if not "%EC%"=="2" echo FINAL: FAIL
echo Acceptance: %ROOT%\state\RAH-OS-ACCEPTANCE.json
echo Sequence  : %ROOT%\state\RAH-OS-HOVED-PC-SEQUENCE.json
exit /b %EC%

:fail
del /q "%TEMPINSTALL%" >nul 2>&1
echo.
echo ============================================================
echo RAH OS v0.6 HOVED-PC ONE CLICK: FAIL
echo ============================================================
echo Installation/update stopped before acceptance completed.
echo Existing C:\RAH files were not broadly deleted.
pause
exit /b 1
