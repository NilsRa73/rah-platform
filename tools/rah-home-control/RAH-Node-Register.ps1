[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Server', 'Node')]
    [string]$Mode = 'Menu',
    [string]$ServerIP = '',
    [ValidateRange(1, 65535)]
    [int]$Port = 18992
)

$ErrorActionPreference = 'Stop'
$RahRoot = Join-Path $env:USERPROFILE 'Documents\RAH Room Control'
$DatabaseFile = Join-Path $RahRoot 'RAH-Nodes.json'
$CsvFile = Join-Path $RahRoot 'RAH-Nodes.csv'
$DashboardFile = Join-Path $RahRoot 'RAH-Node-Dashboard.html'
New-Item -ItemType Directory -Path $RahRoot -Force | Out-Null

function Show-RahHeader {
    Clear-Host
    Write-Host '==============================================' -ForegroundColor DarkYellow
    Write-Host '          RAH NODE REGISTRATION' -ForegroundColor Yellow
    Write-Host '==============================================' -ForegroundColor DarkYellow
    Write-Host ''
}

function Get-RahLocalIP {
    $address = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' -and
            $_.InterfaceAlias -notmatch 'Loopback|Bluetooth|vEthernet'
        } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1
    if (-not $address) { throw 'Fant ingen aktiv lokal IPv4-adresse.' }
    return $address.IPAddress
}

