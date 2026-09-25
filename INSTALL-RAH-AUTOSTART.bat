@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven AI Fabric Autostart Installer v3.2

set "TARGET=%~dp0START-RAH-BRIDGE-AUTOSTART.bat"
set "TASK_NAME=RAH Raven Bridge"
set "BRIDGE_HEALTH=http://127.0.0.1:18765/health"
set "JOB_HEALTH=http://127.0.0.1:18765/agent/jobs/health"
set "AI_PROVIDERS=http://127.0.0.1:18765/ai/providers"
set "RAH_NO_PAUSE=0"
if /I "%~1"=="--no-pause" set "RAH_NO_PAUSE=1"
if not exist "%TARGET%" goto :missing

rem Raven Jobs needs an elevated inherited token. Elevate only the installer;
rem future logons run the task automatically with RunLevel Highest.
fltmc >nul 2>nul
if errorlevel 1 (
  echo RAH Raven AI Fabric trenger Administrator en gang for autostart.
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/d','/c','""%~f0""' -Verb RunAs"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $target=(Resolve-Path -LiteralPath '%TARGET%').Path; $work=(Resolve-Path -LiteralPath '%~dp0').Path; $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name; $hiddenCommand='& ''' + $target.Replace('''','''''') + ''''; $hiddenEncoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($hiddenCommand)); $hiddenArgs='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -EncodedCommand ' + $hiddenEncoded; $action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $hiddenArgs -WorkingDirectory $work; $trigger=New-ScheduledTaskTrigger -AtLogOn -User $user; $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest; $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1); Register-ScheduledTask -TaskName '%TASK_NAME%' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'RAH Raven Bridge + Job Executor + AI Fabric' -Force | Out-Null; $startup=[Environment]::GetFolderPath('Startup'); $old=Join-Path $startup 'RAH Raven Bridge.lnk'; if(Test-Path -LiteralPath $old){ $backup='C:\RAH\Backups\AI-Fabric'; New-Item -ItemType Directory -Force -Path $backup | Out-Null; Copy-Item -LiteralPath $old -Destination (Join-Path $backup 'RAH Raven Bridge.legacy.lnk') -Force; Remove-Item -LiteralPath $old -Force }; Start-ScheduledTask -TaskName '%TASK_NAME%'; Write-Host 'RAH Raven AI Fabric autostart aktivert.'"
if errorlevel 1 goto :error

rem Do not claim success until the exact HOVED-PC Stable gates answer from the
rem Scheduled Task process: canonical Bridge, elevated Job Executor and AI Fabric.
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $ok=$false; for($i=0;$i -lt 30;$i++){ Start-Sleep -Seconds 1; try { $h=Invoke-RestMethod -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2; $j=Invoke-RestMethod -Uri '%JOB_HEALTH%' -TimeoutSec 2; $a=Invoke-RestMethod -Uri '%AI_PROVIDERS%' -TimeoutSec 4; if(($h.job_executor -eq $true) -and ($h.job_executor_ready -eq $true) -and ($h.job_executor_elevated -eq $true) -and ($h.ai_fabric -eq $true) -and ($j.ready -eq $true) -and ($j.elevated -eq $true) -and ($a.ok -eq $true)){ $ok=$true; break } } catch {} }; if(-not $ok){ exit 1 }; Write-Host ('Bridge: job_executor=' + $h.job_executor + ' ready=' + $h.job_executor_ready + ' elevated=' + $h.job_executor_elevated + ' ai_fabric=' + $h.ai_fabric); Write-Host ('Jobs: ready=' + $j.ready + ' elevated=' + $j.elevated); $a.providers | ForEach-Object { Write-Host ($_.id + ': online=' + $_.online + ' ready=' + $_.ready + ' - ' + $_.detail) }; exit 0"
if errorlevel 1 goto :health_error

echo.
echo RAH Raven Bridge + Job Executor + AI Fabric er satt til autostart.
echo Elevated Job Executor er verifisert via /agent/jobs/health.
echo LM Studio og AnythingLLM auto-discovery er aktivert.
echo Ingen nettleser apnes automatisk.
echo.
if "%RAH_NO_PAUSE%"=="0" pause
exit /b 0

:missing
echo FEIL: START-RAH-BRIDGE-AUTOSTART.bat mangler.
if "%RAH_NO_PAUSE%"=="0" pause
exit /b 2

:health_error
echo FEIL: Scheduled Task ble opprettet, men Bridge/Job Executor bestod ikke health-gaten.
if "%RAH_NO_PAUSE%"=="0" pause
exit /b 4

:error
echo FEIL: Kunne ikke opprette elevated Scheduled Task.
if "%RAH_NO_PAUSE%"=="0" pause
exit /b 1