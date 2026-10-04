@echo off
setlocal EnableExtensions
title RAH OS - OMEN HEALTHCHECK
set "ROOT=C:\RAH\RavenOS"
set "LOG=%ROOT%\logs\OMEN-HEALTHCHECK.txt"
if not exist "%ROOT%\logs" mkdir "%ROOT%\logs" >nul 2>&1
(
echo RAH OS OMEN HEALTHCHECK
echo =======================
echo DATE=%DATE% %TIME%
echo COMPUTER=%COMPUTERNAME%
echo USER=%USERNAME%
ver
echo.
echo [NETWORK]
ping -n 1 1.1.1.1
echo.
echo [RAVEN BRIDGE 18765]
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "try{$r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:18765/' -TimeoutSec 3; 'HTTP='+$r.StatusCode; exit 0}catch{'OFFLINE';exit 1}"
echo.
echo [LOCAL AI / LM STUDIO 1234]
powershell.exe -NoLogo -NoProfile -NonInteractive -Command "try{$r=Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:1234/v1/models' -TimeoutSec 3; 'HTTP='+$r.StatusCode; exit 0}catch{'NOT RUNNING - optional';exit 0}"
echo.
echo [BLUETOOTH SERVICE]
sc query bthserv
echo.
echo [AUDIO SERVICE]
sc query Audiosrv
echo.
echo [DISKS]
wmic logicaldisk get DeviceID,FileSystem,FreeSpace,Size,VolumeName
echo.
echo [RAH ROOT]
dir /b "%ROOT%"
) > "%LOG%" 2>&1
type "%LOG%"
echo.
echo Rapport: %LOG%
exit /b 0
