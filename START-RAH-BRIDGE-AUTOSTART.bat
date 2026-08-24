@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "BRIDGE_DIR=%~dp0desktop-bridge"
set "BRIDGE_PORT=18765"
set "BRIDGE_HEALTH=http://127.0.0.1:%BRIDGE_PORT%/health"
set "BRIDGE_FILE=%BRIDGE_DIR%\raven_bridge.py"
set "VENV_PY=%BRIDGE_DIR%\.venv\Scripts\python.exe"
set "BRIDGE_LOG=%BRIDGE_DIR%\rah-autostart.log"

rem Raven is already running: do nothing and exit quietly.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; if($h.home_control_ui -eq $true){ exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
if not errorlevel 1 exit /b 0

rem Autostart must never install packages or open a browser.
if not exist "%BRIDGE_FILE%" exit /b 2
if not exist "%VENV_PY%" exit /b 3

set "RAH_BRIDGE_HOST=127.0.0.1"
set "RAH_BRIDGE_PORT=%BRIDGE_PORT%"
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$env:RAH_BRIDGE_HOST='127.0.0.1'; $env:RAH_BRIDGE_PORT='%BRIDGE_PORT%'; Start-Process -FilePath '%VENV_PY%' -ArgumentList '%BRIDGE_FILE%' -WorkingDirectory '%BRIDGE_DIR%' -WindowStyle Minimized -RedirectStandardOutput '%BRIDGE_LOG%' -RedirectStandardError '%BRIDGE_LOG%.err'" >nul 2>nul
exit /b 0
