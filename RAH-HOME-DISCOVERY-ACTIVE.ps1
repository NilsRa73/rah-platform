param(
    [switch]$Start,
    [string]$OutputPath = "",
    [int]$TimeoutMs = 250,
    [int]$DelayMs = 20,
    [int]$MaxHosts = 254
)

$ErrorActionPreference = 'Stop'

function Test-RahPrivateIPv4 {
    param([string]$Ip)
    $p = $Ip.Split('.')
    if ($p.Count -ne 4) { return $false }
    $a = [int]$p[0]; $b = [int]$p[1]
    return ($a -eq 10) -or ($a -eq 172 -and $b -ge 16 -and $b -le 31) -or ($a -eq 192 -and $b -eq 168)
}

function ConvertTo-RahUInt32 {
    param([string]$Ip)
    $bytes = [System.Net.IPAddress]::Parse($Ip).GetAddressBytes()
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function ConvertFrom-RahUInt32 {
    param([uint32]$Value)
    $bytes = [BitConverter]::GetBytes($Value)
    [Array]::Reverse($bytes)
    return ([System.Net.IPAddress]::new($bytes)).ToString()
}

function Get-RahActivePrivateConfig {
    $candidates = Get-NetIPConfiguration -ErrorAction Stop |
        Where-Object { $_.IPv4Address -and $_.NetAdapter -and $_.NetAdapter.Status -eq 'Up' } |
        ForEach-Object {
            foreach ($addr in $_.IPv4Address) {
                [pscustomobject]@{
                    ipAddress = [string]$addr.IPAddress
                    prefixLength = [int]$addr.PrefixLength
                    ifIndex = [int]$_.InterfaceIndex
                    adapterName = [string]$_.InterfaceAlias
                    interfaceDescription = [string]$_.NetAdapter.InterfaceDescription
                }
            }
        } |
        Where-Object { Test-RahPrivateIPv4 $_.ipAddress }

    $selected = $candidates | Sort-Object prefixLength -Descending | Select-Object -First 1
    if (-not $selected) { throw 'Fant ingen aktiv privat IPv4-adapter (RFC1918).' }
    if ($selected.prefixLength -lt 24 -or $selected.prefixLength -gt 30) {
        throw "Aktiv prototype støtter bare lokale subnett /24 til /30. Oppdaget /$($selected.prefixLength)."
    }
    return $selected
}

if (-not $Start) {
    Write-Error 'Aktiv discovery krever eksplisitt -Start. Kjør bare på eget eller autorisert lokalnett.'
    exit 2
}

if ($TimeoutMs -lt 50 -or $TimeoutMs -gt 2000) { throw 'TimeoutMs må være 50–2000.' }
if ($DelayMs -lt 0 -or $DelayMs -gt 1000) { throw 'DelayMs må være 0–1000.' }
if ($MaxHosts -lt 1 -or $MaxHosts -gt 254) { throw 'MaxHosts må være 1–254.' }

try {
    $cfg = Get-RahActivePrivateConfig
    $ipValue = ConvertTo-RahUInt32 $cfg.ipAddress
    $hostBits = 32 - $cfg.prefixLength
    $mask = [uint32]([uint64]0xFFFFFFFF -shl $hostBits)
    $network = [uint32]($ipValue -band $mask)
    $broadcast = [uint32]($network + ([math]::Pow(2, $hostBits) - 1))

    $first = [uint32]($network + 1)
    $last = [uint32]($broadcast - 1)
    $availableHosts = [int]($last - $first + 1)
    $scanCount = [Math]::Min($availableHosts, $MaxHosts)

    $ping = [System.Net.NetworkInformation.Ping]::new()
    $responders = New-Object System.Collections.Generic.List[object]
    $scanned = 0

    Write-Host "RAH aktiv discovery: $($cfg.ipAddress)/$($cfg.prefixLength) · maks $scanCount hosts" -ForegroundColor Yellow
    Write-Host 'Kun ICMP echo brukes; ingen portskanning eller tjenesteprobing.'

    for ($n = 0; $n -lt $scanCount; $n++) {
        $value = [uint32]($first + $n)
        $target = ConvertFrom-RahUInt32 $value
        if ($target -eq $cfg.ipAddress) { continue }
        $scanned++
        try {
            $reply = $ping.Send($target, $TimeoutMs)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $responders.Add([pscustomobject]@{ ipAddress = $target; latencyMs = [int]$reply.RoundtripTime })
            }
        }
        catch { }
        if ($DelayMs -gt 0) { Start-Sleep -Milliseconds $DelayMs }
    }

    Start-Sleep -Milliseconds 150
    $neighbors = @(Get-NetNeighbor -AddressFamily IPv4 -InterfaceIndex $cfg.ifIndex -ErrorAction SilentlyContinue)

    $devices = @($responders | ForEach-Object {
        $r = $_
        $neighbor = $neighbors | Where-Object { $_.IPAddress -eq $r.ipAddress } | Select-Object -First 1
        [pscustomobject]@{
            ipAddress = $r.ipAddress
            macAddress = if ($neighbor) { [string]$neighbor.LinkLayerAddress } else { '' }
            ifIndex = $cfg.ifIndex
            state = if ($neighbor) { [string]$neighbor.State } else { 'Reachable' }
            source = 'rah-active-icmp-local-subnet'
            passive = $false
            latencyMs = $r.latencyMs
        }
    })

    $document = [ordered]@{
        schema = 'rah-home-discovery-cache'
        version = 1
        product = 'RAH Home Control'
        mode = 'active-local-subnet'
        passive = $false
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        authorization = 'explicit-start-local-private-subnet'
        scan = [ordered]@{
            localIp = $cfg.ipAddress
            prefixLength = $cfg.prefixLength
            network = (ConvertFrom-RahUInt32 $network)
            maxHosts = $MaxHosts
            scannedHosts = $scanned
            timeoutMs = $TimeoutMs
            delayMs = $DelayMs
            protocol = 'ICMP echo only'
        }
        adapters = @([pscustomobject]@{
            ifIndex = $cfg.ifIndex
            name = $cfg.adapterName
            interfaceDescription = $cfg.interfaceDescription
            status = 'Up'
            macAddress = ''
            linkSpeed = ''
        })
        devices = $devices
        note = 'Active prototype: explicitly started, restricted to the selected RFC1918 local subnet (/24 to /30), max 254 hosts, ICMP echo only, no port scanning or service probing.'
    }

    $json = $document | ConvertTo-Json -Depth 7
    if ($OutputPath) {
        $fullPath = [System.IO.Path]::GetFullPath($OutputPath)
        $directory = Split-Path -Parent $fullPath
        if ($directory -and -not (Test-Path -LiteralPath $directory)) {
            New-Item -ItemType Directory -Path $directory -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
        Write-Host "RAH aktiv discovery skrev resultat til: $fullPath" -ForegroundColor Green
        Write-Host "Svarende enheter: $($devices.Count)"
    } else {
        $json
    }
}
catch {
    Write-Error "RAH aktiv discovery feilet: $($_.Exception.Message)"
    exit 1
}
