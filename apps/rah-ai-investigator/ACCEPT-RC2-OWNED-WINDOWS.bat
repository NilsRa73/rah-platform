@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH AI Investigator RC2 Owned Windows Acceptance

echo.
echo  RAH AI INVESTIGATOR v1.0 RC2 - OWNED WINDOWS ACCEPTANCE
echo  ===========================================================
echo  Local-only. Use only your own data or explicitly authorized data.
echo  This can NEVER promote Stable automatically.
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 goto :no_powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%~dp0ACCEPT-RC2-OWNED-WINDOWS.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo Acceptance is ELIGIBLE for a separate Stable review.
) else (
  echo Acceptance is not complete. Stable remains BLOCKED.
)
echo.
pause
exit /b %RC%

:no_powershell
echo ERROR: Windows PowerShell was not found.
pause
exit /b 1
