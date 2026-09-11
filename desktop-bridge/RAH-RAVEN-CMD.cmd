@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0E
title RAH Raven CMD Super Console

set "VERSION=1.0.0"
set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "TOOLS=C:\RAH\Raven\Tools"
set "LOGS=C:\RAH\Logs\RavenBridge"
set "STATE=C:\RAH\State\RavenBridge"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "HEALTH=http://127.0.0.1:18765/health"
set "VISION=http://127.0.0.1:18765/vision/ui"
set "CHRONICLE=http://127.0.0.1:18765/chronicle/ui"
set "INSIGHTS=http://127.0.0.1:18765/chronicle/insights-ui"
set "BRIEF=http://127.0.0.1:18765/chronicle/brief-ui"
set "HOME=http://127.0.0.1:18765/home-control/ui"
set "VAULT=http://127.0.0.1:18765/downloads/ui"
set "USERSCRIPT=http://127.0.0.1:18765/vision/chatgpt.user.js"
set "UPDATE_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/agent/raven-vision-monitor-chatgpt-bridge/desktop-bridge/RAH-RAVEN-CMD.cmd"

if /I "%~1"=="help" goto :help
if /I "%~1"=="status" goto :superstatus
if /I "%~1"=="super" goto :startall
if /I "%~1"=="start" goto :startall
if /I "%~1"=="vision" goto :vision
if /I "%~1"=="chronicle" goto :chronicle
if /I "%~1"=="insights" goto :insights
if /I "%~1"=="brief" goto :brief
if /I "%~1"=="home" goto :home
if /I "%~1"=="vault" goto :vault
if /I "%~1"=="agent" goto :agent
if /I "%~1"=="script" goto :script
if /I "%~1"=="autostart" goto :autostart
if /I "%~1"=="repair" goto :repair
if /I "%~1"=="doctor" goto :doctor
if /I "%~1"=="logs" goto :logs
if /I "%~1"=="update" goto :update
if /I "%~1"=="chatgpt" goto :chatgpt
if not "%~1"=="" goto :help

:menu
cls
echo.
echo ================================================================
echo              RAH RAVEN CMD SUPER CONSOLE v%VERSION%
echo ================================================================
echo.
echo   1  START ALL / recover Raven
echo   2  SUPER STATUS - Bridge + Chronicle + Agent + tasks
echo   3  Raven Vision
echo   4  Chronicle Live
echo   5  Raven Insights
echo   6  Daily Brief
echo   7  Home Control
echo   8  Raven Vault / Downloads
echo   9  Agent Runner - status + safe tests
echo   A  ChatGPT + Vision userscript
echo   B  Install / refresh autostart + watchdog
echo   C  Safe Raven Bridge repair
echo   D  Raven Doctor
echo   E  Open Raven logs
echo   U  Self-update CMD Console
echo   0  Exit
echo.
echo   CMD is the cockpit. PowerShell only runs under the hood.
echo.
choice /C 123456789ABCDEU0 /N /M "Choose: "
if errorlevel 16 goto :exit
if errorlevel 15 goto :update
if errorlevel 14 goto :logs
if errorlevel 13 goto :doctor
if errorlevel 12 goto :repair
if errorlevel 11 goto :autostart
if errorlevel 10 goto :chatgpt
if errorlevel 9 goto :agent
if errorlevel 8 goto :vault
if errorlevel 7 goto :home
if errorlevel 6 goto :brief
if errorlevel 5 goto :insights
if errorlevel 4 goto :chronicle
if errorlevel 3 goto :vision
if errorlevel 2 goto :superstatus
if errorlevel 1 goto :startall
goto :menu

:header
echo.
echo ----------------------------------------------------------------
exit /b 0

:require_runtime
if exist "%BRIDGE%\raven_bridge.py" exit /b 0
echo.
echo [ERROR] Raven runtime not found:
echo         %BRIDGE%
echo.
echo Run the Raven TRUE GREEN bootstrap first.
exit /b 2

:watchdog
call :require_runtime || exit /b 2
if exist "%TOOLS%\raven-watchdog.ps1" (
  "%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%TOOLS%\raven-watchdog.ps1"
  exit /b %ERRORLEVEL%
)
if exist "%BRIDGE%\raven-watchdog.ps1" (
  "%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%BRIDGE%\raven-watchdog.ps1"
  exit /b %ERRORLEVEL%
)
echo [ERROR] raven-watchdog.ps1 not found.
exit /b 5

