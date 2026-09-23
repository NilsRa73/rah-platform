@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH OS v0.6 - HOVED-PC Acceptance

set "RUNNER=%~dp0RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1"
if not exist "%RUNNER%" set "RUNNER=C:\RAH\RavenOS\RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1"
if not exist "%RUNNER%" goto :missing

echo.
echo ============================================================
echo       RAH OS v0.6 - HOVED-PC ACCEPTANCE
echo ============================================================
echo  1 Front Door
echo  2 Raven Core
echo  3 Local AI
echo  4 AnythingLLM
echo  5 Worker Proof
echo  6 Combined RAH-OS-ACCEPTANCE.json
echo.
echo  Worker Proof validates existing evidence only.
echo  No Node token is read or stored by this runner.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RUNNER%"
set "EC=%ERRORLEVEL%"

echo.
if "%EC%"=="0" echo PASS: All RAH OS v0.6 HOVED-PC gates are green.
if "%EC%"=="2" echo PENDING: One or more gates still need runtime/configuration/physical proof.
if not "%EC%"=="0" if not "%EC%"=="2" echo FAIL: One or more required gates failed or produced invalid evidence.
echo.
echo Result: C:\RAH\RavenOS\state\RAH-OS-ACCEPTANCE.json
pause
exit /b %EC%

:missing
echo FAIL: RUN-RAH-OS-v0.6-HOVED-PC-ACCEPTANCE.ps1 was not found.
echo Run INSTALL-RAH-OS.cmd or SAFE REPAIR first.
pause
exit /b 1