function Test-RahAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-RahRustDeskPath {
    $paths = @(
        (Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe')
        (Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe')
        (Join-Path $env:LOCALAPPDATA 'RustDesk\rustdesk.exe')
    )
    return $paths | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
}

function Get-RahRustDeskID {
    $rustDesk = Get-RahRustDeskPath
    if (-not $rustDesk) { return 'Ikke installert' }

    try {
        $output = & $rustDesk --get-id 2>$null | Out-String
        $match = [regex]::Match($output, '[A-Za-z0-9][A-Za-z0-9_-]{5,}')
        if ($match.Success) { return $match.Value }
    }
    catch { }

    return 'Installerert, ID ikke tilgjengelig ennå'
}

function Get-RahNodeData {
    Write-Host 'Leser maskinvare og nettverk ...' -ForegroundColor Cyan

    $computer = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $gpus = Get-CimInstance Win32_VideoController |
        Select-Object -ExpandProperty Name
    $activeAdapter = Get-NetAdapter |
        Where-Object Status -eq 'Up' |
        Sort-Object LinkSpeed -Descending |
        Select-Object -First 1
    $ip = Get-RahLocalIP
    $bluetooth = Get-PnpDevice -Class Bluetooth -ErrorAction SilentlyContinue |
        Where-Object Status -eq 'OK' |
        Select-Object -ExpandProperty FriendlyName
    $spacedesk = Get-Service -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'spacedesk' -or $_.DisplayName -match 'spacedesk' } |
        Select-Object -First 1
    $disks = Get-CimInstance Win32_LogicalDisk -Filter 'DriveType=3' |
        ForEach-Object {
            '{0}: {1} GB free / {2} GB' -f $_.DeviceID,
                [Math]::Round($_.FreeSpace / 1GB, 0),
                [Math]::Round($_.Size / 1GB, 0)
        }

    $modelText = "$($computer.Manufacturer) $($computer.Model)"
    $rahName = if ($env:COMPUTERNAME -match 'OMEN' -or $modelText -match 'OMEN') {
        'RAH-OMEN'
    }
    elseif ($env:COMPUTERNAME -match 'LENOVO' -or $computer.Manufacturer -match 'LENOVO') {
        'RAH-LENOVO'
    }
    elseif ($env:COMPUTERNAME -match 'MAIN|DESKTOP') {
        'RAH-MAIN'
    }
    else {
        'RAH-' + $env:COMPUTERNAME.ToUpperInvariant()
    }

    return [PSCustomObject]@{
        RAHName = $rahName
        ComputerName = $env:COMPUTERNAME
        Registered = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Manufacturer = $computer.Manufacturer
        Model = $computer.Model
        Windows = $os.Caption
        WindowsVersion = $os.Version
        CPU = $cpu.Name
        Cores = $cpu.NumberOfCores
        LogicalProcessors = $cpu.NumberOfLogicalProcessors
        RAMGB = [Math]::Round($computer.TotalPhysicalMemory / 1GB, 1)
        GPU = @($gpus) -join ' | '
        Disks = @($disks) -join ' | '
        IP = $ip
        Adapter = $activeAdapter.InterfaceDescription
        LinkSpeed = $activeAdapter.LinkSpeed
        MAC = $activeAdapter.MacAddress
        RustDeskID = Get-RahRustDeskID
        Spacedesk = if ($spacedesk) { "$($spacedesk.Status) ($($spacedesk.DisplayName))" } else { 'Ikke funnet' }
        BluetoothDevices = @($bluetooth).Count
        Bluetooth = @($bluetooth) -join ' | '
        Room = 'Ikke plassert'
        Status = 'ONLINE'
    }
}

function ConvertTo-RahHtmlText {
    param([object]$Value)
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Write-RahDashboard {
    param([array]$Nodes)

    $cards = foreach ($node in $Nodes) {
        $name = ConvertTo-RahHtmlText $node.RAHName
        $computer = ConvertTo-RahHtmlText $node.ComputerName
        $model = ConvertTo-RahHtmlText "$($node.Manufacturer) $($node.Model)"
        $cpu = ConvertTo-RahHtmlText $node.CPU
        $gpu = ConvertTo-RahHtmlText $node.GPU
        $ip = ConvertTo-RahHtmlText $node.IP
        $adapter = ConvertTo-RahHtmlText $node.Adapter
        $link = ConvertTo-RahHtmlText $node.LinkSpeed
        $rustDesk = ConvertTo-RahHtmlText $node.RustDeskID
        $spacedeskText = ConvertTo-RahHtmlText $node.Spacedesk
        $room = ConvertTo-RahHtmlText $node.Room
        $registered = ConvertTo-RahHtmlText $node.Registered

        @"
<article class="card">
  <div class="name">$name</div>
  <div class="host">$computer · $model</div>
  <div class="status">● ONLINE</div>
  <dl>
    <dt>Rom</dt><dd>$room</dd>
    <dt>CPU</dt><dd>$cpu</dd>
    <dt>GPU</dt><dd>$gpu</dd>
    <dt>RAM</dt><dd>$($node.RAMGB) GB</dd>
    <dt>IP</dt><dd>$ip</dd>
    <dt>Nettverk</dt><dd>$adapter · $link</dd>
    <dt>RustDesk-ID</dt><dd class="gold">$rustDesk</dd>
    <dt>spacedesk</dt><dd>$spacedeskText</dd>
    <dt>Bluetooth</dt><dd>$($node.BluetoothDevices) registrert</dd>
  </dl>
  <small>Sist registrert: $registered</small>
</article>
"@
    }

    $html = @"
<!doctype html>
<html lang="no">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="15">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>RAH Node Dashboard</title>
<style>
body{margin:0;padding:28px;background:radial-gradient(circle at top,#302407,#070707 45%);color:#eadfb8;font-family:Segoe UI,Arial,sans-serif}
h1{color:#d7b541;letter-spacing:2px}.summary{color:#9e9169;margin-bottom:24px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(330px,1fr));gap:16px}.card{background:linear-gradient(145deg,#181308,#080808);border:1px solid #745b18;border-radius:15px;padding:19px;box-shadow:0 10px 30px #000}.name{font-size:22px;font-weight:800;color:#edcf67}.host{color:#aa9b6c;margin:4px 0 10px}.status{color:#70f397;font-weight:700}dl{display:grid;grid-template-columns:110px 1fr;gap:7px;margin-top:17px}dt{color:#aa9145}dd{margin:0;overflow-wrap:anywhere}.gold{color:#edcf67;font-weight:750}small{display:block;border-top:1px solid #40330f;padding-top:12px;margin-top:15px;color:#817858}
</style>
</head>
<body>
<h1>🐦‍⬛ RAH NODE COMMAND</h1>
<div class="summary">$($Nodes.Count) registrerte noder · oppdatert $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')</div>
<section class="grid">$($cards -join "`n")</section>
</body>
</html>
"@
    Set-Content -Path $DashboardFile -Value $html -Encoding utf8
}

function Save-RahNode {
    param([object]$Node)

    $nodes = @()
    if (Test-Path $DatabaseFile) {
        try { $nodes = @(Get-Content $DatabaseFile -Raw | ConvertFrom-Json) }
        catch { $nodes = @() }
    }

    $nodes = @($nodes | Where-Object ComputerName -ne $Node.ComputerName)
    $nodes += $Node
    $nodes = @($nodes | Sort-Object RAHName)

    $nodes | ConvertTo-Json -Depth 8 | Set-Content -Path $DatabaseFile -Encoding utf8
    $nodes | Export-Csv -Path $CsvFile -NoTypeInformation -Encoding utf8
    Write-RahDashboard -Nodes $nodes
}

function Start-RahRegistrationServer {
    Show-RahHeader
    $localIP = Get-RahLocalIP

    if (Test-RahAdmin) {
        $rule = Get-NetFirewallRule -DisplayName 'RAH Node Registration' -ErrorAction SilentlyContinue
        if (-not $rule) {
            New-NetFirewallRule -DisplayName 'RAH Node Registration' -Direction Inbound `
                -Protocol TCP -LocalPort $Port -Action Allow -Profile Private | Out-Null
        }
    }

    $mainNode = Get-RahNodeData
    $mainNode.RAHName = 'RAH-MAIN'
    $mainNode.Room = 'Vinterhage / kontor'
    Save-RahNode -Node $mainNode

    Write-Host ''
    Write-Host "SERVER-IP: $localIP" -ForegroundColor Yellow
    Write-Host "Port: $Port"
    Write-Host 'Hoved-PC-en er registrert. Venter pa Omen og Lenovo.' -ForegroundColor Green
    Write-Host 'Trykk Ctrl+C nar alle nodene er registrert.'
    Start-Process $DashboardFile

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
    $listener.Start()
    try {
        while ($true) {
            $client = $listener.AcceptTcpClient()
            try {
                $stream = $client.GetStream()
                $reader = [System.IO.BinaryReader]::new($stream, [Text.Encoding]::UTF8, $true)
                $writer = [System.IO.BinaryWriter]::new($stream, [Text.Encoding]::UTF8, $true)
                $json = $reader.ReadString()
                $node = $json | ConvertFrom-Json
                Save-RahNode -Node $node
                $writer.Write('OK')
                $writer.Flush()
                Write-Host "Registrert: $($node.RAHName) · $($node.IP)" -ForegroundColor Green
            }
            catch {
                Write-Host "Registreringen feilet: $($_.Exception.Message)" -ForegroundColor Red
            }
            finally {
                if ($reader) { $reader.Dispose() }
                if ($writer) { $writer.Dispose() }
                if ($stream) { $stream.Dispose() }
                $client.Dispose()
            }
        }
    }
    finally { $listener.Stop() }
}

function Send-RahNodeRegistration {
    Show-RahHeader
    if ([string]::IsNullOrWhiteSpace($ServerIP)) {
        $script:ServerIP = Read-Host 'Skriv SERVER-IP fra hoved-PC-en'
    }

    $node = Get-RahNodeData
    Write-Host "Sender $($node.RAHName) til $ServerIP`:$Port ..." -ForegroundColor Cyan

    $client = [System.Net.Sockets.TcpClient]::new()
    try {
        $client.Connect($ServerIP, $Port)
        $stream = $client.GetStream()
        $reader = [System.IO.BinaryReader]::new($stream, [Text.Encoding]::UTF8, $true)
        $writer = [System.IO.BinaryWriter]::new($stream, [Text.Encoding]::UTF8, $true)
        $writer.Write(($node | ConvertTo-Json -Depth 8 -Compress))
        $writer.Flush()
        $reply = $reader.ReadString()
        if ($reply -ne 'OK') { throw "Uventet svar: $reply" }
        Write-Host ''
        Write-Host "$($node.RAHName) er registrert i RAH Room Control." -ForegroundColor Green
        Write-Host "RustDesk-ID: $($node.RustDeskID)" -ForegroundColor Yellow
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($writer) { $writer.Dispose() }
        if ($stream) { $stream.Dispose() }
        $client.Dispose()
    }
}

if ($Mode -eq 'Menu') {
    Show-RahHeader
    Write-Host '1 - Hoved-PC: start registreringsserver'
    Write-Host '2 - Omen/Lenovo: registrer denne noden'
    Write-Host ''
    $choice = Read-Host 'Velg 1 eller 2'
    if ($choice -eq '1') { $Mode = 'Server' }
    elseif ($choice -eq '2') { $Mode = 'Node' }
    else { throw 'Ugyldig valg.' }
}

if ($Mode -eq 'Server') { Start-RahRegistrationServer }
if ($Mode -eq 'Node') { Send-RahNodeRegistration }

