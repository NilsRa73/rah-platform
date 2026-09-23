@echo off
setlocal
title RAH World Media 12.0 - UNINSTALL PROGRAM
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='SilentlyContinue'; $d='C:\RAH\WorldMedia\12.0'; Remove-Item $d -Recurse -Force; Remove-Item ([IO.Path]::Combine([Environment]::GetFolderPath('Desktop'),'RAH World Media 12.0.lnk')) -Force; Remove-Item ([IO.Path]::Combine($env:APPDATA,'Microsoft\Windows\Start Menu\Programs\RAH\RAH World Media 12.0.lnk')) -Force; Write-Host 'Program removed. C:\RAH\IPTV user data/favorites were preserved.'"
pause
