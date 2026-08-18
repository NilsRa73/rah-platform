@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Raven Studio 2.9 Owned Windows Acceptance

set "BRIDGE_LAUNCHER=%~dp0desktop-bridge\start-bridge.bat"
set "BRIDGE_HEALTH=http://127.0.0.1:18765/health"
set "ACCEPT_PS1=%~dp0ACCEPT-RAH-RAVEN-STUDIO-2.9-CANDIDATE.ps1"

if /I "%~1"=="--self-test" goto :self_test

echo.
echo  RAH RAVEN STUDIO 2.9 - OWNED WINDOWS ACCEPTANCE
echo  ==================================================
echo  Dette promoterer aldri Stable automatisk.
echo.

where powershell.exe >nul 2>nul
if errorlevel 1 goto :no_powershell
if not exist "%ACCEPT_PS1%" goto :missing_acceptance
if not exist "%BRIDGE_LAUNCHER%" goto :missing_bridge_launcher

echo [1/3] Sjekker canonical Desktop Bridge pa 127.0.0.1:18765...
call :check_bridge
if not errorlevel 1 (
  echo       [PASS] Bridge + Council proxy svarer.
  goto :run_acceptance
)

echo [2/3] Bridge svarer ikke ennå. Starter fast canonical Bridge-launcher...
start "RAH Raven Desktop Bridge 18765" /min cmd.exe /d /c call "%BRIDGE_LAUNCHER%"

echo       Venter pa ekte health + council_proxy...
for /L %%G in (1,1,60) do (
  timeout /t 1 /nobreak >nul
  call :check_bridge
  if not errorlevel 1 goto :bridge_ready
)
goto :bridge_failed

:bridge_ready
echo       [PASS] Bridge health = OK.
echo       [PASS] Council proxy = OK.

:run_acceptance
echo [3/3] Starter Studio 2.9 acceptance...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ACCEPT_PS1%"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo Acceptance er ELIGIBLE for separat Stable review.
) else (
  echo Acceptance er ikke komplett. Stable forblir blokkert.
)
echo.
pause
exit /b %RC%

:check_bridge
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $h=Invoke-RestMethod -Method Get -Uri '%BRIDGE_HEALTH%' -TimeoutSec 2 -ErrorAction Stop; if($h.ok -eq $true -and $h.council_proxy -eq $true){exit 0}else{exit 2} } catch { exit 1 }"
exit /b %ERRORLEVEL%

:self_test
where powershell.exe >nul 2>nul
if errorlevel 1 exit /b 11
if not exist "%ACCEPT_PS1%" exit /b 12
if not exist "%BRIDGE_LAUNCHER%" exit /b 13
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$e=$null; [System.Management.Automation.Language.Parser]::ParseFile('%ACCEPT_PS1%',[ref]$null,[ref]$e)|Out-Null; if($e.Count -gt 0){exit 14}; exit 0"
if errorlevel 1 exit /b %ERRORLEVEL%
echo [PASS] Studio 2.9 launcher self-test: fixed acceptance + canonical Bridge launcher present.
exit /b 0

:bridge_failed
echo.
echo FEIL: Canonical Desktop Bridge svarte ikke med health.ok=true og council_proxy=true innen 60 sekunder.
echo Forventet endpoint: http://127.0.0.1:18765/health
echo Bridge-vinduet blir staende slik at eventuell Python-feil kan leses.
echo Studio acceptance startes IKKE.
pause
exit /b 3

:missing_bridge_launcher
echo FEIL: Mangler fast Bridge-launcher: desktop-bridge\start-bridge.bat
pause
exit /b 4

:missing_acceptance
echo FEIL: Mangler fast Studio acceptance PowerShell-script.
pause
exit /b 5

:no_powershell
echo FEIL: Windows PowerShell ble ikke funnet.
pause
exit /b 1
