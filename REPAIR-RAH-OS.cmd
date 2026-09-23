@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven OS - Safe Repair

if not exist "%~dp0RAH-OS-SELFTEST.ps1" goto :missing

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$p=[Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent(); if(-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){exit 42}"
if "%ERRORLEVEL%"=="42" (
  echo Requesting Administrator permission for C:\RAH repair...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
    "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

echo.
echo ============================================================
echo              RAH RAVEN OS - SAFE REPAIR
echo ============================================================
echo  Refreshes only the fixed Front Door allowlist.
echo  Does not start Node Agent, change firewall rules, or run a shell.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-OS-SELFTEST.ps1" -RepairFrontDoor
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo FAIL: Safe repair/self-test exited with code %EC%.
  pause
)
exit /b %EC%

:missing
echo FAIL: RAH-OS-SELFTEST.ps1 was not found next to this file.
echo Re-run INSTALL-RAH-OS.cmd.
pause
exit /b 1
