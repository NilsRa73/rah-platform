@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Raven Desktop Bridge - Canonical 18765

set "BRIDGE_URL=http://127.0.0.1:18765/health"

echo.
echo  RAH RAVEN DESKTOP BRIDGE
echo  =========================
echo  Canonical endpoint: http://127.0.0.1:18765
echo  Council proxy:      http://127.0.0.1:18765/lm/chat
echo.

where py >nul 2>nul
if %errorlevel%==0 (
  set "PY=py"
) else (
  where python >nul 2>nul
  if errorlevel 1 goto :no_python
  set "PY=python"
)

if not exist ".venv\Scripts\python.exe" (
  echo [1/4] Creating local Python environment...
  %PY% -m venv .venv
  if errorlevel 1 goto :error
) else (
  echo [1/4] Python environment found.
)

echo [2/4] Installing or checking local dependencies...
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check --quiet -r requirements.txt
if errorlevel 1 goto :error

echo [3/4] Checking whether canonical Bridge is already running...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $h=Invoke-RestMethod -Uri '%BRIDGE_URL%' -TimeoutSec 2; if($h.ok -eq $true -and $h.council_proxy -eq $true){exit 0}else{exit 2} } catch { exit 1 }"
if not errorlevel 1 (
  echo       [PASS] Bridge and Council proxy already answer on 18765.
  echo.
  echo Nothing else is required. Keep the existing Bridge process running.
  pause
  exit /b 0
)

echo [4/4] Starting canonical Raven Bridge...
echo.
echo Keep this window open while Raven Studio is running.
echo If the Bridge stops, the Python error will remain visible here.
echo.
".venv\Scripts\python.exe" raven_bridge.py
set "RC=%ERRORLEVEL%"
if not "%RC%"=="0" goto :error_code
exit /b 0

:no_python
echo.
echo ERROR: Python was not found.
echo Install Python 3.11 or newer, then run this file again.
pause
exit /b 1

:error_code
echo.
echo ERROR: Canonical Raven Bridge exited with code %RC%.
echo Expected local endpoint: http://127.0.0.1:18765
echo Send the text in this window if the error repeats.
pause
exit /b %RC%

:error
echo.
echo ERROR: Raven Bridge setup could not complete.
echo Review the message above, then run this file again.
pause
exit /b 1
