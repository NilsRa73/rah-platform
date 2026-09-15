param(
    [Parameter(Mandatory=$true)][string]$NodeAddress,
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [ValidateSet('hello','pair','health','systemInfo','benchmark')][string]$Action = 'hello',
    [string]$PairCode = '',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahNodeClientVersion = '1.0.0'
$script:RahProtocolVersion = 2
$script:RahMaxResponseBytes = 1048576
$script:RahMaxPeers = 128

function Test-PrivateIPv4 {
    param([Parameter(Mandatory)][string]$Address)
    if ($Address -eq '127.0.0.1' -or $Address -eq 'localhost') { return $true }
    $parts = $Address.Split('.')
    if ($parts.Count -ne 4) { return $false }
    $numbers = @()
    foreach ($part in $parts) {
        if ($part -notmatch '^\d{1,3}$') { return $false }
        $number = [int]$part
        if ($number -lt 0 -or $number -gt 255 -or [string]$number -ne $part) { return $false }
        $numbers += $number
    }
    return (
        $numbers[0] -eq 10 -or
        ($numbers[0] -eq 192 -and $numbers[1] -eq 168) -or
        ($numbers[0] -eq 172 -and $numbers[1] -ge 16 -and $numbers[1] -le 31)
    )
}

function Normalize-RahNodeAddress {
    param([Parameter(Mandatory)][string]$Address)
    $value = $Address.Trim()
    if ($value -ieq 'localhost') { return '127.0.0.1' }
    if (-not (Test-PrivateIPv4 $value)) { throw 'NodeAddress ma vaere localhost eller en privat RFC1918 IPv4-adresse.' }
    return $value
}

function Test-RahSafeText {
    param([string]$Value,[int]$MaxLength=160)
    return (-not [string]::IsNullOrWhiteSpace($Value) -and $Value.Length -le $MaxLength -and $Value -notmatch '[<>\x00-\x1f\x7f]')
}

function Test-RahIsoTimestamp {
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value) -or $Value.Length -gt 64) { return $false }
    $parsed = [DateTimeOffset]::MinValue
    return [DateTimeOffset]::TryParse($Value,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind,[ref]$parsed)
}

function Test-RahTokenFormat {
    param([string]$Token)
    return (-not [string]::IsNullOrWhiteSpace($Token) -and $Token -cmatch '^[0-9a-f]{64}$')
}

function Normalize-RahPeerKey {
    param([string]$Key)
    if ([string]::IsNullOrWhiteSpace($Key)) { return $null }
    if ($Key -notmatch '^(localhost|(?:\d{1,3}\.){3}\d{1,3}):(\d{4,5})$') { return $null }
    try { $address = Normalize-RahNodeAddress -Address $Matches[1] } catch { return $null }
    $portValue = 0
    if (-not [int]::TryParse($Matches[2],[ref]$portValue) -or $portValue -lt 1024 -or $portValue -gt 65535) { return $null }
    return "${address}:$portValue"
}

function Read-RahBoundedLine {
    param([Parameter(Mandatory)]$Stream,[int]$MaxBytes=$script:RahMaxResponseBytes)
    $buffer = New-Object 'System.Collections.Generic.List[byte]'
    while ($true) {
        $value = $Stream.ReadByte()
        if ($value -eq -1) {
            if ($buffer.Count -eq 0) { return $null }
            break
        }
        if ($value -eq 10) { break }
        if ($buffer.Count -ge $MaxBytes) { throw 'node-response-too-large' }
        $buffer.Add([byte]$value)
    }
    $bytes = $buffer.ToArray()
    if ($bytes.Length -gt 0 -and $bytes[$bytes.Length-1] -eq 13) {
        $trimmed = New-Object byte[] ($bytes.Length-1)
        if ($trimmed.Length -gt 0) { [Array]::Copy($bytes,$trimmed,$trimmed.Length) }
        $bytes = $trimmed
    }
    $utf8 = New-Object Text.UTF8Encoding($false,$true)
    try { return $utf8.GetString($bytes) } catch { throw 'invalid-node-utf8' }
}

function Test-RahObjectProperties {
    param([Parameter(Mandatory)]$Object,[Parameter(Mandatory)][string[]]$Required)
    if ($null -eq $Object -or $Object -is [Array]) { return $false }
    $names = @($Object.PSObject.Properties.Name)
    foreach ($name in $Required) { if ($names -notcontains $name) { return $false } }
    return $true
}

$rahDir = Join-Path $env:LOCALAPPDATA 'RAH'
$peersPath = Join-Path $rahDir 'home-node-peers.json'

