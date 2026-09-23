@echo off
setlocal EnableExtensions
title RAH OS Raven v0.3 - Join and Verify

echo.
echo ============================================================
echo       RAH OS RAVEN v0.3 - JOIN AND VERIFY
echo ============================================================
echo.
echo Put this CMD file in the same folder as all
echo RAH-OS-Raven-v0.3-drive-part-XX.zip files, then double-click.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ErrorActionPreference='Stop';" ^
  "$root=[IO.Path]::GetFullPath('%~dp0');" ^
  "$expected='4aa34c3d72a8319e006c4eeb0a30f19a5b296fc39f9484a4270ace60f1177910';" ^
  "$out=Join-Path $root 'RAH-OS-Raven-v0.3-amd64.iso';" ^
  "$tmp=Join-Path $env:TEMP ('RAH-OS-v03-'+[guid]::NewGuid().ToString('N'));" ^
  "New-Item -ItemType Directory -Path $tmp -Force|Out-Null;" ^
  "try {" ^
  "  $zips=@(Get-ChildItem -LiteralPath $root -File -Filter 'RAH-OS-Raven-v0.3-drive-part-*.zip'|Sort-Object Name);" ^
  "  if($zips.Count -ne 9){throw ('Expected 9 part ZIP files, found '+$zips.Count+'. Download all 9 parts.');}" ^
  "  foreach($z in $zips){Write-Host ('EXTRACT '+$z.Name); Expand-Archive -LiteralPath $z.FullName -DestinationPath $tmp -Force;}" ^
  "  $parts=@(Get-ChildItem -LiteralPath $tmp -File -Filter 'RAH-OS-Raven-v0.3-amd64.part-*.bin'|Sort-Object Name);" ^
  "  if($parts.Count -ne 9){throw ('Expected 9 extracted parts, found '+$parts.Count);}" ^
  "  if(Test-Path -LiteralPath $out){Remove-Item -LiteralPath $out -Force;}" ^
  "  $dst=[IO.File]::Open($out,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);" ^
  "  try { foreach($p in $parts){ Write-Host ('JOIN    '+$p.Name); $src=[IO.File]::OpenRead($p.FullName); try{$src.CopyTo($dst)} finally{$src.Dispose()} } } finally {$dst.Dispose()}" ^
  "  Write-Host 'VERIFY  SHA-256';" ^
  "  $actual=(Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash.ToLowerInvariant();" ^
  "  if($actual -ne $expected){throw ('SHA-256 mismatch. Expected '+$expected+' got '+$actual);}" ^
  "  Write-Host 'PASS: RAH OS Raven v0.3 ISO is complete and verified.' -ForegroundColor Green;" ^
  "  Write-Host ('ISO: '+$out);" ^
  "} finally { if(Test-Path -LiteralPath $tmp){Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue} }"
set "RC=%ERRORLEVEL%"

echo.
if not "%RC%"=="0" (
  echo FAIL: ISO was not created or did not verify.
  echo Keep the ZIP parts and run this file again after fixing the error.
) else (
  echo Success. You can now use the ISO for a Live USB or virtual machine.
)
echo.
pause
exit /b %RC%
