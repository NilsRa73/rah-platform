@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Core 7.0 - Acceptance
set "ACCEPT=%~dp0RavenCore7\RAVEN-CORE-7-ACCEPTANCE.ps1"
if not exist "%ACCEPT%" set "ACCEPT=%~dp0RAVEN-CORE-7-ACCEPTANCE.ps1"
if not exist "%ACCEPT%" goto :missing

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%ACCEPT%"
set "EC=%ERRORLEVEL%"
echo.
if "%EC%"=="0" (
  echo Core 7 foundation acceptance completed without FAIL.
) else (
  echo Core 7 foundation acceptance FAILED with code %EC%.
)
pause
exit /b %EC%

:missing
echo FAIL: RAVEN-CORE-7-ACCEPTANCE.ps1 was not found.
pause
exit /b 2
