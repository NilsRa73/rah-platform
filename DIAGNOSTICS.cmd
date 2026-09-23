@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Core 7.0 - Diagnostics
set "CORE=%~dp0RavenCore7\RAVEN-CORE-7.ps1"
if not exist "%CORE%" set "CORE=%~dp0RAVEN-CORE-7.ps1"
if not exist "%CORE%" goto :missing
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%CORE%" -Mode Diagnostics
set "EC=%ERRORLEVEL%"
echo.
pause
exit /b %EC%
:missing
echo FAIL: RAVEN-CORE-7.ps1 was not found.
pause
exit /b 2
