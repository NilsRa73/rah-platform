@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
color 0E
title RAH ChatGPT Handoff Setup

set "BRIDGE=C:\RAH\Raven\rah-platform\desktop-bridge"
set "LIVE=%BRIDGE%\RAH-OBSERVER-LIVE.cmd"
set "URL=http://127.0.0.1:18767/userscript/RAH-RAVEN-CHATGPT-HANDOFF.user.js"
set "HEALTH=http://127.0.0.1:18767/health"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"

if /I "%~1"=="help" goto :help
if /I "%~1"=="status" goto :status
if /I "%~1"=="install" goto :install
if not "%~1"=="" goto :help

:install
if not exist "%LIVE%" (
  echo [ERROR] Live Wall helper missing: %LIVE%
  exit /b 2
)
call "%LIVE%" start >nul 2>nul
call :health
if errorlevel 1 (
  echo [ERROR] Live Wall is not healthy on 127.0.0.1:18767.
  exit /b 3
)
echo.
echo RAH ChatGPT Handoff userscript
echo ----------------------------------------
echo Tampermonkey must show its normal install/confirm page.
echo Raven will NOT click Install or Send for you.
echo.
start "" "%URL%"
exit /b 0

:status
call :health
if errorlevel 1 (
  echo CHATGPT HANDOFF : LIVE WALL OFFLINE
  exit /b 4
)
echo CHATGPT HANDOFF : LOCAL ENDPOINT READY
echo URL             : %URL%
exit /b 0

:health
"%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';try{$h=Invoke-RestMethod '%HEALTH%' -TimeoutSec 5;if($h.ok -and $h.read_only -and $h.handoff -and $h.doctor_status){exit 0}else{exit 3}}catch{exit 4}"
exit /b %ERRORLEVEL%

:help
echo RAH ChatGPT Handoff Setup v1.0
echo.
echo Commands:
echo   install  Start Live Wall and open the local Tampermonkey userscript
echo   status   Check local handoff endpoint readiness
echo   help     Show this help
echo.
echo Safety: no auto-send, no silent extension install, no arbitrary file path.
exit /b 0
