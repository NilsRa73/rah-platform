@echo off
setlocal EnableExtensions EnableDelayedExpansion
title RAH AI Studios Candidate.4 - FULLY OFFLINE Acceptance v1.1

rem ============================================================================
rem RAH AI STUDIOS CANDIDATE.4 - FULLY OFFLINE ACCEPTANCE v1.1
rem LOCAL PACKAGE -> OFFLINE CACHE -> LOCAL BRIDGE -> LOOPBACK READINESS -> FINAL
rem ZERO GitHub / DNS / WAN dependency. Loopback only.
rem No USB, partition, BIOS or disk-layout changes.
rem ============================================================================
set "STUDIO=RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
set "MANIFEST=RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json"
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
set "CACHE_VENV=%CACHE_ROOT%\venv"
set "WHEELHOUSE=%CACHE_ROOT%\wheels"

set "PACKAGE_REPAIRED=0"
set "VENV_RESTORED=0"
set "LOCAL_AI_READY=0"
set "ANYTHING_CONFIGURED=0"

call :resolve_root
if not defined RAH_ROOT goto :fail_root
cd /d "%RAH_ROOT%"

echo.
echo ============================================================
echo  RAH AI STUDIOS CANDIDATE.4 - FULLY OFFLINE ACCEPTANCE v1.1
echo ============================================================
echo  Root: %RAH_ROOT%
echo  Cache: %CACHE_ROOT%
echo  NETWORK: OFFLINE MODE - only loopback is used.
echo  VPN state is irrelevant.
echo  Ingen USB-, partisjons-, BIOS- eller diskendringer.
echo.

echo [PRECHECK]
where curl.exe >nul 2>nul || goto :fail_curl
where powershell.exe >nul 2>nul || goto :fail_powershell
echo PASS     curl.exe
echo PASS     powershell.exe
echo PASS     RAH_OFFLINE=1
echo PASS     loopback-only endpoints

echo.
echo [LOCAL PACKAGE]
call :validate_local_package
if "!LOCAL_VALID!"=="1" (
  echo PASS     Candidate.4 runtime package is complete and version-correct
) else (
  echo REPAIR   Local Candidate.4 package is incomplete or version-mismatched
  call :find_cache
  if not defined FOUND_CACHE goto :fail_no_cache
  echo PASS     Offline payload cache found: !FOUND_CACHE!
  call :restore_from_cache
  if errorlevel 1 goto :fail_cache_repair
  set "PACKAGE_REPAIRED=1"
  call :validate_local_package
  if not "!LOCAL_VALID!"=="1" goto :fail_cache_repair
  echo PASS     Candidate.4 runtime restored from offline cache
)

echo.
echo [OFFLINE CACHE]
call :ensure_payload_cache
if errorlevel 1 (
  echo WARN     Could not refresh payload cache; continuing with validated local runtime
) else (
  echo PASS     Payload recovery cache ready
)
call :ensure_venv_cache
if "!VENV_CACHE_READY!"=="1" (
  echo PASS     Working Python venv recovery cache ready
) else (
  echo PENDING  No working venv cache yet; current local venv may still be enough
)

echo.
echo [LOCAL BRIDGE]
call :fetch_candidate_ready
if "!CANDIDATE_READY!"=="1" (
  echo PASS     Full Candidate.4 Bridge already ready
  goto :bridge_ready
)

call :prepare_bridge_port
if errorlevel 1 goto :fail_foreign_port

call :offline_bridge_start
set "BRIDGE_RC=!ERRORLEVEL!"
if not "!BRIDGE_RC!"=="0" goto :fail_bridge_start

for /L %%G in (1,1,35) do (
  timeout /t 1 /nobreak >nul
  call :fetch_candidate_ready
  if "!CANDIDATE_READY!"=="1" goto :bridge_ready
)
goto :fail_bridge

:bridge_ready
echo PASS     Desktop Bridge verified on 127.0.0.1:18765
echo PASS     App Launcher fixed allowlist
echo PASS     Agent Runner read-only allowlist
echo PASS     AnythingLLM approval gate loaded
echo PASS     App status catalog contains World Media / RAH OS / Raven Browser

echo.
echo [STUDIO]
if not exist "%STUDIO%" goto :fail_package
start "" "%RAH_ROOT%\%STUDIO%"
echo PASS     Candidate.4 Studio opened directly from local disk

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
echo [LOCAL APP LAUNCHERS]
call :check_local_app "apps\rah-world-media\START-HER.cmd" "World Media"
call :check_local_app "START-HER-RAH-OS.cmd" "RAH OS"
call :check_local_app "START-HER-RAH-RAVEN-BROWSER.cmd" "Raven Browser"

