@echo off
setlocal EnableExtensions
title RAH AGENT TEAM v1

if not defined RAH_BRIDGE_INSTALL_URL set "RAH_BRIDGE_INSTALL_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/INSTALL-RAH-AGENT-BRIDGE.ps1"
if not defined RAH_WORKER_INSTALL_URL set "RAH_WORKER_INSTALL_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/INSTALL-RAH-AGENT-WORKER.ps1"
if not defined RAH_TEAM_ACCEPT_URL set "RAH_TEAM_ACCEPT_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-AGENT-TEAM-ACCEPTANCE.ps1"
set "RAH_BRIDGE_MARKER=RahAgentBridgeInstallerVersion = '1.0.0'"
set "RAH_WORKER_MARKER=RahAgentWorkerInstallerVersion = '1.0.0'"
set "RAH_ACCEPT_MARKER=RahAgentTeamAcceptanceVersion='1.0.0'"
set "RAH_SELF_PATH=%~f0"

if /I "%~1"=="--self-test" goto BOOT
if /I "%~1"=="__RAH_ADMIN__" goto VERIFY_ADMIN

fltmc >nul 2>&1
if "%ERRORLEVEL%"=="0" goto VERIFY_ADMIN
echo [RAH] Administrator kreves for install/reparer. Starter UAC automatisk ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Start-Process -FilePath $env:RAH_SELF_PATH -Verb RunAs -ArgumentList '__RAH_ADMIN__'"
if errorlevel 1 goto FAIL_UAC
exit /b 0

:VERIFY_ADMIN
fltmc >nul 2>&1
if errorlevel 1 goto FAIL_NOT_ADMIN
echo [RAH] Administrator: OK

:BOOT
set "RAH_BOOT=%TEMP%\RAH-Agent-Team-Bootstrap"
if not exist "%RAH_BOOT%" mkdir "%RAH_BOOT%" >nul 2>&1
if errorlevel 1 goto FAIL_BOOT
set "RAH_BRIDGE=%RAH_BOOT%\INSTALL-RAH-AGENT-BRIDGE.ps1"
set "RAH_WORKER=%RAH_BOOT%\INSTALL-RAH-AGENT-WORKER.ps1"
set "RAH_ACCEPT=%RAH_BOOT%\RAH-AGENT-TEAM-ACCEPTANCE.ps1"

echo [RAH] Henter og validerer Agent Team-komponenter ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$items=@(@($env:RAH_BRIDGE_INSTALL_URL,$env:RAH_BRIDGE,$env:RAH_BRIDGE_MARKER),@($env:RAH_WORKER_INSTALL_URL,$env:RAH_WORKER,$env:RAH_WORKER_MARKER),@($env:RAH_TEAM_ACCEPT_URL,$env:RAH_ACCEPT,$env:RAH_ACCEPT_MARKER));foreach($x in $items){Invoke-WebRequest -UseBasicParsing -Uri $x[0] -OutFile $x[1];$i=Get-Item $x[1];if($i.Length -le 0 -or $i.Length -gt 4194304){throw 'Ugyldig komponentfil'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($x[1],[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($x[1]);if(-not$s.Contains($x[2])){throw ('Manglende markor: '+$x[2])}}"
if errorlevel 1 goto FAIL_DOWNLOAD

if /I "%~1"=="--self-test" (
  if defined RAH_AGENT_SOURCE_DIR (
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_BRIDGE%" -SelfTest -SourceDirectory "%RAH_AGENT_SOURCE_DIR%"
    if errorlevel 1 goto FAIL_SELFTEST
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_WORKER%" -SelfTest -SourceDirectory "%RAH_AGENT_SOURCE_DIR%"
  ) else (
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_BRIDGE%" -SelfTest
    if errorlevel 1 goto FAIL_SELFTEST
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_WORKER%" -SelfTest
  )
  if errorlevel 1 goto FAIL_SELFTEST
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_ACCEPT%" -SelfTest
  if errorlevel 1 goto FAIL_SELFTEST
  echo [RAH] Agent Team bootstrap self-test PASS.
  exit /b 0
)

echo.
echo [1/3] Agent Bridge install/repair ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_BRIDGE%" -InstallRoot "C:\RAH\AgentBridge" -BusRoot "C:\RAH\AgentBus"
if errorlevel 1 goto FAIL_RUNTIME

echo.
echo [2/3] Agent Worker install/repair ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_WORKER%" -InstallRoot "C:\RAH\AgentWorker" -BridgeRoot "C:\RAH\AgentBridge"
if errorlevel 1 goto FAIL_RUNTIME

echo.
echo [3/3] Agent Team acceptance ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_ACCEPT%" -BridgeRoot "C:\RAH\AgentBridge" -WorkerRoot "C:\RAH\AgentWorker" -BusRoot "C:\RAH\AgentBus"
if errorlevel 1 goto FAIL_RUNTIME

echo.
echo =============================================================
echo RAH AGENT TEAM v1: PASS / READY
echo Rapport: C:\RAH\AgentWorker\reports\RAH-AGENT-TEAM-ACCEPTANCE.txt
echo Bus: C:\RAH\AgentBus
echo =============================================================
pause
exit /b 0

:FAIL_UAC
echo [RAH] FAIL: UAC ble avbrutt eller kunne ikke startes.
pause
exit /b 18
:FAIL_NOT_ADMIN
echo [RAH] FAIL: prosessen er ikke Administrator etter UAC.
pause
exit /b 19
:FAIL_BOOT
echo [RAH] FAIL: bootstrap-mappen kunne ikke opprettes.
pause
exit /b 20
:FAIL_DOWNLOAD
echo [RAH] FAIL: Agent Team-komponenter kunne ikke lastes/valideres.
pause
exit /b 21
:FAIL_SELFTEST
echo [RAH] FAIL: Agent Team self-test feilet.
exit /b 22
:FAIL_RUNTIME
echo [RAH] FAIL: Agent Team install/acceptance feilet.
echo Se C:\RAH\AgentWorker\support og reports.
pause
exit /b 23