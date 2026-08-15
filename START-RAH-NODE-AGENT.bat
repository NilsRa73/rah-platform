@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Node Agent
echo.
echo  RAH NODE AGENT - FIXED ACTION AND APP ALLOWLIST
echo  ================================================
echo  Starter /health og /actions paa lokalnett, port 18766.
echo  /storage finnes bare med --capability storage.
echo  /launch/rustdesk annonseres bare med --capability remote-desktop og lokal RustDesk.
echo  RustDesk-launch tar ingen path, argumenter eller request body.
echo  Ingen generisk process/action, installasjon, shell, filer, kommandoer eller fjernstyring.
echo  Eksempel: --capability storage --capability remote-desktop
echo  Tillatt capability: compute, storage, display, remote-desktop
echo.
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0rah-node-agent.py" --allow-lan %*
  goto :done
)
where python >nul 2>nul
if not errorlevel 1 (
  python "%~dp0rah-node-agent.py" --allow-lan %*
  goto :done
)
echo FEIL: Python 3 ble ikke funnet.
pause
exit /b 1
:done
if errorlevel 1 pause
