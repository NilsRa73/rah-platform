[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Server', 'Client')]
    [string]$Mode = 'Menu',

    [string]$ServerIP = '',

    [ValidateRange(1, 65535)]
    [int]$Port = 18991,

    [ValidateRange(1, 65535)]
    [int]$DiscoveryPort = 18994,

    [ValidateRange(16, 2048)]
    [int]$TestSizeMB = 128
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
$RahRoot = Join-Path (Join-Path $RahUserRoot 'Documents') 'RAH Room Control'
$ResultFile = Join-Path $RahRoot 'RAH-Link-Speed-Results.csv'
$ServerConfigFile = Join-Path $RahRoot 'RAH-Server.json'
New-Item -ItemType Directory -Path $RahRoot -Force | Out-Null

function Show-RahHeader {
    Clear-Host
    Write-Host '==============================================' -ForegroundColor DarkYellow
    Write-Host '        RAH LINK SPEED - HAKOYA' -ForegroundColor Yellow
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
        throw 'Fant ingen aktiv privat IPv4-adresse. Kontroller Wi-Fi eller nettverkskabel.'
    }

    $address = Get-NetIPAddress -AddressFamily IPv4 |
        Where-Object {
            $_.IPAddress -match '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)' -and
            $_.InterfaceAlias -notmatch 'Loopback|Bluetooth|vEthernet'
        } |
        Sort-Object InterfaceMetric |
        Select-Object -First 1

    if (-not $address) {
        throw 'Fant ingen aktiv privat IPv4-adresse. Kontroller Wi-Fi eller nettverkskabel.'
    }

    return $address.IPAddress
}

