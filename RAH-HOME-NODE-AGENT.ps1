param(
    [string]$ListenAddress = '127.0.0.1',
    [switch]$AllowLan,
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahNodeAgentVersion = '1.0.0'
$script:RahProtocolVersion = 2
$script:RahMaxRequestBytes = 8192
$script:RahAllowedActions = @('hello','pair','health','systemInfo','benchmark')

function Test-PrivateIPv4 {
    param([Parameter(Mandatory)][string]$Address)

    if ($Address -eq '127.0.0.1') { return $true }
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

function New-RandomToken {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Test-RahTokenFormat {
    param([string]$Token)
    return (-not [string]::IsNullOrWhiteSpace($Token) -and $Token -cmatch '^[0-9a-f]{64}$')
}

function ConvertFrom-RahHexToken {
    param([Parameter(Mandatory)][string]$Token)
    if (-not (Test-RahTokenFormat $Token)) { return $null }
    $bytes = New-Object byte[] 32
    for ($i = 0; $i -lt 32; $i++) {
        $bytes[$i] = [Convert]::ToByte($Token.Substring($i * 2, 2), 16)
    }
    return $bytes
}

function Test-RahTokenEqual {
    param([string]$Candidate,[string]$Expected)
    $a = ConvertFrom-RahHexToken -Token $Candidate
    $b = ConvertFrom-RahHexToken -Token $Expected
    if ($null -eq $a -or $null -eq $b -or $a.Length -ne $b.Length) { return $false }
    $diff = 0
    for ($i = 0; $i -lt $a.Length; $i++) {
        $diff = $diff -bor ($a[$i] -bxor $b[$i])
    }
    return ($diff -eq 0)
}

function New-RahPairCode {
    $range = [uint64]900000
    $space = [uint64]4294967296
    $limit = $space - ($space % $range)
    $bytes = New-Object byte[] 4
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        do {
            $rng.GetBytes($bytes)
            $value = [uint64][BitConverter]::ToUInt32($bytes,0)
        } while ($value -ge $limit)
    }
    finally { $rng.Dispose() }
    return ([int](100000 + ($value % $range))).ToString('D6')
}

function Write-RahAgentState {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Token)
    if (-not (Test-RahTokenFormat $Token)) { throw 'Refusing to persist invalid node token.' }
    $state = [pscustomobject]@{
        version = 1
        token = $Token
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
    }
    $json = $state | ConvertTo-Json -Depth 4
    $temp = "$Path.tmp"
    [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($false))
    try { Move-Item -LiteralPath $temp -Destination $Path -Force }
    finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}

function Read-RahAgentToken {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        $old = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($old -and [int]$old.version -eq 1 -and (Test-RahTokenFormat ([string]$old.token))) {
            return [string]$old.token
        }
    }
    catch { }
    return $null
}

function Send-Json {
    param([Parameter(Mandatory)]$Stream,[Parameter(Mandatory)]$Object)
    $json = ($Object | ConvertTo-Json -Depth 6 -Compress) + "`n"
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $Stream.Write($bytes,0,$bytes.Length)
    $Stream.Flush()
}

function Read-RahBoundedLine {
    param([Parameter(Mandatory)]$Stream,[int]$MaxBytes = $script:RahMaxRequestBytes)
    $buffer = New-Object 'System.Collections.Generic.List[byte]'
    while ($true) {
        $value = $Stream.ReadByte()
        if ($value -eq -1) {
            if ($buffer.Count -eq 0) { return $null }
            break
        }
        if ($value -eq 10) { break }
        if ($buffer.Count -ge $MaxBytes) { throw 'request-too-large' }
        $buffer.Add([byte]$value)
    }
    $bytes = $buffer.ToArray()
    if ($bytes.Length -gt 0 -and $bytes[$bytes.Length-1] -eq 13) {
        $trimmed = New-Object byte[] ($bytes.Length-1)
        if ($trimmed.Length -gt 0) { [Array]::Copy($bytes,$trimmed,$trimmed.Length) }
        $bytes = $trimmed
    }
    $utf8 = New-Object Text.UTF8Encoding($false,$true)
    try { return $utf8.GetString($bytes) }
    catch { throw 'invalid-utf8' }
}

function Test-RahExactProperties {
    param([Parameter(Mandatory)]$Object,[Parameter(Mandatory)][string[]]$Allowed,[Parameter(Mandatory)][string[]]$Required)
    if ($null -eq $Object -or $Object -is [Array]) { return $false }
    $names = @($Object.PSObject.Properties.Name)
    foreach ($name in $names) { if ($Allowed -notcontains [string]$name) { return $false } }
    foreach ($name in $Required) { if ($names -notcontains $name) { return $false } }
    return ($names.Count -eq $Allowed.Count)
}

