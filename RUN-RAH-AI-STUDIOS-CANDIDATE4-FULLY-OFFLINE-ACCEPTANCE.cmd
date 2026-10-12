@echo off
setlocal EnableExtensions EnableDelayedExpansion
title RAH AI Studios Candidate.4 - FULLY OFFLINE Acceptance

rem ============================================================================
rem RAH AI STUDIOS CANDIDATE.4 - FULLY OFFLINE ACCEPTANCE v1.0
rem LOCAL PACKAGE -> LOCAL CACHE/REPAIR -> LOCAL START -> LOOPBACK READINESS
rem ZERO GitHub / DNS / WAN dependency. Loopback only.
rem No USB, partition, BIOS or disk-layout changes.
rem ============================================================================
set "ENTRY_NAME=START-HER-RAH-AI-STUDIOS-V3.1-CANDIDATE.cmd"
set "HEALTH=http://127.0.0.1:18765/health"
set "STATUS=http://127.0.0.1:18765/apps/status"
set "LM_MODELS=http://127.0.0.1:1234/v1/models"
set "TMP_HEALTH=%TEMP%\rah-offline-c4-health-%RANDOM%.json"
set "TMP_STATUS=%TEMP%\rah-offline-c4-status-%RANDOM%.json"
set "TMP_LM=%TEMP%\rah-offline-c4-lm-%RANDOM%.json"
set "RAH_OFFLINE=1"
set "NO_PROXY=127.0.0.1,localhost,::1"
set "no_proxy=127.0.0.1,localhost,::1"
set "CACHE_ROOT=C:\RAH\Offline\Candidate4"
set "CACHE_PAYLOAD=%CACHE_ROOT%\payload"
set "PACKAGE_REPAIRED=0"
set "LOCAL_AI_READY=0"
set "ANYTHING_CONFIGURED=0"

call :resolve_root
if not defined RAH_ROOT goto :fail_root
cd /d "%RAH_ROOT%"

echo.
echo ============================================================
echo  RAH AI STUDIOS CANDIDATE.4 - FULLY OFFLINE ACCEPTANCE
echo ============================================================
echo  Root: %RAH_ROOT%
echo  Cache: %CACHE_ROOT%
echo  NETWORK: OFFLINE MODE - only 127.0.0.1 / localhost is used.
echo  VPN state is irrelevant to this acceptance path.
echo  Ingen USB-, partisjons-, BIOS- eller diskendringer.
echo.

echo [PRECHECK]
where curl.exe >nul 2>nul || goto :fail_curl
where powershell.exe >nul 2>nul || goto :fail_powershell
echo PASS     curl.exe
echo PASS     powershell.exe
echo PASS     RAH_OFFLINE=1
echo PASS     NO_PROXY limited to loopback

echo.
echo [LOCAL PACKAGE]
call :validate_local_package
if "!LOCAL_VALID!"=="1" (
  echo PASS     Candidate.4 local runtime package is complete and version-correct
  goto :cache_snapshot
)

echo REPAIR   Local Candidate.4 package is incomplete or version-mismatched
call :find_cache
if not defined FOUND_CACHE goto :fail_no_cache
echo PASS     Offline cache found: !FOUND_CACHE!
call :restore_from_cache
if errorlevel 1 goto :fail_cache_repair
set "PACKAGE_REPAIRED=1"
call :validate_local_package
if not "!LOCAL_VALID!"=="1" goto :fail_cache_repair
echo PASS     Local package repaired from offline cache

:cache_snapshot
if not exist "%CACHE_PAYLOAD%" (
  echo.
  echo [OFFLINE CACHE]
  echo CACHE    Creating local recovery snapshot from verified Candidate.4 files
  call :snapshot_cache
  if errorlevel 1 (
    echo WARN     Could not create offline cache; acceptance can still continue
  ) else (
    echo PASS     Offline recovery cache created at %CACHE_ROOT%
  )
) else (
  echo.
  echo [OFFLINE CACHE]
  echo PASS     Offline recovery cache already present
)

