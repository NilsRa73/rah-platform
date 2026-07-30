@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title RAH Raven One-Click Launcher v2.1

set "RAVEN_URL=https://nilsra73.github.io/rah-platform/"
set "BRIDGE_DIR=%~dp0desktop-bridge"
set "BRIDGE_HEALTH=http://127.0.0.1:8765/health"
set "LM_HEALTH=http://127.0.0.1:1234/v1/models"
set "BRIDGE_LOG=%BRIDGE_DIR%\rah-bridge-startup.log"

echo.
echo  RAH RAVEN ONE-CLICK LAUNCHER v2.1
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

echo [1/5] Checking LM Studio...
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

echo [2/5] Checking Desktop Bridge...
if not exist "%BRIDGE_DIR%\server.py" goto :missing_bridge
pushd "%BRIDGE_DIR%"

if not exist ".venv\Scripts\python.exe" (
  echo       Creating local Python environment...
  %PY% -m venv .venv
  if errorlevel 1 goto :bridge_error
)

if exist "requirements.txt" (
  echo       Checking Python packages...
  ".venv\Scripts\python.exe" -m pip install --disable-pip-version-check --quiet -r requirements.txt
  if errorlevel 1 goto :bridge_error
)

echo [3/5] Releasing port 8765 and starting Desktop Bridge...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$pids = Get-NetTCPConnection -LocalPort 8765 -State Listen -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique; foreach($pid in $pids){ try { Stop-Process -Id $pid -Force -ErrorAction Stop } catch {} }" >nul 2>nul
timeout /t 1 /nobreak >nul

del "%BRIDGE_LOG%" >nul 2>nul
set "RAH_BRIDGE_HOST=127.0.0.1"
set "RAH_BRIDGE_PORT=8765"
start "RAH Desktop Bridge v2.1" /min cmd /c "set RAH_BRIDGE_HOST=127.0.0.1&& set RAH_BRIDGE_PORT=8765&& .venv\Scripts\python.exe server.py 1^>rah-bridge-startup.log 2^>^&1"

for /L %%G in (1,1,15) do (
  timeout /t 1 /nobreak >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"
  if not errorlevel 1 goto :bridge_ready
)
goto :bridge_error

:bridge_ready
echo       Desktop Bridge is ready on port 8765.
popd

echo [4/5] Final status check...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $b=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; Write-Host ('      Bridge: READY v' + $b.version) } catch { Write-Host '      Bridge: OFFLINE' }; try { $m=Invoke-RestMethod -Uri '%LM_HEALTH%' -TimeoutSec 2; if($m.data.Count -gt 0){ Write-Host ('      LM Studio: READY - ' + $m.data[0].id) } else { Write-Host '      LM Studio: SERVER READY, NO MODEL LOADED' } } catch { Write-Host '      LM Studio: OFFLINE' }"

echo [5/5] Opening RAH Raven...
start "" "%RAVEN_URL%"

echo.
echo  RAH Raven is open and ready.
echo  Keep LM Studio running when you use Vision.
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
echo ERROR: desktop-bridge\server.py was not found.
echo Keep this launcher inside the extracted rah-platform-main folder.
pause
exit /b 1

:bridge_error
echo.
echo ERROR: Desktop Bridge could not start.
if exist "%BRIDGE_LOG%" (
  echo.
  echo -------- Bridge error log --------
  type "%BRIDGE_LOG%"
  echo -------- End error log -----------
)
popd 2>nul
echo.
echo Copy the error text above into ChatGPT.
pause
exit /b 1
