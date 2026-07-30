@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH LINK V1.5 - HOVED-PC

set "RAH_BRIDGE_HOST=0.0.0.0"
set "RAH_BRIDGE_PORT=8765"
set "BRIDGE_URL=http://127.0.0.1:8765/health"

echo.
echo  RAH LINK V1.5 - HOVED-PC
echo  =========================
echo  Stopper gammel RAH Bridge og starter korrekt LAN-versjon.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "$p=Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'desktop-bridge.*server.py' -or $_.CommandLine -match 'server.py.*8765' }; foreach($x in $p){ try { Stop-Process -Id $x.ProcessId -Force -ErrorAction Stop } catch {} }"
timeout /t 2 /nobreak >nul

where py >nul 2>nul
if %errorlevel%==0 (
  set "PY=py"
) else (
  where python >nul 2>nul
  if errorlevel 1 goto :no_python
  set "PY=python"
)

if not exist ".venv\Scripts\python.exe" (
  echo [1/4] Oppretter Python-miljo...
  %PY% -m venv .venv
  if errorlevel 1 goto :error
) else (
  echo [1/4] Python-miljo funnet.
)

echo [2/4] Kontrollerer avhengigheter...
".venv\Scripts\python.exe" -m pip install --disable-pip-version-check --quiet -r requirements.txt
if errorlevel 1 goto :error

echo [3/4] Apner Windows-brannmur for privat nettverk...
netsh advfirewall firewall show rule name="RAH Link LAN 8765" >nul 2>nul
if errorlevel 1 (
  netsh advfirewall firewall add rule name="RAH Link LAN 8765" dir=in action=allow protocol=TCP localport=8765 profile=private >nul 2>nul
)

echo [4/4] Starter RAH Link LAN...
start "RAH LINK V1.5" /min cmd /c "set RAH_BRIDGE_HOST=0.0.0.0&& set RAH_BRIDGE_PORT=8765&& .venv\Scripts\python.exe server.py"

for /L %%G in (1,1,15) do (
  timeout /t 1 /nobreak >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Uri '%BRIDGE_URL%' -TimeoutSec 2 | Out-Null; exit 0 } catch { exit 1 }"
  if not errorlevel 1 goto :ready
)
goto :bridge_error

:ready
for /f %%I in ('powershell -NoProfile -Command "$ip=(Get-NetIPConfiguration ^| Where-Object {$_.IPv4DefaultGateway -ne $null} ^| Select-Object -First 1 -ExpandProperty IPv4Address).IPAddress; Write-Output $ip"') do set "LANIP=%%I"
echo.
echo RAH Link er klar.
echo Hoved-PC IP: %LANIP%
echo Omen-adresse: http://%LANIP%:8765/link
echo.
start "" "http://127.0.0.1:8765/link"
pause
exit /b 0

:no_python
echo Python ble ikke funnet.
pause
exit /b 1

:bridge_error
echo RAH Link svarte ikke pa port 8765.
echo Kontroller feilmeldingen i RAH LINK-vinduet.
pause
exit /b 1

:error
echo Oppsettet feilet.
pause
exit /b 1
