@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven OS - Front Door

if not exist "%~dp0RAH-OS-CONTROL.ps1" goto :missing

echo.
echo ============================================================
echo               RAH RAVEN OS - FRONT DOOR
echo ============================================================
echo  Local orchestrator for stable RAH components.
echo  No arbitrary shell. No background network discovery.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0RAH-OS-CONTROL.ps1"
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo FAIL: RAH OS control panel exited with code %EC%.
  pause
)
exit /b %EC%

:missing
echo.
echo FAIL: RAH-OS-CONTROL.ps1 was not found next to this launcher.
echo Re-run INSTALL-RAH-OS.cmd.
echo.
pause
exit /b 1
