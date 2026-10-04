@echo off
setlocal EnableExtensions
title RAH OS - MODE SWITCH
:MENU
cls
echo ============================================================
echo                 RAH OS MODE SWITCH
echo ============================================================
echo [1] CONTROLLER MODE - Command Wheel fullscreen
echo [2] DESKTOP MODE    - Windows desktop / Explorer
echo [3] CHATGPT
echo [4] RAVEN DOCTOR
echo [5] LOCAL AI
echo [0] EXIT
choice /C 123450 /N /M "Velg: "
if errorlevel 6 exit /b 0
if errorlevel 5 goto LOCAL
if errorlevel 4 goto DOCTOR
if errorlevel 3 goto GPT
if errorlevel 2 goto DESKTOP
if errorlevel 1 goto CONTROLLER
:CONTROLLER
if exist "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" (
 start "" "%ProgramFiles(x86)%\Microsoft\Edge\Application\msedge.exe" --kiosk "http://127.0.0.1:18765/doctor/RAH-RAVEN-COMMAND-WHEEL.html" --edge-kiosk-type=fullscreen
) else if exist "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" (
 start "" "%ProgramFiles%\Microsoft\Edge\Application\msedge.exe" --kiosk "http://127.0.0.1:18765/doctor/RAH-RAVEN-COMMAND-WHEEL.html" --edge-kiosk-type=fullscreen
) else (
 start "" "http://127.0.0.1:18765/doctor/RAH-RAVEN-COMMAND-WHEEL.html"
)
goto MENU
:DESKTOP
start "" explorer.exe shell:desktop
goto MENU
:GPT
start "" "https://chatgpt.com/"
goto MENU
:DOCTOR
start "" "http://127.0.0.1:18765/doctor/"
goto MENU
:LOCAL
start "" "http://127.0.0.1:1234/v1/models"
goto MENU
