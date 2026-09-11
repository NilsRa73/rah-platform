@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Node Agent 1.4 Stable
echo.
echo  RAH NODE AGENT v1.4 STABLE - RAVEN STATUS + TOKEN-PROOF
echo  ============================================================
echo  Starter Node Agent paa lokalnett, port 18766.
echo  Eksisterende authority: 4 capabilities, 3 actions, 5 gamle business routes.
echo  Ny fast read-only route: GET /raven/status.
echo  Raven-status kan bare kjoere system-inventory via 127.0.0.1:18765.
echo  Fresh token vises lokalt, men sendes aldri som Bearer over LAN.
echo  Beskyttede requests bruker source-bound single-use nonce + HMAC-SHA256 proof.
echo  Ingen arbitrary shell, sti, argumenter, generisk process/action eller file API.
echo.
set "RAW=https://raw.githubusercontent.com/NilsRa73/rah-platform/main"
set "NODE_AGENT=%~dp0rah-node-agent-v1.4.py"
set "NODE_CANDIDATE=%~dp0rah-node-agent-v1.4-candidate.py"

for %%F in (rah-node-agent-v1.4.py rah-node-agent-v1.4-candidate.py) do (
  if not exist "%~dp0%%F" (
    echo  Mangler %%F - henter fast Stable 1.4 runtime fra canonical main...
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $u='%RAW%/%%F'; $t='%~dp0%%F.rah-download'; Invoke-WebRequest -UseBasicParsing -Uri $u -OutFile $t; if((Get-Item -LiteralPath $t).Length -lt 1){throw 'Tom nedlasting'}; Move-Item -LiteralPath $t -Destination '%~dp0%%F' -Force"
    if errorlevel 1 goto :repair_failed
  )
)

if not exist "%NODE_AGENT%" goto :missing
if not exist "%NODE_CANDIDATE%" goto :missing
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
:repair_failed
echo FEIL: Kunne ikke hente de faste Node 1.4 runtime-filene.
echo Ingen alternativ kode eller dynamisk script ble kjoert.
pause
exit /b 2
:missing
echo FEIL: Stable Node 1.4 runtime mangler etter repair.
pause
exit /b 1
:done
if errorlevel 1 pause
