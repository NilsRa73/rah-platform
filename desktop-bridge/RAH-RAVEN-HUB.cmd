@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0E
title RAH Raven HUB v1.1

set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "CORE=%BRIDGE%\RAH-RAVEN-CMD.cmd"
set "WORKERS=%BRIDGE%\RAH-RAVEN-WORKERS.cmd"
set "CONTROL=%BRIDGE%\RAH-RAVEN-WORKER-CONTROL.cmd"
set "AUTOPILOT=%BRIDGE%\RAH-RAVEN-AUTOPILOT.cmd"
set "ANYTHING=%BRIDGE%\RAH-ANYTHINGLLM.cmd"
set "HANDOFF=C:\RAH\AgentWork\AUTOPILOT-LATEST.txt"

if /I "%~1"=="help" goto :help
if /I "%~1"=="start" goto :start
if /I "%~1"=="status" goto :status
if /I "%~1"=="autopilot" goto :autopilot
if /I "%~1"=="handoff" goto :handoff
if /I "%~1"=="workers" goto :workers
if /I "%~1"=="diagnose" goto :diagnose
if /I "%~1"=="repair-workers" goto :repair_workers
if /I "%~1"=="vision" goto :vision
if /I "%~1"=="chronicle" goto :chronicle
if /I "%~1"=="anythingllm" goto :anythingllm
if not "%~1"=="" goto :help

:menu
cls
echo.
echo ========================================================================
echo                       RAH RAVEN HUB v1.1
echo ========================================================================
echo.
echo   1  AUTOPILOT - diagnose + SAFE recovery + handoff
echo   2  SUPER STATUS
echo   3  COPY AUTOPILOT HANDOFF for ChatGPT
echo   4  WORKER STATUS / diagnose
echo   5  RUN WORKERS NOW
echo   6  REPAIR WORKERS
echo   7  FULL WORKER CONTROL
echo   8  RAVEN VISION
echo   9  CHRONICLE
echo   A  ANYTHINGLLM
echo   B  ORIGINAL SUPER CONSOLE
echo   0  EXIT
echo.
choice /C 123456789AB0 /N /M "Choose: "
if errorlevel 12 goto :exit
if errorlevel 11 goto :core_menu
if errorlevel 10 goto :anythingllm_menu
if errorlevel 9 goto :chronicle_menu
if errorlevel 8 goto :vision_menu
if errorlevel 7 goto :control_menu
if errorlevel 6 goto :repair_menu
if errorlevel 5 goto :run_workers_menu
if errorlevel 4 goto :diagnose_menu
if errorlevel 3 goto :handoff_menu
if errorlevel 2 goto :status_menu
if errorlevel 1 goto :autopilot_menu
goto :menu

:require_core
if exist "%CORE%" exit /b 0
echo [ERROR] Raven Super Console missing: %CORE%
exit /b 2

:require_control
if exist "%CONTROL%" exit /b 0
echo [ERROR] Raven Worker Control missing: %CONTROL%
exit /b 3

:require_autopilot
if exist "%AUTOPILOT%" exit /b 0
echo [ERROR] Raven Autopilot missing: %AUTOPILOT%
exit /b 4

:start
call :require_core || exit /b %ERRORLEVEL%
call "%CORE%" super
exit /b %ERRORLEVEL%

:status
call :require_core || exit /b %ERRORLEVEL%
call "%CORE%" status
echo.
if exist "%CONTROL%" call "%CONTROL%" status
echo.
if exist "%AUTOPILOT%" call "%AUTOPILOT%" status
exit /b 0

:autopilot
call :require_autopilot || exit /b %ERRORLEVEL%
call "%AUTOPILOT%" once
exit /b %ERRORLEVEL%

:handoff
if not exist "%HANDOFF%" (
  echo No Autopilot handoff exists yet. Running Autopilot first...
  call :autopilot
)
if not exist "%HANDOFF%" exit /b 5
type "%HANDOFF%" | clip.exe
echo [OK] Autopilot handoff copied to clipboard.
echo      Paste it into ChatGPT when you want me to use the local agent results.
exit /b 0

:workers
call :require_control || exit /b %ERRORLEVEL%
call "%CONTROL%" diagnose
exit /b %ERRORLEVEL%

:diagnose
call :workers
exit /b %ERRORLEVEL%

:repair_workers
call :require_control || exit /b %ERRORLEVEL%
call "%CONTROL%" repair
exit /b %ERRORLEVEL%

:vision
call :require_core || exit /b %ERRORLEVEL%
call "%CORE%" vision
exit /b %ERRORLEVEL%

:chronicle
call :require_core || exit /b %ERRORLEVEL%
call "%CORE%" chronicle
exit /b %ERRORLEVEL%

:anythingllm
if not exist "%ANYTHING%" (
  echo [ERROR] AnythingLLM helper missing: %ANYTHING%
  exit /b 6
)
call "%ANYTHING%"
exit /b %ERRORLEVEL%

:autopilot_menu
call :autopilot
echo.
pause
goto :menu

:status_menu
call :status
echo.
pause
goto :menu

:handoff_menu
call :handoff
echo.
pause
goto :menu

:diagnose_menu
call :diagnose
echo.
pause
goto :menu

:run_workers_menu
if exist "%WORKERS%" (call "%WORKERS%" once) else (echo [ERROR] Worker engine missing.)
echo.
pause
goto :menu

:repair_menu
call :repair_workers
echo.
pause
goto :menu

:control_menu
call :require_control || goto :control_back
call "%CONTROL%"
:control_back
goto :menu

:vision_menu
call :vision
goto :menu

:chronicle_menu
call :chronicle
goto :menu

:anythingllm_menu
call :anythingllm
goto :menu

:core_menu
call :require_core || goto :menu
call "%CORE%"
goto :menu

:help
echo RAH Raven HUB v1.1
echo.
echo Commands:
echo   autopilot       Self-diagnose + SAFE recovery + handoff
echo   handoff         Copy AUTOPILOT-LATEST.txt to clipboard
echo   start           Start/recover Raven Core
echo   status          Core + Worker + Autopilot status
echo   workers         Worker diagnosis
echo   diagnose        Worker diagnosis
echo   repair-workers  Rebuild Worker tasks and rerun
echo   vision          Open Raven Vision
echo   chronicle       Open Chronicle
echo   anythingllm     Open AnythingLLM helper
exit /b 0

:exit
endlocal
exit /b 0
