@echo off
setlocal EnableExtensions
chcp 65001 >nul 2>nul
color 0E
title RAH Raven Big Screen
set "BRIDGE=C:\RAH\Raven\rah-platform\desktop-bridge"
set "PS=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "FONT=%BRIDGE%\set-raven-console-font.ps1"
set "CONSOLE=%BRIDGE%\RAH-RAVEN-CMD.cmd"
if exist "%FONT%" "%PS%" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%FONT%" -Size 24 >nul 2>nul
mode con cols=108 lines=36 >nul 2>nul
if not exist "%CONSOLE%" (
  echo [ERROR] RAH-RAVEN-CMD.cmd not found.
  pause
  exit /b 2
)
call "%CONSOLE%"
endlocal
