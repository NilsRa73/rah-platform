@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0E
title RAH Raven Stable + Workers

set "BRIDGE=C:\RAH\Raven\rah-platform\desktop-bridge"
set "CONSOLE=%BRIDGE%\RAH-RAVEN-CMD.cmd"
set "WORKERS=%BRIDGE%\RAH-RAVEN-WORKERS.cmd"
set "REPAIR=%BRIDGE%\repair-raven-bridge.ps1"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if /I "%~1"=="help" goto :help

echo.
echo ================================================================
echo              RAH RAVEN STABLE + WORKERS
echo ================================================================
echo.

if not exist "%CONSOLE%" (
  echo [ERROR] Raven Super Console missing.
  pause
  exit /b 2
)
if not exist "%WORKERS%" (
  echo [ERROR] Raven Workers missing.
  pause
  exit /b 3
)

echo [1/5] START ALL / Raven recovery...
call "%CONSOLE%" super
set "RC=%ERRORLEVEL%"
if "%RC%"=="0" goto :bridge_ready

echo [2/5] First start did not reach GREEN.
if exist "%REPAIR%" (
  echo       Running guarded Raven repair once...
  "%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%REPAIR%"
  echo       Retrying START ALL...
  call "%CONSOLE%" super
  set "RC=%ERRORLEVEL%"
)
if not "%RC%"=="0" (
  echo.
  echo [STOP] Raven is not stable. Workers will NOT run.
  echo Use Raven Doctor / logs before continuing.
  pause
  exit /b 10
)

:bridge_ready
echo [2/5] Raven Bridge TRUE GREEN.

echo [3/5] Installing / refreshing automatic workers...
call "%WORKERS%" install
if errorlevel 1 (
  echo [WARN] Worker scheduled tasks were not installed.
) else (
  echo [OK] Worker scheduled tasks ready.
)

echo [4/5] Running SCOUT / GUARD / TESTER / DOCTOR now...
call "%WORKERS%" once
set "WRC=%ERRORLEVEL%"

echo [5/5] Final Raven status...
call "%CONSOLE%" status

echo.
echo ================================================================
if "%WRC%"=="0" (
  echo   RAH RAVEN STABLE MODE = READY
  echo   WORKERS = ACTIVE
) else (
  echo   RAH RAVEN = GREEN
  echo   WORKERS = NEED ATTENTION
)
echo ================================================================
echo.
echo Reports: C:\RAH\AgentWork
echo.
pause
exit /b %WRC%

:help
echo RAH Raven Stable + Workers
echo.
echo Starts/recover Raven, uses guarded repair once if needed, installs the
echo fixed Raven Workers tasks, runs the worker suite, then prints final status.
exit /b 0
