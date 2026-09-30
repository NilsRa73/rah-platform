$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Desktop = [Environment]::GetFolderPath('Desktop')
$MenuDir = Join-Path $Desktop 'RAH AI Studios'
$Shell = New-Object -ComObject WScript.Shell

New-Item -ItemType Directory -Force -Path $MenuDir | Out-Null

function New-RahShortcut {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][string]$Target,
        [string]$Arguments = '',
        [string]$WorkingDirectory = $RepoRoot,
        [string]$Description = ''
    )

    $Path = Join-Path $Desktop $Name
    $Shortcut = $Shell.CreateShortcut($Path)
    $Shortcut.TargetPath = $Target
    if ($Arguments) { $Shortcut.Arguments = $Arguments }
    if ($WorkingDirectory) { $Shortcut.WorkingDirectory = $WorkingDirectory }
    if ($Description) { $Shortcut.Description = $Description }
    $Shortcut.WindowStyle = 7
    $Shortcut.Save()
    Write-Host "PASS  $Name" -ForegroundColor Green
}

$StartHer = Join-Path $RepoRoot 'START-HER.cmd'
$Wheel = Join-Path $RepoRoot 'RAH-RAVEN-COMMAND-WHEEL.html'
$MasterWheel = Join-Path $RepoRoot 'RAH-RAVEN-WHEEL.user.js'

if (-not (Test-Path $StartHer)) { throw "Fant ikke START-HER.cmd i $RepoRoot" }
if (-not (Test-Path $Wheel)) { throw "Fant ikke RAH-RAVEN-COMMAND-WHEEL.html i $RepoRoot" }

Write-Host ''
Write-Host '===============================================' -ForegroundColor DarkYellow
Write-Host ' RAH START MENU v1.0 - DESKTOP INSTALLER' -ForegroundColor Yellow
Write-Host '===============================================' -ForegroundColor DarkYellow

New-RahShortcut -Name 'RAH START HER.lnk' -Target $StartHer -Description 'Start Raven Core, Desktop Bridge and Raven Command Wheel'
New-RahShortcut -Name 'RAH COMMAND WHEEL.lnk' -Target $Wheel -Description 'Open the RAH Raven Command Wheel'
New-RahShortcut -Name 'RAH DOCTOR.lnk' -Target (Join-Path $env:WINDIR 'explorer.exe') -Arguments 'http://127.0.0.1:18765/doctor/ui' -Description 'Open Raven Doctor health status'
New-RahShortcut -Name 'RAH ACCEPTANCE FILE.lnk' -Target (Join-Path $env:WINDIR 'explorer.exe') -Arguments 'C:\RAH\RavenOS\state' -Description 'Open folder containing RAH-OS-ACCEPTANCE.json'

# Keep a compact folder with the canonical entry points; old launchers are not deleted.
Copy-Item -Force $StartHer (Join-Path $MenuDir 'START-HER.cmd')
Copy-Item -Force $Wheel (Join-Path $MenuDir 'RAH-RAVEN-COMMAND-WHEEL.html')
if (Test-Path $MasterWheel) {
    Copy-Item -Force $MasterWheel (Join-Path $MenuDir 'RAH-RAVEN-WHEEL.user.js')
}

$Readme = @'
RAH AI STUDIOS - CANONICAL START MENU

DAILY USE
1. RAH START HER
   Starts Raven Core / Bridge, performs the existing safe checks, then opens the Command Wheel.

2. RAH COMMAND WHEEL
   Opens the black/gold Raven launcher directly.

3. RAH DOCTOR
   Opens health status at the local Desktop Bridge.

4. RAH ACCEPTANCE FILE
   Opens C:\RAH\RavenOS\state where RAH-OS-ACCEPTANCE.json is stored.

CHATGPT
Use RAH-RAVEN-WHEEL.user.js as the canonical Tampermonkey wheel.

SAFETY
Old launchers are intentionally not deleted. They remain available for rollback.
Node Agent remains explicit. This installer does not enable arbitrary shell execution.
'@
Set-Content -LiteralPath (Join-Path $MenuDir 'START HER.txt') -Value $Readme -Encoding UTF8

Write-Host ''
Write-Host 'RAH Start Menu v1.0 is ready.' -ForegroundColor Green
Write-Host 'Use: RAH START HER' -ForegroundColor Yellow