echo.
echo [LOCAL START]
call "%ENTRY_NAME%"
set "START_RC=!ERRORLEVEL!"
if not "!START_RC!"=="0" goto :fail_start
echo PASS     Candidate.4 one-click entrypoint dispatched with RAH_OFFLINE=1

echo.
echo [FULL READINESS]
echo Waiting for complete Candidate.4 local readiness...
set "CANDIDATE_READY=0"
for /L %%G in (1,1,45) do (
  timeout /t 1 /nobreak >nul
  call :offline_bridge_repair
set "BRIDGE_DIR=%RAH_ROOT%\desktop-bridge"
set "VENV=%BRIDGE_DIR%\.venv\Scripts\python.exe"
set "WHEELHOUSE=C:\RAH\Offline\Candidate4\wheels"
if not exist "%BRIDGE_DIR%\raven_bridge.py" exit /b 2
if not exist "%BRIDGE_DIR%\requirements.txt" exit /b 2

if not exist "%VENV%" (
  pushd "%BRIDGE_DIR%"
  where py >nul 2>nul
  if not errorlevel 1 (
    py -m venv ".venv" >nul 2>nul
  ) else (
    where python >nul 2>nul
    if errorlevel 1 (
      popd
      exit /b 3
    )
    python -m venv ".venv" >nul 2>nul
  )
  set "VENV_RC=!ERRORLEVEL!"
  popd
  if not "!VENV_RC!"=="0" exit /b 4
)

"%VENV%" -c "import flask, flask_cors, PIL, mss, pypdf" >nul 2>nul
if errorlevel 1 (
  if not exist "%WHEELHOUSE%\." exit /b 8
  "%VENV%" -m pip install --disable-pip-version-check --quiet --no-index --find-links "%WHEELHOUSE%" -r "%BRIDGE_DIR%\requirements.txt" >nul 2>nul
  if errorlevel 1 exit /b 8
)

pushd "%BRIDGE_DIR%"
"%VENV%" -m py_compile server_v16.py server_v17.py app_launcher.py raven_bridge.py agent_runner.py anythingllm_approval.py >nul 2>nul
if errorlevel 1 (
  popd
  exit /b 5
)
start "" /b "%VENV%" "%BRIDGE_DIR%\raven_bridge.py" >nul 2>nul
popd
exit /b 0

:fetch_candidate_ready
  if "!CANDIDATE_READY!"=="1" goto :candidate_ready
)

echo REPAIR   Full readiness not reached in first 45 seconds
echo REPAIR   Running local Bridge repair in strict offline mode
call :offline_bridge_repair
set "REPAIR_RC=!ERRORLEVEL!"
if not "!REPAIR_RC!"=="0" goto :fail_bridge_repair

for /L %%G in (1,1,30) do (
  timeout /t 1 /nobreak >nul
  call :fetch_candidate_ready
  if "!CANDIDATE_READY!"=="1" goto :candidate_ready
)
goto :fail_bridge

:candidate_ready
echo PASS     Desktop Bridge verified on 127.0.0.1:18765
echo PASS     App Launcher fixed allowlist
echo PASS     Agent Runner read-only allowlist
echo PASS     AnythingLLM approval gate loaded
echo PASS     App catalog: World Media / RAH OS / Raven Browser

call :json_bool "%TMP_HEALTH%" "anythingllm_approval_configured" "True"
if not errorlevel 1 set "ANYTHING_CONFIGURED=1"

echo.
echo [LOCAL AI]
curl.exe --noproxy "*" -fsS --max-time 3 "%LM_MODELS%" -o "%TMP_LM%" >nul 2>nul
if errorlevel 1 (
  echo PENDING  LM Studio API is not ready on 127.0.0.1:1234
) else (
  call :json_has_model "%TMP_LM%"
  if errorlevel 1 (
    echo PENDING  LM Studio API answers, but no model is loaded
  ) else (
    set "LOCAL_AI_READY=1"
    echo PASS     LM Studio local API has a loaded model
  )
)

