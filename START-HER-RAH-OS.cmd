@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven OS - Front Door

if not exist "%~dp0RAH-OS-CONTROL.ps1" goto :bootstrap

echo.
echo ============================================================
echo               RAH RAVEN OS - FRONT DOOR
echo ============================================================
echo  PRECHECK - SAFE REPAIR IF NEEDED - START
echo  No arbitrary shell. No background network discovery.
echo.

if exist "%~dp0RAH-OS-SELFTEST.ps1" (
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0RAH-OS-SELFTEST.ps1" -Quick
  if errorlevel 1 (
    echo.
    echo PRECHECK found a Front Door problem.
    if exist "%~dp0REPAIR-RAH-OS.cmd" (
      echo Running fixed-allowlist Safe Repair...
      call "%~dp0REPAIR-RAH-OS.cmd"
    )
    powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File "%~dp0RAH-OS-SELFTEST.ps1" -Quick
    if errorlevel 1 goto :selftestfail
  )
)

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -STA -File "%~dp0RAH-OS-CONTROL.ps1"
set "EC=%ERRORLEVEL%"
if not "%EC%"=="0" (
  echo.
  echo FAIL: RAH OS control panel exited with code %EC%.
  pause
)
exit /b %EC%

:bootstrap
if exist "%~dp0INSTALL-RAH-OS.cmd" (
  echo Front Door files are incomplete. Running installer...
  call "%~dp0INSTALL-RAH-OS.cmd"
  exit /b %ERRORLEVEL%
)
goto :missing

:selftestfail
echo.
echo ============================================================
echo RAH RAVEN OS PRECHECK: FAIL
echo ============================================================
echo Safe Repair could not make the Front Door ready.
echo No Node Agent or remote action was started.
echo.
pause
exit /b 2

:missing
echo.
echo FAIL: RAH-OS-CONTROL.ps1 was not found next to this launcher.
echo INSTALL-RAH-OS.cmd is also unavailable.
echo Re-download the RAH OS Front Door package.
echo.
pause
exit /b 1
