@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH OS v0.6 - Acceptance

if not exist "%~dp0ACCEPT-RAH-OS-v0.6.ps1" goto :missing

echo.
echo ============================================================
echo                 RAH OS v0.6 ACCEPTANCE
echo ============================================================
echo  Front Door - Raven Core - Local AI - AnythingLLM - Worker
echo  Read-only checks except for the local acceptance state file.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0ACCEPT-RAH-OS-v0.6.ps1"
set "EC=%ERRORLEVEL%"

if "%EC%"=="0" (
  echo.
  echo PASS: RAH OS v0.6 acceptance is green.
  pause
  exit /b 0
)
if "%EC%"=="2" (
  echo.
  echo PENDING: Core is safe, but one or more v0.6 gates still need proof.
  echo Open RAH Raven OS Front Door to see the remaining area.
  pause
  exit /b 2
)

echo.
echo FAIL: A v0.6 acceptance gate is invalid or failed.
pause
exit /b %EC%

:missing
echo FAIL: ACCEPT-RAH-OS-v0.6.ps1 was not found next to this launcher.
echo Run INSTALL-RAH-OS.cmd or SAFE REPAIR.
pause
exit /b 1
