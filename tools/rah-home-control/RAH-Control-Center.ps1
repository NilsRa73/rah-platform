[CmdletBinding()]
param(
    [switch]$AutoStart,
    [string]$ProtocolUri = ''
)

$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ToolRoot = Split-Path -Parent $PSCommandPath
$RahRoot = Join-Path $env:USERPROFILE 'Documents\RAH Room Control'
$Gold = [Drawing.Color]::FromArgb(218, 181, 65)
$LightGold = [Drawing.Color]::FromArgb(244, 220, 129)
$DarkGold = [Drawing.Color]::FromArgb(104, 80, 19)
$Black = [Drawing.Color]::FromArgb(6, 6, 6)
$PanelBlack = [Drawing.Color]::FromArgb(17, 15, 10)
$Green = [Drawing.Color]::FromArgb(104, 239, 145)
$Red = [Drawing.Color]::FromArgb(255, 115, 115)

function Start-RahTool {
    param(
        [string]$File,
        [string]$Arguments = ''
    )

    $path = Join-Path $ToolRoot $File
    if (-not (Test-Path $path)) {
        [Windows.Forms.MessageBox]::Show(
            "Fant ikke $File i $ToolRoot",
            'RAH Control Center',
            'OK',
            'Warning'
        ) | Out-Null
        return
    }

    $argumentList = "-NoProfile -ExecutionPolicy Bypass -File `"$path`" $Arguments"
    Start-Process -FilePath 'pwsh.exe' -ArgumentList $argumentList
}

function Start-RahMasterPowerQuiet {
    $path = Join-Path $ToolRoot 'RAH-Master-Power.ps1'
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        return
    }

    Start-Process -FilePath 'pwsh.exe' -ArgumentList @(
        '-NoProfile'
        '-WindowStyle', 'Hidden'
        '-ExecutionPolicy', 'Bypass'
        '-File', ('"{0}"' -f $path)
        '-Quiet'
    ) -WindowStyle Hidden
}

function Find-RahSystemDoctor {
    $desktop = [Environment]::GetFolderPath('Desktop')
    $runtimeRoot = Join-Path $RahRoot 'Runtime'
    $roots = @(
        $env:RAH_PLATFORM_ROOT
        (Join-Path $desktop 'RAH AI Studios\rah-platform')
        (Join-Path $env:USERPROFILE 'Desktop\RAH AI Studios\rah-platform')
        $(if ($env:OneDrive) { Join-Path $env:OneDrive 'Desktop\RAH AI Studios\rah-platform' })
        $(if ($env:OneDriveConsumer) { Join-Path $env:OneDriveConsumer 'Desktop\RAH AI Studios\rah-platform' })
        (Join-Path $runtimeRoot 'rah-platform')
    ) | Where-Object { $_ } | Select-Object -Unique

    foreach ($root in $roots) {
        $doctor = Join-Path $root 'desktop-bridge\doctor.py'
        if (Test-Path -LiteralPath $doctor -PathType Leaf) {
            return $doctor
        }
    }

    foreach ($searchRoot in @($desktop, $runtimeRoot)) {
        if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) {
            continue
        }
        $found = Get-ChildItem -LiteralPath $searchRoot -Filter 'doctor.py' `
            -File -Recurse -Depth 7 -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -match 'desktop-bridge$' } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

function Start-RahSystemDoctor {
    $doctor = Find-RahSystemDoctor
    if (-not $doctor) {
        [Windows.Forms.MessageBox]::Show(
            'System Doctor er ikke klargjort ennå. MASTER POWER startes nå for å hente eller finne den kanoniske RAH-runtimepakken.',
            'RAH System Doctor',
            'OK',
            'Information'
        ) | Out-Null
        Start-RahTool 'RAH-Master-Power.ps1'
        return
    }

    $bridgeRoot = Split-Path -Parent $doctor
    $python = Join-Path $bridgeRoot '.venv\Scripts\python.exe'
    if (-not (Test-Path -LiteralPath $python -PathType Leaf)) {
        [Windows.Forms.MessageBox]::Show(
            'Python-miljøet for System Doctor mangler. MASTER POWER klargjør det nå. Kjør SYSTEM DOCTOR igjen når Bridge-lampen er grønn.',
            'RAH System Doctor',
            'OK',
            'Information'
        ) | Out-Null
        Start-RahTool 'RAH-Master-Power.ps1'
        return
    }

    $cmd = '""{0}" "{1}""' -f $python, $doctor
    Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/k', $cmd) `
        -WorkingDirectory $bridgeRoot
}

