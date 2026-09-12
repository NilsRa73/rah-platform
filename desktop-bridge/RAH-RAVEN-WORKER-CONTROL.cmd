@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0E
title RAH Raven Worker Control v1.0

set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "WORKERS=%BRIDGE%\RAH-RAVEN-WORKERS.cmd"
set "ROOT=C:\RAH\AgentWork"
set "LATEST=%ROOT%\LATEST.txt"
set "LATESTRUN=%ROOT%\LATEST-RUN.txt"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "HEALTH=http://127.0.0.1:18765/health"

if /I "%~1"=="help" goto :help
if /I "%~1"=="status" goto :status
if /I "%~1"=="diagnose" goto :diagnose
if /I "%~1"=="details" goto :details
if /I "%~1"=="run" goto :run
if /I "%~1"=="repair" goto :repair
if /I "%~1"=="report" goto :report
if /I "%~1"=="copy" goto :copy
if /I "%~1"=="install" goto :install
if not "%~1"=="" goto :help

:menu
cls
echo.
echo ========================================================================
echo                  RAH RAVEN WORKER CONTROL v1.0
echo ========================================================================
echo.
call :compact_status
echo.
echo   1  DIAGNOSE latest Worker run
echo   2  OPEN exact failing Worker details
echo   3  RUN Workers now
echo   4  REPAIR Workers tasks + rerun
echo   5  SHOW full latest report
echo   6  COPY latest report
echo   7  OPEN AgentWork folder
echo   8  INSTALL desktop shortcut
echo   0  EXIT
echo.
choice /C 123456780 /N /M "Choose: "
if errorlevel 9 goto :exit
if errorlevel 8 goto :install_menu
if errorlevel 7 goto :open_root
if errorlevel 6 goto :copy_menu
if errorlevel 5 goto :report_menu
if errorlevel 4 goto :repair_menu
if errorlevel 3 goto :run_menu
if errorlevel 2 goto :details_menu
if errorlevel 1 goto :diagnose_menu
goto :menu

:health
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';try{$h=Invoke-RestMethod '%HEALTH%' -TimeoutSec 4;if($h.ok -and $h.council_proxy -and $h.vision_monitor_capture -and $h.local_device_adapter -and $h.agent_runner -and $h.download_manager){exit 0}else{exit 3}}catch{exit 4}"
exit /b %ERRORLEVEL%

:compact_status
call :health
if errorlevel 1 (echo   CORE    : NOT TRUE GREEN) else (echo   CORE    : TRUE GREEN)
if not exist "%LATEST%" (
  echo   WORKERS : NO REPORT YET
  exit /b 0
)
findstr /I /C:"[FAIL]" "%LATEST%" >nul 2>nul
if not errorlevel 1 (
  echo   WORKERS : NEED REPAIR
  exit /b 0
)
findstr /I /C:"[WARN]" "%LATEST%" >nul 2>nul
if not errorlevel 1 (
  echo   WORKERS : PASS WITH WARNING
  exit /b 0
)
echo   WORKERS : GREEN / PASS
exit /b 0

:status
call :compact_status
exit /b 0

:diagnose
echo.
echo ========================================================================
echo                         LATEST DIAGNOSIS
echo ========================================================================
echo.
call :compact_status
echo.
if not exist "%LATEST%" (
  echo No latest Worker report exists yet.
  exit /b 2
)
call :line_status "SCOUT" "SCOUT / project-files"
call :line_status "GUARD" "GUARD / test-bridge-security"
call :line_status "TESTER-COUNCIL" "TESTER / test-council"
call :line_status "TESTER-VISION" "TESTER / test-vision-core"
findstr /I /C:"[WARN] DOCTOR" "%LATEST%" >nul 2>nul
if not errorlevel 1 (
  echo   DOCTOR          : WARNING
) else (
  findstr /I /C:"[PASS] DOCTOR" "%LATEST%" >nul 2>nul
  if not errorlevel 1 (echo   DOCTOR          : PASS) else (echo   DOCTOR          : UNKNOWN)
)
echo.
findstr /I /C:"[FAIL]" "%LATEST%" >nul 2>nul
if not errorlevel 1 (
  echo REPAIR TARGETS:
  findstr /I /C:"[FAIL]" "%LATEST%"
  exit /b 5
)
findstr /I /C:"[WARN]" "%LATEST%" >nul 2>nul
if not errorlevel 1 (
  echo WARNINGS:
  findstr /I /C:"[WARN]" "%LATEST%"
  exit /b 6
)
echo All Worker jobs are PASS.
exit /b 0

:line_status
set "LABEL=%~1"
set "NEEDLE=%~2"
findstr /I /C:"[FAIL] %NEEDLE%" "%LATEST%" >nul 2>nul
if not errorlevel 1 (
  echo   %LABEL% : NEED REPAIR
  exit /b 0
)
findstr /I /C:"[PASS] %NEEDLE%" "%LATEST%" >nul 2>nul
if not errorlevel 1 (
  echo   %LABEL% : PASS
  exit /b 0
)
echo   %LABEL% : UNKNOWN
exit /b 0

