@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH OS v0.8 - FINAL ACCEPTANCE

set "ROOT=C:\RAH\RavenOS"
set "REF="
if defined RAH_OS_SOURCE_REF set "REF=%RAH_OS_SOURCE_REF%"
if not defined REF if exist "%ROOT%\RAH-OS-SOURCE-REF.txt" set /p REF=<"%ROOT%\RAH-OS-SOURCE-REF.txt"
if not defined REF set "REF=main"
set "FINALIZER=%ROOT%\RAH-OS-v0.8-FINALIZE.ps1"

fltmc >nul 2>nul
if errorlevel 1 (
  echo Requesting Administrator permission...
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>&1

echo.
echo ============================================================
echo        RAH OS v0.8 - HOVED-PC FINAL ACCEPTANCE
echo ============================================================
echo  PRECHECK ^> REPAIR ^> START ^> POSTCHECK ^> FINAL PASS/FAIL
echo  Background PowerShell tasks are hidden/noninteractive.
echo  No USB or partition changes.
echo.

if not exist "%FINALIZER%" (
  echo PRECHECK: finalizer missing - restoring pinned file...
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference='Stop';$u='https://raw.githubusercontent.com/NilsRa73/rah-platform/%REF%/RAH-OS-v0.8-FINALIZE.ps1';$d='%FINALIZER%';$t=$d+'.download';Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $t -TimeoutSec 90;if((Get-Item -LiteralPath $t).Length -lt 1000){throw 'Finalizer download too small'};Move-Item -LiteralPath $t -Destination $d -Force"
  if errorlevel 1 goto :download_fail
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%FINALIZER%" -SourceRef "%REF%"
set "EC=%ERRORLEVEL%"

echo.
if "%EC%"=="0" (
  echo FINAL: PASS
) else (
  echo FINAL: FAIL
  echo See: C:\RAH\RavenOS\state\RAH-OS-v0.8-FINALIZE.json
)
echo.
pause
exit /b %EC%

:download_fail
echo.
echo FINAL: FAIL
echo Could not restore the pinned RAH OS finalizer.
pause
exit /b 1
