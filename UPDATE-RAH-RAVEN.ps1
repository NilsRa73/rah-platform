param(
    [switch]$NoStart
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RawBase = "https://raw.githubusercontent.com/NilsRa73/rah-platform/main"
$ManifestName = "RAH-RAVEN-VERSION.json"
$BackupRoot = Join-Path $Root ".rah-backups"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path $BackupRoot $Stamp
$LogFile = Join-Path $Root "rah-raven-update.log"
$RequiredRuntimeFiles = @(
    "desktop-bridge/local_device_adapter.py",
    "desktop-bridge/test_local_device_adapter.py",
    "desktop-bridge/test_local_device_bridge.py",
    "START-RAH-HOME-CONTROL.bat",
    "RAH-CHATGPT-WHEEL.user.js"
)

function Write-RavenLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

function Get-SafeTargetPath {
    param([string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw "Tom filsti i manifestet."
    }
    if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath.Contains("..")) {
        throw "Utrygg filsti i manifestet: $RelativePath"
    }

    $normal = $RelativePath.Replace("/", [IO.Path]::DirectorySeparatorChar)
    $target = [IO.Path]::GetFullPath((Join-Path $Root $normal))
    $rootFull = [IO.Path]::GetFullPath($Root + [IO.Path]::DirectorySeparatorChar)
    if (-not $target.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Filsti peker utenfor RAH-mappen: $RelativePath"
    }
    return $target
}

function Get-FileHashSafe {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $null
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Sync-CommandCenterPackage {
    try {
        $ccUpdater = Join-Path $Root "UPDATE-RAH-COMMAND-CENTER.ps1"
        if (-not (Test-Path -LiteralPath $ccUpdater -PathType Leaf)) {
            Write-RavenLog "Valgfri Command Center-synk ble hoppet over: lokal verifiserende updater mangler."
            return
        }

        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ccUpdater -NoStart
        if ($LASTEXITCODE -ne 0) {
            Write-RavenLog "Command Center-pakken kunne ikke synkroniseres, men Raven-oppdateringen fortsetter."
            return
        }

        Write-RavenLog "Command Center-pakken er synkronisert via lokal verifiserende updater og skrivebordssnarveien er oppdatert."
    }
    catch {
        Write-RavenLog "Valgfri Command Center-synk ble hoppet over: $($_.Exception.Message)"
    }
}

try {
    Write-RavenLog "Starter RAH Raven sikker oppdatering. Rotmappe: $Root"

    $manifestTemp = Join-Path ([IO.Path]::GetTempPath()) ("rah-raven-manifest-{0}.json" -f [Guid]::NewGuid())
    Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$ManifestName" -OutFile $manifestTemp
    $manifest = Get-Content -LiteralPath $manifestTemp -Raw -Encoding UTF8 | ConvertFrom-Json
    Remove-Item -LiteralPath $manifestTemp -Force -ErrorAction SilentlyContinue

    if ($manifest.product -ne "RAH Raven") {
        throw "Manifestet tilhører ikke RAH Raven."
    }
    if (-not $manifest.version -or -not $manifest.files) {
        throw "Manifestet mangler versjon eller filliste."
    }

    $downloadFiles = @($manifest.files | ForEach-Object { [string]$_ })
    foreach ($requiredFile in $RequiredRuntimeFiles) {
        if ($downloadFiles -notcontains $requiredFile) {
            $downloadFiles += $requiredFile
            Write-RavenLog "Påkrevd runtime-fil lagt til i oppdateringssettet: $requiredFile"
        }
    }

    Write-RavenLog "Fant RAH Raven versjon $($manifest.version), launcher $($manifest.launcher)."
    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

    $updated = 0
    $unchanged = 0
    foreach ($relativePath in $downloadFiles) {
        $relative = [string]$relativePath
        $target = Get-SafeTargetPath -RelativePath $relative
        $targetDir = Split-Path -Parent $target
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null

        $encodedPath = ($relative -split "/" | ForEach-Object { [Uri]::EscapeDataString($_) }) -join "/"
        $url = "$RawBase/$encodedPath"
        $download = "$target.rah-download"

        try {
            Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $download
            if (-not (Test-Path -LiteralPath $download -PathType Leaf)) {
                throw "Nedlastingen opprettet ingen fil."
            }
            if ((Get-Item -LiteralPath $download).Length -lt 1) {
                throw "Nedlastet fil er tom."
            }

            $oldHash = Get-FileHashSafe -Path $target
            $newHash = Get-FileHashSafe -Path $download
            if ($oldHash -and $oldHash -eq $newHash) {
                Remove-Item -LiteralPath $download -Force
                $unchanged++
                Write-RavenLog "Uendret: $relative"
                continue
            }

            if (Test-Path -LiteralPath $target -PathType Leaf) {
                $backupTarget = Join-Path $BackupDir ($relative.Replace("/", [IO.Path]::DirectorySeparatorChar))
                New-Item -ItemType Directory -Path (Split-Path -Parent $backupTarget) -Force | Out-Null
                Copy-Item -LiteralPath $target -Destination $backupTarget -Force
            }

            Move-Item -LiteralPath $download -Destination $target -Force
            $updated++
            Write-RavenLog "Oppdatert: $relative"
        }
        finally {
            Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue
        }
    }

    $manifestTarget = Join-Path $Root $ManifestName
    Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$ManifestName" -OutFile "$manifestTarget.rah-download"
    Move-Item -LiteralPath "$manifestTarget.rah-download" -Destination $manifestTarget -Force

    Sync-CommandCenterPackage

    Write-RavenLog "Ferdig. Oppdatert: $updated. Uendret: $unchanged. Sikkerhetskopi: $BackupDir"
    Write-Host ""
    Write-Host "RAH Raven $($manifest.version) er oppdatert." -ForegroundColor Green
    Write-Host "Ingen passord, journaldata eller lokale Chronicle-data ble lastet opp." -ForegroundColor Yellow

    if (-not $NoStart) {
        $launcher = Join-Path $Root "START-RAH-RAVEN-V2.bat"
        if (Test-Path -LiteralPath $launcher) {
            Write-RavenLog "Starter ett-klikklauncheren."
            Start-Process -FilePath $launcher -WorkingDirectory $Root
        }
        else {
            throw "Launcheren ble ikke funnet etter oppdateringen: $launcher"
        }
    }
}
catch {
    Write-RavenLog "FEIL: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Oppdateringen stoppet trygt. Eksisterende filer er ikke slettet." -ForegroundColor Red
    Write-Host "Feil: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
