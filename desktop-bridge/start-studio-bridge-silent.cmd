@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"

rem RAH Raven Studio hidden Bridge bootstrap v1.
rem Non-interactive. No PowerShell. Only loopback 127.0.0.1:18765 is inspected.
set "HEALTH=http://127.0.0.1:18765/health"
set "HEALTH_FILE=%TEMP%\rah-studio-health-%RANDOM%.json"
set "LOG=%LOCALAPPDATA%\RAH-Raven\Studio\bridge.log"
set "ERR=%LOCALAPPDATA%\RAH-Raven\Studio\bridge.err.log"
set "VENV=%~dp0.venv\Scripts\python.exe"
set "BRIDGE=raven_bridge.py"

if not exist "%LOCALAPPDATA%\RAH-Raven\Studio" mkdir "%LOCALAPPDATA%\RAH-Raven\Studio" >nul 2>nul

call :health
if defined READY exit /b 0

rem If something already answers on 18765, replace it only when it identifies as Raven.
if "%ANSWERED%"=="1" (
  findstr /I /C:"RAH Raven Desktop Bridge" "%HEALTH_FILE%" >nul 2>nul
  if errorlevel 1 exit /b 6
  for /f "tokens=5" %%P in ('netstat -ano ^| findstr /R /C:":18765 .*LISTENING"') do (
    taskkill /PID %%P /F >nul 2>nul
  )
  timeout /t 1 /nobreak >nul
)

if not exist "%BRIDGE%" exit /b 2
if not exist "app_launcher.py" exit /b 2
if not exist "requirements.txt" exit /b 2

if not exist "%VENV%" (
  where py >nul 2>nul
  if not errorlevel 1 (
    py -m venv ".venv" >"%LOG%" 2>"%ERR%"
  ) else (
    where python >nul 2>nul
    if errorlevel 1 exit /b 3
    python -m venv ".venv" >"%LOG%" 2>"%ERR%"
  )
  if errorlevel 1 exit /b 4
)

"%VENV%" -c "import flask, flask_cors, PIL, mss, pypdf" >nul 2>nul
if errorlevel 1 (
  "%VENV%" -m pip install --disable-pip-version-check --quiet -r requirements.txt >>"%LOG%" 2>>"%ERR%"
  if errorlevel 1 exit /b 4
)

"%VENV%" -m py_compile server_v16.py server_v17.py app_launcher.py raven_bridge.py agent_runner.py anythingllm_approval.py >>"%LOG%" 2>>"%ERR%"
if errorlevel 1 exit /b 5

start "" /b "%VENV%" "%~dp0%BRIDGE%" >>"%LOG%" 2>>"%ERR%"

for /L %%G in (1,1,25) do (
  timeout /t 1 /nobreak >nul
  call :health
  if defined READY exit /b 0
)

exit /b 7

:health
set "READY="
set "ANSWERED=0"
del "%HEALTH_FILE%" >nul 2>nul
curl.exe -fsS --max-time 2 "%HEALTH%" -o "%HEALTH_FILE%" >nul 2>nul
if errorlevel 1 exit /b 0
set "ANSWERED=1"
findstr /I /C:"app_launcher" "%HEALTH_FILE%" >nul 2>nul
if errorlevel 1 exit /b 0
findstr /I /C:"agent_runner" "%HEALTH_FILE%" >nul 2>nul
if errorlevel 1 exit /b 0
findstr /I /C:"anythingllm_approval_gate" "%HEALTH_FILE%" >nul 2>nul
if errorlevel 1 exit /b 0
set "READY=1"
exit /b 0
