@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH OS v0.6.1 - HOVED-PC Acceptance Fix

set "ROOT=C:\RAH\RavenOS"
set "ENGINE=%ROOT%\RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1"
set "REF=main"
set "RAW=https://raw.githubusercontent.com/NilsRa73/rah-platform/%REF%"

rem Explicit launcher may request one UAC prompt. Background helper PowerShell stays hidden.
fltmc >nul 2>&1
if errorlevel 1 (
  echo Requesting Administrator permission...
  powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>&1

echo.
echo ============================================================
echo       RAH OS v0.6.1 - HOVED-PC ACCEPTANCE FIX
echo ============================================================
echo  PRECHECK ^> SAFE REPAIR ^> START ^> POSTCHECK ^> FINAL
echo.
echo  Safe repair:
echo   - restores only missing fixed RAH files under C:\RAH
echo   - no USB or partition changes
echo   - no firewall changes
echo   - no arbitrary shell
echo   - no fake Worker Proof
echo   - background PowerShell checks are hidden/noninteractive
echo.

echo [1/2] Fetching acceptance engine...
powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';$dst='%ENGINE%';$tmp=$dst+'.download';Invoke-WebRequest -UseBasicParsing -Uri '%RAW%/RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1' -OutFile $tmp -TimeoutSec 60;if((Get-Item -LiteralPath $tmp).Length -lt 1000){throw 'Downloaded acceptance engine is too small.'};Move-Item -LiteralPath $tmp -Destination $dst -Force"
if errorlevel 1 goto :download_fail

echo [2/2] Running acceptance...
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%ENGINE%"
set "EC=%ERRORLEVEL%"

echo.
if "%EC%"=="0" (
  echo ============================================================
  echo FINAL: PASS
  echo ============================================================
) else if "%EC%"=="2" (
  echo ============================================================
  echo FINAL: PENDING
  echo One or more real/configuration gates still need proof.
  echo ============================================================
) else (
  echo ============================================================
  echo FINAL: FAIL
  echo ============================================================
)

echo Acceptance JSON: C:\RAH\RavenOS\state\RAH-OS-ACCEPTANCE.json
echo Sequence log   : C:\RAH\RavenOS\state\RAH-OS-HOVED-PC-SEQUENCE.json
echo.
pause
exit /b %EC%

:download_fail
echo.
echo FINAL: FAIL
echo Could not download the patched acceptance engine.
echo Check internet access and try again.
pause
exit /b 1
