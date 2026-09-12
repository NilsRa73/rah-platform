@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0E
title RAH Raven Autopilot v1.0

set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "CORE=%BRIDGE%\RAH-RAVEN-CMD.cmd"
set "WORKERS=%BRIDGE%\RAH-RAVEN-WORKERS.cmd"
set "CONTROL=%BRIDGE%\RAH-RAVEN-WORKER-CONTROL.cmd"
set "ROOT=C:\RAH\AgentWork"
set "LATEST=%ROOT%\LATEST.txt"
set "HANDOFF=%ROOT%\AUTOPILOT-LATEST.txt"
set "DIAG=%ROOT%\AUTOPILOT-DIAGNOSIS.txt"
set "HEALTH=http://127.0.0.1:18765/health"

if /I "%~1"=="help" goto :help
if /I "%~1"=="once" goto :once
if /I "%~1"=="status" goto :status
if /I "%~1"=="report" goto :report
if /I "%~1"=="open" goto :open
if not "%~1"=="" goto :help

:menu
cls
echo.
echo ========================================================================
echo                      RAH RAVEN AUTOPILOT v1.0
echo ========================================================================
echo.
echo   1  RUN self-diagnosis + SAFE recovery
echo   2  STATUS
echo   3  SHOW ChatGPT handoff report
echo   4  OPEN AgentWork
echo   0  EXIT
echo.
choice /C 12340 /N /M "Choose: "
if errorlevel 5 goto :exit
if errorlevel 4 goto :open_menu
if errorlevel 3 goto :report_menu
if errorlevel 2 goto :status_menu
if errorlevel 1 goto :once_menu
goto :menu

:require_runtime
if not exist "%BRIDGE%\raven_bridge.py" exit /b 2
if not exist "%CORE%" exit /b 3
if not exist "%WORKERS%" exit /b 4
exit /b 0

:health
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';try{$h=Invoke-RestMethod '%HEALTH%' -TimeoutSec 5;if($h.ok -and $h.council_proxy -and $h.vision_monitor_capture -and $h.local_device_adapter -and $h.agent_runner -and $h.download_manager){exit 0}else{exit 3}}catch{exit 4}"
exit /b %ERRORLEVEL%

:once
call :require_runtime || exit /b %ERRORLEVEL%
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>nul

>"%HANDOFF%" echo RAH RAVEN AUTOPILOT v1.0
>>"%HANDOFF%" echo ========================================================================
>>"%HANDOFF%" echo Started: %date% %time%
>>"%HANDOFF%" echo Policy: SAFE recovery automatically; ASK and PLAN are reported only.
>>"%HANDOFF%" echo.

echo [1/4] Raven Core health...
call :health
if errorlevel 1 (
  echo       Core not GREEN. Trying one SAFE START ALL recovery...
  >>"%HANDOFF%" echo [SAFE] Core recovery attempted with existing Raven START ALL.
  call "%CORE%" super >nul 2>nul
  call :health
)
if errorlevel 1 (
  >>"%HANDOFF%" echo [FAIL] Raven Core is still not TRUE GREEN.
  >>"%HANDOFF%" echo [ASK] Deeper Core repair required; Workers were not run.
  >>"%HANDOFF%" echo Overall: FAIL
  type "%HANDOFF%"
  exit /b 10
)
>>"%HANDOFF%" echo [PASS] Raven Core TRUE GREEN.

echo [2/4] Running Raven Workers...
call "%WORKERS%" once
set "WRC=%ERRORLEVEL%"
if "%WRC%"=="5" (
  echo       Worker failure detected. One SAFE rerun to rule out transient error...
  >>"%HANDOFF%" echo [SAFE] Worker failure detected; one controlled rerun attempted.
  timeout /t 2 /nobreak >nul
  call "%WORKERS%" once
  set "WRC=%ERRORLEVEL%"
)

echo [3/4] Building diagnosis...
if exist "%CONTROL%" call "%CONTROL%" diagnose > "%DIAG%" 2>&1

if exist "%LATEST%" (
  >>"%HANDOFF%" echo.
  >>"%HANDOFF%" echo ------------------------- WORKER REPORT -------------------------
  type "%LATEST%" >> "%HANDOFF%"
  >>"%HANDOFF%" echo -----------------------------------------------------------------
)
if exist "%DIAG%" (
  >>"%HANDOFF%" echo.
  >>"%HANDOFF%" echo ------------------------- DIAGNOSIS -----------------------------
  type "%DIAG%" >> "%HANDOFF%"
  >>"%HANDOFF%" echo -----------------------------------------------------------------
)

if "%WRC%"=="0" (
  >>"%HANDOFF%" echo [PASS] Workers healthy. No user action required.
  >>"%HANDOFF%" echo Overall: PASS
  set "FINAL=0"
) else if "%WRC%"=="6" (
  >>"%HANDOFF%" echo [PLAN] Workers passed with warning; keep running and review Doctor/local-model warning later.
  >>"%HANDOFF%" echo Overall: PASS WITH WARNING
  set "FINAL=6"
) else (
  >>"%HANDOFF%" echo [ASK] Named Worker failure remains after SAFE rerun.
  >>"%HANDOFF%" echo [PLAN] Use the captured diagnosis/detail before changing dependencies or system configuration.
  >>"%HANDOFF%" echo Overall: FAIL
  set "FINAL=5"
)

echo [4/4] ChatGPT handoff ready: %HANDOFF%
echo.
type "%HANDOFF%"
exit /b %FINAL%

:status
call :health
if errorlevel 1 (echo CORE      : NOT TRUE GREEN) else (echo CORE      : TRUE GREEN)
if exist "%LATEST%" (
  findstr /I /C:"[FAIL]" "%LATEST%" >nul 2>nul
  if not errorlevel 1 (echo WORKERS   : NEED REPAIR) else (
    findstr /I /C:"[WARN]" "%LATEST%" >nul 2>nul
    if not errorlevel 1 (echo WORKERS   : PASS WITH WARNING) else (echo WORKERS   : PASS)
  )
) else (echo WORKERS   : NO REPORT)
if exist "%HANDOFF%" (echo HANDOFF   : READY) else (echo HANDOFF   : NOT READY)
exit /b 0

:report
if exist "%HANDOFF%" (type "%HANDOFF%"& exit /b 0)
echo No Autopilot handoff report exists yet.
exit /b 2

:open
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>nul
start "" explorer.exe "%ROOT%"
exit /b 0

:once_menu
call :once
echo.
pause
goto :menu
:status_menu
call :status
echo.
pause
goto :menu
:report_menu
call :report
echo.
pause
goto :menu
:open_menu
call :open
goto :menu

:help
echo RAH Raven Autopilot v1.0
echo self-diagnosis + SAFE recovery + ChatGPT handoff
echo.
echo Commands:
echo   once    Diagnose, SAFE-recover, run workers, build handoff
echo   status  Core + Worker + handoff status
echo   report  Show AUTOPILOT-LATEST.txt
echo   open    Open C:\RAH\AgentWork
exit /b 0

:exit
endlocal
exit /b 0
