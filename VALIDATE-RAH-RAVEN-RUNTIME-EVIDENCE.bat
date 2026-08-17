@echo off
setlocal EnableExtensions
cd /d "%~dp0"

set "EVIDENCE=%~1"
if not defined EVIDENCE (
  for /f "delims=" %%F in ('dir /b /a-d /o-d "apps\rah-raven-daily-driver\runtime\exports\RAH-Raven-Runtime-Evidence-*.zip" 2^>nul') do (
    set "EVIDENCE=apps\rah-raven-daily-driver\runtime\exports\%%F"
    goto :found
  )
)

:found
if not defined EVIDENCE (
  echo [RAH Raven] No Runtime Evidence ZIP found.
  echo Usage: VALIDATE-RAH-RAVEN-RUNTIME-EVIDENCE.bat "C:\path\to\RAH-Raven-Runtime-Evidence-*.zip"
  exit /b 2
)

if not exist "%EVIDENCE%" (
  echo [RAH Raven] Evidence ZIP not found: %EVIDENCE%
  exit /b 2
)

where python >nul 2>&1
if errorlevel 1 (
  echo [RAH Raven] Python 3 was not found on PATH.
  exit /b 2
)

echo ================================================================
echo RAH RAVEN - RUNTIME EVIDENCE VALIDATOR
echo ================================================================
echo Evidence: %EVIDENCE%
python "apps\rah-raven-daily-driver\evidence_validator.py" "%EVIDENCE%"
set "RC=%ERRORLEVEL%"

echo.
if "%RC%"=="0" echo [RAH Raven] Automated evidence is eligible for Runtime Test review. Stable remains blocked.
if "%RC%"=="1" echo [RAH Raven] Evidence validation failed or Runtime Test is blocked.
if "%RC%"=="2" echo [RAH Raven] Evidence is valid but Runtime Test remains pending.
exit /b %RC%