function Start-RahHomeControlUpdate {
    $installerUrl = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/codex/rah-home-control-powershell/tools/rah-home-control/Install-RAH-Home-Control.ps1'
    $expectedHash = 'AFAD11FE503180000875ECE81668FB04BD0520B0619BF7EE9F3E1CAF4BB68347'
    $installer = Join-Path ([IO.Path]::GetTempPath()) 'Update-RAH-Home-Control.ps1'
    $backupRoot = Join-Path $RahRoot 'Backups\Home Control'
    $backup = Join-Path $backupRoot (Get-Date -Format 'yyyyMMdd-HHmmss')

    try {
        New-Item -ItemType Directory -Path $backup -Force | Out-Null
        Get-ChildItem -LiteralPath $ToolRoot -Force -ErrorAction SilentlyContinue |
            Copy-Item -Destination $backup -Recurse -Force

        Invoke-WebRequest -Uri $installerUrl -OutFile $installer -UseBasicParsing
        $actualHash = (Get-FileHash -LiteralPath $installer -Algorithm SHA256).Hash
        if ($actualHash -ne $expectedHash) {
            throw 'Sikkerhetskontrollen for RAH-oppdateringen feilet.'
        }
        Unblock-File -LiteralPath $installer
        Start-Process -FilePath 'pwsh.exe' -ArgumentList @(
            '-NoLogo'
            '-NoProfile'
            '-ExecutionPolicy', 'Bypass'
            '-File', ('"{0}"' -f $installer)
        )
        $form.Close()
    }
    catch {
        [Windows.Forms.MessageBox]::Show(
            "Oppdateringen ble stoppet trygt.`n`n$($_.Exception.Message)`n`nEksisterende filer er beholdt.",
            'RAH Home Control Update',
            'OK',
            'Error'
        ) | Out-Null
    }
}

