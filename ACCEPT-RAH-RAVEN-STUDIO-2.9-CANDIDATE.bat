@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Studio 2.9 Owned Windows Acceptance

echo.
echo  RAH RAVEN STUDIO 2.9 - OWNED WINDOWS ACCEPTANCE
echo  ==================================================
echo  Dette promoterer aldri Stable automatisk.
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 goto :no_powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.ps1"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo Acceptance er ELIGIBLE for separat Stable review.
) else (
  echo Acceptance er ikke komplett. Stable forblir blokkert.
)
echo.
pause
exit /b %RC%

:no_powershell
echo FEIL: Windows PowerShell ble ikke funnet.
pause
exit /b 1
