[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Primary', 'Secondary', 'RustDeskOnly')]
    [string]$Role = 'Menu'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$RahRoot = Join-Path $env:USERPROFILE 'Documents\RAH Room Control'
$DownloadRoot = Join-Path $RahRoot 'Installers'
$StatusFile = Join-Path $RahRoot 'RAH-Remote-Status.json'
New-Item -ItemType Directory -Path $DownloadRoot -Force | Out-Null

function Show-RahHeader {
    Clear-Host
    Write-Host '==============================================' -ForegroundColor DarkYellow
    Write-Host '       RAH REMOTE AND DISPLAY SETUP' -ForegroundColor Yellow
    Write-Host '==============================================' -ForegroundColor DarkYellow
    Write-Host ''
}

function Test-RahAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-RahElevation {
    if (Test-RahAdmin) { return }

    Write-Host 'Windows viser na et administratorvindu (UAC).' -ForegroundColor Yellow
    $arguments = @(
        '-NoProfile'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $PSCommandPath)
        '-Role', $Role
    )
    Start-Process -FilePath 'pwsh.exe' -Verb RunAs -ArgumentList $arguments
    exit
}

function Get-RahRustDeskInstaller {
    Write-Host 'Henter siste offisielle RustDesk-utgivelse ...' -ForegroundColor Cyan

    $headers = @{
        'User-Agent' = 'RAH-Room-Control'
        'Accept' = 'application/vnd.github+json'
    }
    $release = Invoke-RestMethod `
        -Uri 'https://api.github.com/repos/rustdesk/rustdesk/releases/latest' `
        -Headers $headers

    $asset = $release.assets |
        Where-Object {
            $_.name -match '^rustdesk-.*-x86_64\.exe$' -and
            $_.name -notmatch '\.sig$'
        } |
        Select-Object -First 1

    if (-not $asset) {
        throw 'Fant ikke Windows x64-installasjonsfil i siste RustDesk-utgivelse.'
    }

    $destination = Join-Path $DownloadRoot $asset.name
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $destination

    $hash = (Get-FileHash -Path $destination -Algorithm SHA256).Hash
    Write-Host "RustDesk: $($release.tag_name)" -ForegroundColor Green
    Write-Host "SHA-256: $hash"
    return $destination
}

