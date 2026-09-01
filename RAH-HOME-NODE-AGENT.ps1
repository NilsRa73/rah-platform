param(
    [string]$ListenAddress = '0.0.0.0',
    [ValidateRange(1024,65535)][int]$Port = 18766
)

$ErrorActionPreference = 'Stop'

function Test-PrivateIPv4([string]$Address) {
    if ($Address -eq '0.0.0.0' -or $Address -eq '127.0.0.1') { return $true }
    $parts = $Address.Split('.')
    if ($parts.Count -ne 4) { return $false }
    try { $n = $parts | ForEach-Object { [int]$_ } } catch { return $false }
    if ($n | Where-Object { $_ -lt 0 -or $_ -gt 255 }) { return $false }
    return ($n[0] -eq 10) -or ($n[0] -eq 192 -and $n[1] -eq 168) -or ($n[0] -eq 172 -and $n[1] -ge 16 -and $n[1] -le 31)
}

function New-RandomToken {
    $bytes = New-Object byte[] 32
    $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
    try { $rng.GetBytes($bytes) } finally { $rng.Dispose() }
    return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

if (-not (Test-PrivateIPv4 $ListenAddress)) {
    throw 'ListenAddress må være loopback, 0.0.0.0 eller en privat RFC1918 IPv4-adresse.'
}

$rahDir = Join-Path $env:LOCALAPPDATA 'RAH'
$statePath = Join-Path $rahDir 'home-node-agent.json'
New-Item -ItemType Directory -Path $rahDir -Force | Out-Null

$token = $null
if (Test-Path -LiteralPath $statePath) {
    try {
        $old = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
        if ($old.token -and ([string]$old.token).Length -ge 32) { $token = [string]$old.token }
    } catch {}
}
if (-not $token) {
    $token = New-RandomToken
    [pscustomobject]@{ version = 1; token = $token; createdAt = (Get-Date).ToUniversalTime().ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath $statePath -Encoding utf8
}

$pairCode = Get-Random -Minimum 100000 -Maximum 999999
$listener = New-Object Net.Sockets.TcpListener ([Net.IPAddress]::Parse($ListenAddress), $Port)
$listener.Start()

function Send-Json($stream, $obj) {
    $json = ($obj | ConvertTo-Json -Depth 6 -Compress) + "`n"
    $bytes = [Text.Encoding]::UTF8.GetBytes($json)
    $stream.Write($bytes, 0, $bytes.Length)
    $stream.Flush()
}

function Read-Line($stream) {
    $reader = New-Object IO.StreamReader ($stream, [Text.Encoding]::UTF8, $false, 4096, $true)
    return $reader.ReadLine()
}

function Get-SystemInfo {
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    [pscustomobject]@{
        computerName = $env:COMPUTERNAME
        userName = $env:USERNAME
        os = [string]$os.Caption
        osVersion = [string]$os.Version
        cpu = [string]$cpu.Name
        logicalProcessors = [int]$cpu.NumberOfLogicalProcessors
        memoryGB = [math]::Round(([double]$os.TotalVisibleMemorySize / 1MB), 1)
        agentVersion = 1
    }
}

function Invoke-SafeBenchmark {
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $sum = 0L
    for ($i = 1; $i -le 2000000; $i++) { $sum = ($sum + (($i * 31) % 9973)) % 2147483647 }
    $sw.Stop()
    [pscustomobject]@{ durationMs = $sw.ElapsedMilliseconds; checksum = $sum; iterations = 2000000 }
}

Write-Host ''
Write-Host 'RAH HOME NODE AGENT v0.1' -ForegroundColor Yellow
Write-Host "Lytter på $ListenAddress`:$Port"
Write-Host "PAIR CODE: $pairCode" -ForegroundColor Cyan
Write-Host 'Tillatte handlinger: hello, pair, health, systemInfo, benchmark'
Write-Host 'Ingen shell, filskriving eller vilkårlig kommando-utførelse er eksponert.'
Write-Host 'Stopp med Ctrl+C.'

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        try {
            $client.ReceiveTimeout = 5000
            $client.SendTimeout = 5000
            $stream = $client.GetStream()
            $line = Read-Line $stream
            if (-not $line -or $line.Length -gt 8192) {
                Send-Json $stream @{ ok = $false; error = 'invalid-request' }
                continue
            }
            try { $req = $line | ConvertFrom-Json } catch {
                Send-Json $stream @{ ok = $false; error = 'invalid-json' }
                continue
            }
            $action = [string]$req.action
            if ($action -eq 'hello') {
                Send-Json $stream @{ ok = $true; product = 'RAH Home Node Agent'; version = 1; computerName = $env:COMPUTERNAME; pairingRequired = $true }
                continue
            }
            if ($action -eq 'pair') {
                if ([string]$req.code -ne [string]$pairCode) {
                    Send-Json $stream @{ ok = $false; error = 'pair-code-rejected' }
                } else {
                    Send-Json $stream @{ ok = $true; paired = $true; token = $token; computerName = $env:COMPUTERNAME }
                }
                continue
            }
            if ([string]$req.token -ne $token) {
                Send-Json $stream @{ ok = $false; error = 'unauthorized' }
                continue
            }
            switch ($action) {
                'health' { Send-Json $stream @{ ok = $true; status = 'ready'; computerName = $env:COMPUTERNAME; utc = (Get-Date).ToUniversalTime().ToString('o') } }
                'systemInfo' { Send-Json $stream @{ ok = $true; result = (Get-SystemInfo) } }
                'benchmark' { Send-Json $stream @{ ok = $true; result = (Invoke-SafeBenchmark) } }
                default { Send-Json $stream @{ ok = $false; error = 'unsupported-action' } }
            }
        } finally {
            $client.Dispose()
        }
    }
} finally {
    $listener.Stop()
}
