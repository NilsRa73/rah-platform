@echo off
setlocal
title RAH OS - START HERE
cls
echo ============================================================
echo                    RAH OS START HERE
echo ============================================================
echo [1] MODE SWITCH
echo [2] RAVEN COMMAND WHEEL
echo [3] OMEN HEALTHCHECK
echo [4] CHATGPT
echo [5] EXIT
choice /C 12345 /N /M "Velg: "
if errorlevel 5 exit /b 0
if errorlevel 4 start "" "https://chatgpt.com/" & exit /b 0
if errorlevel 3 call "C:\RAH\RavenOS\RAH-OS-OMEN-HEALTHCHECK.cmd" & pause & exit /b 0
if errorlevel 2 start "" "http://127.0.0.1:18765/doctor/RAH-RAVEN-COMMAND-WHEEL.html" & exit /b 0
if errorlevel 1 call "C:\RAH\RavenOS\RAH-OS-MODE-SWITCH.cmd" & exit /b 0
