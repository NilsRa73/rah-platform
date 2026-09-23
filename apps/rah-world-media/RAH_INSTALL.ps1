$ErrorActionPreference='Stop'
$Src=Split-Path -Parent $MyInvocation.MyCommand.Path
$Dst='C:\RAH\WorldMedia\12.0'
Write-Host 'RAH World Media 12.0 RAVEN SYNC DECK - INSTALL' -ForegroundColor Yellow
New-Item -ItemType Directory -Force -Path $Dst | Out-Null
Get-ChildItem $Src -Force | Where-Object {$_.Name -notin @('RAH_INSTALL.ps1')} | Copy-Item -Destination $Dst -Recurse -Force
$Wsh=New-Object -ComObject WScript.Shell
$Desktop=[Environment]::GetFolderPath('Desktop')
$Programs=Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\RAH'
New-Item -ItemType Directory -Force -Path $Programs | Out-Null
foreach($lnk in @((Join-Path $Desktop 'RAH World Media 12.0.lnk'),(Join-Path $Programs 'RAH World Media 12.0.lnk'))){
  $s=$Wsh.CreateShortcut($lnk)
  $s.TargetPath=Join-Path $Dst 'START-HER.cmd'
  $s.WorkingDirectory=$Dst
  $s.Description='RAH World Media 12.0 RAVEN SYNC DECK'
  $s.Save()
}
Write-Host "PASS: Installed to $Dst" -ForegroundColor Green
Write-Host 'Desktop + Start Menu shortcuts created.' -ForegroundColor Green
Start-Process (Join-Path $Dst 'START-HER.cmd')
