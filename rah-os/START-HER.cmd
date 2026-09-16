@echo off
setlocal
cd /d "%~dp0"

title RAH OS Raven - USB Prep

echo ============================================================
echo  RAH OS RAVEN - START HER
echo ============================================================
echo.
echo Dette er en READ-ONLY forberedelse og diagnostikk.
echo Ingen USB-disk blir formatert eller skrevet automatisk.
echo.

where powershell.exe >nul 2>&1
if errorlevel 1 (
  echo [FAIL] Windows PowerShell ble ikke funnet.
  echo.
  pause
  exit /b 20
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-OS-USB-PREP.ps1" %*
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" (
  echo [PASS] RAH OS USB-prep er ferdig.
) else if "%RC%"=="2" (
  echo [INFO] Ingen ISO ble funnet ennaa. Se rapporten for neste steg.
) else (
  echo [FAIL] RAH OS USB-prep returnerte feil %RC%.
  echo Se RAH-OS-USB-PREP-*.txt i denne mappen.
)

echo.
pause
exit /b %RC%
