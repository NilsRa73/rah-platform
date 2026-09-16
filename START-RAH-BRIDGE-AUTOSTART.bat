@echo off
setlocal EnableExtensions
cd /d "%~dp0"

rem ============================================================================
rem RAH Raven Bridge autostart v2
rem Starts the canonical Bridge + queued Job Executor with an inherited elevated
rem token. INSTALL-RAH-AUTOSTART.bat installs this through Task Scheduler using
rem RunLevel Highest, so normal logon does not depend on an unelevated Startup link.
rem ============================================================================

set "BRIDGE_DIR=%~dp0desktop-bridge"
set "BRIDGE_PORT=18765"
set "BRIDGE_HEALTH=http://127.0.0.1:%BRIDGE_PORT%/health"
set "JOB_HEALTH=http://127.0.0.1:%BRIDGE_PORT%/agent/jobs/health"
set "BRIDGE_FILE=%BRIDGE_DIR%\raven_bridge_agent.py"
set "VENV_PY=%BRIDGE_DIR%\.venv\Scripts\python.exe"
set "BRIDGE_LOG=%BRIDGE_DIR%\rah-autostart.log"
set "RAH_JOB_DIR=C:\RAH\AgentJobs"
set "RAH_JOB_REQUIRE_ADMIN=1"

rem Job Executor requires an elevated Windows token. Never start a degraded
rem unelevated executor that would look online but reject jobs with HTTP 503.
fltmc >nul 2>nul
if errorlevel 1 exit /b 5

rem If the complete elevated Bridge + Job Executor is already healthy, exit.
powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; $j=Invoke-RestMethod -Uri '%JOB_HEALTH%' -TimeoutSec 2; if(($h.home_control_ui -eq $true) -and ($h.job_executor -eq $true) -and ($h.job_executor_ready -eq $true) -and ($h.job_executor_elevated -eq $true) -and ($j.ready -eq $true) -and ($j.elevated -eq $true)){ exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
if not errorlevel 1 exit /b 0

rem Autostart never downloads packages. The verified updater/launcher owns that.
if not exist "%BRIDGE_FILE%" exit /b 2
if not exist "%VENV_PY%" exit /b 3
if not exist "%BRIDGE_DIR%\raven_jobs.py" exit /b 2
if not exist "%BRIDGE_DIR%\agent_runner.py" exit /b 2

rem Only replace an existing listener when it identifies itself as the RAH Raven
rem Bridge through /health. If an unrelated process owns 18765, fail safely.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $listeners=@(Get-NetTCPConnection -LocalPort %BRIDGE_PORT% -State Listen -ErrorAction SilentlyContinue); if($listeners.Count -eq 0){ exit 0 }; try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2 } catch { exit 6 }; if($h.home_control_ui -ne $true){ exit 6 }; $owners=$listeners | Select-Object -ExpandProperty OwningProcess -Unique; foreach($owner in $owners){ Stop-Process -Id $owner -Force -ErrorAction Stop }; exit 0" >nul 2>nul
if errorlevel 1 exit /b 6

timeout /t 1 /nobreak >nul
set "RAH_BRIDGE_HOST=127.0.0.1"
set "RAH_BRIDGE_PORT=%BRIDGE_PORT%"
powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$env:RAH_BRIDGE_HOST='127.0.0.1'; $env:RAH_BRIDGE_PORT='%BRIDGE_PORT%'; $env:RAH_JOB_DIR='C:\RAH\AgentJobs'; $env:RAH_JOB_REQUIRE_ADMIN='1'; Start-Process -FilePath '%VENV_PY%' -ArgumentList 'raven_bridge_agent.py' -WorkingDirectory '%BRIDGE_DIR%' -WindowStyle Minimized -RedirectStandardOutput '%BRIDGE_LOG%' -RedirectStandardError '%BRIDGE_LOG%.err'" >nul 2>nul
if errorlevel 1 exit /b 4

rem Do not report success until the queued executor is both ready and elevated.
for /L %%G in (1,1,20) do (
  timeout /t 1 /nobreak >nul
  powershell -NoProfile -ExecutionPolicy Bypass -Command "try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; $j=Invoke-RestMethod -Uri '%JOB_HEALTH%' -TimeoutSec 2; if(($h.job_executor_ready -eq $true) -and ($h.job_executor_elevated -eq $true) -and ($j.ready -eq $true) -and ($j.elevated -eq $true)){ exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
  if not errorlevel 1 exit /b 0
)

exit /b 4
