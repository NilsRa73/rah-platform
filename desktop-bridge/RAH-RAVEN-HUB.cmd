@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0E
title RAH Raven HUB v1.0

set "RUNTIME=C:\RAH\Raven\rah-platform"
set "BRIDGE=%RUNTIME%\desktop-bridge"
set "CORE=%BRIDGE%\RAH-RAVEN-CMD.cmd"
set "WORKERS=%BRIDGE%\RAH-RAVEN-WORKERS.cmd"
set "CONTROL=%BRIDGE%\RAH-RAVEN-WORKER-CONTROL.cmd"
set "ANYTHING=%BRIDGE%\RAH-ANYTHINGLLM.cmd"

if /I "%~1"=="help" goto :help
if /I "%~1"=="start" goto :start
if /I "%~1"=="status" goto :status
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
echo                       RAH RAVEN HUB v1.0
echo ========================================================================
echo.
echo   1  START ALL / recover Raven Core
echo   2  SUPER STATUS
echo   3  WORKER STATUS / diagnose
echo   4  RUN WORKERS NOW
echo   5  REPAIR WORKERS
echo   6  FULL WORKER CONTROL
echo   7  RAVEN VISION
echo   8  CHRONICLE
echo   9  ANYTHINGLLM
echo   A  ORIGINAL SUPER CONSOLE
echo   0  EXIT
echo.
choice /C 123456789A0 /N /M "Choose: "
if errorlevel 11 goto :exit
if errorlevel 10 goto :core_menu
if errorlevel 9 goto :anythingllm_menu
if errorlevel 8 goto :chronicle_menu
if errorlevel 7 goto :vision_menu
if errorlevel 6 goto :control_menu
if errorlevel 5 goto :repair_menu
if errorlevel 4 goto :run_workers_menu
if errorlevel 3 goto :diagnose_menu
if errorlevel 2 goto :status_menu
if errorlevel 1 goto :start_menu
goto :menu

:require_core
if exist "%CORE%" exit /b 0
echo [ERROR] Raven Super Console missing: %CORE%
exit /b 2

:require_control
if exist "%CONTROL%" exit /b 0
echo [ERROR] Raven Worker Control missing: %CONTROL%
exit /b 3

:start
call :require_core || exit /b %ERRORLEVEL%
call "%CORE%" super
exit /b %ERRORLEVEL%

:status
call :require_core || exit /b %ERRORLEVEL%
call "%CORE%" status
echo.
if exist "%CONTROL%" call "%CONTROL%" status
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
  exit /b 4
)
call "%ANYTHING%"
exit /b %ERRORLEVEL%

:start_menu
call :start
echo.
pause
goto :menu

:status_menu
call :status
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
echo RAH Raven HUB v1.0
echo.
echo Commands:
echo   start           Start/recover Raven Core
echo   status          Core + Worker status
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