:status_internal
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try {$h=Invoke-RestMethod '%HEALTH%' -TimeoutSec 3; if($h.ok -and $h.council_proxy -and $h.vision_monitor_capture -and $h.local_device_adapter -and $h.agent_runner -and $h.download_manager){Write-Host 'RAVEN       : TRUE GREEN'; exit 0}else{Write-Host 'RAVEN       : NOT GREEN'; exit 3}} catch {Write-Host 'RAVEN       : OFFLINE'; exit 4}"
exit /b %ERRORLEVEL%

:startall
call :header
echo [SUPER] START ALL / RECOVER
call :watchdog
if errorlevel 1 (
  echo [ERROR] Raven recovery did not return GREEN.
  if not "%~1"=="" exit /b %ERRORLEVEL%
  call :pausemenu
  goto :menu
)
call :status_internal
if errorlevel 1 (
  echo [ERROR] Raven started, but the full GREEN gate failed.
  if not "%~1"=="" exit /b %ERRORLEVEL%
  call :pausemenu
  goto :menu
)
echo.
echo [READY] Vision      : %VISION%
echo [READY] Chronicle   : %CHRONICLE%
echo [READY] Insights    : %INSIGHTS%
echo [READY] Daily Brief : %BRIEF%
echo [READY] Home Control: %HOME%
echo [READY] Raven Vault : %VAULT%
echo [READY] Agent Runner: local read-only allowlist
echo.
echo SUPER MODE : READY
if not "%~1"=="" exit /b 0
call :pausemenu
goto :menu

:superstatus
call :header
echo [SUPER STATUS] Checking the whole local Raven chain...
if not exist "%STATE%" mkdir "%STATE%" >nul 2>nul
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try{$h=Invoke-RestMethod '%HEALTH%' -TimeoutSec 3; Write-Host ('Bridge        : '+$(if($h.ok){'ONLINE'}else{'ERROR'})); Write-Host ('Port          : '+$h.port); Write-Host ('Council       : '+$(if($h.council_proxy){'READY'}else{'NO'})); Write-Host ('Vision        : '+$(if($h.vision_monitor_capture){'READY'}else{'NO'})); Write-Host ('Agent Runner  : '+$(if($h.agent_runner){'READY'}else{'NO'})); Write-Host ('Vault         : '+$(if($h.download_manager){'READY'}else{'NO'})); Write-Host ('Device API    : '+$(if($h.local_device_adapter){'READY'}else{'NO'})); try{$c=Invoke-RestMethod 'http://127.0.0.1:18765/chronicle/status' -TimeoutSec 3; Write-Host ('Chronicle     : READY / recording='+$c.recording+' / events='+$c.event_count)}catch{Write-Host 'Chronicle     : ERROR'}; try{$a=Invoke-RestMethod 'http://127.0.0.1:18765/agent/capabilities' -TimeoutSec 3; Write-Host ('Agent mode    : '+$a.mode+' / capabilities='+$a.capabilities.Count)}catch{Write-Host 'Agent mode    : ERROR'}; if($h.ok -and $h.council_proxy -and $h.vision_monitor_capture -and $h.local_device_adapter -and $h.agent_runner -and $h.download_manager){exit 0}else{exit 3}}catch{Write-Host 'Bridge        : OFFLINE'; Write-Host $_.Exception.Message; exit 4}"
set "RC=%ERRORLEVEL%"
call :task_status
if "%RC%"=="0" echo OVERALL       : TRUE GREEN
if not "%RC%"=="0" echo OVERALL       : NEEDS ATTENTION
if not "%~1"=="" exit /b %RC%
call :pausemenu
goto :menu

:task_status
schtasks /Query /TN "RAH Raven Bridge Startup" >nul 2>nul
if errorlevel 1 (echo Startup task  : NOT INSTALLED) else (echo Startup task  : INSTALLED)
schtasks /Query /TN "RAH Raven Bridge Watchdog" >nul 2>nul
if errorlevel 1 (echo Watchdog task : NOT INSTALLED) else (echo Watchdog task : INSTALLED)
exit /b 0

:vision
call :open_local "%VISION%" "Raven Vision"
goto :return_or_menu

:chronicle
call :open_local "%CHRONICLE%" "Chronicle Live"
goto :return_or_menu

