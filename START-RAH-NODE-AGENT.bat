@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Node Agent 1.3 Stable
echo.
echo  RAH NODE AGENT v1.3 STABLE - TOKEN-PROOF + FIXED ALLOWLIST
echo  =============================================================
echo  Starter Node Agent paa lokalnett, port 18766.
echo  Fast authority: 4 capabilities, 3 actions, 5 business routes.
echo  Fresh token vises lokalt, men sendes aldri som Bearer over LAN.
echo  Beskyttede requests bruker source-bound single-use nonce + HMAC-SHA256 proof.
echo  Muterende actions krever fortsatt ephemeral CC approval, Node-local bekreftelse,
echo  requester-source/context, action challenge og Node-local approval proof.
echo  Ingen shell, generic process/action, filer, installasjon eller native fjernstyring.
echo  Eksempel: --capability storage --capability remote-desktop
echo.
set "NODE_AGENT=%~dp0rah-node-agent-v1.3.py"
if not exist "%NODE_AGENT%" goto :missing
where py >nul 2>nul
if not errorlevel 1 (
  py -3 "%NODE_AGENT%" --allow-lan %*
  goto :done
)
where python >nul 2>nul
if not errorlevel 1 (
  python "%NODE_AGENT%" --allow-lan %*
  goto :done
)
echo FEIL: Python 3 ble ikke funnet.
pause
exit /b 1
:missing
echo FEIL: rah-node-agent-v1.3.py mangler. Kjoer UPDATE-RAH-RAVEN.ps1 for eldre installasjon,
echo eller den nye UPDATE-RAH-COMMAND-CENTER.ps1 for v1.9-pakken.
pause
exit /b 1
:done
if errorlevel 1 pause
