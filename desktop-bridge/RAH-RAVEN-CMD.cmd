@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0E
title RAH Raven CMD Console

set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "TOOLS=C:\RAH\Raven\Tools"
set "LOGS=C:\RAH\Logs\RavenBridge"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "HEALTH=http://127.0.0.1:18765/health"
set "VISION=http://127.0.0.1:18765/vision/ui"
set "USERSCRIPT=http://127.0.0.1:18765/vision/chatgpt.user.js"

if /I "%~1"=="help" goto :help
if /I "%~1"=="status" goto :status
if /I "%~1"=="start" goto :start
if /I "%~1"=="vision" goto :vision
if /I "%~1"=="script" goto :script
if /I "%~1"=="autostart" goto :autostart
if /I "%~1"=="repair" goto :repair
if /I "%~1"=="logs" goto :logs
if /I "%~1"=="doctor" goto :doctor
if not "%~1"=="" goto :help

:menu
cls
echo.
echo ============================================================
echo              RAH RAVEN CMD CONSOLE
echo ============================================================
echo.
echo   1  Raven status
echo   2  Start / recover Raven Bridge
echo   3  Open Raven Vision
echo   4  Install / update ChatGPT Vision userscript
echo   5  Install / refresh autostart + watchdog
echo   6  Safe Raven Bridge repair
echo   7  Raven Doctor
echo   8  Open Raven logs
echo   9  Open ChatGPT
echo   0  Exit
echo.
choice /C 1234567890 /N /M "Choose: "
if errorlevel 10 goto :exit
if errorlevel 9 goto :chatgpt
if errorlevel 8 goto :logs
if errorlevel 7 goto :doctor
if errorlevel 6 goto :repair
if errorlevel 5 goto :autostart
if errorlevel 4 goto :script
if errorlevel 3 goto :vision
if errorlevel 2 goto :start
if errorlevel 1 goto :status
goto :menu

:header
echo.
echo ------------------------------------------------------------
exit /b 0

:require_runtime
if exist "%BRIDGE%\raven_bridge.py" exit /b 0
echo.
echo [ERROR] Raven runtime not found:
echo         %BRIDGE%
echo.
echo Run the Raven TRUE GREEN bootstrap first.
exit /b 2

:status
call :header
echo [RAVEN] Checking live status...
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try {$h=Invoke-RestMethod '%HEALTH%' -TimeoutSec 3; if($h.ok -and $h.council_proxy -and $h.vision_monitor_capture -and $h.local_device_adapter){Write-Host 'BRIDGE      : GREEN'; Write-Host ('PORT        : '+$h.port); Write-Host 'COUNCIL     : READY'; Write-Host 'VISION      : READY'; Write-Host 'DEVICE API  : READY'; exit 0}else{Write-Host 'BRIDGE      : YELLOW'; $h|ConvertTo-Json -Depth 5; exit 3}} catch {Write-Host 'BRIDGE      : OFFLINE'; Write-Host $_.Exception.Message; exit 4}"
set "RC=%ERRORLEVEL%"
if not "%~1"=="" exit /b %RC%
call :pausemenu
goto :menu

:start
call :require_runtime || goto :returnmenu
call :header
echo [RAVEN] Start / recover...
if exist "%TOOLS%\raven-watchdog.ps1" (
  "%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%TOOLS%\raven-watchdog.ps1"
) else if exist "%BRIDGE%\raven-watchdog.ps1" (
  "%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%BRIDGE%\raven-watchdog.ps1"
) else (
  echo [ERROR] raven-watchdog.ps1 not found.
  exit /b 5
)
if errorlevel 1 (
  echo [ERROR] Watchdog did not return GREEN.
  if not "%~1"=="" exit /b %ERRORLEVEL%
  call :pausemenu
  goto :menu
)
echo [OK] Raven watchdog completed.
call :status_internal
if not "%~1"=="" exit /b 0
call :pausemenu
goto :menu