function Read-Peers {
    $map = @{}
    if (-not (Test-Path -LiteralPath $peersPath -PathType Leaf)) { return $map }
    try {
        $item = Get-Item -LiteralPath $peersPath -ErrorAction Stop
        if ($item.Length -lt 2 -or $item.Length -gt 1048576) { return $map }
        $obj = Get-Content -LiteralPath $peersPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if (-not $obj -or [int]$obj.version -ne 1 -or $null -eq $obj.PSObject.Properties['peers']) { return $map }
        $count = 0
        foreach ($peer in @($obj.peers)) {
            if ($count -ge $script:RahMaxPeers) { break }
            if (-not (Test-RahObjectProperties -Object $peer -Required @('key','token','computerName','pairedAt'))) { continue }
            $key = Normalize-RahPeerKey -Key ([string]$peer.key)
            $token = [string]$peer.token
            $name = [string]$peer.computerName
            $pairedAt = [string]$peer.pairedAt
            if (-not $key -or -not (Test-RahTokenFormat $token) -or -not (Test-RahSafeText $name 160) -or -not (Test-RahIsoTimestamp $pairedAt)) { continue }
            if (-not $map.ContainsKey($key)) {
                $map[$key] = @{token=$token;computerName=$name;pairedAt=$pairedAt}
                $count++
            }
        }
    }
    catch { return @{} }
    return $map
}

function Save-Peers {
    param([Parameter(Mandatory)][hashtable]$Peers)
    New-Item -ItemType Directory -Path $rahDir -Force | Out-Null
    $items = @()
    foreach ($key in @($Peers.Keys | Sort-Object)) {
        if ($items.Count -ge $script:RahMaxPeers) { break }
        $normalized = Normalize-RahPeerKey -Key ([string]$key)
        if (-not $normalized) { continue }
        $peer = $Peers[$key]
        if (-not (Test-RahTokenFormat ([string]$peer.token)) -or -not (Test-RahSafeText ([string]$peer.computerName) 160) -or -not (Test-RahIsoTimestamp ([string]$peer.pairedAt))) { continue }
        $items += [pscustomobject]@{key=$normalized;token=[string]$peer.token;computerName=[string]$peer.computerName;pairedAt=[string]$peer.pairedAt}
    }
    $json = [pscustomobject]@{version=1;clientVersion=$script:RahNodeClientVersion;peers=@($items)} | ConvertTo-Json -Depth 6
    $temp = "$peersPath.tmp"
    [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($false))
    try { Move-Item -LiteralPath $temp -Destination $peersPath -Force }
    finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}

function Invoke-Node {
    param([Parameter(Mandatory)]$Request)
    $tcp = New-Object Net.Sockets.TcpClient
    try {
        $tcp.ReceiveTimeout = 5000
        $tcp.SendTimeout = 5000
        $tcp.Connect($script:RahNormalizedNodeAddress,$Port)
        $stream = $tcp.GetStream()
        $json = ($Request | ConvertTo-Json -Compress -Depth 5) + "`n"
        $bytes = [Text.Encoding]::UTF8.GetBytes($json)
        if ($bytes.Length -gt 8192) { throw 'client-request-too-large' }
        $stream.Write($bytes,0,$bytes.Length)
        $stream.Flush()
        $line = Read-RahBoundedLine -Stream $stream
        if ([string]::IsNullOrWhiteSpace($line)) { throw 'Noden svarte ikke.' }
        try { return $line | ConvertFrom-Json -ErrorAction Stop }
        catch { throw 'Noden returnerte ugyldig JSON.' }
    }
    finally { $tcp.Dispose() }
}

function Assert-RahHelloResponse {
    param([Parameter(Mandatory)]$Response)
    if (-not (Test-RahObjectProperties -Object $Response -Required @('ok','product','version','computerName','pairingRequired'))) { throw 'Ugyldig hello-svar fra node.' }
    if ($Response.ok -ne $true -or [string]$Response.product -ne 'RAH Home Node Agent' -or [int]$Response.version -ne $script:RahProtocolVersion -or $Response.pairingRequired -ne $true -or -not (Test-RahSafeText ([string]$Response.computerName) 160)) {
        throw 'Node-identitet/protokoll stemmer ikke med RAH Home Node Agent.'
    }
    return $Response
}

function Assert-RahPairResponse {
    param([Parameter(Mandatory)]$Response)
    if (-not (Test-RahObjectProperties -Object $Response -Required @('ok'))) { throw 'Ugyldig pairing-svar.' }
    if ($Response.ok -ne $true) { return $Response }
    if (-not (Test-RahObjectProperties -Object $Response -Required @('paired','token','computerName')) -or $Response.paired -ne $true -or -not (Test-RahTokenFormat ([string]$Response.token)) -or -not (Test-RahSafeText ([string]$Response.computerName) 160)) {
        throw 'Pairing-svaret mangler gyldig token/nodeidentitet.'
    }
    return $Response
}

