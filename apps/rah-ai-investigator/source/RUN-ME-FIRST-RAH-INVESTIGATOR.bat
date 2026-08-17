@echo off
setlocal EnableExtensions DisableDelayedExpansion
title RAH AI Investigator v1.0 RC2
set "ROOT=%~dp0"

if not exist "%ROOT%CHECK-RAH-INVESTIGATOR.ps1" goto :missing
if not exist "%ROOT%RAH-AI-INVESTIGATOR.html" goto :missing

powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%CHECK-RAH-INVESTIGATOR.ps1"
if errorlevel 1 goto :checkfail

start "RAH AI Investigator" "%ROOT%RAH-AI-INVESTIGATOR.html"
exit /b 0

:missing
echo ERROR: Required Investigator files are missing from this folder.
exit /b 2

:checkfail
echo ERROR: Investigator local self-check failed. Nothing was opened.
exit /b 3
