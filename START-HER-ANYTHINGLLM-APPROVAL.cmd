@echo off
setlocal EnableExtensions
title RAH AnythingLLM Approval - START HER
cd /d "%~dp0"

if /I "%~1"=="--self-test" goto SELFTEST

set "RAH_TEST=%~dp0TEST-ANYTHINGLLM-APPROVAL.ps1"
if not exist "%RAH_TEST%" set "RAH_TEST=C:\RAH\TEST-ANYTHINGLLM-APPROVAL.ps1"

set "RAH_CONFIG=%~dp0CONFIGURE-RAH-PROJECT-MEMORY.cmd"
if not exist "%RAH_CONFIG%" set "RAH_CONFIG=C:\RAH\CONFIGURE-RAH-PROJECT-MEMORY.cmd"

if not exist "%RAH_TEST%" goto FAIL_TEST_MISSING

echo [RAH] Starter/verifiserer lokale Raven-tjenester...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "foreach($n in @('RAH Raven AI Providers','RAH Raven Bridge')){try{if(Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue){Start-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue}}catch{}}"
timeout /t 2 /nobreak >nul

if not exist "C:\RAH\AI-Fabric\project-memory.json" goto CONFIGURE
if not exist "C:\RAH\AI-Fabric\Secrets\anythingllm-token.txt" goto CONFIGURE

:RUNTEST
echo.
echo [RAH] Tester AnythingLLM -^> APPROVE -^> Raven Job Executor -^> system-inventory...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_TEST%"
set "RAH_EXIT=%ERRORLEVEL%"
if "%RAH_EXIT%"=="10" goto CONFIGURE
if not "%RAH_EXIT%"=="0" goto FAIL_RUNTIME

echo.
echo =============================================================
echo RAH ANYTHINGLLM APPROVAL: PASS / READY
echo Ingen tastaturgodkjenning kreves for allowlistede read-only jobber.
echo Rapport: C:\RAH\AI-Fabric\anythingllm-approval-test.json
echo =============================================================
pause
exit /b 0

:CONFIGURE
echo.
echo [RAH] AnythingLLM trenger engangsoppsett.
echo [RAH] API-tokenet skal bare limes inn lokalt - aldri i ChatGPT eller GitHub.
if not exist "%RAH_CONFIG%" goto FAIL_CONFIG_MISSING
call "%RAH_CONFIG%"
if errorlevel 1 goto FAIL_CONFIG
echo.
echo [RAH] Starter Raven Bridge pa nytt for a lese delt Project Memory-konfig...
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "try{if(Get-ScheduledTask -TaskName 'RAH Raven Bridge' -ErrorAction SilentlyContinue){Start-ScheduledTask -TaskName 'RAH Raven Bridge' -ErrorAction SilentlyContinue}}catch{}"
timeout /t 3 /nobreak >nul
goto RUNTEST

:SELFTEST
if not exist "%~dp0TEST-ANYTHINGLLM-APPROVAL.ps1" exit /b 31
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0TEST-ANYTHINGLLM-APPROVAL.ps1" -SelfTest
exit /b %ERRORLEVEL%

:FAIL_TEST_MISSING
echo [RAH] FAIL: TEST-ANYTHINGLLM-APPROVAL.ps1 ble ikke funnet.
pause
exit /b 21

:FAIL_CONFIG_MISSING
echo [RAH] FAIL: CONFIGURE-RAH-PROJECT-MEMORY.cmd ble ikke funnet.
pause
exit /b 22

:FAIL_CONFIG
echo [RAH] FAIL: AnythingLLM Project Memory-oppsett feilet.
pause
exit /b 23

:FAIL_RUNTIME
echo [RAH] FAIL: AnythingLLM approval end-to-end-test feilet. Kode %RAH_EXIT%.
echo [RAH] Ingen usikre fallback-kommandoer ble kjort.
pause
exit /b %RAH_EXIT%
