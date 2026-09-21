param(
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:Rah2PcClientVersion = '1.2.0'
$script:Rah2PcPort = 18766
$script:Rah2PcRoute = '/raven/status'
$script:Rah2PcProtocol = 'rah-node-raven-status-v1'
$script:Rah2PcCapability = 'system-inventory'
$script:Rah2PcSource = 'local-raven-job-executor'
$script:EmptySha256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
$script:Utf8NoBom = New-Object Text.UTF8Encoding($false)

function ConvertTo-RahBase64Url {
    param([byte[]]$Bytes)
    return ([Convert]::ToBase64String($Bytes)).TrimEnd('=').Replace('+','-').Replace('/','_')
}

function Assert-RahSafeHost {
    param([string]$HostName)
    $hostValue = ([string]$HostName).Trim()
    if ([string]::IsNullOrWhiteSpace($hostValue) -or $hostValue -match '[/\\:@?#]') {
        throw 'Invalid node address.'
    }
    $ip = $null
    if ([Net.IPAddress]::TryParse($hostValue,[ref]$ip)) { return $hostValue }
    if ($hostValue.Length -gt 253 -or $hostValue -notmatch '^[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$') {
        throw 'Invalid node hostname.'
    }
    return $hostValue
}

function New-RahCanonical {
    param([string]$SessionId,[string]$Nonce)
    if ($SessionId -notmatch '^[A-Za-z0-9_-]{20,64}$') { throw 'Invalid Node session id.' }
    if ($Nonce -notmatch '^[A-Za-z0-9_-]{24,64}$') { throw 'Invalid Node auth nonce.' }
    $lf = [char]10
    return (@(
        'RAH-AUTH-V2'
        $SessionId
        $Nonce
        'GET'
        $script:Rah2PcRoute
        $script:EmptySha256
        ''
        ''
        ''
        ''
        ''
    ) -join $lf)
}

function New-RahProof {
    param([string]$Token,[string]$Canonical)
    $tokenValue = ([string]$Token).Trim()
    if ($tokenValue.Length -lt 24 -or $tokenValue.Length -gt 128) {
        throw 'Fresh Node token is missing or invalid.'
    }
    $hmac = New-Object Security.Cryptography.HMACSHA256
    try {
        $hmac.Key = [Text.Encoding]::UTF8.GetBytes($tokenValue)
        $digest = $hmac.ComputeHash([Text.Encoding]::UTF8.GetBytes($Canonical))
        return ConvertTo-RahBase64Url $digest
    } finally {
        $hmac.Dispose()
    }
}

function ConvertTo-RahCleanInventory {
    param($Payload)
    if ($null -eq $Payload -or $Payload.ok -ne $true) { throw 'Raven status did not return ok=true.' }
    if ([string]$Payload.protocol -ne $script:Rah2PcProtocol) { throw 'Unexpected Raven status protocol.' }
    if ([string]$Payload.source -ne $script:Rah2PcSource -or [string]$Payload.capability -ne $script:Rah2PcCapability) {
        throw 'Unexpected Raven status source/capability.'
    }
    if ($Payload.arbitraryCommands -ne $false -or $Payload.argumentsAllowed -ne $false -or $Payload.localOnlyHop -ne $true) {
        throw 'Remote safety flags failed.'
    }

    $result = $Payload.result
    if ($null -eq $result -or $result.ok -ne $true) { throw 'Inventory job failed.' }
    if ($result.read_only -ne $true -or $result.files_modified -ne $false -or $result.arbitrary_commands -ne $false) {
        throw 'Inventory result safety contract failed.'
    }

    $inv = $result.inventory
    if ($null -eq $inv -or $null -eq $inv.os -or $null -eq $inv.cpu -or $null -eq $inv.raven_bridge -or $null -eq $inv.safety) {
        throw 'Inventory payload is incomplete.'
    }
    if ($inv.safety.read_only -ne $true -or $inv.safety.arbitrary_commands -ne $false -or $inv.safety.file_writes -ne $false -or $inv.safety.automatic_execution -ne $false) {
        throw 'Inventory safety block failed.'
    }

    $hardware = $null
    if ($null -ne $inv.PSObject.Properties['hardware_profile'] -and $null -ne $inv.hardware_profile) {
        if ([string]$inv.hardware_profile.schema -ne 'rah-hardware-profile-v1') { throw 'Unexpected detailed hardware profile schema.' }
        $hardware = $inv.hardware_profile
    }

    $clean = [pscustomobject][ordered]@{
        schema = 'rah-2pc-inventory-proof-v1'
        clientVersion = $script:Rah2PcClientVersion
        status = 'PASS'
        protocol = $script:Rah2PcProtocol
        capability = $script:Rah2PcCapability
        nodeJobId = [string]$Payload.nodeJobId
        inventory = [pscustomobject][ordered]@{
            hostname = [string]$inv.hostname
            os = [pscustomobject][ordered]@{
                system = [string]$inv.os.system
                release = [string]$inv.os.release
                architecture = [string]$inv.os.architecture
            }
            cpu = [pscustomobject][ordered]@{
                name = [string]$inv.cpu.name
                logical_cores = $inv.cpu.logical_cores
            }
            ram_gb = $inv.ram_gb
            gpus = @($inv.gpus | ForEach-Object { [string]$_ })
            monitor_count = $inv.monitor_count
            raven_bridge = [pscustomobject][ordered]@{
                version = [string]$inv.raven_bridge.version
                port = $inv.raven_bridge.port
                health_route = ($inv.raven_bridge.health_route -eq $true)
                agent_route = ($inv.raven_bridge.agent_route -eq $true)
            }
            hardware_profile = $hardware
        }
        safety = [pscustomobject][ordered]@{
            readOnly = $true
            arbitraryCommands = $false
            callerArguments = $false
            tokenPersisted = $false
            localRavenHopOnly = $true
        }
        stdout = [string]$result.stdout
    }
    return $clean
}

function Invoke-Rah2PcInventory {
    param(
        [Parameter(Mandatory=$true)][string]$TargetHost,
        [Parameter(Mandatory=$true)][string]$Token,
        [string]$OutputPath = 'C:\RAH\2PCProof\results\last-inventory.json'
    )

    $safeHost = Assert-RahSafeHost $TargetHost
    $base = 'http://{0}:{1}' -f $safeHost,$script:Rah2PcPort
    $challengeResponse = Invoke-WebRequest -UseBasicParsing -Method Get -Uri ($base + '/health') -Headers @{'X-RAH-Auth-Init'='1';'Accept'='application/json'} -TimeoutSec 8
    if ([int]$challengeResponse.StatusCode -ne 200) { throw 'Auth challenge failed.' }
    $challenge = $challengeResponse.Content | ConvertFrom-Json
    $canonical = New-RahCanonical -SessionId ([string]$challenge.sessionId) -Nonce ([string]$challenge.nonce)
    $proof = New-RahProof -Token $Token -Canonical $canonical

    $statusResponse = Invoke-WebRequest -UseBasicParsing -Method Get -Uri ($base + $script:Rah2PcRoute) -Headers @{'X-RAH-Auth-Nonce'=[string]$challenge.nonce;'X-RAH-Auth-Proof'=$proof;'Accept'='application/json'} -TimeoutSec 30
    if ([int]$statusResponse.StatusCode -ne 200) { throw 'Raven status request failed.' }

    $payload = $statusResponse.Content | ConvertFrom-Json
    $clean = ConvertTo-RahCleanInventory $payload
    $clean | Add-Member -NotePropertyName target -NotePropertyValue ([pscustomobject][ordered]@{host=$safeHost;port=$script:Rah2PcPort})

    $dir = Split-Path -Parent $OutputPath
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::WriteAllText($OutputPath,(($clean | ConvertTo-Json -Depth 24) + [Environment]::NewLine),$script:Utf8NoBom)
    return $clean
}

function Test-Rah2PcClient {
    $session = 'Session_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234'
    $nonce = 'Nonce_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456'
    $token = 'Token_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456'
    $canonical = New-RahCanonical -SessionId $session -Nonce $nonce
    if (-not $canonical.StartsWith('RAH-AUTH-V2' + [char]10)) { throw 'Canonical self-test failed.' }
    $proof = New-RahProof -Token $token -Canonical $canonical
    if ($proof -notmatch '^[A-Za-z0-9_-]{40,64}$') { throw 'HMAC self-test failed.' }

    $mock = [pscustomobject]@{
        ok=$true;protocol=$script:Rah2PcProtocol;source=$script:Rah2PcSource;capability=$script:Rah2PcCapability
        arbitraryCommands=$false;argumentsAllowed=$false;localOnlyHop=$true;nodeJobId='selftest-job'
        result=[pscustomobject]@{
            ok=$true;read_only=$true;files_modified=$false;arbitrary_commands=$false;stdout='selftest inventory ok'
            inventory=[pscustomobject]@{
                hostname='SELFTEST-NODE'
                os=[pscustomobject]@{system='Windows';release='11';architecture='AMD64'}
                cpu=[pscustomobject]@{name='Self Test CPU';logical_cores=8}
                ram_gb=16;gpus=@('Self Test GPU');monitor_count=2
                raven_bridge=[pscustomobject]@{version='2.0.32';port=18765;health_route=$true;agent_route=$true}
                safety=[pscustomobject]@{read_only=$true;arbitrary_commands=$false;file_writes=$false;automatic_execution=$false}
                hardware_profile=[pscustomobject]@{schema='rah-hardware-profile-v1';hostname='SELFTEST-NODE'}
            }
        }
    }
    $clean = ConvertTo-RahCleanInventory $mock
    if ($clean.status -ne 'PASS' -or $clean.inventory.hostname -ne 'SELFTEST-NODE') { throw 'Payload sanitizer self-test failed.' }
    if ($clean.safety.tokenPersisted -ne $false) { throw 'Token persistence self-test failed.' }
    Write-Host 'PASS: RAH 2-PC PowerShell HMAC client self-test' -ForegroundColor Green
}

if ($MyInvocation.InvocationName -ne '.') {
    if ($SelfTest) { Test-Rah2PcClient; exit 0 }
    Write-Host 'RAH-2PC-CLIENT.ps1 is a fixed library. Use the Raven GUI or -SelfTest.'
}
