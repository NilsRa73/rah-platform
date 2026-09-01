param(
 [ValidateSet('Worker','Leader')][string]$Mode='Worker',
 [ValidateRange(1024,65535)][int]$Port=18766
)
$ErrorActionPreference='Stop'
$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
$dir=Join-Path $env:LOCALAPPDATA 'RAH\HomeNode'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$files=@('RAH-HOME-NODE-AGENT.ps1','RAH-HOME-NODE-CLIENT.ps1','RAH-HOME-NODE-JOB.ps1','RAH-HOME-CLUSTER-RUN.ps1')
foreach($f in $files){
 $dest=Join-Path $dir $f
 Invoke-WebRequest -UseBasicParsing -Uri "$base/$f" -OutFile $dest
}
$desktop=[Environment]::GetFolderPath('Desktop')
if($Mode -eq 'Worker'){
 $cmd="powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$(Join-Path $dir 'RAH-HOME-NODE-AGENT.ps1')`" -ListenAddress 0.0.0.0 -Port $Port"
 $shortcut=Join-Path $desktop 'RAH Home Worker.cmd'
 "@echo off`r`n$cmd`r`npause" | Set-Content -LiteralPath $shortcut -Encoding ascii
 Write-Host 'RAH Home Worker er installert.' -ForegroundColor Green
 Write-Host "Start fra skrivebordet: $shortcut"
}else{
 $shortcut=Join-Path $desktop 'RAH Home Nexus.url'
 "[InternetShortcut]`r`nURL=https://nilsra73.github.io/rah-platform/RAH-HOME-NEXUS.html" | Set-Content -LiteralPath $shortcut -Encoding ascii
 Write-Host 'RAH Home Leader-verktøy er installert.' -ForegroundColor Green
 Write-Host "Nexus-snarvei: $shortcut"
}
Write-Host "Filer: $dir"
Write-Host 'Pairing er fortsatt eksplisitt. Ingen node blir automatisk klarert eller paret.'
