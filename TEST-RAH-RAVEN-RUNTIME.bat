@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title RAH Raven Daily Driver Runtime Acceptance

set "APP=%~dp0apps\rah-raven-daily-driver"
set "GATE=%APP%\RUNTIME-GATE-RAH-RAVEN.bat"
set "EVIDENCE=%~dp0EXPORT-RAH-RAVEN-RUNTIME-EVIDENCE.bat"
set "VALIDATOR=%~dp0VALIDATE-RAH-RAVEN-RUNTIME-EVIDENCE.bat"

if not exist "%GATE%" (
  echo ERROR: Runtime Gate was not found:
  echo %GATE%
  exit /b 1
)
if not exist "%EVIDENCE%" (
  echo ERROR: Runtime Evidence exporter was not found:
  echo %EVIDENCE%
  exit /b 1
)
if not exist "%VALIDATOR%" (
  echo ERROR: Runtime Evidence validator was not found:
  echo %VALIDATOR%
  exit /b 1
)

echo ================================================================
echo RAH RAVEN - ONE-CLICK WINDOWS RUNTIME ACCEPTANCE
echo ================================================================
echo Stable promotion is always blocked by this runner.
echo.

set "RAH_RAVEN_NONINTERACTIVE=1"
if "%~1"=="" (
  call "%GATE%"
) else (
  call "%GATE%" "%~1"
)
set "GATE_RC=%ERRORLEVEL%"
set "RAH_RAVEN_NONINTERACTIVE="

echo.
call "%EVIDENCE%"
set "EVIDENCE_RC=%ERRORLEVEL%"
if not "%EVIDENCE_RC%"=="0" (
  echo.
  echo [RAH Raven] Runtime Evidence export failed. Gate result is preserved.
  exit /b 1
)

set "LATEST="
for /f "delims=" %%F in ('dir /b /a-d /o-d "%APP%\runtime\exports\RAH-Raven-Runtime-Evidence-*.zip" 2^>nul') do if not defined LATEST set "LATEST=%APP%\runtime\exports\%%F"
if not defined LATEST (
  echo.
  echo [RAH Raven] Evidence export reported success but no evidence ZIP was found.
  exit /b 1
)

echo.
call "%VALIDATOR%" "%LATEST%"
set "VALIDATOR_RC=%ERRORLEVEL%"
set "READINESS=%LATEST:.zip=.readiness.json%"

echo.
echo ================================================================
echo RAH RAVEN - ACCEPTANCE SUMMARY
echo ================================================================
echo Runtime Gate exit code : %GATE_RC%
echo Evidence ZIP           : %LATEST%
echo Readiness JSON         : %READINESS%
echo Validator exit code    : %VALIDATOR_RC%
echo Stable promotion       : BLOCKED
echo.

if not "%GATE_RC%"=="0" exit /b 1
if "%VALIDATOR_RC%"=="1" exit /b 1
if "%VALIDATOR_RC%"=="2" exit /b 2
if "%VALIDATOR_RC%"=="0" exit /b 0
exit /b 1