function Test-RahRequestShape {
    param([Parameter(Mandatory)]$Request,[Parameter(Mandatory)][string]$Action)
    switch ($Action) {
        'hello' {
            return (Test-RahExactProperties -Object $Request -Allowed @('action') -Required @('action'))
        }
        'pair' {
            if (-not (Test-RahExactProperties -Object $Request -Allowed @('action','code') -Required @('action','code'))) { return $false }
            return ($Request.code -is [string] -and [string]$Request.code -match '^\d{6}$')
        }
        { $_ -in @('health','systemInfo','benchmark') } {
            if (-not (Test-RahExactProperties -Object $Request -Allowed @('action','token') -Required @('action','token'))) { return $false }
            return ($Request.token -is [string] -and (Test-RahTokenFormat ([string]$Request.token)))
        }
        default {
            return (Test-RahExactProperties -Object $Request -Allowed @('action') -Required @('action'))
        }
    }
}

function Get-SystemInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    return [pscustomobject]@{
        computerName = $env:COMPUTERNAME
        os = [string]$os.Caption
        osVersion = [string]$os.Version
        cpu = [string]$cpu.Name
        logicalProcessors = [int]$cpu.NumberOfLogicalProcessors
        memoryGB = [math]::Round(([double]$os.TotalVisibleMemorySize/1MB),1)
        agentVersion = $script:RahProtocolVersion
    }
}

function Invoke-SafeBenchmark {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $sum = 0L
    for ($i=1; $i -le 2000000; $i++) { $sum = ($sum + (($i*31)%9973)) % 2147483647 }
    $sw.Stop()
    return [pscustomobject]@{durationMs=$sw.ElapsedMilliseconds;checksum=$sum;iterations=2000000}
}

function Invoke-RahNodeAgentSelfTest {
    if (-not (Test-PrivateIPv4 '192.168.1.20') -or -not (Test-PrivateIPv4 '172.16.0.1') -or (Test-PrivateIPv4 '8.8.8.8')) {
        throw 'SelfTest: private IPv4 guard failed.'
    }
    $token = New-RandomToken
    if (-not (Test-RahTokenFormat $token) -or -not (Test-RahTokenEqual $token $token)) {
        throw 'SelfTest: token generation/comparison failed.'
    }
    $other = New-RandomToken
    if (Test-RahTokenEqual $token $other) { throw 'SelfTest: distinct tokens compared equal.' }
    $code = New-RahPairCode
    if ($code -notmatch '^\d{6}$' -or [int]$code -lt 100000 -or [int]$code -gt 999999) {
        throw 'SelfTest: pairing code generation failed.'
    }
    $health = [pscustomobject]@{action='health';token=$token}
    if (-not (Test-RahRequestShape -Request $health -Action 'health')) { throw 'SelfTest: valid health request rejected.' }
    $smuggled = [pscustomobject]@{action='health';token=$token;command='whoami'}
    if (Test-RahRequestShape -Request $smuggled -Action 'health') { throw 'SelfTest: extra command field accepted.' }
    $shell = [pscustomobject]@{action='shell'}
    if (-not (Test-RahRequestShape -Request $shell -Action 'shell') -or $script:RahAllowedActions -contains 'shell') {
        throw 'SelfTest: unsupported action guard failed.'
    }
    Write-Host "RAH Home Node Agent $script:RahNodeAgentVersion SelfTest OK" -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-RahNodeAgentSelfTest
    return
}

if ($ListenAddress -eq '0.0.0.0') { throw 'Wildcard 0.0.0.0 er ikke tillatt. Bruk loopback eller eksplisitt privat LAN-adresse.' }
if ($ListenAddress -ne '127.0.0.1') {
    if (-not $AllowLan) { throw 'LAN-lytting krever eksplisitt -AllowLan.' }
    if (-not (Test-PrivateIPv4 $ListenAddress) -or $ListenAddress -eq '127.0.0.1') { throw 'LAN ListenAddress ma vaere privat RFC1918 IPv4.' }
    $local = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { $_.IPAddress })
    if ($local -notcontains $ListenAddress) { throw 'ListenAddress finnes ikke pa denne maskinen.' }
}

$rahDir = Join-Path $env:LOCALAPPDATA 'RAH'
$statePath = Join-Path $rahDir 'home-node-agent.json'
New-Item -ItemType Directory -Path $rahDir -Force | Out-Null
$token = Read-RahAgentToken -Path $statePath
if (-not $token) {
    $token = New-RandomToken
    Write-RahAgentState -Path $statePath -Token $token
}

