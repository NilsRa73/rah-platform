@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Raven Owned Machine Acceptance

set "SCRIPT=%~dp0OWNED-MACHINE-ACCEPT-RAH-RAVEN.ps1"
if not exist "%SCRIPT%" (
  echo ERROR: Owned-machine acceptance script was not found:
  echo %SCRIPT%
  exit /b 1
)

echo ================================================================
echo RAH RAVEN - OWNED WINDOWS MACHINE ACCEPTANCE
echo ================================================================
echo Stable promotion is ALWAYS blocked by this launcher.
echo Use only your own archive and representative owned tool exports.
echo.

if "%~1"=="" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -FacebookArchive "%~1"
)
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo [RAH Raven] Owned-machine acceptance is eligible for MANUAL Stable review.
  echo Stable promotion remains BLOCKED and is not automated.
) else if "%RC%"=="2" (
  echo [RAH Raven] Acceptance is incomplete. Complete the printed manual checks and rerun.
  echo Stable promotion remains BLOCKED.
) else (
  echo [RAH Raven] Acceptance failed. Review the error above.
  echo Stable promotion remains BLOCKED.
)
exit /b %RC%
