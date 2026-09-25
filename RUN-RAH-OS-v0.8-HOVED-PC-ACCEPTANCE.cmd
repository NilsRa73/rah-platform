@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH OS v0.8 - HOVED-PC Acceptance
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1"
set "EC=%ERRORLEVEL%"
echo.
if "%EC%"=="0" echo FINAL: PASS
if "%EC%"=="2" echo FINAL: PENDING
if not "%EC%"=="0" if not "%EC%"=="2" echo FINAL: FAIL
pause
exit /b %EC%
