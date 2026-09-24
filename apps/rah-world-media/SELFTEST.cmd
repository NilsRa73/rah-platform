@echo off
setlocal
cd /d "%~dp0"
title RAH World Media v14.0 RAVEN SMART CLUSTER - SELFTEST
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH_BOOTSTRAP.ps1" -SelfTest
exit /b %errorlevel%
