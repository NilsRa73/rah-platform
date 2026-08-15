@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Node Agent
echo.
echo  RAH NODE AGENT - READ ONLY ACTION CATALOG
echo  ============================================
echo  Starter /health og /actions paa lokalnett, port 18766.
echo  /storage finnes bare med --capability storage.
echo  Ingen generisk action, shell, filer, kommandoer eller fjernstyring.
echo  Valgfritt: legg til --capability compute --capability storage
echo  Tillatt: compute, storage, display, remote-desktop
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