function Assert-RahActionResponse {
    param([Parameter(Mandatory)]$Response,[Parameter(Mandatory)][string]$RequestedAction)
    if (-not (Test-RahObjectProperties -Object $Response -Required @('ok')) -or -not ($Response.ok -is [bool])) { throw 'Ugyldig node-svar: mangler boolsk ok.' }
    if ($Response.ok -ne $true) { return $Response }
    switch ($RequestedAction) {
        'health' {
            if (-not (Test-RahObjectProperties -Object $Response -Required @('status','computerName','utc')) -or [string]$Response.status -ne 'ready' -or -not (Test-RahSafeText ([string]$Response.computerName) 160) -or -not (Test-RahIsoTimestamp ([string]$Response.utc))) { throw 'Ugyldig health-svar.' }
        }
        'systemInfo' {
            if (-not (Test-RahObjectProperties -Object $Response -Required @('result')) -or $null -eq $Response.result -or -not (Test-RahSafeText ([string]$Response.result.computerName) 160)) { throw 'Ugyldig systemInfo-svar.' }
        }
        'benchmark' {
            if (-not (Test-RahObjectProperties -Object $Response -Required @('result')) -or $null -eq $Response.result -or [int64]$Response.result.iterations -ne 2000000 -or [int64]$Response.result.durationMs -lt 0) { throw 'Ugyldig benchmark-svar.' }
        }
    }
    return $Response
}

function Invoke-RahNodeClientSelfTest {
    if ((Normalize-RahNodeAddress -Address 'localhost') -ne '127.0.0.1' -or -not (Test-PrivateIPv4 '192.168.1.2') -or (Test-PrivateIPv4 '8.8.8.8')) { throw 'SelfTest: node address guard failed.' }
    $token = ('ab' * 32)
    if (-not (Test-RahTokenFormat $token) -or (Test-RahTokenFormat 'bad-token')) { throw 'SelfTest: token validator failed.' }
    if ((Normalize-RahPeerKey -Key 'localhost:18766') -ne '127.0.0.1:18766' -or $null -ne (Normalize-RahPeerKey -Key '8.8.8.8:18766')) { throw 'SelfTest: peer key validator failed.' }
    $hello = [pscustomobject]@{ok=$true;product='RAH Home Node Agent';version=2;agentVersion='1.0.0';computerName='WORKER';pairingRequired=$true}
    Assert-RahHelloResponse -Response $hello | Out-Null
    $badHello = [pscustomobject]@{ok=$true;product='Other Agent';version=2;computerName='WORKER';pairingRequired=$true}
    $rejected = $false
    try { Assert-RahHelloResponse -Response $badHello | Out-Null } catch { $rejected = $true }
    if (-not $rejected) { throw 'SelfTest: foreign hello identity accepted.' }
    $health = [pscustomobject]@{ok=$true;status='ready';computerName='WORKER';utc='2026-09-15T12:00:00.000Z'}
    Assert-RahActionResponse -Response $health -RequestedAction 'health' | Out-Null
    Write-Host "RAH Home Node Client $script:RahNodeClientVersion SelfTest OK" -ForegroundColor Green
}

$script:RahNormalizedNodeAddress = Normalize-RahNodeAddress -Address $NodeAddress
if ($SelfTest) {
    Invoke-RahNodeClientSelfTest
    return
}

New-Item -ItemType Directory -Path $rahDir -Force | Out-Null
$key = "$script:RahNormalizedNodeAddress`:$Port"
$peers = Read-Peers

if ($Action -eq 'hello') {
    $response = Invoke-Node -Request @{action='hello'}
    Assert-RahHelloResponse -Response $response | Out-Null
    $response | ConvertTo-Json -Depth 6
    exit 0
}

if ($Action -eq 'pair') {
    if ($PairCode -notmatch '^\d{6}$') { throw 'PairCode er pakrevd og ma vaere seks sifre nar Action=pair.' }
    $hello = Invoke-Node -Request @{action='hello'}
    Assert-RahHelloResponse -Response $hello | Out-Null
    $response = Invoke-Node -Request @{action='pair';code=$PairCode}
    Assert-RahPairResponse -Response $response | Out-Null
    if ($response.ok -ne $true) {
        $response | ConvertTo-Json -Depth 6
        exit 1
    }
    $peers[$key] = @{token=[string]$response.token;computerName=[string]$response.computerName;pairedAt=(Get-Date).ToUniversalTime().ToString('o')}
    Save-Peers -Peers $peers
    Write-Host "Paret med $($response.computerName) pa $key" -ForegroundColor Green
    exit 0
}

if (-not $peers.ContainsKey($key) -or -not (Test-RahTokenFormat ([string]$peers[$key].token))) {
    [pscustomobject]@{ok=$false;error='not-paired-or-invalid-local-token';message='Noden er ikke paret med et gyldig lokalt token. Kjor pair forst.'} | ConvertTo-Json -Compress
    exit 1
}

$response = Invoke-Node -Request @{action=$Action;token=[string]$peers[$key].token}
Assert-RahActionResponse -Response $response -RequestedAction $Action | Out-Null
$response | ConvertTo-Json -Depth 8
if ($response.ok -ne $true) { exit 1 }
