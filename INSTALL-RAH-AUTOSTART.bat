@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven AI Fabric Autostart Installer v3

set "TARGET=%~dp0START-RAH-BRIDGE-AUTOSTART.bat"
set "TASK_NAME=RAH Raven Bridge"
if not exist "%TARGET%" goto :missing

rem Raven Jobs needs an elevated inherited token. Elevate only the installer;
rem future logons run the task automatically with RunLevel Highest.
fltmc >nul 2>nul
if errorlevel 1 (
  echo RAH Raven AI Fabric trenger Administrator en gang for autostart.
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/d','/c','""%~f0""' -Verb RunAs"
  exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $target=(Resolve-Path -LiteralPath '%TARGET%').Path; $work=(Resolve-Path -LiteralPath '%~dp0').Path; $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name; $action=New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/d /c ""{0}""' -f $target) -WorkingDirectory $work; $trigger=New-ScheduledTaskTrigger -AtLogOn -User $user; $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest; $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -RestartCount 99 -RestartInterval (New-TimeSpan -Minutes 1); Register-ScheduledTask -TaskName '%TASK_NAME%' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'RAH Raven Bridge + Job Executor + AI Fabric' -Force | Out-Null; $startup=[Environment]::GetFolderPath('Startup'); $old=Join-Path $startup 'RAH Raven Bridge.lnk'; if(Test-Path -LiteralPath $old){ $backup='C:\RAH\Backups\AI-Fabric'; New-Item -ItemType Directory -Force -Path $backup | Out-Null; Copy-Item -LiteralPath $old -Destination (Join-Path $backup 'RAH Raven Bridge.legacy.lnk') -Force; Remove-Item -LiteralPath $old -Force }; Start-ScheduledTask -TaskName '%TASK_NAME%'; Write-Host 'RAH Raven AI Fabric autostart aktivert.'"
if errorlevel 1 goto :error

echo.
echo RAH Raven Bridge + Job Executor + AI Fabric er satt til autostart.
echo LM Studio og AnythingLLM auto-discovery er aktivert.
echo Ingen nettleser apnes automatisk.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Sleep -Seconds 3; try { $h=Invoke-RestMethod 'http://127.0.0.1:18765/health' -TimeoutSec 3; $a=Invoke-RestMethod 'http://127.0.0.1:18765/ai/providers' -TimeoutSec 5; Write-Host ('Bridge AI Fabric: ' + $h.ai_fabric); $a.providers | ForEach-Object { Write-Host ($_.id + ': online=' + $_.online + ' ready=' + $_.ready + ' - ' + $_.detail) } } catch { Write-Warning $_.Exception.Message }"
echo.
pause
exit /b 0

:missing
echo FEIL: START-RAH-BRIDGE-AUTOSTART.bat mangler.
pause
exit /b 2

:error
echo FEIL: Kunne ikke opprette elevated Scheduled Task.
pause
exit /b 1
