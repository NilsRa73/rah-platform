param(
    [switch]$SelfTest,
    [string]$InputPath = 'C:\RAH\2PCProof\results\last-inventory.json',
    [string]$OutputPath = 'C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json',
    [string]$ExpectedHost = 'DESKTOP-R2HTAGJ'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Utf8NoBom = New-Object Text.UTF8Encoding($false)

function Test-RahPrivateIPv4 {
    param([string]$Address)
    $ip = $null
    if (-not [Net.IPAddress]::TryParse($Address,[ref]$ip)) { return $false }
    if ($ip.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) { return $false }
    $b = $ip.GetAddressBytes()
    return ($b[0] -eq 127 -or $b[0] -eq 10 -or ($b[0] -eq 192 -and $b[1] -eq 168) -or ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31))
}

function Test-RahPrivateTarget {
    param([string]$HostName,[string]$FixedExpectedHost)
    $value = ([string]$HostName).Trim()
    if (Test-RahPrivateIPv4 $value) { return $true }
    if ($value.ToUpperInvariant() -eq $FixedExpectedHost.ToUpperInvariant()) {
        try {
            $addresses = @([Net.Dns]::GetHostAddresses($value) | Where-Object { $_.AddressFamily -eq [Net.Sockets.AddressFamily]::InterNetwork })
            if ($addresses.Count -eq 0) { return $true }
            foreach ($addr in $addresses) { if (-not (Test-RahPrivateIPv4 $addr.ToString())) { return $false } }
            return $true
        } catch { return $true }
    }
    return $false
}

function Test-RahAcceptancePayload {
    param($Payload,[string]$FixedExpectedHost='DESKTOP-R2HTAGJ')
    if ($null -eq $Payload -or [string]$Payload.schema -ne 'rah-2pc-inventory-proof-v1') { throw 'Unexpected inventory result schema.' }
    if ([string]$Payload.status -ne 'PASS') { throw 'Inventory result is not PASS.' }
    if ([string]$Payload.protocol -ne 'rah-node-raven-status-v1') { throw 'Unexpected Node protocol.' }
    if ([string]$Payload.capability -ne 'system-inventory') { throw 'Unexpected Raven capability.' }

    $inv = $Payload.inventory
    $safety = $Payload.safety
    $target = $Payload.target
    if ($null -eq $inv -or $null -eq $safety -or $null -eq $target -or $null -eq $inv.raven_bridge) { throw 'Acceptance payload is incomplete.' }

    $hostname = ([string]$inv.hostname).Trim()
    if ($hostname.ToUpperInvariant() -ne $FixedExpectedHost.ToUpperInvariant()) { throw "Expected Lenovo host $FixedExpectedHost, got $hostname." }
    if ([int]$target.port -ne 18766) { throw 'Node target port is not fixed to 18766.' }
    if (-not (Test-RahPrivateTarget ([string]$target.host) $FixedExpectedHost)) { throw 'Target is not a private LAN endpoint.' }

    if ($safety.readOnly -ne $true) { throw 'Safety flag failed: readOnly' }
    if ($safety.arbitraryCommands -ne $false) { throw 'Safety flag failed: arbitraryCommands' }
    if ($safety.callerArguments -ne $false) { throw 'Safety flag failed: callerArguments' }
    if ($safety.tokenPersisted -ne $false) { throw 'Safety flag failed: tokenPersisted' }
    if ($safety.localRavenHopOnly -ne $true) { throw 'Safety flag failed: localRavenHopOnly' }
    if ([int]$inv.raven_bridge.port -ne 18765) { throw 'Raven bridge port is not 18765.' }
    if ($inv.raven_bridge.health_route -ne $true -or $inv.raven_bridge.agent_route -ne $true) { throw 'Raven bridge routes did not validate.' }

    return [pscustomobject][ordered]@{
        hostname = $hostname
        targetHost = [string]$target.host
        targetPort = 18766
        ravenPort = 18765
        readOnly = $true
        arbitraryCommands = $false
        callerArguments = $false
        tokenPersisted = $false
        localRavenHopOnly = $true
        hardwareProfilePresent = ($null -ne $inv.PSObject.Properties['hardware_profile'] -and $null -ne $inv.hardware_profile -and [string]$inv.hardware_profile.schema -eq 'rah-hardware-profile-v1')
    }
}

function Invoke-Rah2PcFinalAcceptance {
    param(
        [string]$SourcePath = 'C:\RAH\2PCProof\results\last-inventory.json',
        [string]$DestinationPath = 'C:\RAH\2PCProof\results\REAL-HARDWARE-ACCEPTANCE.json',
        [string]$FixedExpectedHost = 'DESKTOP-R2HTAGJ'
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) { throw "Inventory result missing: $SourcePath" }
    $payload = Get-Content -LiteralPath $SourcePath -Raw | ConvertFrom-Json -ErrorAction Stop
    $evidence = Test-RahAcceptancePayload -Payload $payload -FixedExpectedHost $FixedExpectedHost
    $hash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash.ToLowerInvariant()

    $report = [pscustomobject][ordered]@{
        schema = 'rah-2pc-real-hardware-acceptance-v1'
        overall = 'PASS'
        milestone = 'RAH Raven 2-PC Grid real-hardware acceptance'
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
        source = [pscustomobject][ordered]@{path=$SourcePath;sha256=$hash;schema='rah-2pc-inventory-proof-v1'}
        evidence = $evidence
        gates = [pscustomobject][ordered]@{
            inventoryPass=$true;expectedLenovoHost=$true;privateLanOnly=$true;nodePort18766=$true;ravenLocalHop18765=$true
            readOnly=$true;noArbitraryCommands=$true;noCallerArguments=$true;tokenNotPersisted=$true
        }
    }

    $dir = Split-Path -Parent $DestinationPath
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::WriteAllText($DestinationPath,(($report | ConvertTo-Json -Depth 16) + [Environment]::NewLine),$script:Utf8NoBom)
    return $report
}

function Test-Rah2PcAcceptance {
    $good = [pscustomobject]@{
        schema='rah-2pc-inventory-proof-v1';status='PASS';protocol='rah-node-raven-status-v1';capability='system-inventory'
        target=[pscustomobject]@{host='192.168.0.49';port=18766}
        inventory=[pscustomobject]@{
            hostname='DESKTOP-R2HTAGJ'
            raven_bridge=[pscustomobject]@{port=18765;health_route=$true;agent_route=$true}
            hardware_profile=[pscustomobject]@{schema='rah-hardware-profile-v1'}
        }
        safety=[pscustomobject]@{readOnly=$true;arbitraryCommands=$false;callerArguments=$false;tokenPersisted=$false;localRavenHopOnly=$true}
    }
    $result = Test-RahAcceptancePayload $good
    if ($result.hostname -ne 'DESKTOP-R2HTAGJ' -or $result.hardwareProfilePresent -ne $true) { throw 'Acceptance good-case failed.' }
    $good.safety.arbitraryCommands = $true
    $failed = $false
    try { $null = Test-RahAcceptancePayload $good } catch { $failed = $true }
    if (-not $failed) { throw 'Unsafe acceptance payload must fail.' }
    Write-Host 'PASS: RAH 2-PC PowerShell final acceptance self-test' -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($SelfTest) { Test-Rah2PcAcceptance; exit 0 }
    $report = Invoke-Rah2PcFinalAcceptance -SourcePath $InputPath -DestinationPath $OutputPath -FixedExpectedHost $ExpectedHost
    $report | ConvertTo-Json -Depth 16
}
