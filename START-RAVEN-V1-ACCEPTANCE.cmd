@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH RAVEN V1 FINAL ACCEPTANCE

set "RAH_SELF=%~f0"
set "RAH_PS=%~dp0raven\windows\RAH-RAVEN-V1-ACCEPTANCE.ps1"

if /I "%~1"=="--self-test" goto SELFTEST

fltmc >nul 2>&1
if "%ERRORLEVEL%"=="0" goto RUN

echo [RAH] Final acceptance trenger Administrator for eksisterende Agent Team tasks.
echo [RAH] Starter samme fil med UAC ...
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';Start-Process -FilePath $env:RAH_SELF -Verb RunAs -ArgumentList '__RAH_ADMIN__'"
if errorlevel 1 goto FAIL_UAC
exit /b 0

:RUN
echo.
echo ==============================================================
echo RAH RAVEN V1 - FINAL ACCEPTANCE
echo Bridge repair ^> Bridge ^> Doctor/Capture ^> Agent Team LIVE
echo ==============================================================

call "raven\windows\PREPARE-RAVEN-BRIDGE.cmd"
if errorlevel 1 goto FAIL_PREPARE

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RAH_PS%"
set "RAH_RC=%ERRORLEVEL%"

echo.
if "%RAH_RC%"=="0" (
  echo ==============================================================
  echo RAH RAVEN V1: FULL PASS
  echo Rapport: %~dp0Logs\RAVEN-V1-ACCEPTANCE-LATEST.txt
  echo ==============================================================
) else (
  echo ==============================================================
  echo RAH RAVEN V1: FAIL - kode %RAH_RC%
  echo Rapport: %~dp0Logs\RAVEN-V1-ACCEPTANCE-LATEST.txt
  echo ==============================================================
)
pause
exit /b %RAH_RC%

:SELFTEST
call "raven\windows\PREPARE-RAVEN-BRIDGE.cmd" --check
if errorlevel 1 exit /b 31
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_PS%" -SelfTest
exit /b %ERRORLEVEL%

:FAIL_UAC
echo [FAIL] UAC ble avbrutt.
pause
exit /b 18

:FAIL_PREPARE
echo [FAIL] Raven Bridge-miljoet kunne ikke klargjoeres.
pause
exit /b 32