echo.
echo ============================================================
if "!LOCAL_AI_READY!"=="1" if "!ANYTHING_CONFIGURED!"=="1" goto :final_pass
goto :final_pending

:final_pass
echo FINAL: PASS
echo Fully offline Candidate.4 acceptance passed.
echo Bridge, App Launcher, Agent Runner, local AI and AnythingLLM are ready.
if "!PACKAGE_REPAIRED!"=="1" echo NOTE: Local runtime was repaired from offline cache.
set "FINAL_RC=0"
goto :final_end

:final_pending
echo FINAL: PENDING
echo Core Candidate.4 offline acceptance passed.
if "!LOCAL_AI_READY!"=="0" echo PENDING: Start LM Studio local server and load a local model.
if "!ANYTHING_CONFIGURED!"=="0" echo PENDING: AnythingLLM approval needs one-time local configuration.
if "!PACKAGE_REPAIRED!"=="1" echo NOTE: Local runtime was repaired from offline cache.
set "FINAL_RC=10"

:final_end
echo ============================================================
echo.
echo No GitHub, DNS, WAN or VPN access was required.
call :cleanup
pause
exit /b !FINAL_RC!

:validate_local_package
set "LOCAL_VALID=1"
for %%F in (
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json"
  "raven-studio-launch-client.js"
  "RAH-STUDIO-ONE-CLICK.vbs"
  "desktop-bridge\raven_bridge.py"
  "desktop-bridge\app_launcher.py"
  "desktop-bridge\agent_runner.py"
  "desktop-bridge\anythingllm_approval.py"
  "desktop-bridge\requirements.txt"
  "%ENTRY_NAME%"
) do (
  if not exist "%%~F" set "LOCAL_VALID=0"
)
if "!LOCAL_VALID!"=="0" exit /b 0

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$j=Get-Content -LiteralPath 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json' -Raw|ConvertFrom-Json;if($j.version -ceq '3.1.0-candidate.4' -and $j.features.local_app_launcher_version -ceq '0.2.0' -and $j.features.local_app_launcher_mode -ceq 'fixed-allowlist-explicit-launch'){exit 0}else{exit 1}" >nul 2>nul
if errorlevel 1 set "LOCAL_VALID=0"
exit /b 0

:find_cache
set "FOUND_CACHE="
for %%D in (
  "%~dp0OFFLINE-CACHE"
  "%CACHE_PAYLOAD%"
  "%RAH_ROOT%\Offline\Candidate4\payload"
) do (
  if not defined FOUND_CACHE if exist "%%~D\RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json" set "FOUND_CACHE=%%~fD"
)
exit /b 0

:restore_from_cache
for %%F in (
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json"
  "raven-studio-launch-client.js"
  "RAH-STUDIO-ONE-CLICK.vbs"
  "START-HER-RAH-AI-STUDIOS-V3.1-CANDIDATE.cmd"
) do (
  if not exist "!FOUND_CACHE!\%%~F" exit /b 1
  copy /y "!FOUND_CACHE!\%%~F" "%RAH_ROOT%\%%~F" >nul || exit /b 1
)
if not exist "%RAH_ROOT%\desktop-bridge" mkdir "%RAH_ROOT%\desktop-bridge" >nul 2>nul
for %%F in (
  "raven_bridge.py"
  "app_launcher.py"
  "agent_runner.py"
  "anythingllm_approval.py"
  "requirements.txt"
) do (
  if not exist "!FOUND_CACHE!\desktop-bridge\%%~F" exit /b 1
  copy /y "!FOUND_CACHE!\desktop-bridge\%%~F" "%RAH_ROOT%\desktop-bridge\%%~F" >nul || exit /b 1
)
exit /b 0

