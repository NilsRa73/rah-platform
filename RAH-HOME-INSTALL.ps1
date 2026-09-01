param([ValidateSet('Leader','Worker')][string]$Mode='Leader')
$ErrorActionPreference='Stop'
$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
$dir=Join-Path $env:LOCALAPPDATA 'RAH\Home'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$common=@('RAH-HOME-NODE-AGENT.ps1','RAH-HOME-NODE-CLIENT.ps1','RAH-HOME-NODE-JOB.ps1','RAH-HOME-CLUSTER-RUN.ps1','RAH-HOME-PAIR-WIZARD.ps1')
foreach($f in $common){Invoke-WebRequest -UseBasicParsing -Uri "$base/$f" -OutFile (Join-Path $dir $f)}
$desktop=[Environment]::GetFolderPath('Desktop')
if($Mode-eq'Worker'){
 $agent=Join-Path $dir 'RAH-HOME-NODE-AGENT.ps1'
 $cmd=Join-Path $desktop 'RAH Home Worker.cmd'
 "@echo off`r`ntitle RAH Home Worker`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$agent`" -Port 18766`r`npause"|Set-Content -LiteralPath $cmd -Encoding ascii
 Write-Host 'WORKER READY' -ForegroundColor Green
 Write-Host 'Start RAH Home Worker fra skrivebordet. Pair code vises i vinduet.'
}else{
 $pair=Join-Path $dir 'RAH-HOME-PAIR-WIZARD.ps1'
 $pairCmd=Join-Path $desktop 'RAH Pair Worker.cmd'
 "@echo off`r`ntitle RAH Pair Worker`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$pair`"`r`npause"|Set-Content -LiteralPath $pairCmd -Encoding ascii
 $url=Join-Path $desktop 'RAH Home Nexus.url'
 "[InternetShortcut]`r`nURL=https://nilsra73.github.io/rah-platform/RAH-HOME-NEXUS.html"|Set-Content -LiteralPath $url -Encoding ascii
 Write-Host 'LEADER READY' -ForegroundColor Green
 Write-Host 'Skrivebord: RAH Home Nexus + RAH Pair Worker.'
}
Write-Host "Installert i $dir"
Write-Host 'RAH Home åpner ingen vilkårlig fjern-shell. Pairing må fortsatt godkjennes eksplisitt.'
