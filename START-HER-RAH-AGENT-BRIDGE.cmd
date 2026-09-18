@echo off
setlocal EnableExtensions
title RAH AGENT BRIDGE v1

if not defined RAH_AGENT_INSTALL_URL set "RAH_AGENT_INSTALL_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/INSTALL-RAH-AGENT-BRIDGE.ps1"
set "RAH_MARKER=RahAgentBridgeInstallerVersion = '1.0.0'"
set "RAH_SELF_PATH=%~f0"

if /I "%~1"=="--self-test" goto BOOT
if /I "%~1"=="__RAH_ADMIN__" goto VERIFY_ADMIN

fltmc >nul 2>&1
if "%ERRORLEVEL%"=="0" goto VERIFY_ADMIN

echo [RAH] Administrator kreves. Starter samme fil med UAC automatisk ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Start-Process -FilePath $env:RAH_SELF_PATH -Verb RunAs -ArgumentList '__RAH_ADMIN__'"
if errorlevel 1 goto FAIL_UAC
exit /b 0

:VERIFY_ADMIN
fltmc >nul 2>&1
if errorlevel 1 goto FAIL_NOT_ADMIN
echo [RAH] Administrator: OK

:BOOT
set "RAH_BOOT=%TEMP%\RAH-Agent-Bridge-Bootstrap"
if not exist "%RAH_BOOT%" mkdir "%RAH_BOOT%" >nul 2>&1
if errorlevel 1 goto FAIL_BOOT
set "RAH_SCRIPT=%RAH_BOOT%\INSTALL-RAH-AGENT-BRIDGE.ps1"

echo [RAH] Henter og validerer Agent Bridge installer ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_SCRIPT;Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_AGENT_INSTALL_URL -OutFile $p;$i=Get-Item -LiteralPath $p;if($i.Length -le 0 -or $i.Length -gt 4194304){throw 'Ugyldig installer-fil.'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);if(-not $s.Contains($env:RAH_MARKER)){throw 'Manglende Agent Bridge v1-markor.'}"
if errorlevel 1 goto FAIL_DOWNLOAD

if /I "%~1"=="--self-test" (
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -SelfTest
  if errorlevel 1 goto FAIL_SELFTEST
  echo [RAH] Agent Bridge CMD bootstrap self-test PASS.
  exit /b 0
)

echo [RAH] Installerer/reparerer RAH Agent Bridge v1 ...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -InstallRoot "C:\RAH\AgentBridge" -BusRoot "C:\RAH\AgentBus"
set "RAH_EXIT=%ERRORLEVEL%"
echo.
if "%RAH_EXIT%"=="0" (
  echo =============================================================
  echo RAH AGENT BRIDGE: PASS
  echo Health: http://127.0.0.1:18781/health
  echo Bus: C:\RAH\AgentBus
  echo =============================================================
) else (
  echo =============================================================
  echo RAH AGENT BRIDGE: FAIL - kode %RAH_EXIT%
  echo Se C:\RAH\AgentBridge\logs
  echo =============================================================
)
pause
exit /b %RAH_EXIT%

:FAIL_UAC
echo [RAH] FAIL: UAC ble avbrutt eller kunne ikke startes.
pause
exit /b 18

:FAIL_NOT_ADMIN
echo [RAH] FAIL: prosessen er ikke Administrator etter UAC.
pause
exit /b 19

:FAIL_BOOT
echo [RAH] FAIL: kunne ikke opprette bootstrap-mappen.
pause
exit /b 20

:FAIL_DOWNLOAD
echo [RAH] FAIL: installer kunne ikke lastes ned eller valideres.
pause
exit /b 21

:FAIL_SELFTEST
echo [RAH] FAIL: Agent Bridge self-test feilet.
exit /b 22
