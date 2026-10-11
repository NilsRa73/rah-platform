@echo off
setlocal EnableExtensions EnableDelayedExpansion
title RAH AI Studios Candidate.4 - HOVED-PC Acceptance v1.2 VPN-Tolerant

rem ============================================================================
rem RAH AI STUDIOS CANDIDATE.4 - HOVED-PC ACCEPTANCE v1.2
rem VPN-TOLERANT + FULL READINESS + SAFE BRIDGE REPAIR
rem PRECHECK -> UPDATE/FALLBACK -> START -> FULL READINESS -> FINAL
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
set "UPDATE_PENDING=0"

call :resolve_root
if not defined RAH_ROOT goto :fail_root
cd /d "%RAH_ROOT%"

echo.
echo ============================================================
echo  RAH AI STUDIOS CANDIDATE.4 - HOVED-PC ACCEPTANCE v1.2
echo ============================================================
echo  Root: %RAH_ROOT%
echo  VPN-tolerant update/fallback + full Candidate.4 readiness.
echo  Ingen USB-, partisjons-, BIOS- eller diskendringer.
echo.

echo [PRECHECK]
where curl.exe >nul 2>nul || goto :fail_curl
where powershell.exe >nul 2>nul || goto :fail_powershell
echo PASS     curl.exe
echo PASS     powershell.exe
call :local_package_ready
if "!LOCAL_READY!"=="1" (
  echo PASS     Local Candidate.4 runtime package present
) else (
  echo REPAIR   Local Candidate.4 package is incomplete
)

echo.
echo [UPDATE]
echo Tester GitHub main...
del "%UPDATER_NAME%.acceptance-download" >nul 2>nul
curl.exe -fsSL --retry 2 --retry-delay 2 --connect-timeout 8 --max-time 35 "%RAW%/%UPDATER_NAME%" -o "%UPDATER_NAME%.acceptance-download" >nul 2>nul
if errorlevel 1 goto :vpn_fallback
for %%F in ("%UPDATER_NAME%.acceptance-download") do if %%~zF LSS 100 goto :vpn_fallback
move /y "%UPDATER_NAME%.acceptance-download" "%UPDATER_NAME%" >nul
if errorlevel 1 goto :vpn_fallback
echo PASS     Latest updater downloaded from GitHub main

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%UPDATER_NAME%" -NoStart >"%RUN_LOG%" 2>&1
set "UPDATE_RC=!ERRORLEVEL!"
if "!UPDATE_RC!"=="0" (
  echo PASS     RAH package update completed
  goto :after_update
)

echo WARN     Online updater failed. VPN/proxy/network can cause this.
call :local_package_ready
if "!LOCAL_READY!"=="1" (
  echo PENDING  Continuing with complete local Candidate.4 package.
  set "UPDATE_PENDING=1"
  goto :after_update
)
goto :fail_update

:vpn_fallback
del "%UPDATER_NAME%.acceptance-download" >nul 2>nul
echo WARN     GitHub main could not be reached.
echo WARN     VPN/proxy/DNS can cause this.
call :local_package_ready
if "!LOCAL_READY!"=="1" (
  echo PENDING  Local Candidate.4 package is complete; continuing offline.
  set "UPDATE_PENDING=1"
  goto :after_update
)
goto :fail_vpn_package

:after_update
call :local_package_ready
if not "!LOCAL_READY!"=="1" goto :fail_package
echo PASS     Candidate.4 runtime files present

echo.
echo [START]
call "%ENTRY_NAME%"
set "START_RC=!ERRORLEVEL!"
if not "!START_RC!"=="0" goto :fail_start
echo PASS     Candidate.4 one-click entrypoint dispatched

echo.
echo [POSTCHECK]
echo Venter pa full Candidate.4 readiness, ikke bare at port 18765 svarer...
set "CANDIDATE_READY=0"
for /L %%G in (1,1,45) do (
  timeout /t 1 /nobreak >nul
  call :local_package_ready
set "LOCAL_READY=1"
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
  if not exist "%%~F" set "LOCAL_READY=0"
)
exit /b 0

:fetch_candidate_ready
  if "!CANDIDATE_READY!"=="1" goto :candidate_ready
)

echo REPAIR   Full Candidate.4 readiness kom ikke innen 45 sekunder.
echo REPAIR   Kjorer den skjulte Bridge-bootstrapen direkte og venter en gang til.
call "desktop-bridge\start-studio-bridge-silent.cmd"
set "REPAIR_RC=!ERRORLEVEL!"
if not "!REPAIR_RC!"=="0" goto :fail_bridge_repair

for /L %%G in (1,1,30) do (
  timeout /t 1 /nobreak >nul
  call :fetch_candidate_ready
  if "!CANDIDATE_READY!"=="1" goto :candidate_ready
)
goto :fail_bridge

:candidate_ready
echo PASS     Desktop Bridge ready on 127.0.0.1:18765
echo PASS     App Launcher enabled
echo PASS     App Launcher fixed allowlist
echo PASS     Agent Runner loaded
echo PASS     Agent Runner read-only allowlist
echo PASS     AnythingLLM approval gate loaded
echo PASS     App status catalog: World Media / RAH OS / Raven Browser