:insights
call :open_local "%INSIGHTS%" "Raven Insights"
goto :return_or_menu

:brief
call :open_local "%BRIEF%" "Daily Brief"
goto :return_or_menu

:home
call :open_local "%HOME%" "Home Control"
goto :return_or_menu

:vault
call :open_local "%VAULT%" "Raven Vault"
goto :return_or_menu

:open_local
call :status_internal >nul 2>nul
if errorlevel 1 (
  echo [RAVEN] Bridge is not GREEN. Trying recovery first...
  call :watchdog
  if errorlevel 1 exit /b 1
)
echo [RAVEN] Opening %~2...
start "" "%~1"
exit /b 0

:agent
if not "%~1"=="" goto :agent_status
:agent_menu
cls
echo.
echo ================================================================
echo                  RAVEN AGENT RUNNER - SAFE MODE
echo ================================================================
echo.
echo   1  Show Agent Runner capabilities
echo   2  Run read-only Git status
echo   3  Run Bridge security regression test
echo   0  Back
echo.
choice /C 1230 /N /M "Choose: "
if errorlevel 4 goto :menu
if errorlevel 3 goto :agent_security
if errorlevel 2 goto :agent_git
if errorlevel 1 goto :agent_status
goto :agent_menu

:agent_status
call :header
call :status_internal >nul 2>nul
if errorlevel 1 call :watchdog >nul 2>nul
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try{$a=Invoke-RestMethod 'http://127.0.0.1:18765/agent/capabilities' -TimeoutSec 3; Write-Host ('Agent Runner : '+$a.version); Write-Host ('Mode         : '+$a.mode); Write-Host ('Arbitrary cmd: '+$a.arbitrary_commands); Write-Host ('File writes  : '+$a.file_writes); Write-Host ''; $a.capabilities|ForEach-Object{Write-Host (' - '+$_.id+' : '+$(if($_.available){'READY'}else{'MISSING DEP'}))}; exit 0}catch{Write-Host ('Agent ERROR: '+$_.Exception.Message); exit 4}"
set "RC=%ERRORLEVEL%"
if not "%~1"=="" exit /b %RC%
call :pauseagent
goto :agent_menu

:agent_git
call :header
echo This runs only the pre-approved read-only capability: git-status
choice /C YN /N /M "Run it? [Y/N]: "
if errorlevel 2 goto :agent_menu
call :agent_run "git-status"
call :pauseagent
goto :agent_menu

:agent_security
call :header
echo This runs only the pre-approved read-only capability: test-bridge-security
choice /C YN /N /M "Run it? [Y/N]: "
if errorlevel 2 goto :agent_menu
call :agent_run "test-bridge-security"
call :pauseagent
goto :agent_menu

:agent_run
set "CAP=%~1"
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; try{$body=@{capability='%CAP%';confirm=$true}|ConvertTo-Json; $r=Invoke-RestMethod 'http://127.0.0.1:18765/agent/run' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 150; Write-Host ('Capability : '+$r.capability.id); Write-Host ('Exit       : '+$r.exit_code); Write-Host ('Duration ms: '+$r.duration_ms); if($r.stdout){Write-Host ''; Write-Host $r.stdout}; if($r.stderr){Write-Host ''; Write-Host 'STDERR:'; Write-Host $r.stderr}; if($r.ok){exit 0}else{exit 3}}catch{Write-Host ('Agent ERROR: '+$_.Exception.Message); exit 4}"
exit /b %ERRORLEVEL%

:chatgpt
call :header
start "" "https://chatgpt.com/"
echo [RAVEN] ChatGPT opened.
echo [RAVEN] Opening Vision userscript installer/update page...
call :open_local "%USERSCRIPT%" "ChatGPT Vision userscript"
echo Install/update in Tampermonkey, then refresh ChatGPT.
goto :return_or_menu

:script
call :open_local "%USERSCRIPT%" "ChatGPT Vision userscript"
goto :return_or_menu

:autostart
call :require_runtime || goto :returnmenu
call :header
echo [RAVEN] Installing autostart + watchdog.
echo Windows may ask for Administrator approval.
if not exist "%BRIDGE%\install-raven-autostart.ps1" (
  echo [ERROR] install-raven-autostart.ps1 not found.
  goto :returnmenu
)
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%PS%' -Verb RunAs -Wait -ArgumentList '-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File ""%BRIDGE%\install-raven-autostart.ps1""'"
set "RC=%ERRORLEVEL%"
if "%RC%"=="0" call :task_status
if not "%~1"=="" exit /b %RC%
call :pausemenu
goto :menu

