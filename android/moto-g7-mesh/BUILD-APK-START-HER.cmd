@echo off
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
color 0E
title RAH MOTO G7 MESH - APK BUILDER
cd /d "%~dp0"
echo ==========================================================
echo    RAH MOTO G7 MESH v1 - ANDROID APK BUILDER
 echo    Build only. Does not modify running RAH GOLD services.
echo ==========================================================
echo.
if not defined ANDROID_HOME set "ANDROID_HOME=%LOCALAPPDATA%\Android\Sdk"
if defined ANDROID_SDK_ROOT set "ANDROID_HOME=%ANDROID_SDK_ROOT%"
if not exist "%ANDROID_HOME%\platforms\android-35\android.jar" (
 echo BLOCKED: Android SDK API 35 is not installed.
 echo Open Android Studio - SDK Manager - install Android API 35.
 echo Official: https://developer.android.com/studio
 goto :FAIL
)
where java.exe >nul 2>&1
if errorlevel 1 (
 if exist "%ProgramFiles%\Android\Android Studio\jbr\bin\java.exe" set "JAVA_HOME=%ProgramFiles%\Android\Android Studio\jbr"
)
where java.exe >nul 2>&1
if errorlevel 1 if not exist "%JAVA_HOME%\bin\java.exe" (
 echo BLOCKED: Java 17 or newer is required.
 goto :FAIL
)
set "TOOLS=%LOCALAPPDATA%\RAH-MotoMesh-APK-Builder"
set "GRADLE=%TOOLS%\gradle-8.11.1\bin\gradle.bat"
if not exist "%GRADLE%" (
 echo Downloading official Gradle 8.11.1 to local user folder once...
 if not exist "%TOOLS%" mkdir "%TOOLS%"
 curl.exe -fL --retry 2 --connect-timeout 15 "https://services.gradle.org/distributions/gradle-8.11.1-bin.zip" -o "%TOOLS%\gradle.zip"
 if errorlevel 1 (echo BLOCKED: Gradle download failed.&goto :FAIL)
 set "EXPECTED=f397b287023acdba1e9f6fc5ea72d22dd63669d59ed4a289a29b1a76eee151c6"
 set "GOOD="
 for /f "tokens=*" %%H in ('certutil -hashfile "%TOOLS%\gradle.zip" SHA256 ^| findstr /R /I "^[a-f0-9][a-f0-9]*$"') do if /I "%%H"=="!EXPECTED!" set "GOOD=YES"
 if not defined GOOD (echo BLOCKED: Gradle checksum mismatch. File not used.&goto :FAIL)
 powershell.exe -NoProfile -NonInteractive -Command "Expand-Archive -LiteralPath '%TOOLS%\gradle.zip' -DestinationPath '%TOOLS%' -Force"
 if errorlevel 1 (echo BLOCKED: Could not extract Gradle.&goto :FAIL)
 del /q "%TOOLS%\gradle.zip" >nul 2>&1
)
if not exist "%GRADLE%" (echo BLOCKED: Gradle not found.&goto :FAIL)
echo Building APK with Gradle 8.11.1 + SDK 35...
call "%GRADLE%" --no-daemon :app:assembleDebug
if errorlevel 1 (echo FAILED: APK build failed. See errors above.&goto :FAIL)
if not exist "app\build\outputs\apk\debug\app-debug.apk" (
 echo BLOCKED: Gradle did not produce APK.&goto :FAIL
)
if not exist "apk" mkdir apk
copy /y "app\build\outputs\apk\debug\app-debug.apk" "apk\RAH-MOTO-G7-MESH-v1-debug.apk" >nul
if errorlevel 1 goto :FAIL
echo.
echo [PASS] APK created: %CD%\apk\RAH-MOTO-G7-MESH-v1-debug.apk
explorer.exe "%CD%\apk" >nul 2>&1
pause
exit /b 0
:FAIL
echo.
echo No APK created. No modifications to stable RAH services.
pause
exit /b 1
