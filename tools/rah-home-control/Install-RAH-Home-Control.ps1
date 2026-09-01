[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Branch = 'codex/rah-home-control-powershell'
$BaseUrl = "https://raw.githubusercontent.com/NilsRa73/rah-platform/$Branch/tools/rah-home-control"
$RahRoot = Join-Path $env:USERPROFILE 'Documents\RAH Room Control'
$ToolRoot = Join-Path $RahRoot 'Tools'
$Desktop = [Environment]::GetFolderPath('Desktop')

New-Item -ItemType Directory -Path $ToolRoot -Force | Out-Null

$Files = @(
    'RAH-Control-Center.ps1'
    'RAH-Link-Speed.ps1'
    'RAH-Remote-Setup.ps1'
    'RAH-Node-Register.ps1'
    'RAH-Command-Wheel-Home-Control-Addon.user.js'
)

Write-Host ''
Write-Host '==============================================' -ForegroundColor DarkYellow
Write-Host '       RAH HOME CONTROL - POWERSHELL' -ForegroundColor Yellow
Write-Host '==============================================' -ForegroundColor DarkYellow
Write-Host ''

foreach ($File in $Files) {
    Write-Host "Installerer $File ..." -ForegroundColor Cyan
    Invoke-WebRequest -Uri "$BaseUrl/$File" `
        -OutFile (Join-Path $ToolRoot $File) `
        -UseBasicParsing
}

$Launcher = Join-Path $ToolRoot 'RAH-Control-Center.ps1'
$Pwsh = (Get-Command 'pwsh.exe' -ErrorAction Stop).Source

$Shell = New-Object -ComObject WScript.Shell
$Shortcut = $Shell.CreateShortcut((Join-Path $Desktop 'RAH Control Center.lnk'))
$Shortcut.TargetPath = $Pwsh
$Shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$Launcher`""
$Shortcut.WorkingDirectory = $ToolRoot
$Shortcut.IconLocation = "$env:SystemRoot\System32\imageres.dll,25"
$Shortcut.Description = 'RAH Room Control and home network command center'
$Shortcut.Save()

$ProtocolRoot = 'HKCU:\Software\Classes\rah-control-center'
New-Item -Path $ProtocolRoot -Force | Out-Null
Set-Item -Path $ProtocolRoot -Value 'URL:RAH Control Center Protocol'
New-ItemProperty -Path $ProtocolRoot -Name 'URL Protocol' -Value '' `
    -PropertyType String -Force | Out-Null
New-Item -Path "$ProtocolRoot\DefaultIcon" -Force | Out-Null
Set-Item -Path "$ProtocolRoot\DefaultIcon" -Value ('"{0}",0' -f $Pwsh)
New-Item -Path "$ProtocolRoot\shell\open\command" -Force | Out-Null
$ProtocolCommand = '"{0}" -NoProfile -ExecutionPolicy Bypass -File "{1}" "%1"' -f `
    $Pwsh, $Launcher
Set-Item -Path "$ProtocolRoot\shell\open\command" -Value $ProtocolCommand

Write-Host ''
Write-Host 'PowerShell-kontrollsenteret er installert.' -ForegroundColor Green
Write-Host 'Apner RAH Control Center og Wheel-tillegget ...' -ForegroundColor Yellow

Start-Process $Pwsh -ArgumentList @(
    '-NoProfile'
    '-ExecutionPolicy', 'Bypass'
    '-File', ('"{0}"' -f $Launcher)
)

$AddonFile = Join-Path $ToolRoot 'RAH-Command-Wheel-Home-Control-Addon.user.js'
Get-Content -Path $AddonFile -Raw | Set-Clipboard
$AddonUrl = "$BaseUrl/RAH-Command-Wheel-Home-Control-Addon.user.js"
Start-Process $AddonUrl

Write-Host ''
Write-Host 'I Tampermonkey-siden: trykk Installer én gang.' -ForegroundColor Yellow
Write-Host 'Hvis bare kildekoden vises, er den allerede kopiert til utklippstavlen.'
Write-Host 'Deretter oppdaterer du ChatGPT med Ctrl+F5.'
Write-Host 'Hjem-knappen i Command Wheel og Alt+H starter kontrollsenteret.'
Write-Host 'Den gamle Wheel-versjonen er ikke slettet eller overskrevet.'
Write-Host ''
