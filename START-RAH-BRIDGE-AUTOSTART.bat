@echo off
setlocal EnableExtensions
cd /d "%~dp0"

rem ============================================================================
rem RAH Raven Bridge + Job Executor + AI Fabric autostart v3.1
rem Must be launched by the Scheduled Task installed with RunLevel Highest.
rem ============================================================================

set "BRIDGE_DIR=%~dp0desktop-bridge"
set "BRIDGE_PORT=18765"
set "BRIDGE_HEALTH=http://127.0.0.1:%BRIDGE_PORT%/health"
set "JOB_HEALTH=http://127.0.0.1:%BRIDGE_PORT%/agent/jobs/health"
set "AI_PROVIDERS=http://127.0.0.1:%BRIDGE_PORT%/ai/providers"
set "BRIDGE_FILE=%BRIDGE_DIR%\raven_bridge_agent.py"
set "BRIDGE_LOG=%BRIDGE_DIR%\rah-autostart.log"
set "RAH_JOB_DIR=C:\RAH\AgentJobs"
set "RAH_JOB_REQUIRE_ADMIN=1"

fltmc >nul 2>nul
if errorlevel 1 exit /b 5

rem Resolve an existing Python runtime; autostart never installs software.
set "VENV_PY=%BRIDGE_DIR%\.venv\Scripts\python.exe"
if exist "%VENV_PY%" goto :python_ok
set "VENV_PY=C:\RAH\AI-Fabric\venv\Scripts\python.exe"
if exist "%VENV_PY%" goto :python_ok
set "VENV_PY=C:\RAH\Runtime\Python\Scripts\python.exe"
if exist "%VENV_PY%" goto :python_ok
exit /b 3

:python_ok
rem If complete Raven + Jobs + AI Fabric is already healthy, exit quietly.
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -Command "try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; $j=Invoke-RestMethod -Uri '%JOB_HEALTH%' -TimeoutSec 2; $a=Invoke-RestMethod -Uri '%AI_PROVIDERS%' -TimeoutSec 4; if(($h.home_control_ui -eq $true) -and ($h.job_executor -eq $true) -and ($h.job_executor_ready -eq $true) -and ($h.job_executor_elevated -eq $true) -and ($h.ai_fabric -eq $true) -and ($j.ready -eq $true) -and ($j.elevated -eq $true) -and ($a.ok -eq $true)){ exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
if not errorlevel 1 exit /b 0

if not exist "%BRIDGE_FILE%" exit /b 2
if not exist "%BRIDGE_DIR%\raven_jobs.py" exit /b 2
if not exist "%BRIDGE_DIR%\raven_ai_fabric.py" exit /b 2
if not exist "%BRIDGE_DIR%\agent_runner.py" exit /b 2

rem Never kill an unknown owner of 18765. Only a process that identifies as Raven
rem through /health is replaceable.
powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$ErrorActionPreference='Stop'; $listeners=@(Get-NetTCPConnection -LocalPort %BRIDGE_PORT% -State Listen -ErrorAction SilentlyContinue); if($listeners.Count -eq 0){ exit 0 }; try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2 } catch { exit 6 }; if(($h.home_control_ui -ne $true) -and ($h.job_executor -ne $true)){ exit 6 }; $owners=$listeners | Select-Object -ExpandProperty OwningProcess -Unique; foreach($owner in $owners){ Stop-Process -Id $owner -Force -ErrorAction Stop }; exit 0" >nul 2>nul
if errorlevel 1 exit /b 6

timeout /t 1 /nobreak >nul
set "RAH_BRIDGE_HOST=127.0.0.1"
set "RAH_BRIDGE_PORT=%BRIDGE_PORT%"
set "RAH_AI_AUTO_START_LMSTUDIO=1"
set "RAH_AI_AUTO_START_ANYTHINGLLM=1"
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$env:RAH_BRIDGE_HOST='127.0.0.1'; $env:RAH_BRIDGE_PORT='%BRIDGE_PORT%'; $env:RAH_JOB_DIR='C:\RAH\AgentJobs'; $env:RAH_JOB_REQUIRE_ADMIN='1'; $env:RAH_AI_AUTO_START_LMSTUDIO='1'; $env:RAH_AI_AUTO_START_ANYTHINGLLM='1'; Start-Process -FilePath '%VENV_PY%' -ArgumentList 'raven_bridge_agent.py' -WorkingDirectory '%BRIDGE_DIR%' -WindowStyle Hidden -RedirectStandardOutput '%BRIDGE_LOG%' -RedirectStandardError '%BRIDGE_LOG%.err'" >nul 2>nul
if errorlevel 1 exit /b 4

rem Do not report success until Bridge, elevated jobs and AI Fabric are all loaded.
for /L %%G in (1,1,30) do (
  timeout /t 1 /nobreak >nul
  powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -Command "try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; $j=Invoke-RestMethod -Uri '%JOB_HEALTH%' -TimeoutSec 2; $a=Invoke-RestMethod -Uri '%AI_PROVIDERS%' -TimeoutSec 4; if(($h.job_executor_ready -eq $true) -and ($h.job_executor_elevated -eq $true) -and ($h.ai_fabric -eq $true) -and ($j.ready -eq $true) -and ($j.elevated -eq $true) -and ($a.ok -eq $true)){ exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
  if not errorlevel 1 exit /b 0
)

exit /b 4
