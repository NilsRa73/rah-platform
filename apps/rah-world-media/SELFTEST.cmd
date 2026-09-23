@echo off
setlocal
cd /d "%~dp0"
title RAH World Media v12.0 RAVEN SYNC DECK - SELFTEST
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_BOOTSTRAP.ps1" -SelfTest
exit /b %errorlevel%
