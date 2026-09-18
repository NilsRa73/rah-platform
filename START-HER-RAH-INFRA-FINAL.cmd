@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH INFRA FINAL - HOVED-PC + LENOVO

set "HOVED=%~dp0RAH-RAVEN-HOVED-PC-FINAL.ps1"
set "LINK=%~dp0RAH-HOVED-PC-LENOVO-LINK-FINAL.ps1"

if not exist "%HOVED%" (
  echo [FAIL] Mangler RAH-RAVEN-HOVED-PC-FINAL.ps1
  pause
  exit /b 2
)
if not exist "%LINK%" (
  echo [FAIL] Mangler RAH-HOVED-PC-LENOVO-LINK-FINAL.ps1
  pause
  exit /b 2
)

echo.
echo ====================================================================
echo  RAH INFRA FINAL
echo  1. HOVED-PC Raven FINAL/STABLE
echo  2. HOVED-PC -> Lenovo Worker health + systemInfo
echo ====================================================================
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%HOVED%"
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" goto FAIL

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%LINK%" %*
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" goto FAIL

echo.
echo ====================================================================
echo  PASS - RAH INFRA ER FERDIG FOR DENNE CHATTEN
echo  HOVED-PC + LENOVO Worker er verifisert ende-til-ende.
echo ====================================================================
echo.
pause
exit /b 0

:FAIL
echo.
echo ====================================================================
echo  FAIL - RAH INFRA FINAL stoppet med exit %RC%
echo  Se C:\RAH\Logs for siste JSON-rapport.
echo ====================================================================
echo.
pause
exit /b %RC%