:repair
call :require_runtime || goto :returnmenu
call :header
echo [RAVEN] Safe Bridge repair...
if exist "%BRIDGE%\repair-raven-bridge.ps1" (
  "%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%BRIDGE%\repair-raven-bridge.ps1"
  set "RC=%ERRORLEVEL%"
) else (
  echo [ERROR] repair-raven-bridge.ps1 not found.
  echo No destructive fallback will be attempted.
  set "RC=6"
)
if not "%~1"=="" exit /b %RC%
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
goto :return_or_menu

:update
call :header
echo [RAVEN] Checking for CMD Console update...
set "TMP=%TEMP%\RAH-RAVEN-CMD-%RANDOM%-%RANDOM%.cmd"
curl.exe -fL --retry 2 --connect-timeout 10 "%UPDATE_URL%" -o "%TMP%"
if errorlevel 1 (
  echo [ERROR] Update download failed.
  if exist "%TMP%" del /q "%TMP%" >nul 2>nul
  goto :returnmenu
)
findstr /C:"RAH RAVEN CMD SUPER CONSOLE" "%TMP%" >nul
if errorlevel 1 (
  echo [ERROR] Downloaded file failed the Super Console verification marker.
  del /q "%TMP%" >nul 2>nul
  goto :returnmenu
)
fc /B "%TMP%" "%~f0" >nul 2>nul
if not errorlevel 1 (
  echo [OK] CMD Console is already current.
  del /q "%TMP%" >nul 2>nul
  goto :returnmenu
)
set "HELPER=%TEMP%\RAH-RAVEN-UPDATE-%RANDOM%-%RANDOM%.cmd"
>"%HELPER%" echo @echo off
>>"%HELPER%" echo ping 127.0.0.1 -n 2 ^>nul
>>"%HELPER%" echo copy /y "%TMP%" "%~f0" ^>nul
>>"%HELPER%" echo del /q "%TMP%" ^>nul 2^>nul
>>"%HELPER%" echo start "" "%ComSpec%" /d /c ""%~f0""
>>"%HELPER%" echo del /q "%%~f0" ^>nul 2^>nul
echo [OK] Update verified. Restarting into the new CMD Console...
start "RAH Raven Update" "%ComSpec%" /d /c ""%HELPER%""
exit /b 0

:help
echo RAH Raven CMD Super Console v%VERSION%
echo.
echo Usage:
echo   RAH-RAVEN-CMD.cmd                  Interactive Super Console
echo   RAH-RAVEN-CMD.cmd super            START ALL / recover
echo   RAH-RAVEN-CMD.cmd status           Whole-chain status
echo   RAH-RAVEN-CMD.cmd vision           Open Raven Vision
echo   RAH-RAVEN-CMD.cmd chronicle        Open Chronicle Live
echo   RAH-RAVEN-CMD.cmd insights         Open Raven Insights
echo   RAH-RAVEN-CMD.cmd brief            Open Daily Brief
echo   RAH-RAVEN-CMD.cmd home             Open Home Control
echo   RAH-RAVEN-CMD.cmd vault            Open Raven Vault
echo   RAH-RAVEN-CMD.cmd agent            Agent Runner status
echo   RAH-RAVEN-CMD.cmd script           Open Vision userscript
echo   RAH-RAVEN-CMD.cmd autostart        Install startup/watchdog
echo   RAH-RAVEN-CMD.cmd repair           Guarded repair
echo   RAH-RAVEN-CMD.cmd doctor           Raven Doctor
echo   RAH-RAVEN-CMD.cmd logs             Open logs
echo   RAH-RAVEN-CMD.cmd update           Self-update console
echo   RAH-RAVEN-CMD.cmd chatgpt          Open ChatGPT + userscript
exit /b 0

:pausemenu
echo.
pause
exit /b 0

:pauseagent
echo.
pause
exit /b 0

:return_or_menu
if not "%~1"=="" exit /b %ERRORLEVEL%
call :pausemenu
goto :menu

:returnmenu
if not "%~1"=="" exit /b 1
call :pausemenu
goto :menu

:exit
endlocal
exit /b 0