function Copy-RahDiagnostics {
    $masterLog = Join-Path $RahRoot 'Logs\RAH-Master-Power.log'
    $masterStatus = Join-Path $RahRoot 'RAH-Master-Power-Status.json'
    $lines = [Collections.Generic.List[string]]::new()
    $lines.Add('RAH HOME CONTROL DIAGNOSTICS')
    $lines.Add(('Time: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
    $lines.Add(('Computer: {0}' -f $env:COMPUTERNAME))
    $lines.Add(('Bridge 18765: {0}' -f $(if (Test-RahPort 18765) { 'ONLINE' } else { 'OFFLINE' })))
    $lines.Add(('LM Studio 1234: {0}' -f $(if (Test-RahPort 1234) { 'ONLINE' } else { 'OFFLINE' })))
    $lines.Add(('Ollama 11434: {0}' -f $(if (Test-RahPort 11434) { 'ONLINE' } else { 'OFFLINE' })))

    if (Test-Path -LiteralPath $masterStatus -PathType Leaf) {
        $lines.Add('')
        $lines.Add('MASTER STATUS')
        $lines.Add((Get-Content -LiteralPath $masterStatus -Raw))
    }
    if (Test-Path -LiteralPath $masterLog -PathType Leaf) {
        $lines.Add('')
        $lines.Add('MASTER LOG - LAST 120 LINES')
        foreach ($line in (Get-Content -LiteralPath $masterLog -Tail 120)) {
            $lines.Add([string]$line)
        }
    }

    $lines -join "`r`n" | Set-Clipboard
    [Windows.Forms.MessageBox]::Show(
        'RAH-diagnosen er kopiert. Lim den direkte inn i ChatGPT — ikke kopier PowerShell-ledeteksten eller gamle feilmeldinger.',
        'RAH Diagnostics',
        'OK',
        'Information'
    ) | Out-Null
}

function Open-RahFile {
    param([string]$Path)
    if (Test-Path $Path) {
        Start-Process $Path
    }
    else {
        [Windows.Forms.MessageBox]::Show(
            "Filen finnes ikke ennå:`n$Path`n`nKjør den aktuelle registreringen først.",
            'RAH Control Center',
            'OK',
            'Information'
        ) | Out-Null
    }
}

function New-RahButton {
    param(
        [string]$Text,
        [int]$X,
        [int]$Y,
        [scriptblock]$Action,
        [string]$Description
    )

    $button = [Windows.Forms.Button]::new()
    $button.Text = $Text
    $button.Location = [Drawing.Point]::new($X, $Y)
    $button.Size = [Drawing.Size]::new(270, 50)
    $button.FlatStyle = 'Flat'
    $button.FlatAppearance.BorderColor = $DarkGold
    $button.FlatAppearance.BorderSize = 1
    $button.BackColor = $PanelBlack
    $button.ForeColor = $LightGold
    $button.Font = [Drawing.Font]::new('Segoe UI Semibold', 10)
    $button.Cursor = 'Hand'
    $button.Tag = $Description
    $button.Add_MouseEnter({
        $this.BackColor = $Gold
        $this.ForeColor = $Black
        $descriptionLabel.Text = [string]$this.Tag
    })
    $button.Add_MouseLeave({
        $this.BackColor = $PanelBlack
        $this.ForeColor = $LightGold
    })
    $button.Add_Click($Action)
    return $button
}

$form = [Windows.Forms.Form]::new()
$form.Text = 'RAH Control Center'
$form.Size = [Drawing.Size]::new(930, 670)
$form.StartPosition = 'CenterScreen'
$form.BackColor = $Black
$form.ForeColor = $LightGold
$form.Font = [Drawing.Font]::new('Segoe UI', 10)
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false

$title = [Windows.Forms.Label]::new()
$title.Text = 'RAH CONTROL CENTER'
$title.Location = [Drawing.Point]::new(32, 25)
$title.Size = [Drawing.Size]::new(690, 42)
$title.ForeColor = $Gold
$title.Font = [Drawing.Font]::new('Segoe UI Semibold', 25)
$form.Controls.Add($title)

$subtitle = [Windows.Forms.Label]::new()
$subtitle.Text = 'HAAKOYA HOME NETWORK  /  RAVEN COMMAND LAYER'
$subtitle.Location = [Drawing.Point]::new(36, 69)
$subtitle.Size = [Drawing.Size]::new(700, 25)
$subtitle.ForeColor = [Drawing.Color]::FromArgb(160, 142, 88)
$subtitle.Font = [Drawing.Font]::new('Consolas', 10)
$form.Controls.Add($subtitle)

$line = [Windows.Forms.Panel]::new()
$line.Location = [Drawing.Point]::new(35, 105)
$line.Size = [Drawing.Size]::new(845, 1)
$line.BackColor = $DarkGold
$form.Controls.Add($line)

$section1 = [Windows.Forms.Label]::new()
$section1.Text = 'NETWORK & NODES'
$section1.Location = [Drawing.Point]::new(40, 130)
$section1.Size = [Drawing.Size]::new(300, 25)
$section1.ForeColor = $Gold
$section1.Font = [Drawing.Font]::new('Segoe UI Semibold', 11)
$form.Controls.Add($section1)

$section2 = [Windows.Forms.Label]::new()
$section2.Text = 'REMOTE & DISPLAYS'
$section2.Location = [Drawing.Point]::new(330, 130)
$section2.Size = [Drawing.Size]::new(300, 25)
$section2.ForeColor = $Gold
$section2.Font = [Drawing.Font]::new('Segoe UI Semibold', 11)
$form.Controls.Add($section2)

$section3 = [Windows.Forms.Label]::new()
$section3.Text = 'DASHBOARDS & DATA'
$section3.Location = [Drawing.Point]::new(620, 130)
$section3.Size = [Drawing.Size]::new(260, 25)
$section3.ForeColor = $Gold
$section3.Font = [Drawing.Font]::new('Segoe UI Semibold', 11)
$form.Controls.Add($section3)

$descriptionLabel = [Windows.Forms.Label]::new()
$descriptionLabel.Text = 'Velg en RAH-funksjon. Hold musepekeren over en knapp for forklaring.'
$descriptionLabel.Location = [Drawing.Point]::new(38, 535)
$descriptionLabel.Size = [Drawing.Size]::new(840, 40)
$descriptionLabel.ForeColor = [Drawing.Color]::FromArgb(185, 168, 112)
$form.Controls.Add($descriptionLabel)

$masterButton = New-RahButton "MASTER POWER`nSTART ALL" 735 25 {
    Start-RahTool 'RAH-Master-Power.ps1'
} 'Starter både kanonisk RAH Bridge og Ollama. Samme start kjøres automatisk fra Command Wheel.'
$masterButton.Size = [Drawing.Size]::new(145, 68)
$masterButton.Font = [Drawing.Font]::new('Segoe UI Semibold', 9)
$form.Controls.Add($masterButton)

$form.Controls.Add((New-RahButton 'START NODE SERVER' 35 165 {
    Start-RahTool 'RAH-Node-Register.ps1' '-Mode Server'
} 'Starter hoved-PC-en som mottaker for maskinvareprofiler.'))

$form.Controls.Add((New-RahButton 'DISCOVER + REGISTER NODE' 35 225 {
    Start-RahTool 'RAH-Node-Register.ps1' '-Mode Node'
} 'Finner hoved-PC-en automatisk og sender CPU, GPU, RAM, nettverk, RustDesk, spacedesk og Bluetooth-profil.'))

$form.Controls.Add((New-RahButton 'START SPEED SERVER' 35 285 {
    Start-RahTool 'RAH-Link-Speed.ps1' '-Mode Server'
} 'Starter lokal hastighetsserver på hoved-PC-en.'))

$form.Controls.Add((New-RahButton 'RUN SPEED CLIENT' 35 345 {
    Start-RahTool 'RAH-Link-Speed.ps1' '-Mode Client'
} 'Måler reell Wi-Fi/LAN-hastighet fra denne maskinen til hoved-PC-en.'))

$form.Controls.Add((New-RahButton 'REMOTE SETUP' 325 165 {
    Start-RahTool 'RAH-Remote-Setup.ps1'
} 'Installerer riktig RustDesk- og spacedesk-rolle på maskinen.'))

$form.Controls.Add((New-RahButton 'OPEN RUSTDESK' 325 225 {
    $paths = @(
        (Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe')
    ) | Where-Object { $_ -and (Test-Path $_) }
    if ($paths) { Start-Process ($paths | Select-Object -First 1) }
    else { Start-RahTool 'RAH-Remote-Setup.ps1' '-Role RustDeskOnly' }
} 'Åpner RustDesk, eller starter installasjonen dersom programmet mangler.'))

$form.Controls.Add((New-RahButton 'WINDOWS DISPLAY SETTINGS' 325 285 {
    Start-Process 'ms-settings:display'
} 'Åpner Windows skjermoppsett for utvidet skrivebord, oppløsning og plassering.'))

$form.Controls.Add((New-RahButton 'CONNECT WIRELESS DISPLAY' 325 345 {
    Start-Process 'ms-settings-connectabledevices:devicediscovery'
} 'Åpner Windows-området for Miracast og trådløse skjermer.'))

$form.Controls.Add((New-RahButton 'NODE DASHBOARD' 615 165 {
    Open-RahFile (Join-Path $RahRoot 'RAH-Node-Dashboard.html')
} 'Åpner svart/gull oversikt over registrerte maskiner og spesifikasjoner.'))

$form.Controls.Add((New-RahButton 'ROOM CONTROL' 615 225 {
    Open-RahFile (Join-Path $RahRoot 'RAH-Room-Control.html')
} 'Åpner rom-, TV-, projektor- og enhetsoversikten.'))

$form.Controls.Add((New-RahButton 'SPEED RESULTS' 615 285 {
    Open-RahFile (Join-Path $RahRoot 'RAH-Link-Speed-Results.csv')
} 'Åpner lagrede overføringsmålinger mellom RAH-nodene.'))

$form.Controls.Add((New-RahButton 'OPEN RAH DATA FOLDER' 615 345 {
    New-Item -ItemType Directory -Path $RahRoot -Force | Out-Null
    Start-Process explorer.exe -ArgumentList ('"{0}"' -f $RahRoot)
} 'Åpner databasen, rapportene, installasjonsfilene og dashboardene.'))

$form.Controls.Add((New-RahButton 'SYSTEM DOCTOR' 35 575 {
    Start-RahSystemDoctor
} 'Kjører den kanoniske lokale Raven-diagnosen for Bridge, skjermfangst, LM Studio og lastet modell.'))

$form.Controls.Add((New-RahButton 'UPDATE HOME CONTROL' 325 575 {
    Start-RahHomeControlUpdate
} 'Tar sikkerhetskopi og henter siste verifiserte Home Control-versjon uten å endre Command Wheel.'))

$form.Controls.Add((New-RahButton 'COPY DIAGNOSTICS' 615 575 {
    Copy-RahDiagnostics
} 'Kopierer bare fersk RAH-status og relevante logger, klart til å limes inn i ChatGPT.'))

$statusPanel = [Windows.Forms.Panel]::new()
$statusPanel.Location = [Drawing.Point]::new(35, 430)
$statusPanel.Size = [Drawing.Size]::new(845, 80)
$statusPanel.BackColor = $PanelBlack
$statusPanel.BorderStyle = 'FixedSingle'
$form.Controls.Add($statusPanel)

$statusTitle = [Windows.Forms.Label]::new()
$statusTitle.Text = 'LIVE STATUS'
$statusTitle.Location = [Drawing.Point]::new(15, 10)
$statusTitle.Size = [Drawing.Size]::new(120, 22)
$statusTitle.ForeColor = $Gold
$statusPanel.Controls.Add($statusTitle)

$bridgeStatus = [Windows.Forms.Label]::new()
$bridgeStatus.Location = [Drawing.Point]::new(155, 10)
$bridgeStatus.Size = [Drawing.Size]::new(200, 25)
$statusPanel.Controls.Add($bridgeStatus)

$lmStatus = [Windows.Forms.Label]::new()
$lmStatus.Location = [Drawing.Point]::new(365, 10)
$lmStatus.Size = [Drawing.Size]::new(190, 25)
$statusPanel.Controls.Add($lmStatus)

$ollamaStatus = [Windows.Forms.Label]::new()
$ollamaStatus.Location = [Drawing.Point]::new(565, 10)
$ollamaStatus.Size = [Drawing.Size]::new(180, 25)
$statusPanel.Controls.Add($ollamaStatus)

$machineStatus = [Windows.Forms.Label]::new()
$machineStatus.Text = "NODE: $env:COMPUTERNAME"
$machineStatus.Location = [Drawing.Point]::new(155, 43)
$machineStatus.Size = [Drawing.Size]::new(400, 24)
$machineStatus.ForeColor = $LightGold
$statusPanel.Controls.Add($machineStatus)

function Test-RahPort {
    param([int]$Port)
    $client = [Net.Sockets.TcpClient]::new()
    try {
        $result = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        return $result.AsyncWaitHandle.WaitOne(180, $false) -and $client.Connected
    }
    catch { return $false }
    finally { $client.Dispose() }
}

function Update-RahStatus {
    $items = @(
        @{ Label = $bridgeStatus; Name = 'RAH BRIDGE'; Port = 18765 },
        @{ Label = $lmStatus; Name = 'LM STUDIO'; Port = 1234 },
        @{ Label = $ollamaStatus; Name = 'OLLAMA'; Port = 11434 }
    )
    foreach ($item in $items) {
        if (Test-RahPort $item.Port) {
            $item.Label.Text = "● $($item.Name) ONLINE"
            $item.Label.ForeColor = $Green
        }
        else {
            $item.Label.Text = "● $($item.Name) OFFLINE"
            $item.Label.ForeColor = $Red
        }
    }
}

$timer = [Windows.Forms.Timer]::new()
$timer.Interval = 5000
$timer.Add_Tick({ Update-RahStatus })
$timer.Start()
Update-RahStatus

$startRequested = $AutoStart -or ($ProtocolUri -match '^rah-control-center://(open|start-all)')
if ($startRequested) {
    $form.Add_Shown({ Start-RahMasterPowerQuiet })
}

[void]$form.ShowDialog()
$timer.Stop()
$timer.Dispose()
