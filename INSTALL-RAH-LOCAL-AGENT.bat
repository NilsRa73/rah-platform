@echo off
setlocal EnableExtensions
chcp 65001 >nul
color 0E
title RAH LOCAL AGENT + AI BRIDGE

echo ============================================================
echo  RAH LOCAL AGENT + AI BRIDGE - ONE CLICK INSTALL
echo ============================================================
echo.

fltmc >nul 2>&1
if errorlevel 1 (
  echo Requesting administrator rights...
  powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)

set "RAHPS=%TEMP%\INSTALL-RAH-LOCAL-AGENT.ps1"
echo [1/2] Downloading current installer from RAH GitHub...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/INSTALL-RAH-LOCAL-AGENT.ps1' -OutFile '%RAHPS%'"
if errorlevel 1 goto :fail

echo [2/2] Installing and testing RAH Local Agent...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAHPS%"
if errorlevel 1 goto :fail

echo.
echo ============================================================
echo  RAH LOCAL AGENT INSTALL COMPLETE
echo ============================================================
echo.
echo If Tampermonkey opens the generated RAH bridge, choose Install once.
echo Then return to this ChatGPT conversation.
echo.
pause
exit /b 0

:fail
color 0C
echo.
echo ============================================================
echo  RAH INSTALL FAILED
echo ============================================================
echo The installer above printed the exact failing step.
echo.
pause
exit /b 1
