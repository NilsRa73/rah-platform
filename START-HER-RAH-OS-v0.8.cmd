@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH OS v0.8 - Front Door

echo.
echo ============================================================
echo                RAH OS v0.8 - FRONT DOOR
echo ============================================================
echo  PRECHECK - SAFE REPAIR IF NEEDED - CONTROL CENTER
echo.

if not exist "%~dp0RAH-OS-SELFTEST.ps1" goto :missing
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-OS-SELFTEST.ps1" -Quick
if errorlevel 1 (
  echo PRECHECK found a package problem. Running safe repair...
  if not exist "%~dp0REPAIR-RAH-OS.cmd" goto :missing
  call "%~dp0REPAIR-RAH-OS.cmd"
  if errorlevel 1 goto :fail
)

if not exist "%~dp0RAH-OS-CONTROL.ps1" goto :missing
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0RAH-OS-CONTROL.ps1"
exit /b %ERRORLEVEL%

:missing
echo FAIL: v0.8 Front Door files are incomplete.
echo Run INSTALL-RAH-OS.cmd or RAH-OS-v0.8-HOVED-PC-ONE-CLICK.cmd.
pause
exit /b 1

:fail
echo FAIL: Safe Repair could not restore the v0.8 package.
pause
exit /b 2
