@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title RAH Raven One-Click Launcher v3.0

set "RAVEN_URL=%~dp0RAH-RAVEN-NOW-V2.html"
set "STUDIO_URL=%~dp0RAH-RAVEN-START.html"
set "BRIDGE_DIR=%~dp0desktop-bridge"
set "BRIDGE_PORT=18765"
set "BRIDGE_HEALTH=http://127.0.0.1:18765/health"
set "LM_HEALTH=http://127.0.0.1:1234/v1/models"
set "BRIDGE_LOG=%BRIDGE_DIR%\rah-bridge-startup.log"
set "BRIDGE_FILE=raven_bridge.py"

echo.
echo  RAH RAVEN ONE-CLICK LAUNCHER v3.0
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
if not exist "%BRIDGE_DIR%\agent_runner.py" goto :missing_bridge
if not exist "%RAVEN_URL%" goto :missing_startpage
if not exist "%STUDIO_URL%" goto :missing_startpage
pushd "%BRIDGE_DIR%"

if not exist ".venv\Scripts\python.exe" (
  echo       Creating local Python environment...
  %PY% -m venv .venv
  if errorlevel 1 goto :bridge_error
)

echo [3/6] Checking Python packages...
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check --quiet -r requirements.txt
if errorlevel 1 goto :bridge_error

echo [4/6] Testing Bridge, Chronicle, local AI proxy and Agent Runner...
".venv\Scripts\python.exe" -m py_compile "server_v16.py" "server_v17.py" "chronicle_insights.py" "chronicle_ai.py" "agent_runner.py" "%BRIDGE_FILE%" "test_chronicle_v17.py" "test_chronicle_ai.py" "test_raven_bridge_security.py" "test_agent_runner.py"
if errorlevel 1 goto :bridge_error
".venv\Scripts\python.exe" -c "import flask, flask_cors, PIL, mss, pypdf; print('      Python modules: READY')"
if errorlevel 1 goto :bridge_error
".venv\Scripts\python.exe" "test_chronicle_v17.py"
if errorlevel 1 goto :bridge_error
".venv\Scripts\python.exe" "test_chronicle_ai.py"
if errorlevel 1 goto :bridge_error
".venv\Scripts\python.exe" "test_raven_bridge_security.py"
if errorlevel 1 goto :bridge_error
".venv\Scripts\python.exe" "test_agent_runner.py"
if errorlevel 1 goto :bridge_error

echo [5/6] Starting Raven Core Bridge on port %BRIDGE_PORT%...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$owners=Get-NetTCPConnection -LocalPort %BRIDGE_PORT% -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique; foreach($owner in $owners){ Stop-Process -Id $owner -Force -ErrorAction SilentlyContinue }" >nul 2>nul
timeout /t 2 /nobreak >nul

del "%BRIDGE_LOG%" >nul 2>nul
del "%BRIDGE_LOG%.err" >nul 2>nul
set "RAH_BRIDGE_HOST=127.0.0.1"
set "RAH_BRIDGE_PORT=%BRIDGE_PORT%"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:RAH_BRIDGE_HOST='127.0.0.1'; $env:RAH_BRIDGE_PORT='%BRIDGE_PORT%'; Start-Process -FilePath '.venv\Scripts\python.exe' -ArgumentList '%BRIDGE_FILE%' -WorkingDirectory '%BRIDGE_DIR%' -WindowStyle Minimized -RedirectStandardOutput '%BRIDGE_LOG%' -RedirectStandardError '%BRIDGE_LOG%.err'"

for /L %%G in (1,1,20) do (
  timeout /t 1 /nobreak >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; if(($h.case_center -eq $true) -and ($h.chronicle -eq $true) -and ($h.council_proxy -eq $true) -and ($h.agent_runner -eq $true)){ exit 0 } else { exit 1 } } catch { exit 1 }"
  if not errorlevel 1 goto :bridge_ready
)
goto :bridge_error

:bridge_ready
echo       Raven Core Bridge is ready on port %BRIDGE_PORT%.
echo       Raven Now v2:     opens automatically after startup
echo       Raven Studio:     available from Raven Now v2
echo       Agent Runner:     http://127.0.0.1:%BRIDGE_PORT%/agent/capabilities
echo       Local Case Center: http://127.0.0.1:%BRIDGE_PORT%/case
echo       Chronicle Live:   http://127.0.0.1:%BRIDGE_PORT%/chronicle/ui
echo       Raven Insights:   http://127.0.0.1:%BRIDGE_PORT%/chronicle/insights-ui
echo       Daily Brief:      http://127.0.0.1:%BRIDGE_PORT%/chronicle/brief-ui
popd

echo [6/6] Opening Raven Now v2 dashboard...
start "" "%RAVEN_URL%"
echo.
echo  Raven Now v2 is open.
echo  It shows: today's mission - recent projects - system status - one FORTSETT button.
echo  Mission Control remains the explicit gate for changing work status.
echo  Agent Runner remains read-only and requires confirmation for every run.
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
echo ERROR: Required desktop-bridge files were not found.
echo Download and extract the newest complete RAH Raven package.
pause
exit /b 1

:missing_startpage
echo.
echo ERROR: Raven Now v2 or Raven Studio start page was not found.
echo Run the RAH AI Studios updater again to restore the complete package.
pause
exit /b 1

:bridge_error
echo.
echo ERROR: Raven Core Bridge could not start on port %BRIDGE_PORT%.
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
