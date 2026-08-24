@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Bridge Autostart Installer

set "TARGET=%~dp0START-RAH-BRIDGE-AUTOSTART.bat"
if not exist "%TARGET%" goto :missing

powershell -NoProfile -ExecutionPolicy Bypass -Command "$startup=[Environment]::GetFolderPath('Startup'); $lnk=Join-Path $startup 'RAH Raven Bridge.lnk'; $ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut($lnk); $s.TargetPath='%TARGET%'; $s.WorkingDirectory='%~dp0'; $s.WindowStyle=7; $s.Description='Start RAH Raven Bridge silently at Windows logon'; $s.Save(); Write-Host ('RAH autostart aktivert: ' + $lnk)"
if errorlevel 1 goto :error

echo.
echo RAH Raven Bridge starter heretter stille ved Windows-innlogging.
echo Ingen nettleser apnes automatisk.
echo Bruk ChatGPT ^> RAH Wheel ^> Home Control som normal inngang.
echo.
pause
exit /b 0

:missing
echo FEIL: START-RAH-BRIDGE-AUTOSTART.bat mangler.
pause
exit /b 1

:error
echo FEIL: Kunne ikke opprette Windows-autostart.
pause
exit /b 1
