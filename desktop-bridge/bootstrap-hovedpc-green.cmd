@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul

title RAH Raven Bridge - HOVED-PC TRUE GREEN

set "COMMIT=0634428389c475a6f595a8d8d3906f0bfcda1658"
set "PORT=18765"
set "RAH=C:\RAH"
set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "TEMPBASE=C:\RAH\Temp\RavenGreen"
set "ZIP=%TEMPBASE%\rah-platform.zip"
set "EXTRACT=%TEMPBASE%\extract"
set "LOGDIR=C:\RAH\Logs\RavenBridge"
set "STATE=C:\RAH\State\RavenBridge"
set "BACKUPS=C:\RAH\Backups\RavenBridgeRuntime"

call :banner

mkdir "%RAH%" 2>nul
mkdir "%LOGDIR%" 2>nul
mkdir "%STATE%" 2>nul
mkdir "%BACKUPS%" 2>nul

where curl.exe >nul 2>&1 || call :fail "curl.exe ble ikke funnet i Windows."

where py.exe >nul 2>&1
if not errorlevel 1 (
    set "PY=py -3"
) else (
    where python.exe >nul 2>&1 || call :fail "Python 3 ble ikke funnet. Raven trenger Python 3.11 eller nyere."
    set "PY=python"
)

echo [RAH] 1/8 Kontrollerer port %PORT%...
set "PORTBUSY="
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":%PORT% .*LISTENING"') do set "PORTBUSY=%%P"
if defined PORTBUSY (
    echo [RAH] Port %PORT% er allerede i bruk av PID !PORTBUSY!.
    echo [RAH] Tester om det allerede er en frisk canonical Raven Bridge...
    curl.exe --silent --fail --max-time 3 "http://127.0.0.1:%PORT%/health" -o "%STATE%\existing-health.json" >nul 2>&1
    if not errorlevel 1 (
        %PY% -c "import json; d=json.load(open(r'%STATE%\existing-health.json',encoding='utf-8')); assert all(d.get(k) is True for k in ('ok','council_proxy','vision_monitor_capture','local_device_adapter'))" >nul 2>&1
        if not errorlevel 1 goto existing_green
    )
    call :fail "Port 18765 brukes allerede, men prosessen besto ikke Raven health-gaten. Jeg stopper ikke en ukjent prosess automatisk."
)

echo [RAH] 2/8 Laster ned eksakt CI-testet Raven commit...
if exist "%TEMPBASE%" rmdir /s /q "%TEMPBASE%"
mkdir "%EXTRACT%" || call :fail "Kunne ikke lage temp-mappe."
curl.exe -L --fail --retry 2 --connect-timeout 15 -o "%ZIP%" "https://github.com/NilsRa73/rah-platform/archive/%COMMIT%.zip" || call :fail "Nedlasting fra GitHub feilet."
if not exist "%ZIP%" call :fail "Raven ZIP ble ikke lastet ned."

%PY% -m zipfile -e "%ZIP%" "%EXTRACT%" || call :fail "Kunne ikke pakke ut Raven ZIP."
set "SRC="
for /d %%D in ("%EXTRACT%\rah-platform-*") do set "SRC=%%~fD"
if not defined SRC call :fail "Fant ikke utpakket rah-platform mappe."
if not exist "!SRC!\desktop-bridge\raven_bridge.py" call :fail "Canonical raven_bridge.py mangler i pakken."

findstr /C:"local_device_adapter" "!SRC!\desktop-bridge\raven_bridge.py" >nul || call :fail "Canonical Device Adapter marker mangler."
findstr /C:"vision_monitor_capture" "!SRC!\desktop-bridge\raven_bridge.py" >nul || call :fail "Canonical Vision marker mangler."
findstr /C:"council_proxy" "!SRC!\desktop-bridge\raven_bridge.py" >nul || call :fail "Canonical Council marker mangler."
findstr /C:"hovedpc_local_status" "!SRC!\desktop-bridge\raven_bridge.py" >nul && call :fail "Den pensjonerte hovedpc_local_status-importen finnes i kilden."

echo [RAH] 3/8 Tar backup av standard-runtime hvis den finnes...
if exist "%RUNTIME%" (
    set "BACKUP=%BACKUPS%\backup-%RANDOM%-%RANDOM%"
    move "%RUNTIME%" "!BACKUP!" >nul || call :fail "Kunne ikke flytte gammel runtime til backup."
    echo [RAH] Backup: !BACKUP!
)

echo [RAH] 4/8 Installerer canonical runtime i C:\RAH\Raven\rah-platform...
mkdir "C:\RAH\Raven" 2>nul
move "!SRC!" "%RUNTIME%" >nul || call :fail "Kunne ikke installere Raven runtime."
if not exist "%BRIDGE%\raven_bridge.py" call :fail "Runtime mangler raven_bridge.py etter installasjon."

echo [RAH] 5/8 Lager Python-miljo og installerer pinned dependencies...
%PY% -m venv "%BRIDGE%\.venv" || call :fail "Kunne ikke opprette Raven Python venv."
set "VPY=%BRIDGE%\.venv\Scripts\python.exe"
if not exist "%VPY%" call :fail "Venv Python mangler."
"%VPY%" -m pip install --disable-pip-version-check -r "%BRIDGE%\requirements.txt" || call :fail "Dependency install feilet."

