@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Raven Daily Driver - Final Owned Machine Acceptance

set "SCRIPT=%~dp0OWNED-MACHINE-ACCEPT-RAH-RAVEN.ps1"
if not exist "%SCRIPT%" (
  echo [FAIL] Owned-machine acceptance script was not found:
  echo %SCRIPT%
  exit /b 1
)

echo ================================================================
echo RAH RAVEN DAILY DRIVER - FINAL OWNED WINDOWS ACCEPTANCE
echo PRECHECK ^> SAFE REPAIR ^> RUNTIME TEST ^> FINAL REPORT
echo ================================================================
echo Stable promotion is ALWAYS BLOCKED by this launcher.
echo Use only your own archive and representative owned tool exports.
echo.

if /I "%~1"=="--self-test" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -SelfTest
) else if "%~1"=="" (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -FacebookArchive "%~1"
)
set "RC=%ERRORLEVEL%"

echo.
echo ================================================================
if "%RC%"=="0" (
  echo [PASS] Owned-machine acceptance is eligible for MANUAL Stable review.
  echo Stable promotion remains BLOCKED and is not automated.
) else if "%RC%"=="2" (
  echo [PENDING] Acceptance is incomplete.
  echo Fix the single prerequisite printed above, then run THIS SAME BAT again.
  echo Stable promotion remains BLOCKED.
) else (
  echo [FAIL] Acceptance failed.
  echo Review the first FAIL message above, then run THIS SAME BAT again.
  echo Stable promotion remains BLOCKED.
)
echo.
echo Human-readable report:
echo %%USERPROFILE%%\Desktop\RAH Daily Driver Evidence\FINAL-ACCEPTANCE-SUMMARY.txt
echo ================================================================
exit /b %RC%
