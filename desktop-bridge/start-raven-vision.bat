@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Vision - One Click Start

set "RAVEN_URL=https://nilsra73.github.io/rah-platform/#vision"
set "BRIDGE_URL=http://127.0.0.1:8765/health"
set "LM_URL=http://127.0.0.1:1234/v1/models"

echo.
echo  RAH RAVEN VISION v1.3
echo  ======================
echo  Starting the complete local Vision chain...
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
  echo [1/5] Creating local Python environment...
  %PY% -m venv .venv
  if errorlevel 1 goto :error
) else (
  echo [1/5] Python environment found.
)

echo [2/5] Checking dependencies...
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check --quiet -r requirements.txt
if errorlevel 1 goto :error

echo [3/5] Starting Desktop Bridge when needed...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Uri '%BRIDGE_URL%' -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
  start "RAH Desktop Bridge" /min ".venv\Scripts\python.exe" server.py
  call :wait_bridge
  if errorlevel 1 goto :bridge_error
) else (
  echo       Desktop Bridge is already running.
)

echo [4/5] Checking LM Studio...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $m=Invoke-RestMethod -Uri '%LM_URL%' -TimeoutSec 3; if($m.data.Count -gt 0){ exit 0 } else { exit 2 } } catch { exit 1 }"
if %errorlevel%==1 (
  echo       WARNING: LM Studio server is not running on port 1234.
  echo       Open LM Studio, load a vision model, then start Local Server.
) else if %errorlevel%==2 (
  echo       WARNING: LM Studio is running, but no model is loaded.
) else (
  echo       LM Studio and a loaded model were found.
)

echo [5/5] Opening RAH Raven Command Center...
start "" "%RAVEN_URL%"

echo.
echo Running Raven Doctor...
timeout /t 2 /nobreak >nul
".venv\Scripts\python.exe" doctor.py

echo.
echo Raven Vision is open. Keep this window for status and diagnostics.
echo Press any key to close this launcher. The bridge keeps running separately.
pause >nul
exit /b 0

:wait_bridge
for /L %%G in (1,1,12) do (
  timeout /t 1 /nobreak >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Uri '%BRIDGE_URL%' -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"
  if not errorlevel 1 exit /b 0
)
exit /b 1

:no_python
echo.
echo ERROR: Python was not found.
echo Install Python 3.11 or newer from https://www.python.org/downloads/windows/
echo During installation, enable 'Add Python to PATH'.
pause
exit /b 1

:bridge_error
echo.
echo ERROR: Desktop Bridge did not answer on port 8765.
echo Run start-bridge.bat to see the detailed Python error.
pause
exit /b 1

:error
echo.
echo ERROR: Raven Vision setup could not complete.
echo Review the message above, then run this file again.
pause
exit /b 1