function Install-RahRustDesk {
    $existing = Get-Command 'rustdesk.exe' -ErrorAction SilentlyContinue
    if (-not $existing) {
        $possible = @(
            (Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe')
            (Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe')
        ) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
        if ($possible) { $existing = Get-Item $possible }
    }

    if ($existing) {
        Write-Host 'RustDesk er allerede installert.' -ForegroundColor Green
        return
    }

    $installer = Get-RahRustDeskInstaller
    Write-Host 'Installerer RustDesk ...' -ForegroundColor Cyan
    $process = Start-Process -FilePath $installer -ArgumentList '--silent-install' -Wait -PassThru
    if ($process.ExitCode -notin 0, 3010) {
        throw "RustDesk-installasjonen returnerte kode $($process.ExitCode)."
    }
    Write-Host 'RustDesk installert.' -ForegroundColor Green
}

function Install-RahSpacedeskDriver {
    Write-Host 'Henter spacedesk DRIVER fra offisiell nettside ...' -ForegroundColor Cyan
    $msi = Join-Path $DownloadRoot 'spacedesk-driver-latest.msi'
    Invoke-WebRequest -Uri 'https://www.spacedesk.net/downloadidd64' -OutFile $msi

    if ((Get-Item $msi).Length -lt 1MB) {
        throw 'Den nedlastede spacedesk-filen er uventet liten. Installasjonen er stoppet.'
    }

    $signature = Get-AuthenticodeSignature -FilePath $msi
    Write-Host "Digital signatur: $($signature.Status)"
    if ($signature.Status -ne 'Valid') {
        throw 'spacedesk-installasjonsfilen har ikke en gyldig digital signatur.'
    }

    Write-Host 'Installerer spacedesk DRIVER for hoved-PC ...' -ForegroundColor Cyan
    $process = Start-Process -FilePath 'msiexec.exe' `
        -ArgumentList @('/i', ('"{0}"' -f $msi), '/passive', '/norestart') `
        -Wait -PassThru

    if ($process.ExitCode -notin 0, 1641, 3010) {
        throw "spacedesk-installasjonen returnerte kode $($process.ExitCode)."
    }
    Write-Host 'spacedesk DRIVER installert.' -ForegroundColor Green
}

function Open-RahSpacedeskViewer {
    Write-Host 'Apner offisiell spacedesk Viewer i Microsoft Store ...' -ForegroundColor Cyan
    Start-Process 'ms-windows-store://pdp/?ProductId=9NBLGGH4TRM4'
    Write-Host 'Trykk Installer i Store-vinduet.' -ForegroundColor Yellow
}

function New-RahRemoteShortcuts {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $shell = New-Object -ComObject WScript.Shell

    $rustDeskPaths = @(
        (Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe')
        (Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe')
    ) | Where-Object { $_ -and (Test-Path $_) }

    $rustDesk = $rustDeskPaths | Select-Object -First 1
    if ($rustDesk) {
        $shortcut = $shell.CreateShortcut((Join-Path $desktop 'RAH Remote - RustDesk.lnk'))
        $shortcut.TargetPath = $rustDesk
        $shortcut.WorkingDirectory = Split-Path $rustDesk
        $shortcut.IconLocation = "$rustDesk,0"
        $shortcut.Save()
    }

    $roomControl = Join-Path $RahRoot 'RAH-Room-Control.html'
    if (Test-Path $roomControl) {
        $shortcut = $shell.CreateShortcut((Join-Path $desktop 'RAH Room Control.lnk'))
        $shortcut.TargetPath = $roomControl
        $shortcut.WorkingDirectory = $RahRoot
        $shortcut.Save()
    }
}

Show-RahHeader

if ($Role -eq 'Menu') {
    Write-Host '1 - Hoved-PC: RustDesk + spacedesk DRIVER'
    Write-Host '2 - Omen/Lenovo: RustDesk + spacedesk VIEWER'
    Write-Host '3 - Bare RustDesk'
    Write-Host ''
    $choice = Read-Host 'Velg 1, 2 eller 3'
    switch ($choice) {
        '1' { $Role = 'Primary' }
        '2' { $Role = 'Secondary' }
        '3' { $Role = 'RustDeskOnly' }
        default { throw 'Ugyldig valg.' }
    }
}

Request-RahElevation
Show-RahHeader

Install-RahRustDesk

if ($Role -eq 'Primary') {
    Install-RahSpacedeskDriver
}
elseif ($Role -eq 'Secondary') {
    Open-RahSpacedeskViewer
}

New-RahRemoteShortcuts

$status = [ordered]@{
    Updated = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Computer = $env:COMPUTERNAME
    Role = $Role
    RustDeskInstalled = [bool](
        (Test-Path (Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe')) -or
        (Test-Path (Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe'))
    )
    SpacedeskDriverRequested = ($Role -eq 'Primary')
    SpacedeskViewerOpened = ($Role -eq 'Secondary')
    UnattendedAccessConfigured = $false
}
$status | ConvertTo-Json | Set-Content -Path $StatusFile -Encoding utf8

Write-Host ''
Write-Host '==============================================' -ForegroundColor DarkYellow
Write-Host '        RAH REMOTE SETUP FERDIG' -ForegroundColor Yellow
Write-Host '==============================================' -ForegroundColor DarkYellow
Write-Host "Maskinrolle: $Role" -ForegroundColor Green
Write-Host 'RustDesk-passord og ubemannet tilgang er ikke endret.'
Write-Host 'Ingen automatisk omstart er utfort.'
Write-Host ''
Read-Host 'Trykk Enter for a lukke'

