[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Server', 'Node')]
    [string]$Mode = 'Menu',
    [string]$ServerIP = '',
    [ValidateRange(1, 65535)]
    [int]$Port = 18992,
    [ValidateRange(1, 65535)]
    [int]$DiscoveryPort = 18993
)

$ErrorActionPreference = 'Stop'
$RahIsWindows = [Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT
$RahUserRoot = if ($env:USERPROFILE) {
    $env:USERPROFILE
}
elseif ($env:HOME) {
    $env:HOME
}
else {
    [Environment]::GetFolderPath('UserProfile')
}
$RahDocumentsRoot = Join-Path $RahUserRoot 'Documents'
$RahRoot = Join-Path $RahDocumentsRoot 'RAH Room Control'
$DatabaseFile = Join-Path $RahRoot 'RAH-Nodes.json'
$CsvFile = Join-Path $RahRoot 'RAH-Nodes.csv'
$DashboardFile = Join-Path $RahRoot 'RAH-Node-Dashboard.html'
$RoomControlFile = Join-Path $RahRoot 'RAH-Room-Control.html'
$ServerConfigFile = Join-Path $RahRoot 'RAH-Server.json'
New-Item -ItemType Directory -Path $RahRoot -Force | Out-Null

function Show-RahHeader {
    Clear-Host
    Write-Host '==============================================' -ForegroundColor DarkYellow
    Write-Host '          RAH NODE REGISTRATION' -ForegroundColor Yellow
    Write-Host '==============================================' -ForegroundColor DarkYellow
    Write-Host ''
}

function Get-RahLocalIP {
    if (-not $RahIsWindows) {
        $ipCommand = Get-Command 'ip' -ErrorAction SilentlyContinue
        if ($ipCommand) {
            $route = (& $ipCommand.Source -4 route get 1.1.1.1 2>$null | Select-Object -First 1) -join ' '
            $match = [regex]::Match($route, '\bsrc\s+(\d{1,3}(?:\.\d{1,3}){3})')
            if ($match.Success) {
                return $match.Groups[1].Value
            }
        }

        $address = [Net.Dns]::GetHostAddresses([Net.Dns]::GetHostName()) |
            Where-Object {
                $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork -and
                $_.ToString() -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)'
            } |
            Select-Object -First 1
        if ($address) {
            return $address.ToString()
        }
        throw 'Fant ingen aktiv lokal IPv4-adresse.'
    }

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
    if (-not $RahIsWindows) {
        return $false
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-RahRustDeskPath {
    $paths = if ($RahIsWindows) {
        @(
            $(if ($env:ProgramFiles) { Join-Path $env:ProgramFiles 'RustDesk\rustdesk.exe' })
            $(if (${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} 'RustDesk\rustdesk.exe' })
            $(if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'RustDesk\rustdesk.exe' })
        )
    }
    else {
        @('/usr/bin/rustdesk', '/usr/local/bin/rustdesk', '/opt/rustdesk/rustdesk')
    }
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

    return 'Installert, ID ikke tilgjengelig ennå'
}

function Get-RahLinuxNodeData {
    Write-Host 'Leser Linux-maskinvare og nettverk ...' -ForegroundColor Cyan

    $manufacturer = if (Test-Path -LiteralPath '/sys/class/dmi/id/sys_vendor') {
        (Get-Content -LiteralPath '/sys/class/dmi/id/sys_vendor' -Raw).Trim()
    }
    else { 'Linux' }
    $model = if (Test-Path -LiteralPath '/sys/class/dmi/id/product_name') {
        (Get-Content -LiteralPath '/sys/class/dmi/id/product_name' -Raw).Trim()
    }
    else { [Net.Dns]::GetHostName() }

    $osText = 'Linux'
    $osVersion = ''
    if (Test-Path -LiteralPath '/etc/os-release') {
        $osLines = Get-Content -LiteralPath '/etc/os-release'
        $pretty = $osLines | Where-Object { $_ -match '^PRETTY_NAME=' } | Select-Object -First 1
        $version = $osLines | Where-Object { $_ -match '^VERSION_ID=' } | Select-Object -First 1
        if ($pretty) { $osText = ($pretty -replace '^PRETTY_NAME=', '').Trim('"') }
        if ($version) { $osVersion = ($version -replace '^VERSION_ID=', '').Trim('"') }
    }

    $cpu = 'Ukjent CPU'
    if (Test-Path -LiteralPath '/proc/cpuinfo') {
        $cpuLine = Get-Content -LiteralPath '/proc/cpuinfo' |
            Where-Object { $_ -match '^(model name|Hardware)\s*:' } |
            Select-Object -First 1
        if ($cpuLine) { $cpu = ($cpuLine -replace '^.*?:\s*', '').Trim() }
    }
    $logicalProcessors = [Environment]::ProcessorCount
    $cores = $logicalProcessors
    $lscpu = Get-Command 'lscpu' -ErrorAction SilentlyContinue
    if ($lscpu) {
        $coreLine = & $lscpu.Source 2>$null | Where-Object { $_ -match '^Core\(s\) per socket:' } | Select-Object -First 1
        $socketLine = & $lscpu.Source 2>$null | Where-Object { $_ -match '^Socket\(s\):' } | Select-Object -First 1
        if ($coreLine -and $socketLine) {
            $coreCount = [int](($coreLine -split ':', 2)[1].Trim())
            $socketCount = [int](($socketLine -split ':', 2)[1].Trim())
            if ($coreCount -gt 0 -and $socketCount -gt 0) { $cores = $coreCount * $socketCount }
        }
    }

    $ramGB = 0
    if (Test-Path -LiteralPath '/proc/meminfo') {
        $ramLine = Get-Content -LiteralPath '/proc/meminfo' |
            Where-Object { $_ -match '^MemTotal:' } | Select-Object -First 1
        if ($ramLine -match '(\d+)') { $ramGB = [Math]::Round(([double]$Matches[1] * 1KB) / 1GB, 1) }
    }

    $gpu = 'Ukjent GPU'
    $lspci = Get-Command 'lspci' -ErrorAction SilentlyContinue
    if ($lspci) {
        $gpuLines = & $lspci.Source 2>$null |
            Where-Object { $_ -match '(VGA compatible controller|3D controller|Display controller)' }
        if ($gpuLines) { $gpu = @($gpuLines) -join ' | ' }
    }

    $ip = Get-RahLocalIP
    $adapter = 'Ukjent adapter'
    $ipCommand = Get-Command 'ip' -ErrorAction SilentlyContinue
    if ($ipCommand) {
        $route = (& $ipCommand.Source -4 route get 1.1.1.1 2>$null | Select-Object -First 1) -join ' '
        $adapterMatch = [regex]::Match($route, '\bdev\s+(\S+)')
        if ($adapterMatch.Success) { $adapter = $adapterMatch.Groups[1].Value }
    }
    $linkSpeed = 'Ukjent'
    $speedFile = "/sys/class/net/$adapter/speed"
    if (Test-Path -LiteralPath $speedFile) {
        $speedValue = (Get-Content -LiteralPath $speedFile -Raw -ErrorAction SilentlyContinue).Trim()
        if ($speedValue -match '^\d+$' -and [int]$speedValue -gt 0) { $linkSpeed = "$speedValue Mbps" }
    }
    $mac = 'Ukjent'
    $macFile = "/sys/class/net/$adapter/address"
    if (Test-Path -LiteralPath $macFile) { $mac = (Get-Content -LiteralPath $macFile -Raw).Trim() }

    $networkName = $adapter
    $nmcli = Get-Command 'nmcli' -ErrorAction SilentlyContinue
    if ($nmcli) {
        $wifi = & $nmcli.Source -t -f ACTIVE,SSID dev wifi 2>$null |
            Where-Object { $_ -match '^yes:' } | Select-Object -First 1
        if ($wifi) { $networkName = ($wifi -replace '^yes:', '').Trim() }
    }

    $bluetooth = @()
    $bluetoothctl = Get-Command 'bluetoothctl' -ErrorAction SilentlyContinue
    if ($bluetoothctl) {
        $bluetooth = @(
            & $bluetoothctl.Source devices 2>$null |
                ForEach-Object { ($_ -replace '^Device\s+[0-9A-Fa-f:]+\s*', '').Trim() } |
                Where-Object { $_ }
        )
    }

    $disks = 'Se df -h'
    $df = Get-Command 'df' -ErrorAction SilentlyContinue
    if ($df) {
        $diskLines = & $df.Source -h -x tmpfs -x devtmpfs 2>$null | Select-Object -Skip 1
        if ($diskLines) { $disks = @($diskLines) -join ' | ' }
    }

    $hostName = [Net.Dns]::GetHostName()
    $rahName = if ($hostName -match 'LENOVO' -or $manufacturer -match 'LENOVO') {
        'RAH-LENOVO'
    }
    elseif ($hostName -match 'OMEN' -or $model -match 'OMEN') {
        'RAH-OMEN'
    }
    else {
        'RAH-' + $hostName.ToUpperInvariant()
    }
    $role = if ($rahName -eq 'RAH-LENOVO') { 'Cluster Node 3 / Kali-Debian' } else { 'Linux Cluster Node' }

    return [PSCustomObject]@{
        RAHName = $rahName
        Role = $role
        ComputerName = $hostName
        Registered = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Manufacturer = $manufacturer
        Model = $model
        Windows = $osText
        WindowsVersion = $osVersion
        CPU = $cpu
        Cores = $cores
        LogicalProcessors = $logicalProcessors
        RAMGB = $ramGB
        GPU = $gpu
        Disks = $disks
        IP = $ip
        Adapter = $adapter
        NetworkName = $networkName
        LinkSpeed = $linkSpeed
        MAC = $mac
        RustDeskID = Get-RahRustDeskID
        Spacedesk = 'Ikke relevant på Linux'
        BluetoothDevices = @($bluetooth).Count
        Bluetooth = @($bluetooth) -join ' | '
        Room = 'Datarom / Vinterhage'
        Status = 'ONLINE'
    }
}

function Save-RahServerConfig {
    param(
        [Parameter(Mandatory)]
        [string]$IP,
        [string]$ComputerName = '',
        [int]$RegistrationPort = $Port,
        [int]$SpeedPort = 18991
    )

    [ordered]@{
        protocol = 'RAH_HOME_SERVER_V1'
        computer = $ComputerName
        ip = $IP
        registration_port = $RegistrationPort
        discovery_port = $DiscoveryPort
        speed_port = $SpeedPort
        saved_at = (Get-Date).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath $ServerConfigFile -Encoding UTF8
}

function Find-RahRegistrationServer {
    Write-Host "Søker automatisk etter RAH hoved-PC på lokalnettet ..." -ForegroundColor Cyan
    $udp = [Net.Sockets.UdpClient]::new()
    try {
        $udp.EnableBroadcast = $true
        $udp.Client.ReceiveTimeout = 1800
        $message = [Text.Encoding]::UTF8.GetBytes('RAH_NODE_DISCOVER_V1')
        $target = [Net.IPEndPoint]::new([Net.IPAddress]::Broadcast, $DiscoveryPort)
        [void]$udp.Send($message, $message.Length, $target)

        $remote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
        $replyBytes = $udp.Receive([ref]$remote)
        $reply = [Text.Encoding]::UTF8.GetString($replyBytes) | ConvertFrom-Json
        if ($reply.protocol -ne 'RAH_NODE_SERVER_V1') {
            return $null
        }

        $ip = [string]$reply.ip
        if (-not $ip) {
            $ip = $remote.Address.ToString()
        }
        if ($ip -notmatch '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)') {
            return $null
        }

        $registrationPort = [int]$reply.registration_port
        if ($registrationPort -lt 1 -or $registrationPort -gt 65535) {
            return $null
        }
        $script:Port = $registrationPort

        Save-RahServerConfig -IP $ip -ComputerName ([string]$reply.computer) `
            -RegistrationPort $registrationPort -SpeedPort ([int]$reply.speed_port)
        Write-Host "Fant $($reply.computer) på $ip." -ForegroundColor Green
        return $ip
    }
    catch {
        Write-Host 'Automatisk søk fant ingen aktiv registreringsserver.' -ForegroundColor DarkYellow
        return $null
    }
    finally {
        $udp.Dispose()
    }
}

function Get-RahNodeData {
    if (-not $RahIsWindows) {
        return (Get-RahLinuxNodeData)
    }

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
    $networkProfile = if ($activeAdapter) {
        Get-NetConnectionProfile -InterfaceIndex $activeAdapter.IfIndex `
            -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    else {
        $null
    }
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

    $role = 'Home Device'
    $room = 'Ikke plassert'
    if ($rahName -eq 'RAH-MAIN') {
        $role = 'Main Room / Home Server'
        $room = 'Datarom / Vinterhage'
    }
    elseif ($rahName -eq 'RAH-OMEN') {
        $role = 'Cluster Node 2 / Windows'
        $room = 'Datarom / Vinterhage'
    }
    elseif ($rahName -eq 'RAH-LENOVO') {
        $role = 'Cluster Node 3 / Kali-Debian'
        $room = 'Datarom / Vinterhage'
    }

    return [PSCustomObject]@{
        RAHName = $rahName
        Role = $role
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
        NetworkName = if ($networkProfile) { $networkProfile.Name } else { 'Ukjent' }
        LinkSpeed = $activeAdapter.LinkSpeed
        MAC = $activeAdapter.MacAddress
        RustDeskID = Get-RahRustDeskID
        Spacedesk = if ($spacedesk) { "$($spacedesk.Status) ($($spacedesk.DisplayName))" } else { 'Ikke funnet' }
        BluetoothDevices = @($bluetooth).Count
        Bluetooth = @($bluetooth) -join ' | '
        Room = $room
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
        $role = ConvertTo-RahHtmlText $(if ($node.Role) { $node.Role } else { 'Home Device' })
        $computer = ConvertTo-RahHtmlText $node.ComputerName
        $model = ConvertTo-RahHtmlText "$($node.Manufacturer) $($node.Model)"
        $cpu = ConvertTo-RahHtmlText $node.CPU
        $gpu = ConvertTo-RahHtmlText $node.GPU
        $ip = ConvertTo-RahHtmlText $node.IP
        $adapter = ConvertTo-RahHtmlText $node.Adapter
        $link = ConvertTo-RahHtmlText $node.LinkSpeed
        $networkName = ConvertTo-RahHtmlText $(if ($node.NetworkName) { $node.NetworkName } else { 'Ukjent' })
        $rustDesk = ConvertTo-RahHtmlText $node.RustDeskID
        $spacedeskText = ConvertTo-RahHtmlText $node.Spacedesk
        $room = ConvertTo-RahHtmlText $node.Room
        $registered = ConvertTo-RahHtmlText $node.Registered
        $bluetoothItems = @(
            ([string]$node.Bluetooth -split '\s+\|\s+') |
                Where-Object { $_ } |
                ForEach-Object { ConvertTo-RahHtmlText $_ }
        )
        $bluetoothHtml = if ($bluetoothItems) {
            '<details><summary>{0} registrert</summary><div class="bt">{1}</div></details>' -f `
                $bluetoothItems.Count, ($bluetoothItems -join '<br>')
        }
        else {
            'Ingen aktive/parede Bluetooth-enheter funnet'
        }

        @"
<article class="card">
  <div class="name">$name</div>
  <div class="host">$computer · $model</div>
  <div class="status">● ONLINE</div>
  <dl>
    <dt>Rolle</dt><dd class="gold">$role</dd>
    <dt>Rom</dt><dd>$room</dd>
    <dt>CPU</dt><dd>$cpu</dd>
    <dt>GPU</dt><dd>$gpu</dd>
    <dt>RAM</dt><dd>$($node.RAMGB) GB</dd>
    <dt>IP</dt><dd>$ip</dd>
    <dt>Nettverk</dt><dd>$networkName · $adapter · $link</dd>
    <dt>RustDesk-ID</dt><dd class="gold">$rustDesk</dd>
    <dt>spacedesk</dt><dd>$spacedeskText</dd>
    <dt>Bluetooth</dt><dd>$bluetoothHtml</dd>
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
h1{color:#d7b541;letter-spacing:2px}.summary{color:#9e9169;margin-bottom:24px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(330px,1fr));gap:16px}.card{background:linear-gradient(145deg,#181308,#080808);border:1px solid #745b18;border-radius:15px;padding:19px;box-shadow:0 10px 30px #000}.name{font-size:22px;font-weight:800;color:#edcf67}.host{color:#aa9b6c;margin:4px 0 10px}.status{color:#70f397;font-weight:700}dl{display:grid;grid-template-columns:110px 1fr;gap:7px;margin-top:17px}dt{color:#aa9145}dd{margin:0;overflow-wrap:anywhere}.gold{color:#edcf67;font-weight:750}details{cursor:pointer}.bt{color:#bfb28c;margin-top:6px;line-height:1.45}small{display:block;border-top:1px solid #40330f;padding-top:12px;margin-top:15px;color:#817858}
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

function Write-RahRoomControl {
    param([array]$Nodes)

    $rooms = @(
        [PSCustomObject]@{
            Name = 'Datarom'
            Subtitle = 'Vinterhage · MAIN ROOM'
            Main = $true
            Devices = @(
                'RAH-MAIN · Windows 11 Home Server'
                'RAH-OMEN · Cluster Node 2'
                'RAH-LENOVO · Cluster Node 3 / Kali-Debian'
                'RAH-PROJECTOR-POLAROID · Android projector'
                'RAH-PROJECTOR-HY320 · Android projector'
                'RAH-TV-SAMSUNG-DATAROM'
                'RAH-XIAOMI-TV-DATAROM'
            )
        }
        [PSCustomObject]@{
            Name = 'Stue 1'
            Subtitle = 'Stor skjerm- og kinoflate'
            Main = $false
            Devices = @(
                'RAH-PROJECTOR-STUE1-A'
                'RAH-PROJECTOR-STUE1-B'
                'RAH-TV-STUE1'
            )
        }
        [PSCustomObject]@{
            Name = 'Stue 2'
            Subtitle = 'Sekundær sosial sone'
            Main = $false
            Devices = @(
                'RAH-TV-STUE2'
                'RAH-GOOGLE-TV-STUE2'
            )
        }
        [PSCustomObject]@{
            Name = 'Soverom'
            Subtitle = 'Soverom 2 Vest-profil'
            Main = $false
            Devices = @(
                'RAH-TV-SOVEROM'
                'RAH-PROJECTOR-SOVEROM2-VEST'
                'RAH-XIAOMI-TV-SOVEROM'
            )
        }
        [PSCustomObject]@{
            Name = 'Bad'
            Subtitle = 'Skjerm og projektor'
            Main = $false
            Devices = @(
                'RAH-TV-BAD'
                'RAH-PROJECTOR-BAD'
            )
        }
        [PSCustomObject]@{
            Name = 'Flyttbare enheter'
            Subtitle = 'Fjernstyring og ekstraskjermer'
            Main = $false
            Devices = @(
                'RAH-PHONE-1 · spacedesk / RustDesk'
                'RAH-PHONE-2 · spacedesk / RustDesk'
                'RAH-PHONE-3 · spacedesk / RustDesk'
                'RAH-PS4-REMOTE'
            )
        }
    )

    $roomCards = foreach ($room in $rooms) {
        $roomName = ConvertTo-RahHtmlText $room.Name
        $subtitle = ConvertTo-RahHtmlText $room.Subtitle
        $mainBadge = if ($room.Main) { '<span class="main">MAIN ROOM</span>' } else { '' }
        $devices = foreach ($device in $room.Devices) {
            '<li><span>{0}</span><em>KJENT PROFIL</em></li>' -f (ConvertTo-RahHtmlText $device)
        }
        @"
<article class="room">
  <header><div><h2>$roomName</h2><p>$subtitle</p></div>$mainBadge</header>
  <ul>$($devices -join "`n")</ul>
</article>
"@
    }

    $nodeRows = foreach ($node in $Nodes) {
        $name = ConvertTo-RahHtmlText $node.RAHName
        $role = ConvertTo-RahHtmlText $(if ($node.Role) { $node.Role } else { 'Home Device' })
        $room = ConvertTo-RahHtmlText $node.Room
        $ip = ConvertTo-RahHtmlText $node.IP
        $rustDesk = ConvertTo-RahHtmlText $node.RustDeskID
        @"
<tr><td class="gold">$name</td><td>$role</td><td>$room</td><td>$ip</td><td>$rustDesk</td><td><span class="online">ONLINE</span></td></tr>
"@
    }
    if (-not $nodeRows) {
        $nodeRows = '<tr><td colspan="6">Ingen noder er registrert ennå.</td></tr>'
    }

    $bluetoothCards = foreach ($node in $Nodes) {
        $items = @(
            ([string]$node.Bluetooth -split '\s+\|\s+') |
                Where-Object { $_ } |
                ForEach-Object { '<li>{0}</li>' -f (ConvertTo-RahHtmlText $_) }
        )
        if (-not $items) {
            $items = '<li>Ingen aktive/parede Bluetooth-enheter funnet.</li>'
        }
        @"
<article class="bluetooth"><h3>$(ConvertTo-RahHtmlText $node.RAHName)</h3><ul>$($items -join "`n")</ul></article>
"@
    }
    if (-not $bluetoothCards) {
        $bluetoothCards = '<article class="bluetooth"><h3>Venter på noder</h3><p>Bluetooth-kartet fylles når en PC registreres.</p></article>'
    }

    $html = @"
<!doctype html>
<html lang="no">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="20">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>RAH Room Control</title>
<style>
:root{color-scheme:dark;--gold:#d9b941;--light:#f1dfa0;--line:#705617;--panel:#120f08;--green:#70ef9a}*{box-sizing:border-box}body{margin:0;background:radial-gradient(circle at 25% 0,#302407,#060606 46%);color:#e6dbb4;font:15px Segoe UI,Arial,sans-serif;padding:28px}main{max-width:1500px;margin:auto}h1{color:var(--gold);letter-spacing:3px;margin-bottom:4px}.lead{color:#9d916e;margin:0 0 24px}.rooms{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:16px}.room,.bluetooth,.panel{background:linear-gradient(145deg,#181308,#080808);border:1px solid var(--line);border-radius:16px;padding:18px;box-shadow:0 12px 28px #0008}.room header{display:flex;justify-content:space-between;gap:12px;align-items:flex-start}.room h2,.bluetooth h3{color:var(--light);margin:0}.room p{color:#9e916d;margin:4px 0}.main{background:linear-gradient(135deg,#ffe78b,#b68118);color:#171005;padding:6px 9px;border-radius:999px;font-weight:900;font-size:11px}.room ul,.bluetooth ul{list-style:none;padding:0;margin:15px 0 0}.room li{display:flex;justify-content:space-between;gap:12px;padding:8px 0;border-top:1px solid #34290e}.room em{font-style:normal;color:#897a50;font-size:11px;white-space:nowrap}.panel{margin-top:20px;overflow:auto}.panel h2{color:var(--gold)}table{width:100%;border-collapse:collapse;min-width:900px}th,td{text-align:left;padding:10px;border-bottom:1px solid #34290e}th{color:#a9934c}.gold{color:var(--light);font-weight:800}.online{color:var(--green);font-weight:800}.btgrid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:14px}.bluetooth li{padding:5px 0;border-bottom:1px solid #2b230f;color:#bdb18a}.foot{color:#817858;margin-top:20px}
</style>
</head>
<body><main>
<h1>🐦‍⬛ RAH ROOM CONTROL</h1>
<p class="lead">Håkøya Home Layer · $($rooms.Count) romprofiler · $($Nodes.Count) registrerte PC-noder</p>
<section class="rooms">$($roomCards -join "`n")</section>
<section class="panel"><h2>REGISTRERTE NODER</h2><table><thead><tr><th>Navn</th><th>Rolle</th><th>Rom</th><th>IP</th><th>RustDesk-ID</th><th>Status</th></tr></thead><tbody>$($nodeRows -join "`n")</tbody></table></section>
<section class="panel"><h2>BLUETOOTH-KART</h2><p>Bare lokalt registrerte, aktive/parede enheter vises. Ingen automatisk tilkobling utføres.</p><div class="btgrid">$($bluetoothCards -join "`n")</div></section>
<p class="foot">Oppdatert $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss') · MAIN ROOM er eksklusivt satt til Datarom / Vinterhage.</p>
</main></body></html>
"@

    Set-Content -LiteralPath $RoomControlFile -Value $html -Encoding UTF8
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
    Write-RahRoomControl -Nodes $nodes
}

function Start-RahRegistrationServer {
    Show-RahHeader
    $localIP = Get-RahLocalIP

    if (Test-RahAdmin) {
        $tcpRule = Get-NetFirewallRule -DisplayName 'RAH Node Registration' -ErrorAction SilentlyContinue
        if (-not $tcpRule) {
            New-NetFirewallRule -DisplayName 'RAH Node Registration' -Direction Inbound `
                -Protocol TCP -LocalPort $Port -Action Allow -Profile Private | Out-Null
        }
        $udpRule = Get-NetFirewallRule -DisplayName 'RAH Node Discovery' -ErrorAction SilentlyContinue
        if (-not $udpRule) {
            New-NetFirewallRule -DisplayName 'RAH Node Discovery' -Direction Inbound `
                -Protocol UDP -LocalPort $DiscoveryPort -Action Allow -Profile Private | Out-Null
        }
    }

    $mainNode = Get-RahNodeData
    $mainNode.RAHName = 'RAH-MAIN'
    $mainNode.Role = 'Main Room / Home Server'
    $mainNode.Room = 'Datarom / Vinterhage'
    Save-RahNode -Node $mainNode
    Save-RahServerConfig -IP $localIP -ComputerName $env:COMPUTERNAME

    Write-Host ''
    Write-Host "SERVER-IP: $localIP" -ForegroundColor Yellow
    Write-Host "Port: $Port"
    Write-Host "Automatisk funn: UDP $DiscoveryPort"
    Write-Host 'Hoved-PC-en er registrert. Venter på Omen og Lenovo.' -ForegroundColor Green
    Write-Host 'De andre maskinene finner denne IP-en automatisk.' -ForegroundColor Green
    Write-Host 'Trykk Ctrl+C når alle nodene er registrert.'
    Start-Process $DashboardFile

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
    $udp = [Net.Sockets.UdpClient]::new($DiscoveryPort)
    $listener.Start()
    try {
        while ($true) {
            while ($udp.Available -gt 0) {
                $remote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
                $requestBytes = $udp.Receive([ref]$remote)
                $requestText = [Text.Encoding]::UTF8.GetString($requestBytes)
                if ($requestText -eq 'RAH_NODE_DISCOVER_V1') {
                    $response = [ordered]@{
                        protocol = 'RAH_NODE_SERVER_V1'
                        computer = $env:COMPUTERNAME
                        ip = $localIP
                        registration_port = $Port
                        speed_port = 18991
                    } | ConvertTo-Json -Compress
                    $responseBytes = [Text.Encoding]::UTF8.GetBytes($response)
                    [void]$udp.Send($responseBytes, $responseBytes.Length, $remote)
                    Write-Host "Hoved-PC funnet av $($remote.Address)." -ForegroundColor DarkCyan
                }
            }

            if ($listener.Pending()) {
                $client = $listener.AcceptTcpClient()
                $reader = $null
                $writer = $null
                $stream = $null
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

            Start-Sleep -Milliseconds 80
        }
    }
    finally {
        $udp.Dispose()
        $listener.Stop()
    }
}

function Send-RahNodeRegistration {
    Show-RahHeader
    if ([string]::IsNullOrWhiteSpace($ServerIP)) {
        $script:ServerIP = Find-RahRegistrationServer
    }
    if ([string]::IsNullOrWhiteSpace($ServerIP)) {
        $script:ServerIP = Read-Host 'Automatisk funn mislyktes. Skriv SERVER-IP fra hoved-PC-en'
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
        Save-RahServerConfig -IP $ServerIP -ComputerName 'RAH-MAIN'
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
