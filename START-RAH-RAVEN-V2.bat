@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title RAH Raven One-Click Launcher v2

set "RAVEN_URL=https://nilsra73.github.io/rah-platform/"
set "BRIDGE_DIR=%~dp0desktop-bridge"
set "BRIDGE_HEALTH=http://127.0.0.1:8765/health"
set "LM_HEALTH=http://127.0.0.1:1234/v1/models"

echo.
echo  RAH RAVEN ONE-CLICK LAUNCHER v2
echo  =================================
echo.

rem --- Find Python ---
where py >nul 2>nul
if %errorlevel%==0 (
  set "PY=py"
) else (
  where python >nul 2>nul
  if errorlevel 1 goto :no_python
  set "PY=python"
)

rem --- Start LM Studio if not already answering ---
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
    echo       LM Studio opened. Load your vision model and start Local Server on port 1234.
  ) else (
    echo       LM Studio was not found automatically.
    echo       Open it manually and start Local Server on port 1234.
  )
) else (
  echo       LM Studio server is ready.
)

rem --- Ensure bridge folder exists ---
echo [2/5] Checking Desktop Bridge...
if not exist "%BRIDGE_DIR%\server.py" goto :missing_bridge
pushd "%BRIDGE_DIR%"

if not exist ".venv\Scripts\python.exe" (
  echo       Creating local Python environment...
  %PY% -m venv .venv
  if errorlevel 1 goto :bridge_error
)

if exist "requirements.txt" (
  ".venv\Scripts\python.exe" -m pip install --disable-pip-version-check --quiet -r requirements.txt
  if errorlevel 1 goto :bridge_error
)

rem --- Stop only an old RAH server.py process from this folder ---
echo [3/5] Starting correct RAH Desktop Bridge...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root=[IO.Path]::GetFullPath('%BRIDGE_DIR%'); Get-CimInstance Win32_Process | Where-Object { ($_.Name -match '^python(w)?\.exe$') -and $_.CommandLine -like '*server.py*' -and $_.ExecutablePath -like "$root*" } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }" >nul 2>nul

set "RAH_BRIDGE_HOST=127.0.0.1"
set "RAH_BRIDGE_PORT=8765"
start "RAH Desktop Bridge v2" /min cmd /c "set RAH_BRIDGE_HOST=127.0.0.1&& set RAH_BRIDGE_PORT=8765&& .venv\Scripts\python.exe server.py"

for /L %%G in (1,1,15) do (
  timeout /t 1 /nobreak >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"
  if not errorlevel 1 goto :bridge_ready
)
goto :bridge_error

:bridge_ready
echo       Desktop Bridge is ready on port 8765.
popd

rem --- Final status ---
echo [4/5] Final status check...
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $b=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; Write-Host '      Bridge: READY'; } catch { Write-Host '      Bridge: OFFLINE' }; try { $m=Invoke-RestMethod -Uri '%LM_HEALTH%' -TimeoutSec 2; if($m.data.Count -gt 0){ Write-Host ('      LM Studio: READY - ' + $m.data[0].id) } else { Write-Host '      LM Studio: SERVER READY, NO MODEL LOADED' } } catch { Write-Host '      LM Studio: OFFLINE' }"

echo [5/5] Opening RAH Raven...
start "" "%RAVEN_URL%"

echo.
echo  RAH Raven is open.
echo  Keep LM Studio running when you use Vision.
echo  You may close this launcher window.
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
popd 2>nul
echo.
echo ERROR: Desktop Bridge could not start.
echo Close old RAH windows, then run this launcher again.
pause
exit /b 1
