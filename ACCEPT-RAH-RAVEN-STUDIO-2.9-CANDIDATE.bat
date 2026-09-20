@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Raven Studio 2.9 - Legacy Compatibility

set "COMPAT=%~dp0ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.ps1"
if not exist "%COMPAT%" (
  echo [FAIL] Missing Studio 2.9 compatibility wrapper.
  exit /b 2
)

echo ================================================================
echo RAH RAVEN STUDIO 2.9 - RETIRED / COMPATIBILITY
echo ================================================================
echo Studio 2.9 has been superseded by Studio 3.0 Stable.
echo This old entry point forwards only to the canonical Studio 3.0 finalizer.
echo.

if /I "%~1"=="--self-test" (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%COMPAT%" -SelfTest
) else (
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%COMPAT%"
)
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo [PASS] Studio 3.0 Stable compatibility path completed.
  echo Report: C:\RAH\Logs\RAVEN-STUDIO-FINAL-LATEST.json
) else (
  echo [FAIL] Studio 3.0 Stable finalizer returned %RC%.
)
exit /b %RC%
