@echo off
setlocal EnableExtensions DisableDelayedExpansion
chcp 65001 >nul 2>nul
title RAH Raven v2 - One Click Autofix
color 0E

set "RAH_COMMIT=caccca86247dd5a342334a7509e9edc3a57a50d4"
set "RAH_ROOT=%LOCALAPPDATA%\RAH\Raven"
set "RAH_RAW=https://raw.githubusercontent.com/NilsRa73/rah-platform/%RAH_COMMIT%"
set "RAH_UPDATER=%RAH_ROOT%\UPDATE-RAH-RAVEN.ps1"
set "RAH_STARTER=%RAH_ROOT%\UPDATE-AND-START-RAH-RAVEN.bat"
set "RAH_LOG=%RAH_ROOT%\install-one-click-v2.log"

echo.
echo ================================================================
echo          RAH RAVEN v2 - ONE CLICK AUTOFIX FOR WINDOWS
echo ================================================================
echo.
echo Mappen blir: %RAH_ROOT%
echo Ingen Git eller WinGet er nodvendig.
echo.

if not exist "%RAH_ROOT%" mkdir "%RAH_ROOT%" >nul 2>nul
if not exist "%RAH_ROOT%" goto :folder_error
>"%RAH_LOG%" echo [%date% %time%] RAH Raven v2 startet.
>>"%RAH_LOG%" echo Kilde-commit: %RAH_COMMIT%

echo [1/5] Tester internett mot GitHub...
call :download "%RAH_RAW%/UPDATE-RAH-RAVEN.ps1" "%RAH_UPDATER%"
if errorlevel 1 goto :download_error

echo [2/5] Henter Raven-starter...
call :download "%RAH_RAW%/UPDATE-AND-START-RAH-RAVEN.bat" "%RAH_STARTER%"
if errorlevel 1 goto :download_error

echo [3/5] Kontrollerer filidentitet...
findstr /C:"RAH Raven sikker oppdatering" "%RAH_UPDATER%" >nul 2>nul
if errorlevel 1 (
  >>"%RAH_LOG%" echo FEIL: Updater-identiteten mangler.
  goto :identity_error
)
findstr /C:"RAH RAVEN - UPDATE AND START" "%RAH_STARTER%" >nul 2>nul
if errorlevel 1 (
  >>"%RAH_LOG%" echo FEIL: Starter-identiteten mangler.
  goto :identity_error
)
>>"%RAH_LOG%" echo Bootstrap-filer: VERIFIED

echo [4/5] Lager skrivebordssnarvei...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';$d=[Environment]::GetFolderPath('Desktop');$w=New-Object -ComObject WScript.Shell;$s=$w.CreateShortcut((Join-Path $d 'RAH Raven.lnk'));$s.TargetPath='%RAH_STARTER%';$s.WorkingDirectory='%RAH_ROOT%';$s.Description='Oppdater og start RAH Raven';$s.Save()" >>"%RAH_LOG%" 2>&1
if errorlevel 1 (
  echo       Snarvei hoppet over. Raven kan fortsatt installeres.
) else (
  echo       Skrivebordssnarvei opprettet.
)

echo [5/5] Oppdaterer og starter Raven...
echo       Svar JA pa Windows Administrator-sporsmalet.
call "%RAH_STARTER%"
set "RAH_RC=%ERRORLEVEL%"
if not "%RAH_RC%"=="0" goto :raven_error

>>"%RAH_LOG%" echo [%date% %time%] FULLFORT - Raven startet.
echo.
echo ================================================================
echo  FERDIG - RAH RAVEN ER INSTALLERT OG STARTET
echo ================================================================
timeout /t 4 /nobreak >nul
exit /b 0

:download
set "DL_URL=%~1"
set "DL_TARGET=%~2"
set "DL_TEMP=%~2.download"
del "%DL_TEMP%" >nul 2>nul

where curl.exe >nul 2>nul
if not errorlevel 1 (
  curl.exe -fL --retry 3 --retry-delay 2 --connect-timeout 20 --max-time 120 -o "%DL_TEMP%" "%DL_URL%" >>"%RAH_LOG%" 2>&1
  if not errorlevel 1 goto :download_validate
  >>"%RAH_LOG%" echo curl feilet. Prover PowerShell-reserve.
)

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop';[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;Invoke-WebRequest -UseBasicParsing -Uri '%DL_URL%' -OutFile '%DL_TEMP%' -TimeoutSec 120" >>"%RAH_LOG%" 2>&1
if errorlevel 1 exit /b 1

:download_validate
if not exist "%DL_TEMP%" exit /b 1
for %%A in ("%DL_TEMP%") do if %%~zA LSS 100 exit /b 1
move /Y "%DL_TEMP%" "%DL_TARGET%" >nul
if errorlevel 1 exit /b 1
>>"%RAH_LOG%" echo Lastet ned: %DL_TARGET%
exit /b 0

:folder_error
echo FEIL: Kunne ikke opprette installasjonsmappen.
echo Mappe: %RAH_ROOT%
pause
exit /b 2

:download_error
del "%RAH_UPDATER%.download" >nul 2>nul
del "%RAH_STARTER%.download" >nul 2>nul
echo.
echo FEIL: GitHub-nedlastingen feilet med bade curl og PowerShell.
echo Logg: %RAH_LOG%
echo Eksisterende Raven-filer ble ikke slettet.
pause
exit /b 3

:identity_error
echo.
echo FEIL: Nedlastede filer hadde ikke forventet Raven-identitet.
echo Ingen ukjent kode ble startet.
echo Logg: %RAH_LOG%
pause
exit /b 4

:raven_error
>>"%RAH_LOG%" echo Raven returnerte feilkode %RAH_RC%.
echo.
echo FEIL: Raven returnerte feilkode %RAH_RC%.
echo Hovedlogg: %RAH_ROOT%\rah-raven-update.log
echo Installerlogg: %RAH_LOG%
echo Vinduet holdes apent slik at feilen kan fotograferes.
pause
exit /b %RAH_RC%
