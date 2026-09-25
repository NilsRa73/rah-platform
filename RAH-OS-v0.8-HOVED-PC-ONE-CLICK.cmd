@echo off
setlocal EnableExtensions
title RAH OS v0.8 - HOVED-PC ONE CLICK

set "ROOT=C:\RAH\RavenOS"
set "REF=f9624bee3f63c7a9e2b09f8b6f9eb195a1515b3f"
set "TMP=%USERPROFILE%\Downloads\RAH-OS-v0.8-INSTALL.download.cmd"

echo.
echo ============================================================
echo          RAH OS v0.8 - HOVED-PC ONE CLICK
echo ============================================================
echo  1  Download candidate installer to Downloads ^(not TEMP^)
echo  2  Backup current C:\RAH\RavenOS
echo  3  Install fixed v0.8 allowlist
echo  4  Self-test
echo  5  Run ordered acceptance
echo.
echo  No USB or partition changes.
echo  Node Agent is not auto-started.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';$u='https://raw.githubusercontent.com/NilsRa73/rah-platform/%REF%/INSTALL-RAH-OS-v0.8.cmd';Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile '%TMP%';if((Get-Item -LiteralPath '%TMP%').Length -lt 500){throw 'Installer download too small'}"
if errorlevel 1 goto :fail

set "RAH_OS_SOURCE_REF=%REF%"
set "RAH_OS_RUN_ACCEPTANCE=1"
call "%TMP%"
set "EC=%ERRORLEVEL%"
del /q "%TMP%" >nul 2>&1
exit /b %EC%

:fail
echo.
echo FAIL: Could not download the v0.8 installer.
pause
exit /b 1
