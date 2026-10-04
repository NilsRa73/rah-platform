@echo off
setlocal
title RAH OS - START HERE
:MENU
cls
echo.
echo ============================================================
echo                    RAH OS START HERE
echo ============================================================
echo   [1] MODE SWITCH
echo   [2] RAVEN COMMAND WHEEL
echo   [3] OMEN HEALTHCHECK
echo   [4] CHATGPT
echo   [5] EXIT
echo ============================================================
choice /C 12345 /N /M "Velg: "
if errorlevel 5 goto EXIT
if errorlevel 4 goto GPT
if errorlevel 3 goto HEALTH
if errorlevel 2 goto WHEEL
if errorlevel 1 goto MODES
:MODES
call "C:\RAH\RavenOS\RAH-OS-MODE-SWITCH.cmd"
goto MENU
:WHEEL
start "" "http://127.0.0.1:18765/doctor/RAH-RAVEN-COMMAND-WHEEL.html"
goto MENU
:HEALTH
call "C:\RAH\RavenOS\RAH-OS-OMEN-HEALTHCHECK.cmd"
pause
goto MENU
:GPT
start "" "https://chatgpt.com/"
goto MENU
:EXIT
exit /b 0