echo.
echo ============================================================
if "!LOCAL_AI_READY!"=="1" if "!ANYTHING_CONFIGURED!"=="1" goto :final_pass
goto :final_pending

:final_pass
echo FINAL: PASS
echo Fully offline Candidate.4 acceptance passed.
echo Bridge, App Launcher, Agent Runner, local AI and AnythingLLM are ready.
if "!PACKAGE_REPAIRED!"=="1" echo NOTE: Runtime was restored from offline cache.
if "!VENV_RESTORED!"=="1" echo NOTE: Python venv was restored from offline cache.
set "FINAL_RC=0"
goto :final_end

:final_pending
echo FINAL: PENDING
echo Candidate.4 core acceptance passed fully offline.
if "!LOCAL_AI_READY!"=="0" echo PENDING: Start LM Studio local server and load a local model.
if "!ANYTHING_CONFIGURED!"=="0" echo PENDING: AnythingLLM approval needs one-time local configuration.
if "!PACKAGE_REPAIRED!"=="1" echo NOTE: Runtime was restored from offline cache.
if "!VENV_RESTORED!"=="1" echo NOTE: Python venv was restored from offline cache.
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
  "desktop-bridge\raven_bridge.py"
  "desktop-bridge\app_launcher.py"
  "desktop-bridge\agent_runner.py"
  "desktop-bridge\anythingllm_approval.py"
  "desktop-bridge\requirements.txt"
) do (
  if not exist "%%~F" set "LOCAL_VALID=0"
)
if "!LOCAL_VALID!"=="0" exit /b 0

powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$j=Get-Content -LiteralPath '%MANIFEST%' -Raw|ConvertFrom-Json;if($j.version -ceq '3.1.0-candidate.4' -and $j.features.local_app_launcher_version -ceq '0.2.0' -and $j.features.local_app_launcher_mode -ceq 'fixed-allowlist-explicit-launch'){exit 0}else{exit 1}" >nul 2>nul
if errorlevel 1 set "LOCAL_VALID=0"
exit /b 0

:find_cache
set "FOUND_CACHE="
for %%D in (
  "%~dp0OFFLINE-CACHE"
  "%CACHE_PAYLOAD%"
  "%RAH_ROOT%\Offline\Candidate4\payload"
) do (
  if not defined FOUND_CACHE if exist "%%~D\%MANIFEST%" set "FOUND_CACHE=%%~fD"
)
exit /b 0

:restore_from_cache
for %%F in (
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json"
  "raven-studio-launch-client.js"
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

:ensure_payload_cache
if exist "%CACHE_PAYLOAD%\%MANIFEST%" exit /b 0
if not exist "%CACHE_PAYLOAD%" mkdir "%CACHE_PAYLOAD%" >nul 2>nul
if not exist "%CACHE_PAYLOAD%\desktop-bridge" mkdir "%CACHE_PAYLOAD%\desktop-bridge" >nul 2>nul
for %%F in (
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
  "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json"
  "raven-studio-launch-client.js"
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
  echo Candidate version: 3.1.0-candidate.4
  echo Contains local runtime files and, when available, a working Python venv snapshot.
)
exit /b 0

:ensure_venv_cache
set "VENV_CACHE_READY=0"
if exist "%CACHE_VENV%\Scripts\python.exe" (
  "%CACHE_VENV%\Scripts\python.exe" -c "import flask, flask_cors, PIL, mss, pypdf" >nul 2>nul
  if not errorlevel 1 (
    set "VENV_CACHE_READY=1"
    exit /b 0
  )
)
if not exist "%RAH_ROOT%\desktop-bridge\.venv\Scripts\python.exe" exit /b 0
"%RAH_ROOT%\desktop-bridge\.venv\Scripts\python.exe" -c "import flask, flask_cors, PIL, mss, pypdf" >nul 2>nul
if errorlevel 1 exit /b 0
if not exist "%CACHE_ROOT%" mkdir "%CACHE_ROOT%" >nul 2>nul
robocopy "%RAH_ROOT%\desktop-bridge\.venv" "%CACHE_VENV%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 exit /b 0
if exist "%CACHE_VENV%\Scripts\python.exe" set "VENV_CACHE_READY=1"
exit /b 0

:restore_venv_cache
if not exist "%CACHE_VENV%\Scripts\python.exe" exit /b 1
if exist "%RAH_ROOT%\desktop-bridge\.venv" rmdir /s /q "%RAH_ROOT%\desktop-bridge\.venv" >nul 2>nul
robocopy "%CACHE_VENV%" "%RAH_ROOT%\desktop-bridge\.venv" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 exit /b 1
if not exist "%RAH_ROOT%\desktop-bridge\.venv\Scripts\python.exe" exit /b 1
set "VENV_RESTORED=1"
exit /b 0

:prepare_bridge_port
del "%TMP_HEALTH%" >nul 2>nul
curl.exe --noproxy "*" -fsS --max-time 2 "%HEALTH%" -o "%TMP_HEALTH%" >nul 2>nul
if errorlevel 1 exit /b 0
call :json_value "%TMP_HEALTH%" "name" "RAH Raven Desktop Bridge"
if errorlevel 1 exit /b 9
for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":18765 .*LISTENING"') do (
  taskkill /PID %%P /F >nul 2>nul
)
timeout /t 1 /nobreak >nul
exit /b 0

