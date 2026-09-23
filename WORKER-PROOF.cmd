@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Core 7.0 - Worker Proof

set "PROOF=%~dp0RavenCore7\RAVEN-CORE-7-WORKER-PROOF.ps1"
if not exist "%PROOF%" set "PROOF=%~dp0RAVEN-CORE-7-WORKER-PROOF.ps1"
if not exist "%PROOF%" goto :missing

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%PROOF%" -Mode Prepare
set "EC=%ERRORLEVEL%"
echo.
if "%EC%"=="0" (
  echo Worker Proof completed without FAIL.
) else (
  echo Worker Proof returned code %EC%.
)
pause
exit /b %EC%

:missing
echo FAIL: RAVEN-CORE-7-WORKER-PROOF.ps1 was not found.
pause
exit /b 2
