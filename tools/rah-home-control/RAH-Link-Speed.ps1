[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Server', 'Client')]
    [string]$Mode = 'Menu',

    [string]$ServerIP = '',

    [ValidateRange(1, 65535)]
    [int]$Port = 18991,

    [ValidateRange(16, 2048)]
    [int]$TestSizeMB = 128
)

$ErrorActionPreference = 'Stop'
$RahRoot = Join-Path $env:USERPROFILE 'Documents\RAH Room Control'
$ResultFile = Join-Path $RahRoot 'RAH-Link-Speed-Results.csv'
New-Item -ItemType Directory -Path $RahRoot -Force | Out-Null

function Show-RahHeader {
    Clear-Host
    Write-Host '==============================================' -ForegroundColor DarkYellow
    Write-Host '        RAH LINK SPEED - HAKOYA' -ForegroundColor Yellow
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

    if (-not $address) {
        throw 'Fant ingen aktiv privat IPv4-adresse. Kontroller Wi-Fi eller nettverkskabel.'
    }

    return $address.IPAddress
}

function Test-RahAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Start-RahServer {
    Show-RahHeader
    $localIP = Get-RahLocalIP

    Write-Host 'Modus: HOVED-PC / MALESERVER' -ForegroundColor Cyan
    Write-Host "Maskin: $env:COMPUTERNAME"
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
    }
    else {
        Write-Host 'Hvis klienten ikke kommer inn: start PowerShell som administrator.' -ForegroundColor DarkYellow
    }

    Write-Host 'Venter pa Omen, Lenovo eller en annen RAH-node.' -ForegroundColor Green
    Write-Host 'Trykk Ctrl+C nar malingene er ferdige.'
    Write-Host ''

    $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
    $listener.Start()

    try {
        while ($true) {
            $client = $listener.AcceptTcpClient()
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
                    Server = $env:COMPUTERNAME
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
                Write-Host "Malingen feilet: $($_.Exception.Message)" -ForegroundColor Red
            }
            finally {
                if ($reader) { $reader.Dispose() }
                if ($writer) { $writer.Dispose() }
                if ($stream) { $stream.Dispose() }
                $client.Dispose()
            }
        }
    }
    finally {
        $listener.Stop()
    }
}

function Start-RahClient {
    Show-RahHeader

    if ([string]::IsNullOrWhiteSpace($ServerIP)) {
        $script:ServerIP = Read-Host 'Skriv SERVER-IP som vises pa hoved-PC-en'
    }

    Write-Host "Kobler $env:COMPUTERNAME til $ServerIP`:$Port ..." -ForegroundColor Cyan

    $adapter = Get-NetAdapter |
        Where-Object Status -eq 'Up' |
        Sort-Object LinkSpeed -Descending |
        Select-Object -First 1

    $client = [System.Net.Sockets.TcpClient]::new()
    $client.ReceiveBufferSize = 1MB
    $client.SendBufferSize = 1MB

    try {
        $client.Connect($ServerIP, $Port)
        $stream = $client.GetStream()
        $reader = [System.IO.BinaryReader]::new($stream, [Text.Encoding]::UTF8, $true)
        $writer = [System.IO.BinaryWriter]::new($stream, [Text.Encoding]::UTF8, $true)

        $writer.Write($env:COMPUTERNAME)
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
        $writer.Write([string]$adapter.InterfaceDescription)
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

