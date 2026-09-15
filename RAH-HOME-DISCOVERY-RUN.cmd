@echo off
setlocal
cd /d "%~dp0"

set "RAH_RUNNER=%~dp0RAH-HOME-DISCOVERY-RUN.ps1"
set "RAH_RUNNER_URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-DISCOVERY-RUN.ps1"

where powershell.exe >nul 2>nul
if errorlevel 1 (
  echo [RAH] Fant ikke Windows PowerShell.
  pause
  exit /b 1
)

if exist "%RAH_RUNNER%" goto RUN

echo [RAH] Runner-script mangler lokalt. Henter stable versjon...

if not exist "C:\RAH\Home" mkdir "C:\RAH\Home" >nul 2>nul
if exist "C:\RAH\Home" (
  set "RAH_RUNNER=C:\RAH\Home\RAH-HOME-DISCOVERY-RUN.ps1"
) else (
  set "RAH_RUNNER=%LOCALAPPDATA%\RAH\Home\RAH-HOME-DISCOVERY-RUN.ps1"
  if not exist "%LOCALAPPDATA%\RAH\Home" mkdir "%LOCALAPPDATA%\RAH\Home" >nul 2>nul
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Invoke-WebRequest -UseBasicParsing -Uri '%RAH_RUNNER_URL%' -OutFile '%RAH_RUNNER%'; $t=Get-Content -LiteralPath '%RAH_RUNNER%' -Raw; if($t -notmatch 'RahRunnerVersion' -or $t -notmatch 'Invoke-RahHomeDiscoveryRunner'){Remove-Item -LiteralPath '%RAH_RUNNER%' -Force -ErrorAction SilentlyContinue; throw 'Downloaded runner failed RAH contract validation.'}"
if errorlevel 1 (
  echo [RAH] Kunne ikke hente eller validere Discovery Runner.
  pause
  exit /b 2
)

:RUN
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%RAH_RUNNER%" %*
set "RAH_EXIT=%ERRORLEVEL%"

if not "%RAH_EXIT%"=="0" (
  echo.
  echo [RAH] Discovery Runner feilet med kode %RAH_EXIT%.
  pause
)

exit /b %RAH_EXIT%
