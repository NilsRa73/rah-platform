@echo off
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0\..\.."

set "BRIDGE_DIR=%CD%\desktop-bridge"
set "VENV_DIR=!BRIDGE_DIR!\.venv"
set "VENV_PY=!VENV_DIR!\Scripts\python.exe"
set "BASEPY="
set "SELECTED="

for %%V in (3.13 3.12 3.11) do (
  if not defined BASEPY (
    py -%%V -c "import sys; print(sys.executable)" > "%TEMP%\rah-python-probe.txt" 2>nul
    if not errorlevel 1 (
      set "BASEPY=py -%%V"
      for /f "usebackq delims=" %%P in ("%TEMP%\rah-python-probe.txt") do if not defined SELECTED set "SELECTED=%%P"
    )
  )
)

if not defined BASEPY (
  where py >nul 2>nul
  if not errorlevel 1 (
    set "BASEPY=py"
    for /f "delims=" %%P in ('py -c "import sys; print(sys.executable)" 2^>nul') do if not defined SELECTED set "SELECTED=%%P"
  )
)

if not defined BASEPY (
  where python >nul 2>nul
  if not errorlevel 1 (
    set "BASEPY=python"
    for /f "delims=" %%P in ('python -c "import sys; print(sys.executable)" 2^>nul') do if not defined SELECTED set "SELECTED=%%P"
  )
)

if not defined BASEPY (
  echo [FAIL] No working Python was found for Raven Bridge.
  exit /b 1
)

echo [INFO] Raven Bridge Python: !SELECTED!

set "VENV_OK=0"
if exist "!VENV_PY!" (
  "!VENV_PY!" -c "import sys; print(sys.executable)" >nul 2>nul
  if not errorlevel 1 set "VENV_OK=1"
)

if "!VENV_OK!"=="0" (
  if exist "!VENV_DIR!" (
    for /f %%T in ('powershell.exe -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%T"
    set "ARCHIVE=!BRIDGE_DIR!\.venv-broken-!STAMP!"
    echo [REPAIR] Stale Raven .venv detected. Archiving to:
    echo          !ARCHIVE!
    move "!VENV_DIR!" "!ARCHIVE!" >nul
    if errorlevel 1 (
      echo [FAIL] Could not archive the stale Raven .venv.
      exit /b 1
    )
  )

  pushd "!BRIDGE_DIR!"
  !BASEPY! -m venv .venv
  set "RC=!ERRORLEVEL!"
  popd
  if not "!RC!"=="0" (
    echo [FAIL] Could not create a fresh Raven .venv.
    exit /b 1
  )
  echo [PASS] Fresh Raven .venv created.
) else (
  echo [PASS] Existing Raven .venv is healthy.
)

if /I "%~1"=="--check" (
  echo [PASS] Raven Bridge environment check complete.
  exit /b 0
)

pushd "!BRIDGE_DIR!"
"!VENV_PY!" -m pip install --disable-pip-version-check --quiet -r requirements.txt
set "RC=!ERRORLEVEL!"
popd
if not "!RC!"=="0" (
  echo [FAIL] Raven Bridge dependencies could not be validated.
  exit /b 1
)

echo [PASS] Raven Bridge dependencies validated.
exit /b 0
