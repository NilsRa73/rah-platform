@echo off
setlocal
cd /d "%~dp0"
title Install RAH Raven Daily Driver

set "APP=%~dp0apps\rah-raven-daily-driver"
if not exist "%APP%\main.py" (
  echo ERROR: Daily Driver app folder is missing.
  pause
  exit /b 1
)

where python >nul 2>nul
if errorlevel 1 (
  echo ERROR: Python 3 was not found in PATH.
  echo Install Python 3 for Windows and enable "Add Python to PATH".
  pause
  exit /b 1
)

cd /d "%APP%"
if not exist ".venv\Scripts\python.exe" (
  echo Creating isolated Python environment...
  python -m venv .venv
)

echo Installing the only required third-party dependency...
".venv\Scripts\python.exe" -m pip install --upgrade pip
".venv\Scripts\python.exe" -m pip install -r requirements.txt

for %%D in (data logs reports devices imports exports state) do (
  if not exist "runtime\%%D" mkdir "runtime\%%D"
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%APP%\install_windows.ps1"
if errorlevel 1 exit /b 1

echo.
echo Checking LM Studio local server on 127.0.0.1:1234...
powershell.exe -NoProfile -Command "try { $r=Invoke-RestMethod -TimeoutSec 2 http://127.0.0.1:1234/v1/models; Write-Host 'LM Studio: ONLINE' -ForegroundColor Green } catch { Write-Host 'LM Studio: OFFLINE - start the server in LM Studio Developer tab when you want local AI.' -ForegroundColor Yellow }"

echo.
echo Installation complete.
if /I "%RAH_RAVEN_INSTALL_NO_START%"=="1" (
  echo Headless acceptance mode: installation verified; Daily Driver start skipped.
  exit /b 0
)

echo Starting RAH Raven Daily Driver...
start "" "%APP%\START-RAH-RAVEN.bat"
exit /b 0
