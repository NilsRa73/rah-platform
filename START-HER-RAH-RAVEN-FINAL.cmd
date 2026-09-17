@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven HOVED-PC FINAL / STABLE

set "RAH_SELF_PATH=%~f0"
set "RAH_FINAL_PS1=%~dp0RAH-RAVEN-HOVED-PC-FINAL.ps1"

if not exist "%RAH_FINAL_PS1%" (
  echo.
  echo [FAIL] Mangler RAH-RAVEN-HOVED-PC-FINAL.ps1
  echo Kjor denne filen fra roten av rah-platform.
  echo.
  pause
  exit /b 2
)

rem One-click contract: self-elevate once, then keep the Administrator token
rem for the final verifier, Scheduled Task repair and Raven child processes.
fltmc >nul 2>&1
if errorlevel 1 (
  echo [UAC] Ber om Administrator for RAH Raven FINAL/STABLE...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/d','/c','""' + $env:RAH_SELF_PATH + '"" __RAH_ADMIN__' -Verb RunAs"
  exit /b
)

if /I "%~1"=="__RAH_ADMIN__" shift

echo.
echo ====================================================================
echo  RAH RAVEN HOVED-PC - ONE CLICK FINAL / STABLE
echo ====================================================================
echo  PRECHECK ^> REPAIR ^> START ^> POSTCHECK ^> SYSTEM-INVENTORY
echo.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RAH_FINAL_PS1%"
set "RAH_RC=%ERRORLEVEL%"

echo.
if "%RAH_RC%"=="0" (
  echo ====================================================================
  echo  PASS - RAH Raven HOVED-PC FINAL/STABLE
  echo  Rapport: C:\RAH\Logs\RAVEN-HOVED-PC-FINAL-LATEST.json
  echo ====================================================================
) else (
  echo ====================================================================
  echo  FAIL - RAH Raven HOVED-PC trenger fortsatt reparasjon
  echo  Se: C:\RAH\Logs\RAVEN-HOVED-PC-FINAL-LATEST.json
  echo ====================================================================
)
echo.
pause
exit /b %RAH_RC%
