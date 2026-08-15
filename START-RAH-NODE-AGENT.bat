@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Node Agent
echo.
echo  RAH NODE AGENT - FIXED ACTION, APP AND HANDOFF ALLOWLIST
echo  =======================================================
echo  Starter /health og /actions paa lokalnett, port 18766.
echo  /storage finnes bare med --capability storage.
echo  /launch/rustdesk og /handoff/rustdesk annonseres bare med --capability remote-desktop og lokal RustDesk.
echo  Handoff tar kun validert RustDesk peerId. Ingen password, path, server, key eller frie argumenter.
echo  Ingen generisk process/action, installasjon, shell, filer, kommandoer eller native fjernstyring.
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
