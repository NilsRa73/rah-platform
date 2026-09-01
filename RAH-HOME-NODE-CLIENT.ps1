param(
    [Parameter(Mandatory=$true)][string]$NodeAddress,
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [ValidateSet('hello','pair','health','systemInfo','benchmark')][string]$Action = 'hello',
    [string]$PairCode = ''
)

$ErrorActionPreference = 'Stop'

function Test-PrivateIPv4([string]$Address) {
    if ($Address -eq '127.0.0.1' -or $Address -eq 'localhost') { return $true }
    $parts = $Address.Split('.')
    if ($parts.Count -ne 4) { return $false }
    try { $n = $parts | ForEach-Object { [int]$_ } } catch { return $false }
    if ($n | Where-Object { $_ -lt 0 -or $_ -gt 255 }) { return $false }
    return ($n[0] -eq 10) -or ($n[0] -eq 192 -and $n[1] -eq 168) -or ($n[0] -eq 172 -and $n[1] -ge 16 -and $n[1] -le 31)
}

if (-not (Test-PrivateIPv4 $NodeAddress)) {
    throw 'NodeAddress må være localhost eller en privat RFC1918 IPv4-adresse.'
}

$rahDir = Join-Path $env:LOCALAPPDATA 'RAH'
$peersPath = Join-Path $rahDir 'home-node-peers.json'
New-Item -ItemType Directory -Path $rahDir -Force | Out-Null

function Read-Peers {
    $map = @{}
    if (-not (Test-Path -LiteralPath $peersPath)) { return $map }
    try {
        $obj = Get-Content -LiteralPath $peersPath -Raw | ConvertFrom-Json
        if ($obj -and $obj.peers) {
            foreach ($p in @($obj.peers)) {
                if ($p.key -and $p.token) {
                    $map[[string]$p.key] = @{ token = [string]$p.token; computerName = [string]$p.computerName; pairedAt = [string]$p.pairedAt }
                }
            }
        }
    } catch {}
    return $map
}

function Save-Peers($peers) {
    $items = @()
    foreach ($k in $peers.Keys) {
        $p = $peers[$k]
        $items += [pscustomobject]@{ key = $k; token = $p.token; computerName = $p.computerName; pairedAt = $p.pairedAt }
    }
    [pscustomobject]@{ version = 1; peers = $items } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $peersPath -Encoding utf8
}

function Invoke-Node($request) {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $client.ReceiveTimeout = 5000
        $client.SendTimeout = 5000
        $client.Connect($NodeAddress, $Port)
        $stream = $client.GetStream()
        $json = ($request | ConvertTo-Json -Compress) + "`n"
        $bytes = [Text.Encoding]::UTF8.GetBytes($json)
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Flush()
        $reader = New-Object IO.StreamReader ($stream, [Text.Encoding]::UTF8, $false, 4096, $true)
        $line = $reader.ReadLine()
        if (-not $line) { throw 'Noden svarte ikke.' }
        return $line | ConvertFrom-Json
    } finally {
        $client.Dispose()
    }
}

$key = "$NodeAddress`:$Port"
$peers = Read-Peers

if ($Action -eq 'hello') {
    Invoke-Node @{ action = 'hello' } | ConvertTo-Json -Depth 6
    exit 0
}

if ($Action -eq 'pair') {
    if (-not $PairCode) { throw 'PairCode er påkrevd når Action=pair.' }
    $response = Invoke-Node @{ action = 'pair'; code = $PairCode }
    if (-not $response.ok -or -not $response.token) {
        $response | ConvertTo-Json -Depth 6
        exit 1
    }
    $peers[$key] = @{ token = [string]$response.token; computerName = [string]$response.computerName; pairedAt = (Get-Date).ToUniversalTime().ToString('o') }
    Save-Peers $peers
    Write-Host "Paret med $($response.computerName) på $key" -ForegroundColor Green
    exit 0
}

if (-not $peers.ContainsKey($key) -or -not $peers[$key].token) {
    throw "Noden er ikke paret. Kjør først: -Action pair -PairCode <kode>"
}

$response = Invoke-Node @{ action = $Action; token = [string]$peers[$key].token }
$response | ConvertTo-Json -Depth 8
if (-not $response.ok) { exit 1 }
