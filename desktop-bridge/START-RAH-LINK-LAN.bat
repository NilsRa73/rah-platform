@echo off
setlocal EnableExtensions DisableDelayedExpansion
cd /d "%~dp0"
title RAH Link LAN - RETIRED
color 0E

echo.
echo ================================================================
echo  RAH LINK LAN v1.4/v1.5 - RETIRED LEGACY UTILITY
echo ================================================================
echo.
echo Denne gamle LAN-launcheren er pensjonert og starter IKKE nettverk.
echo Den aapner IKKE Windows Firewall og starter IKKE server.py.
echo.
echo Aarsak:
echo Den gamle RAH Link-flaten hadde ingen current auth/pairing-lifecycle og
echo er ikke del av Raven 2.0.32 Stable-pakken.
echo.
echo Current lokal Raven Desktop Bridge bruker:
echo   desktop-bridge\start-bridge.bat
echo   http://127.0.0.1:18765
echo.
echo Hvis RAH Link over LAN skal gjenapnes senere, maa den faa en separat
echo Candidate-livssyklus med eksplisitt auth/pairing og egen sikkerhetsgate.
echo.
echo Ingen handling er utført.
echo.
pause
exit /b 2
