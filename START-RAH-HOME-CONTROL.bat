@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title RAH Home Control - One Click

set "BRIDGE_DIR=%~dp0desktop-bridge"
set "BRIDGE_PORT=18765"
set "BRIDGE_HEALTH=http://127.0.0.1:%BRIDGE_PORT%/health"
set "HOME_URL=http://127.0.0.1:%BRIDGE_PORT%/home-control/ui"
set "BRIDGE_FILE=%BRIDGE_DIR%\raven_bridge.py"
set "VENV_PY=%BRIDGE_DIR%\.venv\Scripts\python.exe"
set "BRIDGE_LOG=%BRIDGE_DIR%\rah-home-control-startup.log"

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; if($h.home_control_ui -eq $true){ exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
if not errorlevel 1 goto :open_home

if not exist "%BRIDGE_FILE%" goto :missing_bridge

if not exist "%VENV_PY%" (
  echo RAH Bridge er ikke ferdig installert ennå.
  echo Starter hovedlauncheren én gang for å klargjøre miljøet...
  if exist "%~dp0START-RAH-RAVEN-V2.bat" (
    start "RAH Raven Setup" "%~dp0START-RAH-RAVEN-V2.bat"
    exit /b 0
  )
  goto :missing_bridge
)

pushd "%BRIDGE_DIR%"
set "RAH_BRIDGE_HOST=127.0.0.1"
set "RAH_BRIDGE_PORT=%BRIDGE_PORT%"
start "RAH Raven Bridge" /min "%VENV_PY%" "%BRIDGE_FILE%" 1>"%BRIDGE_LOG%" 2>"%BRIDGE_LOG%.err"
popd

for /L %%G in (1,1,15) do (
  timeout /t 1 /nobreak >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; if($h.home_control_ui -eq $true){ exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
  if not errorlevel 1 goto :open_home
)

echo.
echo FEIL: RAH Bridge svarte ikke på port %BRIDGE_PORT%.
echo Se logg: %BRIDGE_LOG%.err
pause
exit /b 1

:open_home
start "" "%HOME_URL%"
exit /b 0

:missing_bridge
echo.
echo FEIL: RAH Desktop Bridge mangler eller er ikke installert komplett.
echo Kjør RAH AI Studios updater/installer først.
pause
exit /b 1
