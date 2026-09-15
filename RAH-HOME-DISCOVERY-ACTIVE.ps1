param(
    [switch]$Start,
    [string]$OutputPath = '',
    [int]$TimeoutMs = 250,
    [int]$DelayMs = 20,
    [int]$MaxHosts = 254,
    [int]$InterfaceIndex = 0,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahActiveDiscoveryVersion = '1.0.0'
$script:RahAllowedNeighborStates = @('Reachable','Stale','Delay','Probe','Permanent')

function Test-RahPrivateIPv4 {
    param([Parameter(Mandatory)][string]$Ip)

    $parsed = $null
    if (-not [System.Net.IPAddress]::TryParse($Ip, [ref]$parsed)) { return $false }
    if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) { return $false }

    $b = $parsed.GetAddressBytes()
    return (
        $b[0] -eq 10 -or
        ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) -or
        ($b[0] -eq 192 -and $b[1] -eq 168)
    )
}

function ConvertTo-RahUInt32 {
    param([Parameter(Mandatory)][string]$Ip)
    $parsed = [System.Net.IPAddress]::Parse($Ip)
    if ($parsed.AddressFamily -ne [System.Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Ikke IPv4: $Ip"
    }
    $bytes = $parsed.GetAddressBytes()
    [Array]::Reverse($bytes)
    return [BitConverter]::ToUInt32($bytes, 0)
}

function ConvertFrom-RahUInt32 {
    param([Parameter(Mandatory)][uint32]$Value)
    $bytes = [BitConverter]::GetBytes($Value)
    [Array]::Reverse($bytes)
    return ([System.Net.IPAddress]::new($bytes)).ToString()
}

function Get-RahSubnetPlan {
    param(
        [Parameter(Mandatory)][string]$IpAddress,
        [Parameter(Mandatory)][int]$PrefixLength
    )

    if (-not (Test-RahPrivateIPv4 $IpAddress)) {
        throw "IP-adressen er ikke privat RFC1918 IPv4: $IpAddress"
    }
    if ($PrefixLength -lt 24 -or $PrefixLength -gt 30) {
        throw "Aktiv discovery støtter bare lokale subnett /24 til /30. Oppdaget /$PrefixLength."
    }

    $ipValue = ConvertTo-RahUInt32 $IpAddress
    $hostBits = 32 - $PrefixLength
    $mask64 = ([uint64]4294967295 -shl $hostBits) -band [uint64]4294967295
    $mask = [uint32]$mask64
    $network = [uint32]($ipValue -band $mask)
    $broadcast = [uint32]($network + ([uint32]([math]::Pow(2, $hostBits) - 1)))
    $first = [uint32]($network + 1)
    $last = [uint32]($broadcast - 1)
    $availableHosts = [int]($last - $first + 1)

    return [pscustomobject]@{
        ipAddress = $IpAddress
        prefixLength = $PrefixLength
        networkValue = $network
        broadcastValue = $broadcast
        firstValue = $first
        lastValue = $last
        network = ConvertFrom-RahUInt32 $network
        broadcast = ConvertFrom-RahUInt32 $broadcast
        firstHost = ConvertFrom-RahUInt32 $first
        lastHost = ConvertFrom-RahUInt32 $last
        availableHosts = $availableHosts
    }
}

function Get-RahScanTargets {
    param(
        [Parameter(Mandatory)]$Plan,
        [Parameter(Mandatory)][string]$LocalIp,
        [Parameter(Mandatory)][int]$Limit
    )

    if ($Limit -lt 1 -or $Limit -gt 254) { throw 'Limit må være 1-254.' }

    $targets = New-Object System.Collections.Generic.List[string]
    for ([uint32]$value = $Plan.firstValue; $value -le $Plan.lastValue; $value++) {
        $target = ConvertFrom-RahUInt32 $value
        if ($target -eq $LocalIp) { continue }
        $targets.Add($target)
        if ($targets.Count -ge $Limit) { break }
    }
    return @($targets)
}

function Get-RahActivePrivateConfig {
    param([int]$RequestedInterfaceIndex = 0)

    $candidates = @(Get-NetIPConfiguration -ErrorAction Stop |
        Where-Object { $_.IPv4Address -and $_.NetAdapter -and $_.NetAdapter.Status -eq 'Up' } |
        ForEach-Object {
            foreach ($addr in $_.IPv4Address) {
                [pscustomobject]@{
                    ipAddress = [string]$addr.IPAddress
                    prefixLength = [int]$addr.PrefixLength
                    ifIndex = [int]$_.InterfaceIndex
                    adapterName = [string]$_.InterfaceAlias
                    interfaceDescription = [string]$_.NetAdapter.InterfaceDescription
                    macAddress = [string]$_.NetAdapter.MacAddress
                    linkSpeed = [string]$_.NetAdapter.LinkSpeed
                }
            }
        } |
        Where-Object {
            (Test-RahPrivateIPv4 $_.ipAddress) -and
            $_.prefixLength -ge 24 -and
            $_.prefixLength -le 30
        })

    if ($RequestedInterfaceIndex -gt 0) {
        $candidates = @($candidates | Where-Object { $_.ifIndex -eq $RequestedInterfaceIndex })
        if (-not $candidates) {
            throw "Fant ingen aktiv privat /24-/30 IPv4-adapter med InterfaceIndex $RequestedInterfaceIndex."
        }
    }

    if (-not $candidates) {
        throw 'Fant ingen aktiv privat IPv4-adapter (RFC1918) med subnett /24 til /30.'
    }

    if ($candidates.Count -gt 1 -and $RequestedInterfaceIndex -le 0) {
        $defaultIfIndex = $null
        try {
            $route = Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction Stop |
                Sort-Object RouteMetric |
                Select-Object -First 1
            if ($route) { $defaultIfIndex = [int]$route.InterfaceIndex }
        }
        catch { }

        if ($null -ne $defaultIfIndex) {
            $defaultCandidates = @($candidates | Where-Object { $_.ifIndex -eq $defaultIfIndex })
            if ($defaultCandidates.Count -eq 1) {
                return $defaultCandidates[0]
            }
        }

        $choices = ($candidates | ForEach-Object { "$($_.ifIndex):$($_.adapterName) $($_.ipAddress)/$($_.prefixLength)" }) -join ', '
        throw "Flere private adaptere er aktive. Kjør på nytt med -InterfaceIndex. Kandidater: $choices"
    }

    return $candidates[0]
}

function Normalize-RahNeighborState {
    param([string]$State)
    if ($script:RahAllowedNeighborStates -contains $State) { return $State }
    return 'Reachable'
}

function New-RahActiveDiscoveryDocument {
    param(
        [Parameter(Mandatory)]$Config,
        [Parameter(Mandatory)]$Plan,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Devices,
        [Parameter(Mandatory)][int]$ScannedHosts,
        [Parameter(Mandatory)][int]$Timeout,
        [Parameter(Mandatory)][int]$Delay,
        [Parameter(Mandatory)][int]$HostLimit
    )

    return [ordered]@{
        schema = 'rah-home-discovery-cache'
        version = 1
        scriptVersion = $script:RahActiveDiscoveryVersion
        product = 'RAH Home Control'
        mode = 'active-local-subnet'
        passive = $false
        scope = 'rfc1918-selected-local-subnet'
        generatedAt = (Get-Date).ToUniversalTime().ToString('o')
        authorization = 'explicit-start-local-private-subnet'
        scan = [ordered]@{
            localIp = $Config.ipAddress
            prefixLength = $Config.prefixLength
            network = $Plan.network
            maxHosts = $HostLimit
            scannedHosts = $ScannedHosts
            timeoutMs = $Timeout
            delayMs = $Delay
            protocol = 'ICMP echo only'
        }
        adapters = @([pscustomobject]@{
            ifIndex = [int]$Config.ifIndex
            name = [string]$Config.adapterName
            interfaceDescription = [string]$Config.interfaceDescription
            status = 'Up'
            macAddress = [string]$Config.macAddress
            linkSpeed = [string]$Config.linkSpeed
        })
        devices = @($Devices)
        note = 'Active local discovery v1: explicitly started, restricted to one selected RFC1918 /24-/30 subnet, ICMP echo only, no port scanning, service probing, DNS enumeration or remote shell.'
    }
}

function Write-RahActiveDiscoveryDocument {
    param(
        [Parameter(Mandatory)]$Document,
        [string]$Path = ''
    )

    $json = $Document | ConvertTo-Json -Depth 8
    if (-not $Path) { return $json }

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $directory = Split-Path -Parent $fullPath
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
    Write-Host "RAH aktiv discovery skrev resultat til: $fullPath" -ForegroundColor Green
    Write-Host "Svarende enheter: $(@($Document.devices).Count)"
}

function Invoke-RahActiveDiscoverySelfTest {
    $cases = @(
        @{ Ip='10.0.0.1'; Expected=$true },
        @{ Ip='172.16.1.1'; Expected=$true },
        @{ Ip='172.31.255.254'; Expected=$true },
        @{ Ip='192.168.1.1'; Expected=$true },
        @{ Ip='172.32.0.1'; Expected=$false },
        @{ Ip='8.8.8.8'; Expected=$false },
        @{ Ip='not-an-ip'; Expected=$false }
    )
    foreach ($case in $cases) {
        if ((Test-RahPrivateIPv4 $case.Ip) -ne $case.Expected) {
            throw "SelfTest feilet for $($case.Ip)."
        }
    }

    $plan24 = Get-RahSubnetPlan -IpAddress '192.168.1.10' -PrefixLength 24
    if ($plan24.network -ne '192.168.1.0' -or $plan24.broadcast -ne '192.168.1.255' -or $plan24.availableHosts -ne 254) {
        throw 'SelfTest feilet for /24 subnettberegning.'
    }

    $plan30 = Get-RahSubnetPlan -IpAddress '10.0.0.1' -PrefixLength 30
    $targets = @(Get-RahScanTargets -Plan $plan30 -LocalIp '10.0.0.1' -Limit 254)
    if ($targets.Count -ne 1 -or $targets[0] -ne '10.0.0.2') {
        throw 'SelfTest feilet for /30 targetliste.'
    }

    if ((Normalize-RahNeighborState 'Unknown') -ne 'Reachable') {
        throw 'SelfTest feilet for state-normalisering.'
    }

    $cfg = [pscustomobject]@{
        ipAddress='192.168.1.10'; prefixLength=24; ifIndex=7; adapterName='Ethernet';
        interfaceDescription='Mock Ethernet'; macAddress='AA-BB-CC-DD-EE-01'; linkSpeed='1 Gbps'
    }
    $doc = New-RahActiveDiscoveryDocument -Config $cfg -Plan $plan24 -Devices @() -ScannedHosts 0 -Timeout 250 -Delay 20 -HostLimit 254
    if ($doc.schema -ne 'rah-home-discovery-cache' -or $doc.mode -ne 'active-local-subnet' -or $doc.passive -ne $false -or $doc.scan.protocol -ne 'ICMP echo only') {
        throw 'SelfTest feilet for output-kontrakten.'
    }

    Write-Host "RAH Home Discovery Active $script:RahActiveDiscoveryVersion SelfTest OK" -ForegroundColor Green
}

function Invoke-RahActiveDiscovery {
    param(
        [string]$Path = '',
        [int]$Timeout = 250,
        [int]$Delay = 20,
        [int]$HostLimit = 254,
        [int]$RequestedInterfaceIndex = 0
    )

    if ($Timeout -lt 50 -or $Timeout -gt 2000) { throw 'TimeoutMs må være 50-2000.' }
    if ($Delay -lt 0 -or $Delay -gt 1000) { throw 'DelayMs må være 0-1000.' }
    if ($HostLimit -lt 1 -or $HostLimit -gt 254) { throw 'MaxHosts må være 1-254.' }
    if ($RequestedInterfaceIndex -lt 0) { throw 'InterfaceIndex kan ikke være negativ.' }

    $cfg = Get-RahActivePrivateConfig -RequestedInterfaceIndex $RequestedInterfaceIndex
    $plan = Get-RahSubnetPlan -IpAddress $cfg.ipAddress -PrefixLength $cfg.prefixLength
    $targets = @(Get-RahScanTargets -Plan $plan -LocalIp $cfg.ipAddress -Limit $HostLimit)

    Write-Host "RAH aktiv discovery v$script:RahActiveDiscoveryVersion: $($cfg.ipAddress)/$($cfg.prefixLength) på $($cfg.adapterName)" -ForegroundColor Yellow
    Write-Host "Maks $($targets.Count) mål - ICMP echo only - ingen portskanning eller tjenesteprobing."

    $responders = New-Object System.Collections.Generic.List[object]
    $scanned = 0
    $ping = [System.Net.NetworkInformation.Ping]::new()
    try {
        foreach ($target in $targets) {
            $scanned++
            try {
                $reply = $ping.Send($target, $Timeout)
                if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                    $responders.Add([pscustomobject]@{ ipAddress=$target; latencyMs=[int]$reply.RoundtripTime })
                }
            }
            catch { }
            if ($Delay -gt 0) { Start-Sleep -Milliseconds $Delay }
        }
    }
    finally {
        $ping.Dispose()
    }

    Start-Sleep -Milliseconds 150
    $neighbors = @(Get-NetNeighbor -AddressFamily IPv4 -InterfaceIndex $cfg.ifIndex -ErrorAction SilentlyContinue)

    $devices = @($responders | ForEach-Object {
        $r = $_
        $neighbor = $neighbors | Where-Object { $_.IPAddress -eq $r.ipAddress } | Select-Object -First 1
        [pscustomobject]@{
            ipAddress = [string]$r.ipAddress
            macAddress = if ($neighbor) { [string]$neighbor.LinkLayerAddress } else { '' }
            ifIndex = [int]$cfg.ifIndex
            state = if ($neighbor) { Normalize-RahNeighborState ([string]$neighbor.State) } else { 'Reachable' }
            source = 'rah-active-icmp-local-subnet'
            passive = $false
            latencyMs = [int]$r.latencyMs
        }
    })

    $document = New-RahActiveDiscoveryDocument -Config $cfg -Plan $plan -Devices $devices -ScannedHosts $scanned -Timeout $Timeout -Delay $Delay -HostLimit $HostLimit
    Write-RahActiveDiscoveryDocument -Document $document -Path $Path
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ($SelfTest) {
            Invoke-RahActiveDiscoverySelfTest
            return
        }

        if (-not $Start) {
            throw 'Aktiv discovery krever eksplisitt -Start. Kjør bare på eget eller autorisert lokalnett.'
        }

        Invoke-RahActiveDiscovery -Path $OutputPath -Timeout $TimeoutMs -Delay $DelayMs -HostLimit $MaxHosts -RequestedInterfaceIndex $InterfaceIndex
    }
    catch {
        Write-Error "RAH aktiv discovery feilet: $($_.Exception.Message)"
        exit 1
    }
}
