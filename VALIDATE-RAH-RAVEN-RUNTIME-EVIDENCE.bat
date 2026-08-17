@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "APP=%~dp0apps\rah-raven-daily-driver"
set "SCRIPT=%APP%\evidence_validator.py"
set "PY=%APP%\.venv\Scripts\python.exe"
set "EVIDENCE=%~1"

if not exist "%SCRIPT%" (
  echo [RAH Raven] Evidence validator script was not found: %SCRIPT%
  exit /b 1
)

if not exist "%PY%" (
  where python >nul 2>&1
  if errorlevel 1 (
    echo [RAH Raven] Python 3 was not found. Run INSTALL-RAH-RAVEN.bat first.
    exit /b 2
  )
  set "PY=python"
)

if not defined EVIDENCE (
  for /f "delims=" %%F in ('dir /b /a-d /o-d "%APP%\runtime\exports\RAH-Raven-Runtime-Evidence-*.zip" 2^>nul') do if not defined EVIDENCE set "EVIDENCE=%APP%\runtime\exports\%%F"
)

if not defined EVIDENCE (
  echo [RAH Raven] No Runtime Evidence ZIP found.
  echo Usage: VALIDATE-RAH-RAVEN-RUNTIME-EVIDENCE.bat "C:\path\to\RAH-Raven-Runtime-Evidence-*.zip"
  exit /b 2
)

if not exist "%EVIDENCE%" (
  echo [RAH Raven] Evidence ZIP not found: %EVIDENCE%
  exit /b 2
)

echo ================================================================
echo RAH RAVEN - RUNTIME EVIDENCE VALIDATOR
echo ================================================================
echo Evidence: %EVIDENCE%
"%PY%" "%SCRIPT%" "%EVIDENCE%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" echo [RAH Raven] Automated evidence is eligible for Runtime Test review. Stable remains blocked.
if "%RC%"=="1" echo [RAH Raven] Evidence validation failed or Runtime Test is blocked.
if "%RC%"=="2" echo [RAH Raven] Evidence is valid but Runtime Test remains pending.
exit /b %RC%
