@echo off
setlocal EnableExtensions EnableDelayedExpansion
title RAH AI Studios Candidate.4 - HOVED-PC Acceptance

rem ============================================================================
rem RAH AI STUDIOS CANDIDATE.4 - HOVED-PC ACCEPTANCE v1.0
rem PRECHECK -> UPDATE -> START -> POSTCHECK -> FINAL
rem No USB, partition, BIOS or disk-layout changes.
rem ============================================================================
set "RAW=https://raw.githubusercontent.com/NilsRa73/rah-platform/main"
set "UPDATER_NAME=UPDATE-RAH-RAVEN.ps1"
set "ENTRY_NAME=START-HER-RAH-AI-STUDIOS-V3.1-CANDIDATE.cmd"
set "HEALTH=http://127.0.0.1:18765/health"
set "STATUS=http://127.0.0.1:18765/apps/status"
set "TMP_HEALTH=%TEMP%\rah-studio-c4-health-%RANDOM%.json"
set "TMP_STATUS=%TEMP%\rah-studio-c4-status-%RANDOM%.json"
set "RUN_LOG=%TEMP%\rah-studio-c4-acceptance-%RANDOM%.log"

call :resolve_root
if not defined RAH_ROOT goto :fail_root
cd /d "%RAH_ROOT%"

echo.
echo ============================================================
echo  RAH AI STUDIOS CANDIDATE.4 - HOVED-PC ACCEPTANCE
echo ============================================================
echo  Root: %RAH_ROOT%
echo  Ingen USB-, partisjons-, BIOS- eller diskendringer.
echo.

echo [PRECHECK]
where curl.exe >nul 2>nul || goto :fail_curl
where powershell.exe >nul 2>nul || goto :fail_powershell
echo PASS     curl.exe
echo PASS     powershell.exe
if exist "%ENTRY_NAME%" (
  echo PASS     Candidate.4 entrypoint exists
) else (
  echo REPAIR   Candidate.4 entrypoint missing; updater will restore it
)

echo.
echo [UPDATE]
curl.exe -fsSL --retry 3 --connect-timeout 10 --max-time 60 "%RAW%/%UPDATER_NAME%" -o "%UPDATER_NAME%.acceptance-download"
if errorlevel 1 goto :fail_update_download
for %%F in ("%UPDATER_NAME%.acceptance-download") do if %%~zF LSS 100 goto :fail_update_download
move /y "%UPDATER_NAME%.acceptance-download" "%UPDATER_NAME%" >nul
if errorlevel 1 goto :fail_update_download
echo PASS     Latest verified updater downloaded from main

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%UPDATER_NAME%" -NoStart >"%RUN_LOG%" 2>&1
set "UPDATE_RC=!ERRORLEVEL!"
if not "!UPDATE_RC!"=="0" goto :fail_update
echo PASS     RAH package update completed

for %%F in (
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json"
  "raven-studio-launch-client.js"
  "RAH-STUDIO-ONE-CLICK.vbs"
  "desktop-bridge\raven_bridge.py"
  "desktop-bridge\app_launcher.py"
  "desktop-bridge\start-studio-bridge-silent.cmd"
  "%ENTRY_NAME%"
) do (
  if not exist "%%~F" (
    echo FAIL     Missing package file: %%~F
    goto :fail_package
  )
)
echo PASS     Candidate.4 runtime files present

echo.
echo [START]
call "%ENTRY_NAME%"
set "START_RC=!ERRORLEVEL!"
if not "!START_RC!"=="0" goto :fail_start
echo PASS     Candidate.4 one-click entrypoint dispatched

echo.
echo [POSTCHECK]
set "BRIDGE_OK=0"
for /L %%G in (1,1,30) do (
  timeout /t 1 /nobreak >nul
  call :fetch_health
  if "!BRIDGE_OK!"=="1" goto :bridge_ready
)
goto :fail_bridge

:bridge_ready
echo PASS     Desktop Bridge ready on 127.0.0.1:18765

call :json_has "%TMP_HEALTH%" ""app_launcher":true"
if errorlevel 1 goto :fail_launcher
echo PASS     App Launcher enabled

call :json_has "%TMP_HEALTH%" ""app_launcher_mode":"fixed-allowlist-explicit-launch""
if errorlevel 1 goto :fail_launcher
echo PASS     App Launcher fixed allowlist

call :json_has "%TMP_HEALTH%" ""agent_runner":true"
if errorlevel 1 goto :fail_agent
echo PASS     Agent Runner loaded

call :json_has "%TMP_HEALTH%" ""agent_runner_mode":"read-only-allowlist""
if errorlevel 1 goto :fail_agent
echo PASS     Agent Runner read-only allowlist

call :json_has "%TMP_HEALTH%" ""anythingllm_approval_gate":true"
if errorlevel 1 goto :fail_anything_gate
echo PASS     AnythingLLM approval gate loaded

