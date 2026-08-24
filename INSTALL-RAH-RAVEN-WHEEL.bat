@echo off
setlocal
cd /d "%~dp0"
title Install RAH Raven Wheel v1

echo.
echo  RAH RAVEN WHEEL v1 - ONE TIME SETUP
echo  ===================================
echo.
echo  This opens the Raven Wheel userscript in your browser.
echo  Tampermonkey will ask you to approve the installation once.
echo.

start "" "https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-RAVEN-WHEEL.user.js"

echo  Browser opened.
echo  1. Press Install in Tampermonkey.
echo  2. Start RAH Raven with START-RAH-RAVEN-V2.bat.
echo  3. Reload ChatGPT.
echo  4. The gold Raven button appears at the bottom-right.
echo.
echo  After setup, ChatGPT downloads registered by Raven Wheel are moved to:
echo  Documents\RAH-Raven-Vault\YYYY\MM\DD

echo.
pause
