@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"
title RAH Link LAN

set "RAH_BRIDGE_HOST=0.0.0.0"
set "RAH_BRIDGE_PORT=8765"
set "BRIDGE_URL=http://127.0.0.1:8765/health"
set "LAN_IP="

for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command "$c=Get-NetIPConfiguration ^| Where-Object {$_.IPv4DefaultGateway -and $_.IPv4Address.IPAddress -notlike '169.254.*'} ^| Select-Object -First 1; if($c){$c.IPv4Address.IPAddress}"`) do set "LAN_IP=%%I"

if not defined LAN_IP set "LAN_IP=127.0.0.1"

echo.
echo  RAH LINK LAN v1.5
echo  =================
echo  Connects HP Omen to this PC, Desktop Bridge and LM Studio.
echo  Main PC network address: %LAN_IP%
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
  echo [1/4] Creating Python environment...
  %PY% -m venv .venv
  if errorlevel 1 goto :error
) else (
  echo [1/4] Python environment found.
)

echo [2/4] Checking dependencies...
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check --quiet -r requirements.txt
if errorlevel 1 goto :error

echo [3/4] Adding Windows Firewall rule for private network...
netsh advfirewall firewall show rule name="RAH Link LAN 8765" >nul 2>nul
if errorlevel 1 (
  netsh advfirewall firewall add rule name="RAH Link LAN 8765" dir=in action=allow protocol=TCP localport=8765 profile=private >nul 2>nul
  if errorlevel 1 echo       Windows may ask for permission when the bridge starts.
) else (
  echo       Firewall rule already exists.
)

echo [4/4] Starting RAH Link...
start "RAH Link LAN" /min cmd /c "set RAH_BRIDGE_HOST=0.0.0.0&& set RAH_BRIDGE_PORT=8765&& .venv\Scripts\python.exe server.py"

for /L %%G in (1,1,15) do (
  timeout /t 1 /nobreak >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Uri '%BRIDGE_URL%' -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"
  if not errorlevel 1 goto :ready
)
goto :bridge_error

:ready
echo.
echo RAH Link is ready.
echo On HP Omen run RAH-RAVEN-LINK-FINDER.bat
echo or open:
echo.
echo   http://%LAN_IP%:8765/link
echo.
echo Keep RAH Link and LM Studio running while using Omen.
start "" "http://127.0.0.1:8765/link"
pause
exit /b 0

:no_python
echo ERROR: Python was not found.
echo Install Python from https://www.python.org/downloads/windows/
pause
exit /b 1

:bridge_error
echo ERROR: RAH Link did not start on port 8765.
echo Close any old Desktop Bridge window and run this file again.
pause
exit /b 1

:error
echo ERROR: Setup failed. Review the message above.
pause
exit /b 1
