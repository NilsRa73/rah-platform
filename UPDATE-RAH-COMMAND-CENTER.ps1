param(
    [switch]$NoStart
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$RawBase = "https://raw.githubusercontent.com/NilsRa73/rah-platform/main"
$ManifestName = "RAH-COMMAND-CENTER-VERSION.json"
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$BackupDir = Join-Path (Join-Path $Root ".rah-backups") ("command-center-" + $Stamp)
$LogFile = Join-Path $Root "rah-command-center-update.log"

function Write-CcLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

function Get-SafeTargetPath {
    param([string]$RelativePath)

    if ([string]::IsNullOrWhiteSpace($RelativePath)) {
        throw "Tom filsti i Command Center-manifestet."
    }
    if ([IO.Path]::IsPathRooted($RelativePath) -or $RelativePath.Contains("..")) {
        throw "Utrygg Command Center-fil: $RelativePath"
    }

    $normal = $RelativePath.Replace("/", [IO.Path]::DirectorySeparatorChar)
    $target = [IO.Path]::GetFullPath((Join-Path $Root $normal))
    $rootFull = [IO.Path]::GetFullPath($Root + [IO.Path]::DirectorySeparatorChar)
    if (-not $target.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Command Center-fil peker utenfor RAH-mappen: $RelativePath"
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

function Install-CommandCenterShortcut {
    param([string]$EntryPath)

    $desktop = [Environment]::GetFolderPath("Desktop")
    $shortcutPath = Join-Path $desktop "RAH Command Center.lnk"
    $launcher = Join-Path $Root "DOBBELTKLIKK-HER-START-RAH-COMMAND-CENTER.bat"
    $target = if (Test-Path -LiteralPath $launcher -PathType Leaf) { $launcher } else { $EntryPath }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $target
    $shortcut.WorkingDirectory = $Root
    $shortcut.Description = "Oppdater og start RAH Raven Command Center"
    $shortcut.WindowStyle = 1
    $shortcut.Save()

    Write-CcLog "Skrivebordssnarvei klar: $shortcutPath"
}

try {
    Write-CcLog "Starter RAH Command Center sikker pakkeoppdatering."

    $manifestTemp = Join-Path ([IO.Path]::GetTempPath()) ("rah-cc-manifest-{0}.json" -f [Guid]::NewGuid())
    Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$ManifestName" -OutFile $manifestTemp
    $manifest = Get-Content -LiteralPath $manifestTemp -Raw -Encoding UTF8 | ConvertFrom-Json

    if ($manifest.product -ne "RAH Raven Command Center") {
        throw "Manifestet tilhører ikke RAH Raven Command Center."
    }
    if (-not $manifest.version -or -not $manifest.entry -or -not $manifest.runtime -or -not $manifest.package_files) {
        throw "Command Center-manifestet mangler påkrevde pakkefelter."
    }

    New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
    $updated = 0
    $unchanged = 0

    foreach ($relativePath in $manifest.package_files) {
        $relative = [string]$relativePath
        $target = Get-SafeTargetPath -RelativePath $relative
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null

        $encodedPath = ($relative -split "/" | ForEach-Object { [Uri]::EscapeDataString($_) }) -join "/"
        $download = "$target.rah-download"

        try {
            Invoke-WebRequest -UseBasicParsing -Uri "$RawBase/$encodedPath" -OutFile $download
            if (-not (Test-Path -LiteralPath $download -PathType Leaf) -or (Get-Item -LiteralPath $download).Length -lt 1) {
                throw "Tom eller manglende nedlasting: $relative"
            }

            $oldHash = Get-FileHashSafe -Path $target
            $newHash = Get-FileHashSafe -Path $download
            if ($oldHash -and $oldHash -eq $newHash) {
                Remove-Item -LiteralPath $download -Force
                $unchanged++
                continue
            }

            if (Test-Path -LiteralPath $target -PathType Leaf) {
                $backupTarget = Join-Path $BackupDir ($relative.Replace("/", [IO.Path]::DirectorySeparatorChar))
                New-Item -ItemType Directory -Path (Split-Path -Parent $backupTarget) -Force | Out-Null
                Copy-Item -LiteralPath $target -Destination $backupTarget -Force
            }

            Move-Item -LiteralPath $download -Destination $target -Force
            $updated++
            Write-CcLog "Oppdatert: $relative"
        }
        finally {
            Remove-Item -LiteralPath $download -Force -ErrorAction SilentlyContinue
        }
    }

    $manifestTarget = Get-SafeTargetPath -RelativePath $ManifestName
    Move-Item -LiteralPath $manifestTemp -Destination $manifestTarget -Force

    $entryPath = Get-SafeTargetPath -RelativePath ([string]$manifest.entry)
    if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
        throw "Command Center entry mangler etter oppdatering: $entryPath"
    }

    Install-CommandCenterShortcut -EntryPath $entryPath
    Write-CcLog "Command Center $($manifest.version) klar. Oppdatert: $updated. Uendret: $unchanged."

    Write-Host ""
    Write-Host "RAH Command Center $($manifest.version) er klar." -ForegroundColor Green
    Write-Host "Ingen lokale prosjektdata, passord eller Chronicle-data ble lastet opp." -ForegroundColor Yellow

    if (-not $NoStart) {
        Start-Process -FilePath $entryPath -WorkingDirectory $Root
    }
}
catch {
    Remove-Item -LiteralPath $manifestTemp -Force -ErrorAction SilentlyContinue
    Write-CcLog "FEIL: $($_.Exception.Message)"
    Write-Host ""
    Write-Host "Command Center-oppdateringen stoppet trygt." -ForegroundColor Red
    Write-Host "Eksisterende lokale filer ble ikke slettet." -ForegroundColor Red
    exit 1
}
