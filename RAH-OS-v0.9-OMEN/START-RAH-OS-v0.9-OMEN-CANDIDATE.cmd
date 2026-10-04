@echo off
setlocal EnableExtensions
title RAH OS v0.9 - OMEN CANDIDATE
set "ROOT=C:\RAH\RavenOS"
set "BASE=%~dp0"
fltmc >nul 2>nul
if errorlevel 1 (
  echo [RAH] Ber om Administrator-tilgang...
  powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
  exit /b
)
if not exist "%ROOT%" mkdir "%ROOT%" >nul 2>&1
if not exist "%ROOT%\state" mkdir "%ROOT%\state" >nul 2>&1
if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1
echo.
echo ============================================================
echo        RAH OS v0.9 - OMEN REFERENCE MACHINE
echo ============================================================
copy /Y "%BASE%RAH-OS-OMEN-HEALTHCHECK.cmd" "%ROOT%\RAH-OS-OMEN-HEALTHCHECK.cmd" >nul
copy /Y "%BASE%RAH-OS-MODE-SWITCH.cmd" "%ROOT%\RAH-OS-MODE-SWITCH.cmd" >nul
copy /Y "%BASE%RAH-OS-START-HERE.cmd" "%ROOT%\RAH-OS-START-HERE.cmd" >nul
call "%ROOT%\RAH-OS-OMEN-HEALTHCHECK.cmd"
set "HC=%ERRORLEVEL%"
set "DESK=%PUBLIC%\Desktop"
if not exist "%DESK%" set "DESK=%USERPROFILE%\Desktop"
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ws=New-Object -ComObject WScript.Shell;$s=$ws.CreateShortcut('%DESK%\RAH OS START HERE.lnk');$s.TargetPath='C:\RAH\RavenOS\RAH-OS-START-HERE.cmd';$s.WorkingDirectory='C:\RAH\RavenOS';$s.Description='RAH OS - Omen Reference Machine';$s.Save()" >nul 2>&1
echo.
if exist "%ROOT%\RAH-OS-v0.8-FINALIZE.ps1" (
  echo [RAH] Fant eksisterende v0.8 finalizer. Lar den ligge urort.
) else (
  echo [RAH] v0.8 finalizer er ikke lokal enna. Dette er OK for kandidatpakken.
)
echo.
if "%HC%"=="0" (echo RAH OS v0.9 OMEN: READY FOR HUMAN TEST) else (echo RAH OS v0.9 OMEN: READY WITH WARNINGS)
start "" "http://127.0.0.1:18765/doctor/RAH-RAVEN-COMMAND-WHEEL.html"
pause
exit /b %HC%
