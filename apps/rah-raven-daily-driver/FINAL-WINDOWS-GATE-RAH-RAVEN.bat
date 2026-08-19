@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Raven Daily Driver 1.0 - Final Windows Gate

echo.
echo ============================================================
echo   RAH RAVEN DAILY DRIVER 1.0 - FINAL WINDOWS GATE
echo ============================================================
echo   This gate does NOT promote Stable.
echo   It only runs owned-machine acceptance checks and writes
 echo   privacy-safe evidence under Desktop\RAH Daily Driver Evidence.
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo ERROR: Windows PowerShell was not found.
  pause
  exit /b 1
)

if "%~1"=="" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0FINAL-WINDOWS-GATE-RAH-RAVEN.ps1"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0FINAL-WINDOWS-GATE-RAH-RAVEN.ps1" -ArchivePath "%~1"
)
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo [PASS] Core Windows evidence is ready for final owned-tool review.
) else if "%RC%"=="2" (
  echo [PARTIAL] Evidence was written, but one or more required checks are still pending.
) else (
  echo [STOP] Final Windows Gate stopped with exit code %RC%.
)
echo.
pause
exit /b %RC%
