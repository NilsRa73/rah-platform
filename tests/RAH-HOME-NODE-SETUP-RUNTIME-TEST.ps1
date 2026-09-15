param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Parse {
    param([Parameter(Mandatory)][string]$Path)
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors) | Out-Null
    if (@($errors).Count -ne 0) { throw "Parser failure in ${Path}: $($errors[0].Message)" }
}

function Invoke-Child {
    param([Parameter(Mandatory)][string[]]$CommandArgs,[int]$ExpectedExit = 0)
    $exe = Join-Path $PSHOME 'powershell.exe'
    $old = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $exe @CommandArgs
        $code = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $old }
    if ($code -ne $ExpectedExit) { throw "Unexpected child exit ${code}; expected $ExpectedExit" }
}

$repo = [IO.Path]::GetFullPath($RepoRoot)
$legacy = Join-Path $repo 'RAH-HOME-NODE-SETUP.ps1'
$installer = Join-Path $repo 'RAH-HOME-INSTALL.ps1'
Assert-Parse $legacy
Assert-Parse $installer

Invoke-Child @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$legacy,'-SelfTest')

$temp = Join-Path $env:TEMP ('rah-home-legacy-v1-' + [Guid]::NewGuid().ToString('N'))
$installRoot = Join-Path $temp 'home'
$desktop = Join-Path $temp 'desktop'
try {
    Invoke-Child @(
        '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$legacy,
        '-Mode','Leader','-Port','18766',
        '-InstallerPath',$installer,
        '-InstallRoot',$installRoot,
        '-DesktopPath',$desktop,
        '-SourceDirectory',$repo
    )

    $statePath = Join-Path $installRoot 'rah-home-install-state.json'
    if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) { throw 'Legacy wrapper did not produce Unified Installer state.' }
    $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
    if ($state.schema -ne 'rah-home-install-state' -or $state.version -ne 1 -or $state.mode -ne 'Leader' -or [int]$state.port -ne 18766) {
        throw 'Legacy wrapper -> Unified Installer state contract failed.'
    }
    foreach ($name in @('RAH Pair Worker.cmd','RAH Run Cluster Plan.cmd','RAH Test Worker LAN.cmd','RAH Home Nexus.url')) {
        if (-not (Test-Path -LiteralPath (Join-Path $desktop $name) -PathType Leaf)) { throw "Legacy wrapper missing Leader output: $name" }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $installRoot 'RAH-HOME-NODE-AGENT.ps1') -PathType Leaf)) { throw 'Legacy wrapper did not install stable Node Agent.' }

    $exe = Join-Path $PSHOME 'powershell.exe'
    $old = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $legacy -Mode Leader -Port 18767 -InstallerPath $installer -InstallRoot $installRoot -DesktopPath $desktop -SourceDirectory $repo 2>$null
        $badPortExit = $LASTEXITCODE
    }
    finally { $ErrorActionPreference = $old }
    if ($badPortExit -eq 0) { throw 'Legacy wrapper accepted non-standard port 18767.' }

    Write-Host 'PASS: RAH Home Node Legacy Setup v1 wrapper -> Unified Installer staging runtime' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
