@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Node Agent
echo.
echo  RAH NODE AGENT - READ ONLY CAPABILITIES
echo  ========================================
echo  Starter kun /health paa lokalnett, port 18766.
echo  Ingen shell, filer, kommandoer eller fjernstyring.
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
