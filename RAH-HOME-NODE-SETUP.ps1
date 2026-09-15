param(
    [ValidateSet('Worker','Leader')][string]$Mode = 'Worker',
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [string]$InstallerPath = '',
    [string]$InstallRoot = '',
    [string]$DesktopPath = '',
    [string]$SourceDirectory = '',
    [string]$WorkerAddress = '',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahLegacySetupVersion = '1.0.0'
$script:RahInstallerUrl = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-INSTALL.ps1'
$script:RahMaxInstallerBytes = 1048576

function Assert-RahInstallerV1 {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'RAH Home Unified Installer mangler.' }
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -le 0 -or $item.Length -gt $script:RahMaxInstallerBytes) { throw 'Unified Installer har ugyldig filstørrelse.' }
    if ([IO.Path]::GetFileName($item.FullName) -cne 'RAH-HOME-INSTALL.ps1') { throw 'Unified Installer har uventet filnavn.' }

    $tokens = $null
    $parseErrors = $null
    [Management.Automation.Language.Parser]::ParseFile($item.FullName,[ref]$tokens,[ref]$parseErrors) | Out-Null
    if (@($parseErrors).Count -ne 0) { throw "Unified Installer besto ikke PowerShell-parser: $($parseErrors[0].Message)" }

    $text = [IO.File]::ReadAllText($item.FullName)
    foreach ($marker in @(
        '$script:RahHomeInstallerVersion = ''1.0.0''',
        'Invoke-RahInstallerSelfTest',
        'Get-RahComponentManifest',
        'New-RahWorkerShortcut',
        'New-RahLeaderShortcuts'
    )) {
        if (-not $text.Contains($marker)) { throw "Unified Installer mangler stable-v1-kontrakt: $marker" }
    }
    return (Resolve-Path -LiteralPath $item.FullName).Path
}

function Get-RahInstallerV1 {
    param([string]$RequestedPath = '')
    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        return Assert-RahInstallerV1 -Path ([IO.Path]::GetFullPath($RequestedPath))
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($PSScriptRoot)) { [void]$candidates.Add((Join-Path $PSScriptRoot 'RAH-HOME-INSTALL.ps1')) }
    if (-not [string]::IsNullOrWhiteSpace($env:SystemDrive)) { [void]$candidates.Add((Join-Path $env:SystemDrive 'RAH\Home\RAH-HOME-INSTALL.ps1')) }
    if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) { [void]$candidates.Add((Join-Path $env:LOCALAPPDATA 'RAH\Home\RAH-HOME-INSTALL.ps1')) }
    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            try { return Assert-RahInstallerV1 -Path $candidate } catch { }
        }
    }

    $downloadDir = Join-Path $env:TEMP 'RAH\HomeLegacy'
    New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null
    $target = Join-Path $downloadDir 'RAH-HOME-INSTALL.ps1'
    $stage = "$target.download"
    try {
        Invoke-WebRequest -UseBasicParsing -Uri $script:RahInstallerUrl -OutFile $stage -ErrorAction Stop
        Move-Item -LiteralPath $stage -Destination $target -Force
        return Assert-RahInstallerV1 -Path $target
    }
    finally {
        if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Force -ErrorAction SilentlyContinue }
    }
}

function Invoke-RahLegacySelfTest {
    if ($script:RahLegacySetupVersion -ne '1.0.0') { throw 'SelfTest: uventet legacy-versjon.' }
    if ($script:RahInstallerUrl -ne 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-INSTALL.ps1') { throw 'SelfTest: uventet installer-kilde.' }
    if ($script:RahMaxInstallerBytes -ne 1048576) { throw 'SelfTest: installer size guard feilet.' }
    $expectedMarkers = @('Invoke-RahInstallerSelfTest','Get-RahComponentManifest','New-RahWorkerShortcut','New-RahLeaderShortcuts')
    if ($expectedMarkers.Count -ne 4) { throw 'SelfTest: installer-kontraktmarkører feilet.' }
    Write-Host "RAH Home Node Legacy Setup $script:RahLegacySetupVersion SelfTest OK" -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-RahLegacySelfTest
    return
}

if ($Port -ne 18766) {
    throw 'Legacy Setup støtter kun sikker standardport 18766. Bruk RAH-HOME-INSTALL.cmd direkte for annen eksplisitt port.'
}

$installer = Get-RahInstallerV1 -RequestedPath $InstallerPath
$powerShellExe = Join-Path $PSHOME 'powershell.exe'
if (-not (Test-Path -LiteralPath $powerShellExe -PathType Leaf)) { throw 'Fant ikke Windows PowerShell under PSHOME.' }

$arguments = @(
    '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
    '-File',$installer,
    '-Mode',$Mode,
    '-Port',[string]$Port
)
if (-not [string]::IsNullOrWhiteSpace($InstallRoot)) { $arguments += @('-InstallRoot',$InstallRoot) }
if (-not [string]::IsNullOrWhiteSpace($DesktopPath)) { $arguments += @('-DesktopPath',$DesktopPath) }
if (-not [string]::IsNullOrWhiteSpace($SourceDirectory)) { $arguments += @('-SourceDirectory',$SourceDirectory) }
if (-not [string]::IsNullOrWhiteSpace($WorkerAddress)) { $arguments += @('-WorkerAddress',$WorkerAddress) }

Write-Host "RAH HOME NODE LEGACY SETUP v$script:RahLegacySetupVersion" -ForegroundColor Yellow
Write-Host 'Kompatibilitetsmodus: all installasjon videresendes til RAH Home Unified Installer v1.'

$oldPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = 'Continue'
    & $powerShellExe @arguments
    $exitCode = $LASTEXITCODE
}
finally { $ErrorActionPreference = $oldPreference }

if ($exitCode -ne 0) { throw "Unified Installer avsluttet med kode $exitCode." }
Write-Host 'Legacy Setup fullført via Unified Installer v1.' -ForegroundColor Green