$pairCode = New-RahPairCode
$pairExpires = (Get-Date).AddMinutes(10)
$pairFailures = 0
$lockUntil = [datetime]::MinValue
$listener = New-Object Net.Sockets.TcpListener ([Net.IPAddress]::Parse($ListenAddress),$Port)
$listener.Start()

Write-Host ''
Write-Host "RAH HOME NODE AGENT v$script:RahNodeAgentVersion" -ForegroundColor Yellow
Write-Host "Lytter pa $ListenAddress`:$Port"
Write-Host "PAIR CODE: $pairCode (gyldig i 10 minutter)" -ForegroundColor Cyan
Write-Host 'Maks 5 feil pairingforsok for 60 sekunders lasing.'
Write-Host 'Tillatt: hello, pair, health, systemInfo, benchmark. Ingen vilkarlig shell.'

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $remote = ([Net.IPEndPoint]$client.Client.RemoteEndPoint).Address.ToString()
            if ($ListenAddress -ne '127.0.0.1' -and (-not (Test-PrivateIPv4 $remote) -or $remote -eq '127.0.0.1')) {
                $client.Dispose()
                continue
            }
            $client.ReceiveTimeout = 5000
            $client.SendTimeout = 5000
            $stream = $client.GetStream()
            try { $line = Read-RahBoundedLine -Stream $stream }
            catch {
                Send-Json -Stream $stream -Object @{ok=$false;error=[string]$_.Exception.Message}
                continue
            }
            if ([string]::IsNullOrWhiteSpace($line)) {
                Send-Json -Stream $stream -Object @{ok=$false;error='invalid-request'}
                continue
            }
            try { $req = $line | ConvertFrom-Json -ErrorAction Stop }
            catch {
                Send-Json -Stream $stream -Object @{ok=$false;error='invalid-json'}
                continue
            }
            if ($req -is [Array] -or $null -eq $req.PSObject.Properties['action'] -or -not ($req.action -is [string])) {
                Send-Json -Stream $stream -Object @{ok=$false;error='invalid-request'}
                continue
            }
            $action = [string]$req.action
            if ($action.Length -gt 32 -or -not (Test-RahRequestShape -Request $req -Action $action)) {
                Send-Json -Stream $stream -Object @{ok=$false;error='invalid-request'}
                continue
            }

            if ($action -eq 'hello') {
                Send-Json -Stream $stream -Object @{ok=$true;product='RAH Home Node Agent';version=$script:RahProtocolVersion;agentVersion=$script:RahNodeAgentVersion;computerName=$env:COMPUTERNAME;pairingRequired=$true}
                continue
            }

            if ($action -eq 'pair') {
                if ((Get-Date) -lt $lockUntil) {
                    Send-Json -Stream $stream -Object @{ok=$false;error='pairing-temporarily-locked'}
                    continue
                }
                if ((Get-Date) -gt $pairExpires) {
                    Send-Json -Stream $stream -Object @{ok=$false;error='pair-code-expired'}
                    continue
                }
                if ([string]$req.code -cne [string]$pairCode) {
                    $pairFailures++
                    if ($pairFailures -ge 5) {
                        $lockUntil = (Get-Date).AddSeconds(60)
                        $pairFailures = 0
                    }
                    Send-Json -Stream $stream -Object @{ok=$false;error='pair-code-rejected'}
                }
                else {
                    $pairFailures = 0
                    Send-Json -Stream $stream -Object @{ok=$true;paired=$true;token=$token;computerName=$env:COMPUTERNAME}
                }
                continue
            }

            if ($script:RahAllowedActions -notcontains $action) {
                Send-Json -Stream $stream -Object @{ok=$false;error='unsupported-action'}
                continue
            }
            if (-not (Test-RahTokenEqual ([string]$req.token) $token)) {
                Send-Json -Stream $stream -Object @{ok=$false;error='unauthorized'}
                continue
            }

            switch ($action) {
                'health' {
                    Send-Json -Stream $stream -Object @{ok=$true;status='ready';computerName=$env:COMPUTERNAME;utc=(Get-Date).ToUniversalTime().ToString('o')}
                }
                'systemInfo' {
                    Send-Json -Stream $stream -Object @{ok=$true;result=(Get-SystemInfo)}
                }
                'benchmark' {
                    Send-Json -Stream $stream -Object @{ok=$true;result=(Invoke-SafeBenchmark)}
                }
                default {
                    Send-Json -Stream $stream -Object @{ok=$false;error='unsupported-action'}
                }
            }
        }
        finally {
            if ($client) { $client.Dispose() }
        }
    }
}
finally {
    $listener.Stop()
}