:offline_bridge_start
set "BRIDGE_DIR=%RAH_ROOT%\desktop-bridge"
set "VENV=%BRIDGE_DIR%\.venv\Scripts\python.exe"
if not exist "%BRIDGE_DIR%\raven_bridge.py" exit /b 2
if not exist "%BRIDGE_DIR%\requirements.txt" exit /b 2

if not exist "%VENV%" (
  call :restore_venv_cache
  if errorlevel 1 (
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
)

"%VENV%" -c "import flask, flask_cors, PIL, mss, pypdf" >nul 2>nul
if errorlevel 1 (
  call :restore_venv_cache
  if errorlevel 1 (
    if not exist "%WHEELHOUSE%\." exit /b 8
    "%VENV%" -m pip install --disable-pip-version-check --quiet --no-index --find-links "%WHEELHOUSE%" -r "%BRIDGE_DIR%\requirements.txt" >nul 2>nul
    if errorlevel 1 exit /b 8
  )
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

:check_local_app
if exist "%~1" (
  echo PASS     %~2 launcher present
) else (
  echo PENDING  %~2 launcher is not present locally
)
exit /b 0

:json_value
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$j=Get-Content -LiteralPath '%~1' -Raw|ConvertFrom-Json;$p=$j.PSObject.Properties['%~2'];if($null-ne$p -and [string]$p.Value -ceq '%~3'){exit 0}else{exit 1}" >nul 2>nul
exit /b %ERRORLEVEL%

:json_bool
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$j=Get-Content -LiteralPath '%~1' -Raw|ConvertFrom-Json;$p=$j.PSObject.Properties['%~2'];if($null-ne$p -and [string]$p.Value -ceq '%~3'){exit 0}else{exit 1}" >nul 2>nul
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
if not defined RAH_ROOT if exist "%~dp0%MANIFEST%" set "RAH_ROOT=%~dp0"
exit /b 0

:fail_root
echo.
echo FINAL: FAIL
echo No local RAH installation was found.
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
echo FINAL: FAIL
echo Local Candidate.4 runtime is incomplete and no offline payload cache exists.
echo Expected: %CACHE_PAYLOAD%
echo No network repair was attempted.
pause
exit /b 23

:fail_cache_repair
echo FINAL: FAIL
echo Offline payload cache could not restore a valid Candidate.4 runtime.
pause
exit /b 24

:fail_foreign_port
echo FINAL: FAIL
echo Port 18765 belongs to a service that did not identify as RAH Raven Desktop Bridge.
echo Nothing was killed.
pause
exit /b 25

:fail_bridge_start
echo FINAL: FAIL
echo Offline Bridge start failed. Exit=!BRIDGE_RC!
if "!BRIDGE_RC!"=="8" echo Missing Python dependencies: restore venv cache or place wheels in %WHEELHOUSE%.
echo No online package source was used.
pause
exit /b 26

:fail_bridge
echo FINAL: FAIL
echo Full Candidate.4 readiness was not reached after offline Bridge start.
echo No external network was used.
call :cleanup
pause
exit /b 27

:fail_package
echo FINAL: FAIL
echo Candidate.4 local package is incomplete.
call :cleanup
pause
exit /b 28

:cleanup
del "%TMP_HEALTH%" >nul 2>nul
del "%TMP_STATUS%" >nul 2>nul
del "%TMP_LM%" >nul 2>nul
exit /b 0
