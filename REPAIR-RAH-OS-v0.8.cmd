@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH OS v0.8 - Safe Repair

if not exist "%~dp0RAH-OS-v0.8-SELFTEST.ps1" goto :missing
echo.
echo ============================================================
echo                RAH OS v0.8 SAFE REPAIR
echo ============================================================
echo  Repairs only the fixed candidate allowlist.
echo  No USB, partition, firewall or remote-node changes.
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-OS-v0.8-SELFTEST.ps1" -Repair
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" pause
exit /b %EC%

:missing
echo FAIL: RAH-OS-v0.8-SELFTEST.ps1 missing.
pause
exit /b 1
