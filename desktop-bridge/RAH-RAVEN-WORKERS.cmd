@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0E
title RAH Raven Workers

set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "PY=%BRIDGE%\.venv\Scripts\python.exe"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "ROOT=C:\RAH\AgentWork"
set "LOGS=C:\RAH\Logs\RavenWorkers"
set "HEALTH=http://127.0.0.1:18765/health"
set "AGENT=http://127.0.0.1:18765/agent/run"

if /I "%~1"=="help" goto :help
if /I "%~1"=="once" goto :once
if /I "%~1"=="install" goto :install
if /I "%~1"=="status" goto :status
if /I "%~1"=="open" goto :open
if /I "%~1"=="uninstall" goto :uninstall
if not "%~1"=="" goto :help

:menu
cls
echo.
echo ================================================================
echo                 RAH RAVEN WORKERS v1.0
echo ================================================================
echo.
echo   1  RUN WORKERS NOW
echo   2  INSTALL automatic workers
echo   3  LAST STATUS / REPORT
echo   4  OPEN worker reports
echo   5  REMOVE automatic worker tasks
echo   0  BACK / EXIT
echo.
echo   SCOUT  = Git status
echo   GUARD  = Bridge security
echo   TESTER = Council + Vision Core
echo   DOCTOR = local Raven / LM Studio health
echo.
choice /C 123450 /N /M "Choose: "
if errorlevel 6 goto :exit
if errorlevel 5 goto :uninstall_menu
if errorlevel 4 goto :open_menu
if errorlevel 3 goto :status_menu
if errorlevel 2 goto :install_menu
if errorlevel 1 goto :once_menu
goto :menu

:require_runtime
if not exist "%BRIDGE%\raven_bridge.py" (
  echo [ERROR] Raven runtime missing: %BRIDGE%
  exit /b 2
)
if not exist "%PY%" (
  echo [ERROR] Raven Python environment missing: %PY%
  exit /b 3
)
exit /b 0

:health
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';try{$h=Invoke-RestMethod '%HEALTH%' -TimeoutSec 4;if($h.ok -and $h.council_proxy -and $h.vision_monitor_capture -and $h.local_device_adapter -and $h.agent_runner -and $h.download_manager){exit 0}else{exit 3}}catch{exit 4}"
exit /b %ERRORLEVEL%

:once
call :require_runtime || exit /b %ERRORLEVEL%
call :health
if errorlevel 1 (
  echo [BLOCKED] Raven Bridge is not TRUE GREEN. Workers did not run.
  exit /b 10
)
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>nul
if not exist "%LOGS%" mkdir "%LOGS%" >nul 2>nul
set "STAMP=%RANDOM%-%RANDOM%"
set "RUN=%ROOT%\Runs\%STAMP%"
mkdir "%RUN%" >nul 2>nul
set "SUMMARY=%RUN%\SUMMARY.txt"

>"%SUMMARY%" echo RAH RAVEN WORKERS
>>"%SUMMARY%" echo ================================================================
>>"%SUMMARY%" echo Started: %date% %time%
>>"%SUMMARY%" echo Raven Bridge: TRUE GREEN
>>"%SUMMARY%" echo.

echo.
echo [SCOUT] git-status...
call :agent_job "git-status" "SCOUT" "%RUN%\SCOUT-git-status.json" "%SUMMARY%"

echo [GUARD] test-bridge-security...
call :agent_job "test-bridge-security" "GUARD" "%RUN%\GUARD-bridge-security.json" "%SUMMARY%"

echo [TESTER] test-council...
call :agent_job "test-council" "TESTER" "%RUN%\TESTER-council.json" "%SUMMARY%"

echo [TESTER] test-vision-core...
call :agent_job "test-vision-core" "TESTER" "%RUN%\TESTER-vision-core.json" "%SUMMARY%"

echo [DOCTOR] Raven Doctor...
pushd "%BRIDGE%"
"%PY%" doctor.py --json > "%RUN%\DOCTOR.json" 2> "%RUN%\DOCTOR.err.txt"
set "DRC=%ERRORLEVEL%"
popd
if "%DRC%"=="0" (
  echo [PASS] DOCTOR
  >>"%SUMMARY%" echo [PASS] DOCTOR
) else (
  echo [FAIL] DOCTOR
  >>"%SUMMARY%" echo [FAIL] DOCTOR exit=%DRC%
)

