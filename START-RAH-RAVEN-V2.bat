@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title RAH Raven One-Click Launcher v2.6

set "RAVEN_URL=%~dp0RAH-RAVEN-START.html"
set "BRIDGE_DIR=%~dp0desktop-bridge"
set "BRIDGE_PORT=18765"
set "BRIDGE_HEALTH=http://127.0.0.1:18765/health"
set "LM_HEALTH=http://127.0.0.1:1234/v1/models"
set "BRIDGE_LOG=%BRIDGE_DIR%\rah-bridge-startup.log"
set "BRIDGE_FILE=server_v16.py"

echo.
echo  RAH RAVEN ONE-CLICK LAUNCHER v2.6
echo  ===================================
echo.

where py >nul 2>nul
if %errorlevel%==0 (
  set "PY=py"
) else (
  where python >nul 2>nul
  if errorlevel 1 goto :no_python
  set "PY=python"
)

echo [1/6] Checking LM Studio...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Uri '%LM_HEALTH%' -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"
if errorlevel 1 (
  echo       LM Studio server is not answering. Trying to open LM Studio...
  set "LM_EXE="
  for %%P in (
    "%LOCALAPPDATA%\Programs\LM Studio\LM Studio.exe"
    "%LOCALAPPDATA%\LM Studio\LM Studio.exe"
    "%ProgramFiles%\LM Studio\LM Studio.exe"
    "%ProgramFiles(x86)%\LM Studio\LM Studio.exe"
  ) do if exist "%%~P" if not defined LM_EXE set "LM_EXE=%%~P"
  if defined LM_EXE (
    start "LM Studio" "!LM_EXE!"
    echo       LM Studio opened. Load a model and start Local Server on port 1234.
  ) else (
    echo       LM Studio was not found automatically. Open it manually.
  )
) else (
  echo       LM Studio server is ready.
)

echo [2/6] Checking Desktop Bridge files...
if not exist "%BRIDGE_DIR%\%BRIDGE_FILE%" goto :missing_bridge
if not exist "%RAVEN_URL%" goto :missing_startpage
pushd "%BRIDGE_DIR%"

if not exist ".venv\Scripts\python.exe" (
  echo       Creating local Python environment...
  %PY% -m venv .venv
  if errorlevel 1 goto :bridge_error
)

echo [3/6] Checking Python packages...
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check --quiet -r requirements.txt
if errorlevel 1 goto :bridge_error

echo [4/6] Testing bridge code...
".venv\Scripts\python.exe" -m py_compile "%BRIDGE_FILE%"
if errorlevel 1 goto :bridge_error
".venv\Scripts\python.exe" -c "import flask, flask_cors, PIL, mss, pypdf; print('      Python modules: READY')"
if errorlevel 1 goto :bridge_error

echo [5/6] Starting Desktop Bridge v1.6 on port %BRIDGE_PORT%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$owners=Get-NetTCPConnection -LocalPort %BRIDGE_PORT% -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique; foreach($owner in $owners){ Stop-Process -Id $owner -Force -ErrorAction SilentlyContinue }" >nul 2>nul
timeout /t 2 /nobreak >nul

del "%BRIDGE_LOG%" >nul 2>nul
del "%BRIDGE_LOG%.err" >nul 2>nul
set "RAH_BRIDGE_HOST=127.0.0.1"
set "RAH_BRIDGE_PORT=%BRIDGE_PORT%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:RAH_BRIDGE_HOST='127.0.0.1'; $env:RAH_BRIDGE_PORT='%BRIDGE_PORT%'; Start-Process -FilePath '.venv\Scripts\python.exe' -ArgumentList '%BRIDGE_FILE%' -WorkingDirectory '%BRIDGE_DIR%' -WindowStyle Minimized -RedirectStandardOutput '%BRIDGE_LOG%' -RedirectStandardError '%BRIDGE_LOG%.err'"

for /L %%G in (1,1,20) do (
  timeout /t 1 /nobreak >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; if($h.case_center -eq $true){ exit 0 } else { exit 1 } } catch { exit 1 }"
  if not errorlevel 1 goto :bridge_ready
)
goto :bridge_error

:bridge_ready
echo       Desktop Bridge is ready on port %BRIDGE_PORT%.
echo       Local Case Center: http://127.0.0.1:%BRIDGE_PORT%/case
popd

echo [6/6] Opening RAH Raven Startside v2.6...
start "" "%RAVEN_URL%"
echo.
echo  RAH Raven Startside is open and ready.
echo  Use Local Case Center for PDF extraction and source-based AI analysis.
echo.
pause
exit /b 0

:no_python
echo.
echo ERROR: Python was not found.
echo Install Python 3.11 or newer from:
echo https://www.python.org/downloads/windows/
echo Enable "Add Python to PATH" during installation.
pause
exit /b 1

:missing_bridge
echo.
echo ERROR: desktop-bridge\%BRIDGE_FILE% was not found.
echo Download and extract the newest complete RAH Raven package.
pause
exit /b 1

:missing_startpage
echo.
echo ERROR: RAH-RAVEN-START.html was not found.
echo Download and extract the newest complete RAH Raven package.
pause
exit /b 1

:bridge_error
echo.
echo ERROR: Desktop Bridge could not start on port %BRIDGE_PORT%.
echo.
if exist "%BRIDGE_LOG%" (
  echo -------- Bridge output --------
  type "%BRIDGE_LOG%"
)
if exist "%BRIDGE_LOG%.err" (
  echo -------- Bridge error ---------
  type "%BRIDGE_LOG%.err"
)
echo -------- End diagnostics --------
popd 2>nul
echo.
echo Copy all text from "ERROR" down into ChatGPT.
pause
exit /b 1
