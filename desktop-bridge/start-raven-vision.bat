@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Raven Vision - One Click Start

set "RAVEN_URL=http://127.0.0.1:18765/vision/ui"
set "LM_URL=http://127.0.0.1:1234/v1/models"
set "LM_JSON=%TEMP%\rah-raven-lm-models.json"

echo.
echo  RAH RAVEN VISION - POWERSHELL-FREE LOCAL CHAIN
echo  ===============================================
echo  Bridge: http://127.0.0.1:18765
echo.

where py >nul 2>nul
if %errorlevel%==0 (
  set "PY=py -3"
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

echo [3/5] Checking and recovering canonical Desktop Bridge...
if exist "raven_recover.py" (
  ".venv\Scripts\python.exe" raven_recover.py
  if errorlevel 1 goto :bridge_error
) else (
  curl.exe --silent --fail --max-time 3 "http://127.0.0.1:18765/health" >nul 2>nul
  if errorlevel 1 (
    start "RAH Desktop Bridge" /min ".venv\Scripts\python.exe" raven_bridge.py
    call :wait_bridge
    if errorlevel 1 goto :bridge_error
  )
)

echo [4/5] Checking LM Studio without PowerShell...
curl.exe --silent --fail --max-time 3 "%LM_URL%" -o "%LM_JSON%" >nul 2>nul
if errorlevel 1 (
  echo       WARNING: LM Studio server is not running on port 1234.
  echo       Raven Vision itself is still ready.
) else (
  ".venv\Scripts\python.exe" -c "import json; d=json.load(open(r'%LM_JSON%',encoding='utf-8')); raise SystemExit(0 if isinstance(d.get('data'),list) and len(d['data']) else 2)"
  if errorlevel 2 (
    echo       WARNING: LM Studio is running, but no model is loaded.
  ) else (
    echo       LM Studio and a loaded model were found.
  )
)

echo [5/5] Opening local RAH Raven Vision...
start "" "%RAVEN_URL%"

echo.
echo Running Raven Doctor...
".venv\Scripts\python.exe" doctor.py

echo.
echo Raven Vision is ready. Desktop Bridge is on port 18765.
echo Press any key to close this launcher; the Bridge remains available.
pause >nul
exit /b 0

:wait_bridge
for /L %%G in (1,1,15) do (
  timeout /t 1 /nobreak >nul
  curl.exe --silent --fail --max-time 2 "http://127.0.0.1:18765/health" >nul 2>nul
  if not errorlevel 1 exit /b 0
)
exit /b 1

:no_python
echo.
echo ERROR: Python was not found.
echo Install Python 3.11 or newer, then run this file again.
pause
exit /b 1

:bridge_error
echo.
echo ERROR: Canonical Desktop Bridge recovery failed or port 18765 is occupied.
echo No unknown process was terminated.
pause
exit /b 1

:error
echo.
echo ERROR: Raven Vision setup could not complete.
echo Review the message above, then run this file again.
pause
exit /b 1
