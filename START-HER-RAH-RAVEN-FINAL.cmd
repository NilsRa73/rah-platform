@echo off
setlocal EnableExtensions
title RAH RAVEN FINAL - AUTO READY

set "RAH_SELF_PATH=%~f0"
set "RAH_FINAL_NAME=RAH-RAVEN-HOVED-PC-FINAL.ps1"
set "RAH_LATEST=C:\RAH\Logs\RAVEN-HOVED-PC-FINAL-LATEST.json"
set "RAH_RUN_LOG=%TEMP%\RAH-RAVEN-FINAL-LAST.log"

rem Canonical flow: PRECHECK > REPAIR > AI SELFTEST > AGENT TEAM LIVE > SYSTEM-INVENTORY > POSTCHECK.
if /I "%~1"=="--self-test" goto PREPARE
if /I "%~1"=="__RAH_ADMIN__" goto PREPARE

fltmc >nul 2>&1
if "%ERRORLEVEL%"=="0" goto PREPARE
echo [RAH] Ber om Administrator en gang...
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Start-Process -FilePath $env:RAH_SELF_PATH -Verb RunAs -ArgumentList '__RAH_ADMIN__'"
if errorlevel 1 goto FAIL_UAC
exit /b 0

:PREPARE
set "RAH_SOURCE=%~dp0"
if exist "%~dp0%RAH_FINAL_NAME%" if exist "%~dp0RAH-AI-CHAT-RECOVERY.ps1" if exist "%~dp0INSTALL-RAH-AI-FABRIC.ps1" goto VALIDATE

echo [RAH] Henter siste validerte RAH main-pakke...
set "RAH_BOOT=%TEMP%\RAH-Raven-Final-Bootstrap"
set "RAH_ZIP=%RAH_BOOT%\rah-main.zip"
set "RAH_STAGE=%RAH_BOOT%\stage"
set "RAH_SOURCE_FILE=%RAH_BOOT%\source.txt"
if exist "%RAH_BOOT%" rmdir /s /q "%RAH_BOOT%" >nul 2>&1
mkdir "%RAH_STAGE%" >nul 2>&1
if errorlevel 1 goto FAIL_BOOT

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/NilsRa73/rah-platform/archive/refs/heads/main.zip' -OutFile $env:RAH_ZIP -TimeoutSec 90;Expand-Archive -LiteralPath $env:RAH_ZIP -DestinationPath $env:RAH_STAGE -Force;$d=Get-ChildItem -LiteralPath $env:RAH_STAGE -Directory|Select-Object -First 1;if(-not$d){throw 'RAH archive missing project directory'};[IO.File]::WriteAllText($env:RAH_SOURCE_FILE,$d.FullName)"
if errorlevel 1 goto FAIL_DOWNLOAD
set /p RAH_SOURCE=<"%RAH_SOURCE_FILE%"
if not defined RAH_SOURCE goto FAIL_DOWNLOAD
set "RAH_SOURCE=%RAH_SOURCE%\"

:VALIDATE
set "RAH_FINAL_PS1=%RAH_SOURCE%%RAH_FINAL_NAME%"
if not exist "%RAH_FINAL_PS1%" goto FAIL_PACKAGE
if not exist "%RAH_SOURCE%RAH-AI-CHAT-RECOVERY.ps1" goto FAIL_PACKAGE
if not exist "%RAH_SOURCE%INSTALL-RAH-AI-FABRIC.ps1" goto FAIL_PACKAGE
if not exist "%RAH_SOURCE%INSTALL-RAH-AGENT-BRIDGE.ps1" goto FAIL_PACKAGE
if not exist "%RAH_SOURCE%INSTALL-RAH-AGENT-WORKER.ps1" goto FAIL_PACKAGE

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_FINAL_PS1;$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);foreach($m in @('RahRavenFinalVersion = ''2.0.0''','AI Fabric repair','Autonomous AI repair/self-test','system-inventory','C:\RAH\AI-Fabric\rah-platform')){if(-not$s.Contains($m)){throw ('Missing FINAL marker: '+$m)}}"
if errorlevel 1 goto FAIL_PACKAGE

if /I "%~1"=="--self-test" (
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_FINAL_PS1%" -SelfTest
  if errorlevel 1 goto FAIL_SELFTEST
  echo RAH RAVEN FINAL SELFTEST: PASS
  exit /b 0
)

echo.
echo ================================================
echo  RAH RAVEN - AUTO REPAIR / AUTO SELFTEST
echo  Vent. Ingen rapportlesing er nodvendig.
echo ================================================
echo.

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_FINAL_PS1%" >"%RAH_RUN_LOG%" 2>&1
set "RAH_RC=%ERRORLEVEL%"

echo.
if "%RAH_RC%"=="0" (
  echo ================================================
  echo  RAH RAVEN: READY
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try{$j=Get-Content -LiteralPath 'C:\RAH\Logs\RAVEN-HOVED-PC-FINAL-LATEST.json' -Raw|ConvertFrom-Json;if($j.winner_provider){Write-Host ('  AI: '+$j.winner_provider+' / '+$j.winner_model)}}catch{}"
  echo ================================================
  pause
  exit /b 0
)

echo ================================================
echo  RAH RAVEN: FAIL AFTER AUTO-REPAIR
echo  Systemet har allerede provd repair, fallback,
echo  restart, AI-selftest og ny LIVE-test selv.
echo ================================================
pause
exit /b %RAH_RC%

:FAIL_UAC
echo RAH RAVEN: UAC FAIL
pause
exit /b 18

:FAIL_BOOT
echo RAH RAVEN: BOOTSTRAP FAIL
pause
exit /b 20

:FAIL_DOWNLOAD
echo RAH RAVEN: DOWNLOAD/EXTRACT FAIL
pause
exit /b 21

:FAIL_PACKAGE
echo RAH RAVEN: PACKAGE VALIDATION FAIL
pause
exit /b 22

:FAIL_SELFTEST
echo RAH RAVEN FINAL SELFTEST: FAIL
exit /b 23
