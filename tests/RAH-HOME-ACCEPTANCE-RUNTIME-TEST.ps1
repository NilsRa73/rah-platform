param([string]$RepoRoot = (Split-Path -Parent $PSScriptRoot))

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Parse {
    param([Parameter(Mandatory)][string]$Path)
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors) | Out-Null
    if (@($errors).Count -ne 0) { throw "Parser failure in $Path : $($errors[0].Message)" }
}

function Invoke-CheckedPowerShell {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $exe = Join-Path $PSHOME 'powershell.exe'
    & $exe @Arguments
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "Child PowerShell failed with exit code $code" }
}

$repo = [IO.Path]::GetFullPath($RepoRoot)
$acceptance = Join-Path $repo 'RAH-HOME-ACCEPTANCE.ps1'
$installer = Join-Path $repo 'RAH-HOME-INSTALL.ps1'
Assert-Parse $acceptance
Assert-Parse $installer

Invoke-CheckedPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$acceptance,'-SelfTest')

$temp = Join-Path $env:TEMP ('rah-home-acceptance-v1-' + [Guid]::NewGuid().ToString('N'))
$root = Join-Path $temp 'home'
$desktop = Join-Path $temp 'desktop'

try {
    Invoke-CheckedPowerShell @(
        '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$acceptance,
        '-InstallRoot',$root,'-DesktopPath',$desktop,'-SourceDirectory',$repo
    )

    $reportPath = Join-Path $root 'reports\rah-home-acceptance-latest.json'
    $textPath = Join-Path $root 'RAH-HOME-ACCEPTANCE.txt'
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) { throw 'Acceptance JSON report missing.' }
    if (-not (Test-Path -LiteralPath $textPath -PathType Leaf)) { throw 'Acceptance text report missing.' }

    $report = Get-Content -Raw -LiteralPath $reportPath | ConvertFrom-Json
    if ($report.schema -ne 'rah-home-acceptance' -or [int]$report.version -ne 1 -or -not $report.pass) { throw 'Acceptance report contract failed.' }
    if ($report.acceptanceVersion -ne '1.0.0') { throw 'Acceptance version mismatch.' }
    if (@($report.checks).Count -ne 13) { throw "Expected 13 acceptance checks, got $(@($report.checks).Count)." }
    if (@($report.checks | Where-Object { -not $_.ok }).Count -ne 0) { throw 'Acceptance report contains failed checks.' }

    foreach ($name in @(
        'RAH-HOME-NODE-AGENT.ps1',
        'RAH-HOME-NODE-CLIENT.ps1',
        'RAH-HOME-NODE-JOB.ps1',
        'RAH-HOME-CLUSTER-RUN.ps1',
        'RAH-HOME-CLUSTER-CONTROLLER.ps1',
        'RAH-HOME-PAIR-WIZARD.ps1',
        'RAH-HOME-LAN-ACCEPTANCE.ps1',
        'RAH-HOME-INSTALL.ps1'
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $name) -PathType Leaf)) { throw "Installed file missing: $name" }
    }

    foreach ($name in @('RAH Pair Worker.cmd','RAH Run Cluster Plan.cmd','RAH Test Worker LAN.cmd','RAH Home Nexus.url')) {
        if (-not (Test-Path -LiteralPath (Join-Path $desktop $name) -PathType Leaf)) { throw "Desktop shortcut missing: $name" }
    }

    $state = Get-Content -Raw -LiteralPath (Join-Path $root 'rah-home-install-state.json') | ConvertFrom-Json
    if ($state.mode -ne 'Leader' -or [int]$state.port -ne 18766) { throw 'Installed Leader state mismatch.' }

    Write-Host 'PASS: RAH Home Acceptance v1 Windows offline staging runtime' -ForegroundColor Green
}
finally {
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue }
}
