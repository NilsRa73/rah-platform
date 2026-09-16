@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Bridge Autostart Installer v2

set "TARGET=%~dp0START-RAH-BRIDGE-AUTOSTART.bat"
set "TASK_NAME=RAH Raven Bridge"
if not exist "%TARGET%" goto :missing

rem The queued Job Executor requires Administrator on Windows. Elevate once while
rem installing the scheduled task; future logons run it with RunLevel Highest.
fltmc >nul 2>nul
if errorlevel 1 (
  echo.
  echo RAH autostart trenger Administrator for aa installere elevated Scheduled Task.
  echo Ber om UAC...
  powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath 'cmd.exe' -ArgumentList '/d','/c','""%~f0""' -Verb RunAs"
  exit /b
)

fltmc >nul 2>nul
if errorlevel 1 goto :admin_error

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $target=(Resolve-Path -LiteralPath '%TARGET%').Path; $work=(Resolve-Path -LiteralPath '%~dp0').Path; $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name; $action=New-ScheduledTaskAction -Execute 'cmd.exe' -Argument ('/d /c ""{0}""' -f $target) -WorkingDirectory $work; $trigger=New-ScheduledTaskTrigger -AtLogOn -User $user; $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest; $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew; Register-ScheduledTask -TaskName '%TASK_NAME%' -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description 'Start elevated RAH Raven Bridge + queued Job Executor at Windows logon' -Force | Out-Null; $startup=[Environment]::GetFolderPath('Startup'); $old=Join-Path $startup 'RAH Raven Bridge.lnk'; if(Test-Path -LiteralPath $old){ Remove-Item -LiteralPath $old -Force }; Start-ScheduledTask -TaskName '%TASK_NAME%'; Write-Host ('RAH elevated autostart aktivert: Task Scheduler -> %TASK_NAME%')"
if errorlevel 1 goto :error

echo.
echo RAH Raven Bridge + Job Executor starter heretter elevated ved Windows-innlogging.
echo Den gamle unelevated Startup-linken er fjernet hvis den fantes.
echo Ingen nettleser apnes automatisk av autostart.
echo.
pause
exit /b 0

:missing
echo FEIL: START-RAH-BRIDGE-AUTOSTART.bat mangler.
pause
exit /b 2

:admin_error
echo FEIL: Administrator-token mangler etter UAC.
pause
exit /b 5

:error
echo FEIL: Kunne ikke opprette elevated Windows Scheduled Task.
pause
exit /b 1
