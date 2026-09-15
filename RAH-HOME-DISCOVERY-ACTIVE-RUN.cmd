@echo off
setlocal
cd /d "%~dp0"

set "RAH_RUNNER=%~dp0RAH-HOME-DISCOVERY-ACTIVE-RUN.ps1"
set "RAH_RUNNER_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-DISCOVERY-ACTIVE-RUN.ps1"

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo [RAH] Windows PowerShell was not found.
  pause
  exit /b 1
)

if exist "%RAH_RUNNER%" goto RUN

echo [RAH] Active Discovery Runner is missing. Downloading stable version...
if not exist "C:\RAH\Home" mkdir "C:\RAH\Home" >nul 2>nul
if exist "C:\RAH\Home" (
  set "RAH_RUNNER=C:\RAH\Home\RAH-HOME-DISCOVERY-ACTIVE-RUN.ps1"
) else (
  set "RAH_RUNNER=%LOCALAPPDATA%\RAH\Home\RAH-HOME-DISCOVERY-ACTIVE-RUN.ps1"
  if not exist "%LOCALAPPDATA%\RAH\Home" mkdir "%LOCALAPPDATA%\RAH\Home" >nul 2>nul
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Invoke-WebRequest -UseBasicParsing -Uri '%RAH_RUNNER_URL%' -OutFile '%RAH_RUNNER%'; $t=Get-Content -LiteralPath '%RAH_RUNNER%' -Raw; if($t -notmatch 'RahActiveRunnerVersion' -or $t -notmatch 'Test-RahActiveConsent' -or $t -notmatch 'Invoke-RahActiveDiscoveryRunner'){Remove-Item -LiteralPath '%RAH_RUNNER%' -Force -ErrorAction SilentlyContinue; throw 'Downloaded runner failed RAH contract validation.'}"
if errorlevel 1 (
  echo [RAH] Could not download or validate Active Discovery Runner.
  pause
  exit /b 2
)

:RUN
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RAH_RUNNER%" %*
set "RAH_EXIT=%ERRORLEVEL%"
if not "%RAH_EXIT%"=="0" (
  echo.
  echo [RAH] Active Discovery Runner failed with code %RAH_EXIT%.
  pause
)
exit /b %RAH_EXIT%