>>"%SUMMARY%" echo.
>>"%SUMMARY%" echo Finished: %date% %time%
copy /y "%SUMMARY%" "%ROOT%\LATEST.txt" >nul 2>nul
>"%ROOT%\LATEST-RUN.txt" echo %RUN%

echo.
echo ================================================================
echo                 RAVEN WORKER RUN COMPLETE
echo ================================================================
type "%SUMMARY%"
echo.
echo Reports: %RUN%
exit /b 0

:agent_job
set "CAP=%~1"
set "ROLE=%~2"
set "OUT=%~3"
set "SUM=%~4"
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';try{$body=@{capability='%CAP%';confirm=$true}|ConvertTo-Json;$r=Invoke-WebRequest '%AGENT%' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 160 -UseBasicParsing;$r.Content|Set-Content -LiteralPath '%OUT%' -Encoding UTF8;$j=$r.Content|ConvertFrom-Json;if($j.ok){exit 0}else{exit 3}}catch{if($_.ErrorDetails.Message){$_.ErrorDetails.Message|Set-Content -LiteralPath '%OUT%' -Encoding UTF8}else{$_.Exception.Message|Set-Content -LiteralPath '%OUT%' -Encoding UTF8};exit 4}"
set "JRC=%ERRORLEVEL%"
if "%JRC%"=="0" (
  echo [PASS] %ROLE% / %CAP%
  >>"%SUM%" echo [PASS] %ROLE% / %CAP%
) else (
  echo [FAIL] %ROLE% / %CAP%
  >>"%SUM%" echo [FAIL] %ROLE% / %CAP% exit=%JRC%
)
exit /b 0

:install
call :require_runtime || exit /b %ERRORLEVEL%
fltmc >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
  "%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -Verb RunAs -Wait -ArgumentList '/d /c ""%~f0"" install-elevated'"
  exit /b %ERRORLEVEL%
)
goto :install_elevated

:install-elevated
:install_elevated
schtasks /Create /F /TN "RAH Raven Workers Startup" /SC ONLOGON /RL HIGHEST /TR "\"%~f0\" once" >nul
if errorlevel 1 exit /b 20
schtasks /Create /F /TN "RAH Raven Workers Hourly" /SC HOURLY /MO 1 /RL HIGHEST /TR "\"%~f0\" once" >nul
if errorlevel 1 exit /b 21
echo [OK] Raven Workers Startup installed.
echo [OK] Raven Workers Hourly installed.
exit /b 0

:status
if exist "%ROOT%\LATEST.txt" (
  type "%ROOT%\LATEST.txt"
) else (
  echo No Raven Worker report exists yet.
)
exit /b 0

:open
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>nul
start "" explorer.exe "%ROOT%"
exit /b 0

:uninstall
fltmc >nul 2>&1
if not "%ERRORLEVEL%"=="0" (
  "%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -Verb RunAs -Wait -ArgumentList '/d /c ""%~f0"" uninstall-elevated'"
  exit /b %ERRORLEVEL%
)
goto :uninstall_elevated

:uninstall-elevated
:uninstall_elevated
schtasks /Delete /F /TN "RAH Raven Workers Startup" >nul 2>nul
schtasks /Delete /F /TN "RAH Raven Workers Hourly" >nul 2>nul
echo [OK] Automatic Raven Worker tasks removed.
exit /b 0

:once_menu
call :once
echo.
pause
goto :menu

:install_menu
call :install
echo.
pause
goto :menu

:status_menu
call :status
echo.
pause
goto :menu

:open_menu
call :open
goto :menu

:uninstall_menu
call :uninstall
echo.
pause
goto :menu

:help
echo RAH Raven Workers v1.0
echo.
echo Usage:
echo   RAH-RAVEN-WORKERS.cmd          Interactive menu
echo   RAH-RAVEN-WORKERS.cmd once     Run fixed safe worker suite
echo   RAH-RAVEN-WORKERS.cmd install  Install startup + hourly tasks
echo   RAH-RAVEN-WORKERS.cmd status   Show last report
echo   RAH-RAVEN-WORKERS.cmd open     Open report folder
echo   RAH-RAVEN-WORKERS.cmd uninstall Remove automatic tasks
exit /b 0

:exit
endlocal
exit /b 0
