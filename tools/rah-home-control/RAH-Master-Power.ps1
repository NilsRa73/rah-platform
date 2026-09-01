[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$NoAutostart
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$RahRoot = Join-Path $env:USERPROFILE 'Documents\RAH Room Control'
$ToolRoot = Split-Path -Parent $PSCommandPath
$LogRoot = Join-Path $RahRoot 'Logs'
$RuntimeRoot = Join-Path $RahRoot 'Runtime'
$LogFile = Join-Path $LogRoot 'RAH-Master-Power.log'
$StatusFile = Join-Path $RahRoot 'RAH-Master-Power-Status.json'

New-Item -ItemType Directory -Path $RahRoot, $LogRoot, $RuntimeRoot -Force | Out-Null

function Write-RahLog {
    param(
        [string]$Message,
        [ValidateSet('INFO', 'OK', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    if (-not $Quiet) {
        $color = switch ($Level) {
            'OK' { 'Green' }
            'WARN' { 'Yellow' }
            'ERROR' { 'Red' }
            default { 'Cyan' }
        }
        Write-Host $line -ForegroundColor $color
    }
}

function Test-RahPort {
    param(
        [Parameter(Mandatory)]
        [int]$Port,
        [int]$TimeoutMs = 500
    )

    $client = [Net.Sockets.TcpClient]::new()
    try {
        $result = $client.BeginConnect('127.0.0.1', $Port, $null, $null)
        return $result.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function Wait-RahPort {
    param(
        [Parameter(Mandatory)]
        [int]$Port,
        [int]$Seconds = 20
    )

    for ($attempt = 0; $attempt -lt $Seconds; $attempt++) {
        if (Test-RahPort -Port $Port) {
            return $true
        }
        Start-Sleep -Seconds 1
    }
    return $false
}

function Get-OllamaPaths {
    $paths = [Collections.Generic.List[string]]::new()
    $command = Get-Command 'ollama.exe' -ErrorAction SilentlyContinue
    if ($command -and $command.Source) {
        $paths.Add([string]$command.Source)
    }

    foreach ($candidate in @(
        (Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama app.exe'),
        (Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama.exe'),
        (Join-Path $env:LOCALAPPDATA 'Ollama\ollama.exe')
    )) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            $paths.Add($candidate)
        }
    }

    return @($paths | Select-Object -Unique)
}

function Start-RahOllama {
    if (Test-RahPort -Port 11434) {
        Write-RahLog 'Ollama svarer allerede på 127.0.0.1:11434.' 'OK'
        return $true
    }

    $paths = @(Get-OllamaPaths)
    if (-not $paths) {
        Write-RahLog 'Ollama ble ikke funnet i PATH eller standard Windows-mappen.' 'ERROR'
        return $false
    }

    $app = $paths | Where-Object { [IO.Path]::GetFileName($_) -ieq 'ollama app.exe' } | Select-Object -First 1
    if ($app) {
        Write-RahLog "Starter Ollama-appen: $app"
        Start-Process -FilePath $app -WindowStyle Hidden
        if (Wait-RahPort -Port 11434 -Seconds 15) {
            Write-RahLog 'Ollama er online på 127.0.0.1:11434.' 'OK'
            return $true
        }
    }

    $cli = $paths | Where-Object { [IO.Path]::GetFileName($_) -ieq 'ollama.exe' } | Select-Object -First 1
    if (-not $cli) {
        Write-RahLog 'Ollama-appen startet, men API-et svarte ikke på port 11434.' 'ERROR'
        return $false
    }

    $stdout = Join-Path $LogRoot 'ollama-serve.log'
    $stderr = Join-Path $LogRoot 'ollama-serve.err.log'
    Write-RahLog "Starter Ollama-serveren: $cli serve"
    Start-Process -FilePath $cli -ArgumentList 'serve' -WindowStyle Hidden `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr

    if (Wait-RahPort -Port 11434 -Seconds 20) {
        Write-RahLog 'Ollama er online på 127.0.0.1:11434.' 'OK'
        return $true
    }

    Write-RahLog "Ollama svarte ikke. Se $stderr" 'ERROR'
    return $false
}

function Find-RahPlatformRoot {
    $candidates = [Collections.Generic.List[string]]::new()
    if ($env:RAH_PLATFORM_ROOT) {
        $candidates.Add($env:RAH_PLATFORM_ROOT)
    }

    $desktop = [Environment]::GetFolderPath('Desktop')
    foreach ($candidate in @(
        (Join-Path $desktop 'RAH AI Studios\rah-platform'),
        (Join-Path $env:USERPROFILE 'Desktop\RAH AI Studios\rah-platform'),
        $(if ($env:OneDrive) { Join-Path $env:OneDrive 'Desktop\RAH AI Studios\rah-platform' }),
        $(if ($env:OneDriveConsumer) { Join-Path $env:OneDriveConsumer 'Desktop\RAH AI Studios\rah-platform' }),
        (Join-Path $RuntimeRoot 'rah-platform')
    )) {
        if ($candidate) {
            $candidates.Add([string]$candidate)
        }
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath (Join-Path $candidate 'desktop-bridge\raven_bridge.py') -PathType Leaf) {
            return $candidate
        }
    }

    foreach ($searchRoot in @($desktop, (Join-Path $env:USERPROFILE 'Documents'))) {
        if (-not (Test-Path -LiteralPath $searchRoot -PathType Container)) {
            continue
        }
        $found = Get-ChildItem -LiteralPath $searchRoot `
            -Filter 'START-RAH-BRIDGE-AUTOSTART.bat' -File -Recurse -Depth 5 `
            -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1
        if ($found) {
            $root = Split-Path -Parent $found.FullName
            if (Test-Path -LiteralPath (Join-Path $root 'desktop-bridge\raven_bridge.py') -PathType Leaf) {
                return $root
            }
        }
    }

    return $null
}

function Install-RahBridgeRuntime {
    $target = Join-Path $RuntimeRoot 'rah-platform'
    if (Test-Path -LiteralPath $target) {
        $target = Join-Path $RuntimeRoot ('rah-platform-recovery-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }

    $token = [Guid]::NewGuid().ToString('N')
    $archive = Join-Path ([IO.Path]::GetTempPath()) "rah-platform-$token.zip"
    $extract = Join-Path ([IO.Path]::GetTempPath()) "rah-platform-$token"
    $url = 'https://codeload.github.com/NilsRa73/rah-platform/zip/refs/heads/main'

    try {
        Write-RahLog 'Kanonisk Bridge mangler lokalt. Henter en urørt kopi fra NilsRa73/rah-platform.' 'WARN'
        Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
        Expand-Archive -LiteralPath $archive -DestinationPath $extract -Force
        $source = Join-Path $extract 'rah-platform-main'
        if (-not (Test-Path -LiteralPath (Join-Path $source 'desktop-bridge\raven_bridge.py') -PathType Leaf)) {
            throw 'Den hentede RAH-pakken mangler desktop-bridge/raven_bridge.py.'
        }
        Move-Item -LiteralPath $source -Destination $target
        Write-RahLog "Bridge-runtime installert side om side: $target" 'OK'
        return $target
    }
    catch {
        Write-RahLog "Kunne ikke hente Bridge-runtime: $($_.Exception.Message)" 'ERROR'
        return $null
    }
    finally {
        Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $extract -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Start-RahBridge {
    if (Test-RahPort -Port 18765) {
        Write-RahLog 'RAH Bridge svarer allerede på 127.0.0.1:18765.' 'OK'
        return $true
    }

    $platformRoot = Find-RahPlatformRoot
    if (-not $platformRoot) {
        $platformRoot = Install-RahBridgeRuntime
    }
    if (-not $platformRoot) {
        return $false
    }

    Write-RahLog "Bruker RAH-plattform: $platformRoot"
    $bridgeRoot = Join-Path $platformRoot 'desktop-bridge'
    $venvPython = Join-Path $bridgeRoot '.venv\Scripts\python.exe'
    $autostart = Join-Path $platformRoot 'START-RAH-BRIDGE-AUTOSTART.bat'
    $setup = Join-Path $bridgeRoot 'start-bridge.bat'

    if ((Test-Path -LiteralPath $venvPython -PathType Leaf) -and
        (Test-Path -LiteralPath $autostart -PathType Leaf)) {
        Write-RahLog 'Starter eksisterende kanonisk Bridge stille.'
        Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/c', ('"{0}"' -f $autostart)) `
            -WorkingDirectory $platformRoot -WindowStyle Hidden
    }
    elseif (Test-Path -LiteralPath $setup -PathType Leaf) {
        Write-RahLog 'Klargjør Bridge-miljøet første gang. Et minimert statusvindu kan vises.' 'WARN'
        Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d', '/c', ('"{0}"' -f $setup)) `
            -WorkingDirectory $bridgeRoot -WindowStyle Minimized
    }
    else {
        Write-RahLog "Bridge-startfil mangler i $platformRoot" 'ERROR'
        return $false
    }

    if (Wait-RahPort -Port 18765 -Seconds 90) {
        Write-RahLog 'RAH Bridge er online på 127.0.0.1:18765.' 'OK'
        return $true
    }

    $errorLogs = @(
        (Join-Path $bridgeRoot 'rah-autostart.log.err'),
        (Join-Path $bridgeRoot 'rah-bridge-startup.log.err'),
        (Join-Path $bridgeRoot 'rah-home-control-startup.log.err')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf }
    $logHint = if ($errorLogs) { $errorLogs -join '; ' } else { $bridgeRoot }
    Write-RahLog "RAH Bridge svarte ikke innen 90 sekunder. Se: $logHint" 'ERROR'
    return $false
}

function Install-RahMasterAutostart {
    if ($NoAutostart) {
        return
    }

    $pwsh = (Get-Command 'pwsh.exe' -ErrorAction SilentlyContinue).Source
    if (-not $pwsh) {
        return
    }
    $startup = [Environment]::GetFolderPath('Startup')
    $shortcutPath = Join-Path $startup 'RAH Master Power.lnk'
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $pwsh
    $shortcut.Arguments = '-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "{0}" -Quiet' -f $PSCommandPath
    $shortcut.WorkingDirectory = $ToolRoot
    $shortcut.WindowStyle = 7
    $shortcut.Description = 'Starter RAH Bridge og Ollama ved Windows-innlogging'
    $shortcut.Save()
    Write-RahLog "Autostart er klar: $shortcutPath" 'OK'
}

if (-not $Quiet) {
    Clear-Host
    Write-Host ''
    Write-Host '==============================================' -ForegroundColor DarkYellow
    Write-Host '       RAH MASTER POWER - START ALL' -ForegroundColor Yellow
    Write-Host '==============================================' -ForegroundColor DarkYellow
    Write-Host ''
}

$ollamaOnline = $false
$bridgeOnline = $false
try {
    $ollamaOnline = Start-RahOllama
}
catch {
    Write-RahLog "Ollama-start feilet: $($_.Exception.Message)" 'ERROR'
}

try {
    $bridgeOnline = Start-RahBridge
}
catch {
    Write-RahLog "Bridge-start feilet: $($_.Exception.Message)" 'ERROR'
}

try {
    Install-RahMasterAutostart
}
catch {
    Write-RahLog "Autostart kunne ikke opprettes: $($_.Exception.Message)" 'WARN'
}

$status = [ordered]@{
    checked_at = (Get-Date).ToString('o')
    computer = $env:COMPUTERNAME
    bridge_online = [bool]$bridgeOnline
    bridge_endpoint = 'http://127.0.0.1:18765'
    ollama_online = [bool]$ollamaOnline
    ollama_endpoint = 'http://127.0.0.1:11434'
    log = $LogFile
}
$status | ConvertTo-Json | Set-Content -LiteralPath $StatusFile -Encoding UTF8

if (-not $Quiet) {
    Write-Host ''
    if ($bridgeOnline -and $ollamaOnline) {
        Write-Host 'RAH MASTER POWER: ALT ER ONLINE.' -ForegroundColor Green
    }
    else {
        Write-Host 'RAH MASTER POWER: ÉN ELLER FLERE TJENESTER TRENGER TILSYN.' -ForegroundColor Yellow
        Write-Host "Logg: $LogFile" -ForegroundColor DarkYellow
    }
    Write-Host 'Du kan lukke dette vinduet. Control Center oppdaterer status automatisk.'
    Start-Sleep -Seconds 4
}

if ($bridgeOnline -and $ollamaOnline) {
    exit 0
}
exit 1
