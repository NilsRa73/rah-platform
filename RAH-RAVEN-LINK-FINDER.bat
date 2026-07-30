@echo off
setlocal
cd /d "%~dp0"
title RAH Raven Link Finder
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0RAH-RAVEN-LINK-FINDER.ps1"
if errorlevel 1 pause