:get_run
set "RUN="
if exist "%LATESTRUN%" set /p "RUN="<"%LATESTRUN%"
if not defined RUN exit /b 1
if not exist "%RUN%" exit /b 2
exit /b 0

:details
call :get_run
if errorlevel 1 (
  echo No valid latest run folder.
  exit /b 2
)
set "OPENED=0"
call :detail_if_fail "SCOUT / project-files" "%RUN%\SCOUT-project-files.json"
call :detail_if_fail "GUARD / test-bridge-security" "%RUN%\GUARD-bridge-security.json"
call :detail_if_fail "TESTER / test-council" "%RUN%\TESTER-council.json"
call :detail_if_fail "TESTER / test-vision-core" "%RUN%\TESTER-vision-core.json"
findstr /I /C:"[WARN] DOCTOR" "%LATEST%" >nul 2>nul
if not errorlevel 1 (
  if exist "%RUN%\DOCTOR.err.txt" start "" notepad.exe "%RUN%\DOCTOR.err.txt"
  if exist "%RUN%\DOCTOR.json" start "" notepad.exe "%RUN%\DOCTOR.json"
  set "OPENED=1"
)
if "%OPENED%"=="0" start "" explorer.exe "%RUN%"
exit /b 0

:detail_if_fail
findstr /I /C:"[FAIL] %~1" "%LATEST%" >nul 2>nul
if errorlevel 1 exit /b 0
if exist "%~2" (start "" notepad.exe "%~2") else (echo [MISSING DETAIL] %~2)
set "OPENED=1"
exit /b 0

:run
if not exist "%WORKERS%" (
  echo [ERROR] Worker engine missing: %WORKERS%
  exit /b 2
)
call "%WORKERS%" once
set "RC=%ERRORLEVEL%"
echo.
call :diagnose
exit /b %RC%

:repair
call :require_admin
if errorlevel 1 exit /b %ERRORLEVEL%
call :health
if errorlevel 1 (
  echo [BLOCKED] Raven Core is not TRUE GREEN. Worker repair did not run.
  exit /b 10
)
if not exist "%WORKERS%" (
  echo [ERROR] Worker engine missing: %WORKERS%
  exit /b 2
)
schtasks /Delete /F /TN "RAH Raven Workers Startup" >nul 2>nul
schtasks /Delete /F /TN "RAH Raven Workers Hourly" >nul 2>nul
call "%WORKERS%" install
if errorlevel 1 exit /b 20
call "%WORKERS%" once
set "RC=%ERRORLEVEL%"
echo.
call :diagnose
exit /b %RC%

:report
if exist "%LATEST%" (type "%LATEST%" & exit /b 0)
echo No latest Worker report exists.
exit /b 2

:copy
if not exist "%LATEST%" (
  echo No report to copy.
  exit /b 2
)
type "%LATEST%" | clip.exe
echo [OK] Latest Raven Worker report copied to clipboard.
exit /b 0

:install
call :require_admin
if errorlevel 1 exit /b %ERRORLEVEL%
set "TOOLS=C:\RAH\Raven\Tools"
if not exist "%TOOLS%" mkdir "%TOOLS%" >nul 2>nul
copy /y "%~f0" "%TOOLS%\RAH-RAVEN-WORKER-CONTROL.cmd" >nul
set "DESKTOP="
for /f "usebackq delims=" %%D in (`"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"
if not defined DESKTOP set "DESKTOP=%USERPROFILE%\Desktop"
>"%DESKTOP%\RAH Raven Worker Control.cmd" (
  echo @echo off
  echo call "%TOOLS%\RAH-RAVEN-WORKER-CONTROL.cmd"
)
echo [OK] Desktop shortcut installed.
exit /b 0

:require_admin
fltmc >nul 2>&1
if "%ERRORLEVEL%"=="0" exit /b 0
echo [RAH] Administrator approval required...
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -Verb RunAs -Wait -ArgumentList '/d /c ""%~f0"" repair'"
exit /b 100

:open_root
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>nul
start "" explorer.exe "%ROOT%"
goto :menu

:diagnose_menu
call :diagnose
echo.
pause
goto :menu

:details_menu
call :details
echo.
pause
goto :menu

:run_menu
call :run
echo.
pause
goto :menu

:repair_menu
call :repair
echo.
pause
goto :menu

:report_menu
call :report
echo.
pause
goto :menu

:copy_menu
call :copy
echo.
pause
goto :menu

:install_menu
call :install
echo.
pause
goto :menu

:help
echo RAH Raven Worker Control v1.0
echo.
echo Commands:
echo   status     Compact Core + Worker state
echo   diagnose   Identify exact failing Worker
echo   details    Open exact failing Worker detail files
echo   run        Run Workers now
echo   repair     Rebuild Worker tasks + rerun
echo   report     Show latest full report
echo   copy       Copy latest report to clipboard
echo   install    Install desktop shortcut
exit /b 0

:exit
endlocal
exit /b 0
