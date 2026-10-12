@echo off
setlocal EnableExtensions
title RAH Doctor + Acceptance

start "" "http://127.0.0.1:18765/doctor/ui"

if exist "C:\RAH\RavenOS\state\RAH-OS-ACCEPTANCE.json" (
  start "" explorer.exe /select,"C:\RAH\RavenOS\state\RAH-OS-ACCEPTANCE.json"
) else (
  if exist "C:\RAH\RavenOS\state" (
    start "" explorer.exe "C:\RAH\RavenOS\state"
  ) else (
    echo RAH-OS-ACCEPTANCE.json er ikke laget enna.
    echo Kjor ACCEPT-RAH-OS-v0.6.cmd forst.
    pause
  )
)
exit /b 0
