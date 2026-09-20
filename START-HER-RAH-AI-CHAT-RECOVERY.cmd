@echo off
setlocal EnableExtensions
title RAH AI CHAT RECOVERY v1.2 AUTO SELFTEST

if not defined RAH_RECOVERY_URL set "RAH_RECOVERY_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-AI-CHAT-RECOVERY.ps1"
set "RAH_MARKER=RahAiChatRecoveryVersion = '1.2.0'"
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
set "RAH_BOOT=%TEMP%\RAH-AI-Chat-Recovery-Bootstrap"
if not exist "%RAH_BOOT%" mkdir "%RAH_BOOT%" >nul 2>&1
if errorlevel 1 goto FAIL_BOOT
set "RAH_SCRIPT=%RAH_BOOT%\RAH-AI-CHAT-RECOVERY.ps1"

echo [RAH] Henter og validerer AI Chat Recovery ...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$p=$env:RAH_SCRIPT;Invoke-WebRequest -UseBasicParsing -Uri $env:RAH_RECOVERY_URL -OutFile $p;$i=Get-Item -LiteralPath $p;if($i.Length -le 0 -or $i.Length -gt 4194304){throw 'Ugyldig recovery-fil.'};$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($p,[ref]$t,[ref]$e)|Out-Null;if(@($e).Count){throw $e[0].Message};$s=[IO.File]::ReadAllText($p);if(-not $s.Contains($env:RAH_MARKER)){throw 'Manglende AI Chat Recovery v1-markor.'}"
if errorlevel 1 goto FAIL_DOWNLOAD

if /I "%~1"=="--self-test" (
  if defined RAH_RECOVERY_SOURCE_DIR (
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -SelfTest -SourceDirectory "%RAH_RECOVERY_SOURCE_DIR%"
  ) else (
    powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -SelfTest
  )
  if errorlevel 1 goto FAIL_SELFTEST
  echo [RAH] AI Chat Recovery bootstrap self-test PASS.
  exit /b 0
)

echo.
echo =============================================================
echo RAH AI CHAT RECOVERY
echo - backup eksisterende AI Fabric
echo - installer validert v1.3.1 runtime + Worker trace
echo - restart Raven Bridge
echo - autonom AI selftest + auto-repair + Agent Team LIVE
echo =============================================================
echo.

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_SCRIPT%" -RuntimeRoot "C:\RAH\AI-Fabric\rah-platform"
set "RAH_EXIT=%ERRORLEVEL%"

echo.
if "%RAH_EXIT%"=="0" (
  echo =============================================================
  echo RAH AUTO SELFTEST: FULL PASS
  echo =============================================================
) else (
  echo =============================================================
  echo RAH AI CHAT RECOVERY: FAIL - kode %RAH_EXIT%
  echo Recovery: C:\RAH\AI-Fabric\Recovery\RAH-AI-CHAT-RECOVERY.txt
  echo Live    : C:\RAH\AgentWorker\reports\RAH-AGENT-TEAM-LIVE.txt
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
echo [RAH] FAIL: bootstrap-mappen kunne ikke opprettes.
pause
exit /b 20

:FAIL_DOWNLOAD
echo [RAH] FAIL: AI Chat Recovery kunne ikke lastes eller valideres.
pause
exit /b 21

:FAIL_SELFTEST
echo [RAH] FAIL: AI Chat Recovery self-test feilet.
exit /b 22
