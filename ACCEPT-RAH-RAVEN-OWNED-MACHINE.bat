@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Raven Daily Driver - Legacy Acceptance Compatibility

set "SCRIPT=%~dp0OWNED-MACHINE-ACCEPT-RAH-RAVEN.ps1"
if not exist "%SCRIPT%" (
  echo [FAIL] Missing compatibility script:
  echo %SCRIPT%
  exit /b 1
)

echo ================================================================
echo RAH RAVEN DAILY DRIVER v1.0 - LEGACY ACCEPTANCE COMPATIBILITY
echo ================================================================
echo Daily Driver is already STABLE.
echo This old launcher now forwards to the Stable self-diagnosing finalizer.
echo.

if /I "%~1"=="--self-test" (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -SelfTest
) else if "%~1"=="" (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
) else (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -FacebookArchive "%~1"
)
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo [PASS] Stable finalizer compatibility path completed.
  echo Report: C:\RAH\Logs\RAVEN-DAILY-DRIVER-FINAL-LATEST.json
) else (
  echo [FAIL] Stable finalizer compatibility path returned %RC%.
)
exit /b %RC%