:snapshot_cache
if not exist "%CACHE_PAYLOAD%" mkdir "%CACHE_PAYLOAD%" >nul 2>nul
if not exist "%CACHE_PAYLOAD%\desktop-bridge" mkdir "%CACHE_PAYLOAD%\desktop-bridge" >nul 2>nul
for %%F in (
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json"
  "raven-studio-launch-client.js"
  "RAH-STUDIO-ONE-CLICK.vbs"
  "START-HER-RAH-AI-STUDIOS-V3.1-CANDIDATE.cmd"
) do (
  copy /y "%RAH_ROOT%\%%~F" "%CACHE_PAYLOAD%\%%~F" >nul || exit /b 1
)
for %%F in (
  "raven_bridge.py"
  "app_launcher.py"
  "agent_runner.py"
  "anythingllm_approval.py"
  "requirements.txt"
) do (
  copy /y "%RAH_ROOT%\desktop-bridge\%%~F" "%CACHE_PAYLOAD%\desktop-bridge\%%~F" >nul || exit /b 1
)
> "%CACHE_ROOT%\README-OFFLINE.txt" (
  echo RAH Candidate.4 offline recovery cache
  echo Created locally by RUN-RAH-AI-STUDIOS-CANDIDATE4-FULLY-OFFLINE-ACCEPTANCE.cmd
  echo Candidate version: 3.1.0-candidate.4
  echo This cache contains only the files required by the Candidate.4 offline acceptance path.
)
exit /b 0

:fetch_candidate_ready
set "CANDIDATE_READY=0"
del "%TMP_HEALTH%" >nul 2>nul
del "%TMP_STATUS%" >nul 2>nul
curl.exe --noproxy "*" -fsS --max-time 2 "%HEALTH%" -o "%TMP_HEALTH%" >nul 2>nul
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
curl.exe --noproxy "*" -fsS --max-time 2 "%STATUS%" -o "%TMP_STATUS%" >nul 2>nul
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

:json_has_model
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$j=Get-Content -LiteralPath '%~1' -Raw|ConvertFrom-Json;if($j.data -is [array] -and $j.data.Count -gt 0){exit 0}else{exit 1}" >nul 2>nul
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
if not defined RAH_ROOT if exist "%~dp0RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json" set "RAH_ROOT=%~dp0"
exit /b 0

:fail_root
echo.
echo FINAL: FAIL
echo No local RAH installation was found.
echo Place this file in the RAH folder, C:\RAH, or Desktop\RAH AI Studios.
pause
exit /b 20

:fail_curl
echo FINAL: FAIL
echo curl.exe is missing from Windows PATH.
pause
exit /b 21

:fail_powershell
echo FINAL: FAIL
echo Windows PowerShell is missing; local JSON validation cannot run.
pause
exit /b 22

:fail_no_cache
echo.
echo FINAL: FAIL
echo Local Candidate.4 runtime is incomplete and no offline recovery cache exists.
echo Expected cache: %CACHE_PAYLOAD%
echo No network repair was attempted.
pause
exit /b 23

:fail_cache_repair
echo FINAL: FAIL
echo Offline cache exists but could not restore a valid Candidate.4 runtime.
echo No network repair was attempted.
pause
exit /b 24

:fail_start
echo FINAL: FAIL
echo Candidate.4 local entrypoint failed. Exit=!START_RC!
pause
exit /b 25

:fail_bridge
echo FINAL: FAIL
echo Full Candidate.4 readiness was not reached after local start and safe offline repair.
echo No external network was used.
echo See %%LOCALAPPDATA%%\RAH-Raven\Studio\bridge.err.log
call :cleanup
pause
exit /b 26

:fail_bridge_repair
echo FINAL: FAIL
echo Offline Bridge bootstrap failed. Exit=!REPAIR_RC!
if "!REPAIR_RC!"=="8" echo Offline dependencies are missing; pre-stage .venv or C:\RAH\Offline\Candidate4\wheels.
echo No online package source was used.
echo See %%LOCALAPPDATA%%\RAH-Raven\Studio\bridge.err.log
call :cleanup
pause
exit /b 27

:cleanup
del "%TMP_HEALTH%" >nul 2>nul
del "%TMP_STATUS%" >nul 2>nul
del "%TMP_LM%" >nul 2>nul
exit /b 0