set "ANYTHING_CONFIGURED=0"
call :json_bool "%TMP_HEALTH%" "anythingllm_approval_configured" "True"
if not errorlevel 1 set "ANYTHING_CONFIGURED=1"

if "!UPDATE_PENDING!"=="1" goto :final_pending_update
if "!ANYTHING_CONFIGURED!"=="1" goto :final_pass
goto :final_pending_anything

:final_pass
echo.
echo ============================================================
echo FINAL: PASS
echo Candidate.4, Bridge, App Launcher, Agent Runner and
echo AnythingLLM approval are ready.
echo ============================================================
set "FINAL_RC=0"
goto :final_end

:final_pending_update
echo.
echo ============================================================
echo FINAL: PENDING
echo Core Candidate.4 acceptance passed locally.
echo Online update was skipped/failed, likely VPN/proxy/network.
if "!ANYTHING_CONFIGURED!"=="1" (
  echo AnythingLLM approval is configured.
) else (
  echo AnythingLLM approval also needs one-time local configuration.
)
echo Turn VPN off later and run this same file once more.
echo ============================================================
set "FINAL_RC=11"
goto :final_end

:final_pending_anything
echo.
echo ============================================================
echo FINAL: PENDING
echo Candidate.4, Bridge, App Launcher and Agent Runner are ready.
echo AnythingLLM approval exists but needs one-time local configuration.
echo ============================================================
set "FINAL_RC=10"

:final_end
echo.
echo Studio should now be open and show the same local status.
call :cleanup
pause
exit /b !FINAL_RC!

:fetch_candidate_ready
set "CANDIDATE_READY=0"
del "%TMP_HEALTH%" >nul 2>nul
del "%TMP_STATUS%" >nul 2>nul
curl.exe -fsS --max-time 2 "%HEALTH%" -o "%TMP_HEALTH%" >nul 2>nul
if errorlevel 1 exit /b 0
call :json_bool "%TMP_HEALTH%" "ok" "True"
if errorlevel 1 exit /b 0
call :json_value "%TMP_HEALTH%" "name" "RAH Raven Desktop Bridge"
if errorlevel 1 exit /b 0
call :json_bool "%TMP_HEALTH%" "app_launcher" "True"
if errorlevel 1 exit /b 0
call :json_value "%TMP_HEALTH%" "app_launcher_mode" "fixed-allowlist-explicit-launch"
if errorlevel 1 exit /b 0
call :json_bool "%TMP_HEALTH%" "agent_runner" "True"
if errorlevel 1 exit /b 0
call :json_value "%TMP_HEALTH%" "agent_runner_mode" "read-only-allowlist"
if errorlevel 1 exit /b 0
call :json_bool "%TMP_HEALTH%" "anythingllm_approval_gate" "True"
if errorlevel 1 exit /b 0
curl.exe -fsS --max-time 2 "%STATUS%" -o "%TMP_STATUS%" >nul 2>nul
if errorlevel 1 exit /b 0
call :json_app "%TMP_STATUS%" "world-media"
if errorlevel 1 exit /b 0
call :json_app "%TMP_STATUS%" "rah-os"
if errorlevel 1 exit /b 0
call :json_app "%TMP_STATUS%" "raven-browser"
if errorlevel 1 exit /b 0
set "CANDIDATE_READY=1"
exit /b 0

:json_value
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$j=Get-Content -LiteralPath '%~1' -Raw|ConvertFrom-Json;$v=$j.PSObject.Properties['%~2'].Value;if([string]$v -ceq '%~3'){exit 0}else{exit 1}" >nul 2>nul
exit /b %ERRORLEVEL%

:json_bool
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$j=Get-Content -LiteralPath '%~1' -Raw|ConvertFrom-Json;$v=$j.PSObject.Properties['%~2'].Value;if([string]$v -ceq '%~3'){exit 0}else{exit 1}" >nul 2>nul
exit /b %ERRORLEVEL%

:json_app
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$j=Get-Content -LiteralPath '%~1' -Raw|ConvertFrom-Json;if($null-ne$j.apps.PSObject.Properties['%~2']){exit 0}else{exit 1}" >nul 2>nul
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

:fail_vpn_package
echo.
echo FINAL: FAIL
echo GitHub kan ikke nas akkurat na, og lokal Candidate.4-pakke er ufullstendig.
echo Mest sannsynlig: VPN/proxy/DNS blokkerer GitHub.
echo Sla av VPN midlertidig og dobbeltklikk samme fil igjen.
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

:fail_bridge_repair
echo FINAL: FAIL
echo Candidate.4 Bridge safe-repair feilet. Exit=!REPAIR_RC!
echo Se %%LOCALAPPDATA%%\RAH-Raven\Studio\bridge.err.log
call :cleanup
pause
exit /b 28

:cleanup
del "%TMP_HEALTH%" >nul 2>nul
del "%TMP_STATUS%" >nul 2>nul
del "%UPDATER_NAME%.acceptance-download" >nul 2>nul
exit /b 0