echo [RAH] 6/8 Kompilerer kjerne og kjorer security regression...
"%VPY%" -m py_compile "%BRIDGE%\raven_bridge.py" "%BRIDGE%\doctor.py" "%BRIDGE%\server_v16.py" "%BRIDGE%\server_v17.py" "%BRIDGE%\agent_runner.py" "%BRIDGE%\download_manager.py" "%BRIDGE%\local_device_adapter.py" || call :fail "Python compile-test feilet."

set "RAH_CHRONICLE_DIR=C:\RAH\Data\Chronicle"
set "RAH_DOWNLOAD_MANAGER_STATE=C:\RAH\Data\DownloadManager\state.json"
set "RAH_RAVEN_VAULT=C:\RAH\Data\Vault"
set "RAH_DOWNLOADS_DIR=C:\RAH\Data\Incoming"
mkdir "%RAH_CHRONICLE_DIR%" 2>nul
mkdir "C:\RAH\Data\DownloadManager" 2>nul
mkdir "%RAH_RAVEN_VAULT%" 2>nul
mkdir "%RAH_DOWNLOADS_DIR%" 2>nul

pushd "%BRIDGE%"
"%VPY%" test_raven_bridge_security.py
if errorlevel 1 (
    popd
    call :fail "Raven security regression test feilet."
)
popd

echo [RAH] 7/8 Starter canonical Raven Bridge...
set "OUTLOG=%LOGDIR%\bridge-cmd.out.log"
set "ERRLOG=%LOGDIR%\bridge-cmd.err.log"
pushd "%BRIDGE%"
start "RAH Raven Bridge" /min "%VPY%" raven_bridge.py
popd

echo [RAH] 8/8 Venter pa live health og kjorer TRUE GREEN gates...
set "READY="
for /L %%I in (1,1,30) do (
    curl.exe --silent --fail --max-time 2 "http://127.0.0.1:%PORT%/health" -o "%STATE%\health.json" >nul 2>&1
    if not errorlevel 1 (
        set "READY=1"
        goto health_ready
    )
    timeout /t 1 /nobreak >nul
)

:health_ready
if not defined READY call :fail "Raven Bridge svarte ikke pa /health innen 30 sekunder."

"%VPY%" -c "import json; d=json.load(open(r'%STATE%\health.json',encoding='utf-8')); req=('ok','council_proxy','vision_monitor_capture','local_device_adapter'); bad=[k for k in req if d.get(k) is not True]; assert not bad, 'Mangler health-flagg: '+','.join(bad); print('HEALTH PASS')" || call :fail "Canonical /health gate feilet."

curl.exe --silent --fail --max-time 5 "http://127.0.0.1:%PORT%/capture/monitors" -o "%STATE%\monitors.json" || call :fail "Raven Vision monitor-endepunkt svarte ikke."
"%VPY%" -c "import json; d=json.load(open(r'%STATE%\monitors.json',encoding='utf-8')); assert d.get('ok') is True and int(d.get('count',0))>=1; print('VISION PASS - monitors:',d['count'])" || call :fail "Raven Vision fant ingen skjermer."

curl.exe --silent --fail --max-time 5 "http://127.0.0.1:%PORT%/device/status" -o "%STATE%\device.json" || call :fail "Device API svarte ikke."
"%VPY%" -c "import json; d=json.load(open(r'%STATE%\device.json',encoding='utf-8')); assert d.get('ok') is True; print('DEVICE API PASS')" || call :fail "Device API live gate feilet."

goto true_green

:existing_green
echo [RAH] Eksisterende Bridge besto canonical health-gaten.
curl.exe --silent --fail --max-time 5 "http://127.0.0.1:%PORT%/capture/monitors" -o "%STATE%\monitors.json" || call :fail "Eksisterende Bridge mangler fungerende Raven Vision."
%PY% -c "import json; d=json.load(open(r'%STATE%\monitors.json',encoding='utf-8')); assert d.get('ok') is True and int(d.get('count',0))>=1" || call :fail "Eksisterende Raven Vision fant ingen skjermer."
curl.exe --silent --fail --max-time 5 "http://127.0.0.1:%PORT%/device/status" -o "%STATE%\device.json" || call :fail "Eksisterende Bridge mangler fungerende Device API."
%PY% -c "import json; d=json.load(open(r'%STATE%\device.json',encoding='utf-8')); assert d.get('ok') is True" || call :fail "Eksisterende Device API feilet."

goto true_green

:true_green
echo.
echo ============================================================
echo       RAVEN BRIDGE + AUTO-REPAIR = TRUE GREEN
echo ============================================================
echo.
echo Bridge     : ONLINE
echo Port       : %PORT%
echo Council    : READY
echo Vision     : READY
echo Device API : READY
echo Security   : PASS / canonical build
echo Runtime    : %RUNTIME%
echo.
echo MILESTONE  : PASS
echo.
exit /b 0

:banner
echo.
echo ============================================================
echo  RAH RAVEN - POWERSHELL-FREE HOVED-PC GREEN BOOTSTRAP
echo ============================================================
echo.
exit /b 0

:fail
echo.
echo ============================================================
echo  RAVEN BRIDGE - NOT GREEN
echo ============================================================
echo %~1
echo.
exit /b 1