:status_internal
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try {$h=Invoke-RestMethod '%HEALTH%' -TimeoutSec 3; if($h.ok -and $h.council_proxy -and $h.vision_monitor_capture -and $h.local_device_adapter){Write-Host 'RAVEN       : TRUE GREEN'; exit 0}else{Write-Host 'RAVEN       : NOT GREEN'; exit 3}} catch {Write-Host 'RAVEN       : OFFLINE'; exit 4}"
exit /b %ERRORLEVEL%

:vision
call :header
echo [RAVEN] Opening Raven Vision...
start "" "%VISION%"
if not "%~1"=="" exit /b 0
call :pausemenu
goto :menu

:script
call :header
echo [RAVEN] Opening ChatGPT Vision userscript installer...
start "" "%USERSCRIPT%"
echo Install/update it in Tampermonkey, then refresh ChatGPT.
if not "%~1"=="" exit /b 0
call :pausemenu
goto :menu

:autostart
call :require_runtime || goto :returnmenu
call :header
echo [RAVEN] Installing autostart + watchdog.
echo         Windows may ask for Administrator approval.
if not exist "%BRIDGE%\install-raven-autostart.ps1" (
  echo [ERROR] install-raven-autostart.ps1 not found.
  goto :returnmenu
)
"%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%PS%' -Verb RunAs -Wait -ArgumentList '-NoLogo -NoProfile -ExecutionPolicy Bypass -File ""%BRIDGE%\install-raven-autostart.ps1""'"
if errorlevel 1 echo [ERROR] Autostart installer returned an error.
if not "%~1"=="" exit /b %ERRORLEVEL%
call :pausemenu
goto :menu

:repair
call :require_runtime || goto :returnmenu
call :header
echo [RAVEN] Safe Bridge repair...
if exist "%BRIDGE%\repair-raven-bridge.ps1" (
  "%PS%" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%BRIDGE%\repair-raven-bridge.ps1"
) else (
  echo [ERROR] repair-raven-bridge.ps1 not found in the standardized runtime.
  echo         No destructive fallback will be attempted.
  if not "%~1"=="" exit /b 6
)
if not "%~1"=="" exit /b %ERRORLEVEL%
call :pausemenu
goto :menu

:doctor
call :require_runtime || goto :returnmenu
call :header
echo [RAVEN] Doctor...
if not exist "%BRIDGE%\.venv\Scripts\python.exe" (
  echo [ERROR] Raven Python environment is missing.
  goto :returnmenu
)
pushd "%BRIDGE%"
".venv\Scripts\python.exe" doctor.py
set "RC=%ERRORLEVEL%"
popd
if not "%~1"=="" exit /b %RC%
call :pausemenu
goto :menu

:logs
if not exist "%LOGS%" mkdir "%LOGS%" >nul 2>nul
start "" explorer.exe "%LOGS%"
if not "%~1"=="" exit /b 0
goto :menu

:chatgpt
start "" "https://chatgpt.com/"
goto :menu

:help
echo RAH Raven CMD Console
echo.
echo Usage:
echo   RAH-RAVEN-CMD.cmd             Interactive menu
echo   RAH-RAVEN-CMD.cmd status      Live health
echo   RAH-RAVEN-CMD.cmd start       Start/recover Bridge
echo   RAH-RAVEN-CMD.cmd vision      Open Raven Vision
echo   RAH-RAVEN-CMD.cmd script      Open Tampermonkey userscript
echo   RAH-RAVEN-CMD.cmd autostart   Install scheduled startup/watchdog
echo   RAH-RAVEN-CMD.cmd repair      Run guarded Bridge repair
echo   RAH-RAVEN-CMD.cmd doctor      Run Raven Doctor
echo   RAH-RAVEN-CMD.cmd logs        Open logs
exit /b 0

:pausemenu
echo.
pause
exit /b 0

:returnmenu
if not "%~1"=="" exit /b 1
call :pausemenu
goto :menu

:exit
endlocal
exit /b 0
