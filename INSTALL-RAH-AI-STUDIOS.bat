@echo off
setlocal EnableExtensions
title RAH AI Studios - First-time installer

echo.
echo  RAH AI STUDIOS - ENKEL INSTALLASJON
echo  ====================================
echo.
echo Lager en egen RAH AI Studios-mappe pa skrivebordet,
echo henter siste installasjon fra GitHub og lager en startsnarvei.
echo.

set "PS1=%TEMP%\INSTALL-RAH-AI-STUDIOS-%RANDOM%.ps1"
set "URL=https://raw.githubusercontent.com/NilsRa73/rah-platform/main/INSTALL-RAH-AI-STUDIOS.ps1"

powershell -NoProfile -ExecutionPolicy Bypass -Command "[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%URL%' -OutFile '%PS1%'; if((Get-Item '%PS1%').Length -lt 1){throw 'Installer download was empty'}"
if errorlevel 1 goto :error

powershell -NoProfile -ExecutionPolicy Bypass -File "%PS1%"
set "RC=%ERRORLEVEL%"
del "%PS1%" >nul 2>nul
if not "%RC%"=="0" goto :error

echo.
echo  FERDIG.
echo  Du skal na ha:
echo    - mappen "RAH AI Studios" pa skrivebordet
echo    - snarveien "RAH AI Studios"
echo    - filen "00-START-HER.txt" med enkel oversikt
echo.
pause
exit /b 0

:error
echo.
echo  FEIL: RAH AI Studios kunne ikke installeres ferdig.
echo  Ingen eksisterende RAH-mappe slettes av installasjonen.
echo  Kopier feilmeldingen over og lim den inn i ChatGPT.
echo.
pause
exit /b 1