function Test-RahAdministrator {
    if (-not $RahIsWindows) {
        return $false
    }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-RahComputerName {
    if ($env:COMPUTERNAME) {
        return $env:COMPUTERNAME
    }
    return [Net.Dns]::GetHostName()
}

function Get-RahAdapterDescription {
    if ($RahIsWindows) {
        $adapter = Get-NetAdapter |
            Where-Object Status -eq 'Up' |
            Sort-Object LinkSpeed -Descending |
            Select-Object -First 1
        if ($adapter) {
            return [string]$adapter.InterfaceDescription
        }
        return 'Ukjent Windows-adapter'
    }

    $ipCommand = Get-Command 'ip' -ErrorAction SilentlyContinue
    if ($ipCommand) {
        $route = (& $ipCommand.Source -4 route get 1.1.1.1 2>$null | Select-Object -First 1) -join ' '
        $match = [regex]::Match($route, '\bdev\s+(\S+)')
        if ($match.Success) {
            return "Linux $($match.Groups[1].Value)"
        }
    }
    return 'Ukjent Linux-adapter'
}

function Save-RahSpeedServerConfig {
    param(
        [Parameter(Mandatory)]
        [string]$IP,
        [string]$ComputerName = '',
        [int]$SpeedPort = $Port
    )

    $registrationPort = 18992
    $nodeDiscoveryPort = 18993
    if (Test-Path -LiteralPath $ServerConfigFile -PathType Leaf) {
        try {
            $existing = Get-Content -LiteralPath $ServerConfigFile -Raw | ConvertFrom-Json
            if ([int]$existing.registration_port -ge 1) {
                $registrationPort = [int]$existing.registration_port
            }
            if ([int]$existing.discovery_port -ge 1) {
                $nodeDiscoveryPort = [int]$existing.discovery_port
            }
        }
        catch { }
    }

    [ordered]@{
        protocol = 'RAH_HOME_SERVER_V1'
        computer = $ComputerName
        ip = $IP
        registration_port = $registrationPort
        discovery_port = $nodeDiscoveryPort
        speed_port = $SpeedPort
        speed_discovery_port = $DiscoveryPort
        saved_at = (Get-Date).ToString('o')
    } | ConvertTo-Json | Set-Content -LiteralPath $ServerConfigFile -Encoding UTF8
}

function Find-RahSavedSpeedServer {
    if (-not (Test-Path -LiteralPath $ServerConfigFile -PathType Leaf)) {
        return $null
    }
    try {
        $config = Get-Content -LiteralPath $ServerConfigFile -Raw | ConvertFrom-Json
        $ip = [string]$config.ip
        if ($ip -notmatch '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)') {
            return $null
        }
        if ([int]$config.speed_port -ge 1 -and [int]$config.speed_port -le 65535) {
            $script:Port = [int]$config.speed_port
        }
        return $ip
    }
    catch {
        return $null
    }
}

function Find-RahSpeedServer {
    Write-Host 'Søker automatisk etter RAH måleserver på lokalnettet ...' -ForegroundColor Cyan
    $udp = [Net.Sockets.UdpClient]::new()
    try {
        $udp.EnableBroadcast = $true
        $udp.Client.ReceiveTimeout = 1800
        $message = [Text.Encoding]::UTF8.GetBytes('RAH_SPEED_DISCOVER_V1')
        $target = [Net.IPEndPoint]::new([Net.IPAddress]::Broadcast, $DiscoveryPort)
        [void]$udp.Send($message, $message.Length, $target)

        $remote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
        $replyBytes = $udp.Receive([ref]$remote)
        $reply = [Text.Encoding]::UTF8.GetString($replyBytes) | ConvertFrom-Json
        if ($reply.protocol -ne 'RAH_SPEED_SERVER_V1') {
            return $null
        }

        $ip = [string]$reply.ip
        if (-not $ip) {
            $ip = $remote.Address.ToString()
        }
        if ($ip -notmatch '^(10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[01])\.)') {
            return $null
        }

        $speedPort = [int]$reply.speed_port
        if ($speedPort -lt 1 -or $speedPort -gt 65535) {
            return $null
        }
        $script:Port = $speedPort
        Save-RahSpeedServerConfig -IP $ip -ComputerName ([string]$reply.computer) -SpeedPort $speedPort
        Write-Host "Fant $($reply.computer) på $ip`:$speedPort." -ForegroundColor Green
        return $ip
    }
    catch {
        Write-Host 'Direkte søk fant ingen aktiv måleserver.' -ForegroundColor DarkYellow
        return $null
    }
    finally {
        $udp.Dispose()
    }
}

function Start-RahServer {
    Show-RahHeader
    $localIP = Get-RahLocalIP
    $computerName = Get-RahComputerName

    Write-Host 'Modus: HOVED-PC / MALESERVER' -ForegroundColor Cyan
    Write-Host "Maskin: $computerName"
    Write-Host "SERVER-IP: $localIP" -ForegroundColor Yellow
    Write-Host "Port: $Port"
    Write-Host ''

    if (Test-RahAdministrator) {
        $rule = Get-NetFirewallRule -DisplayName 'RAH Link Speed' -ErrorAction SilentlyContinue
        if (-not $rule) {
            New-NetFirewallRule -DisplayName 'RAH Link Speed' -Direction Inbound `
                -Protocol TCP -LocalPort $Port -Action Allow -Profile Private | Out-Null
            Write-Host 'Brannmurregel opprettet for privat nettverk.' -ForegroundColor Green
        }
        $udpRule = Get-NetFirewallRule -DisplayName 'RAH Link Speed Discovery' -ErrorAction SilentlyContinue
        if (-not $udpRule) {
            New-NetFirewallRule -DisplayName 'RAH Link Speed Discovery' -Direction Inbound `
                -Protocol UDP -LocalPort $DiscoveryPort -Action Allow -Profile Private | Out-Null
            Write-Host 'Automatisk måleserver-funn er åpnet på privat nettverk.' -ForegroundColor Green
        }
    }
    else {
        Write-Host 'Hvis klienten ikke kommer inn: start PowerShell som administrator.' -ForegroundColor DarkYellow
    }

    Write-Host 'Venter pa Omen, Lenovo eller en annen RAH-node.' -ForegroundColor Green
    Write-Host "Andre noder finner serveren automatisk via UDP $DiscoveryPort." -ForegroundColor Green
    Write-Host 'Trykk Ctrl+C nar malingene er ferdige.'
    Write-Host ''

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
    $udp = [Net.Sockets.UdpClient]::new($DiscoveryPort)
    $listener.Start()
    Save-RahSpeedServerConfig -IP $localIP -ComputerName $computerName -SpeedPort $Port

    try {
        while ($true) {
            while ($udp.Available -gt 0) {
                $remote = [Net.IPEndPoint]::new([Net.IPAddress]::Any, 0)
                $requestBytes = $udp.Receive([ref]$remote)
                $requestText = [Text.Encoding]::UTF8.GetString($requestBytes)
                if ($requestText -eq 'RAH_SPEED_DISCOVER_V1') {
                    $response = [ordered]@{
                        protocol = 'RAH_SPEED_SERVER_V1'
                        computer = $computerName
                        ip = $localIP
                        speed_port = $Port
                    } | ConvertTo-Json -Compress
                    $responseBytes = [Text.Encoding]::UTF8.GetBytes($response)
                    [void]$udp.Send($responseBytes, $responseBytes.Length, $remote)
                    Write-Host "Måleserver funnet av $($remote.Address)." -ForegroundColor DarkCyan
                }
            }

            if ($listener.Pending()) {
                $client = $listener.AcceptTcpClient()
                $reader = $null
                $writer = $null
                $stream = $null
                try {
                    $remoteIP = $client.Client.RemoteEndPoint.Address.ToString()
                    Write-Host "Tilkobling fra $remoteIP ..." -ForegroundColor Cyan

                    $stream = $client.GetStream()
                    $reader = [System.IO.BinaryReader]::new($stream, [Text.Encoding]::UTF8, $true)
                    $writer = [System.IO.BinaryWriter]::new($stream, [Text.Encoding]::UTF8, $true)

                    $clientName = $reader.ReadString()
                    $requestedMB = $reader.ReadInt32()
                    $bytesToSend = [int64]$requestedMB * 1MB
                    $writer.Write($bytesToSend)
                    $writer.Flush()

                    $buffer = [byte[]]::new(256KB)
                    [System.Random]::new().NextBytes($buffer)
                    $remaining = $bytesToSend

                    while ($remaining -gt 0) {
                        $count = [int][Math]::Min($buffer.Length, $remaining)
                        $stream.Write($buffer, 0, $count)
                        $remaining -= $count
                    }
                    $stream.Flush()

                    $seconds = $reader.ReadDouble()
                    $mbps = $reader.ReadDouble()
                    $megabytesSec = $reader.ReadDouble()
                    $adapterName = $reader.ReadString()
                    $rating = $reader.ReadString()

                    $record = [PSCustomObject]@{
                        Time = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
                        Server = $computerName
                        ServerIP = $localIP
                        Client = $clientName
                        ClientIP = $remoteIP
                        Adapter = $adapterName
                        TestSizeMB = $requestedMB
                        Seconds = [Math]::Round($seconds, 2)
                        Mbps = [Math]::Round($mbps, 1)
                        MegabytesPerSecond = [Math]::Round($megabytesSec, 1)
                        Rating = $rating
                    }

                    $append = Test-Path $ResultFile
                    $record | Export-Csv -Path $ResultFile -NoTypeInformation -Encoding utf8 -Append:$append

                    Write-Host ''
                    Write-Host "$clientName : $([Math]::Round($mbps, 1)) Mbit/s" -ForegroundColor Yellow
                    Write-Host "$([Math]::Round($megabytesSec, 1)) MB/s - $rating" -ForegroundColor Green
                    Write-Host "Lagret: $ResultFile"
                    Write-Host ''
                }
                catch {
                    Write-Host "Målingen feilet: $($_.Exception.Message)" -ForegroundColor Red
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

function Start-RahClient {
    Show-RahHeader
    $computerName = Get-RahComputerName

    if ([string]::IsNullOrWhiteSpace($ServerIP)) {
        $script:ServerIP = Find-RahSpeedServer
    }
    if ([string]::IsNullOrWhiteSpace($ServerIP)) {
        $script:ServerIP = Find-RahSavedSpeedServer
        if ($ServerIP) {
            Write-Host "Bruker lagret RAH hoved-PC: $ServerIP`:$Port" -ForegroundColor Green
        }
    }
    if ([string]::IsNullOrWhiteSpace($ServerIP)) {
        $script:ServerIP = Read-Host 'Automatisk funn mislyktes. Skriv SERVER-IP fra hoved-PC-en'
    }

    Write-Host "Kobler $computerName til $ServerIP`:$Port ..." -ForegroundColor Cyan
    $adapterDescription = Get-RahAdapterDescription

    $client = [System.Net.Sockets.TcpClient]::new()
    $client.ReceiveBufferSize = 1MB
    $client.SendBufferSize = 1MB

    try {
        $client.Connect($ServerIP, $Port)
        $stream = $client.GetStream()
        $reader = [System.IO.BinaryReader]::new($stream, [Text.Encoding]::UTF8, $true)
        $writer = [System.IO.BinaryWriter]::new($stream, [Text.Encoding]::UTF8, $true)

        $writer.Write($computerName)
        $writer.Write($TestSizeMB)
        $writer.Flush()

        $expectedBytes = $reader.ReadInt64()
        $buffer = [byte[]]::new(256KB)
        [int64]$received = 0
        $timer = [System.Diagnostics.Stopwatch]::StartNew()

        while ($received -lt $expectedBytes) {
            $needed = [int][Math]::Min($buffer.Length, $expectedBytes - $received)
            $read = $stream.Read($buffer, 0, $needed)
            if ($read -le 0) { throw 'Forbindelsen ble avbrutt.' }
            $received += $read
            $percent = [Math]::Round(($received / $expectedBytes) * 100)
            Write-Progress -Activity 'RAH maler lokal nettverkshastighet' `
                -Status "$percent prosent" -PercentComplete $percent
        }

        $timer.Stop()
        Write-Progress -Activity 'RAH maler lokal nettverkshastighet' -Completed

        $seconds = $timer.Elapsed.TotalSeconds
        $mbps = (($received * 8) / 1MB) / $seconds
        $megabytesSec = ($received / 1MB) / $seconds

        $rating = if ($mbps -ge 500) {
            'Suveren - store filer og rask skjermstromming'
        }
        elseif ($mbps -ge 200) {
            'Meget god - RAH cluster og 4K'
        }
        elseif ($mbps -ge 80) {
            'God - fjernstyring og video'
        }
        elseif ($mbps -ge 30) {
            'Brukbar - kan begrense hoyopplost skjermdeling'
        }
        else {
            'Svak - nettverket bor optimaliseres'
        }

        $writer.Write([double]$seconds)
        $writer.Write([double]$mbps)
        $writer.Write([double]$megabytesSec)
        $writer.Write([string]$adapterDescription)
        $writer.Write($rating)
        $writer.Flush()

        Write-Host ''
        Write-Host '==============================================' -ForegroundColor DarkYellow
        Write-Host '                  RESULTAT' -ForegroundColor Yellow
        Write-Host '==============================================' -ForegroundColor DarkYellow
        Write-Host "$([Math]::Round($mbps, 1)) Mbit/s" -ForegroundColor Green
        Write-Host "$([Math]::Round($megabytesSec, 1)) MB per sekund"
        Write-Host $rating -ForegroundColor Yellow
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
    Write-Host '1 - Start hoved-PC som maleserver'
    Write-Host '2 - Mal denne maskinen mot hoved-PC'
    Write-Host ''
    $choice = Read-Host 'Velg 1 eller 2'
    if ($choice -eq '1') { $Mode = 'Server' }
    elseif ($choice -eq '2') { $Mode = 'Client' }
    else { throw 'Ugyldig valg.' }
}

if ($Mode -eq 'Server') { Start-RahServer }
if ($Mode -eq 'Client') { Start-RahClient }