set "ANYTHING_CONFIGURED=0"
call :json_has "%TMP_HEALTH%" ""anythingllm_approval_configured":true"
if not errorlevel 1 set "ANYTHING_CONFIGURED=1"

curl.exe -fsS --max-time 3 "%STATUS%" -o "%TMP_STATUS%" >nul 2>nul
if errorlevel 1 goto :fail_status
call :json_has "%TMP_STATUS%" ""world-media""
if errorlevel 1 goto :fail_status
call :json_has "%TMP_STATUS%" ""rah-os""
if errorlevel 1 goto :fail_status
call :json_has "%TMP_STATUS%" ""raven-browser""
if errorlevel 1 goto :fail_status
echo PASS     App status catalog: World Media / RAH OS / Raven Browser

echo.
echo ============================================================
if "!ANYTHING_CONFIGURED!"=="1" (
  echo FINAL: PASS
  echo Candidate.4, Bridge, App Launcher, Agent Runner and
  echo AnythingLLM approval are ready.
  set "FINAL_RC=0"
) else (
  echo FINAL: PENDING
  echo Candidate.4, Bridge, App Launcher and Agent Runner are ready.
  echo AnythingLLM approval exists but needs one-time local configuration.
  set "FINAL_RC=10"
)
echo ============================================================
echo.
echo Studio should now be open and show the same local status.
call :cleanup
pause
exit /b !FINAL_RC!

:fetch_health
set "BRIDGE_OK=0"
del "%TMP_HEALTH%" >nul 2>nul
curl.exe -fsS --max-time 2 "%HEALTH%" -o "%TMP_HEALTH%" >nul 2>nul
if errorlevel 1 exit /b 0
call :json_has "%TMP_HEALTH%" ""ok":true"
if errorlevel 1 exit /b 0
call :json_has "%TMP_HEALTH%" ""name":"RAH Raven Desktop Bridge""
if errorlevel 1 exit /b 0
set "BRIDGE_OK=1"
exit /b 0

:json_has
findstr /I /L /C:%2 %1 >nul 2>nul
exit /b %ERRORLEVEL%

:resolve_root
set "RAH_ROOT="
for %%D in (
  "%~dp0"
  "C:\RAH"
  "%USERPROFILE%\Desktop\RAH AI Studios"
) do (
  if not defined RAH_ROOT if exist "%%~D\RAH-RAVEN-VERSION.json" set "RAH_ROOT=%%~fD"
)
if not defined RAH_ROOT if exist "%~dp0UPDATE-RAH-RAVEN.ps1" set "RAH_ROOT=%~dp0"
exit /b 0

:fail_root
echo.
echo FINAL: FAIL
echo Fant ikke en lokal RAH-mappe.
echo Legg denne filen i RAH-mappen, C:\RAH, eller RAH AI Studios pa skrivebordet.
pause
exit /b 20

:fail_curl
echo FINAL: FAIL
echo curl.exe mangler i Windows PATH.
pause
exit /b 21

:fail_powershell
echo FINAL: FAIL
echo Windows PowerShell mangler. Den brukes kun i den eksplisitte updater-runden.
pause
exit /b 22

:fail_update_download
echo FINAL: FAIL
echo Kunne ikke hente siste updater fra GitHub main.
call :cleanup
pause
exit /b 23

:fail_update
echo FINAL: FAIL
echo RAH updater feilet. Exit=!UPDATE_RC!
echo ---- siste updater-logg ----
type "%RUN_LOG%" 2>nul
echo ---- slutt ----
call :cleanup
pause
exit /b 24

:fail_package
echo FINAL: FAIL
echo Candidate.4-pakken er ufullstendig etter update.
call :cleanup
pause
exit /b 25

:fail_start
echo FINAL: FAIL
echo Candidate.4 entrypoint feilet. Exit=!START_RC!
call :cleanup
pause
exit /b 26

:fail_bridge
echo FINAL: FAIL
echo Raven Bridge svarte ikke som verifisert Raven innen 30 sekunder.
echo Se %%LOCALAPPDATA%%\RAH-Raven\Studio\bridge.err.log
call :cleanup
pause
exit /b 27

:fail_launcher
echo FINAL: FAIL
echo App Launcher mangler eller har feil sikkerhetsmodus.
call :cleanup
pause
exit /b 28

:fail_agent
echo FINAL: FAIL
echo Agent Runner mangler eller er ikke read-only allowlist.
call :cleanup
pause
exit /b 29

:fail_anything_gate
echo FINAL: FAIL
echo AnythingLLM approval gate mangler i Bridge.
call :cleanup
pause
exit /b 30

:fail_status
echo FINAL: FAIL
echo App-statusendepunktet mangler forventede allowlist-apper.
call :cleanup
pause
exit /b 31

:cleanup
del "%TMP_HEALTH%" >nul 2>nul
del "%TMP_STATUS%" >nul 2>nul
exit /b 0
