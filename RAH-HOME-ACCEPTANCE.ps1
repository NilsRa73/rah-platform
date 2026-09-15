param(
    [string]$InstallRoot = 'C:\RAH\Home',
    [string]$DesktopPath = '',
    [string]$SourceDirectory = '',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahHomeAcceptanceVersion = '1.0.0'
$script:RahInstallerName = 'RAH-HOME-INSTALL.ps1'
$script:RahInstallerUrl = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-INSTALL.ps1'
$script:RahMaxInstallerBytes = 4MB
$script:RahExpectedComponents = @(
    'RAH-HOME-NODE-AGENT.ps1',
    'RAH-HOME-NODE-CLIENT.ps1',
    'RAH-HOME-NODE-JOB.ps1',
    'RAH-HOME-CLUSTER-RUN.ps1',
    'RAH-HOME-CLUSTER-CONTROLLER.ps1',
    'RAH-HOME-PAIR-WIZARD.ps1',
    'RAH-HOME-LAN-ACCEPTANCE.ps1'
)
$script:RahExpectedLeaderShortcuts = @(
    'RAH Pair Worker.cmd',
    'RAH Run Cluster Plan.cmd',
    'RAH Test Worker LAN.cmd',
    'RAH Home Nexus.url'
)

function Test-RahAdministrator {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch { return $false }
}

function Assert-RahPowerShellFile {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Mangler PowerShell-fil: $Path" }
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors) | Out-Null
    if (@($errors).Count -ne 0) { throw "PowerShell-parser avviste $Path : $($errors[0].Message)" }
    return $true
}

function Assert-RahInstaller {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw 'Mangler Unified Installer.' }
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ([IO.Path]::GetFileName($item.FullName) -cne $script:RahInstallerName) { throw 'Uventet installerfilnavn.' }
    if ($item.Length -le 0 -or $item.Length -gt $script:RahMaxInstallerBytes) { throw 'Ugyldig størrelse på Unified Installer.' }
    Assert-RahPowerShellFile -Path $item.FullName | Out-Null
    $text = [IO.File]::ReadAllText($item.FullName)
    foreach ($marker in @("RahHomeInstallerVersion = '1.0.0'",'Get-RahComponentManifest','Invoke-RahInstallerSelfTest')) {
        if (-not $text.Contains($marker)) { throw "Unified Installer mangler stable-v1 kontrakt: $marker" }
    }
    return $item.FullName
}

function Resolve-RahDesktopPath {
    param([string]$Requested)
    if (-not [string]::IsNullOrWhiteSpace($Requested)) { return [IO.Path]::GetFullPath($Requested) }
    $desktop = [Environment]::GetFolderPath('Desktop')
    if ([string]::IsNullOrWhiteSpace($desktop)) { throw 'Fant ikke skrivebordsmappen.' }
    return [IO.Path]::GetFullPath($desktop)
}

function Get-RahInstaller {
    param([string]$LocalSourceDirectory,[string]$BootstrapRoot)
    New-Item -ItemType Directory -Path $BootstrapRoot -Force | Out-Null
    $target = Join-Path $BootstrapRoot $script:RahInstallerName
    if (-not [string]::IsNullOrWhiteSpace($LocalSourceDirectory)) {
        $sourceRoot = [IO.Path]::GetFullPath($LocalSourceDirectory)
        $source = Join-Path $sourceRoot $script:RahInstallerName
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw 'SourceDirectory mangler RAH-HOME-INSTALL.ps1.' }
        Copy-Item -LiteralPath $source -Destination $target -Force
    }
    else {
        Invoke-WebRequest -UseBasicParsing -Uri $script:RahInstallerUrl -OutFile $target -ErrorAction Stop
    }
    return Assert-RahInstaller -Path $target
}

function Invoke-RahChildPowerShell {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $exe = Join-Path $PSHOME 'powershell.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw "Fant ikke Windows PowerShell: $exe" }
    & $exe @Arguments
    $code = $LASTEXITCODE
    if ($code -ne 0) { throw "RAH child PowerShell feilet med exit code $code." }
}

function Test-RahInstallOutput {
    param([Parameter(Mandatory)][string]$Root,[Parameter(Mandatory)][string]$Desktop)
    $checks = @()

    foreach ($name in $script:RahExpectedComponents) {
        $path = Join-Path $Root $name
        $ok = Test-Path -LiteralPath $path -PathType Leaf
        if ($ok) {
            try { Assert-RahPowerShellFile -Path $path | Out-Null } catch { $ok = $false }
        }
        $checks += [pscustomobject]@{ name="component:$name"; ok=[bool]$ok; path=$path }
    }

    $installerCopy = Join-Path $Root $script:RahInstallerName
    $installerOk = Test-Path -LiteralPath $installerCopy -PathType Leaf
    if ($installerOk) {
        try { Assert-RahInstaller -Path $installerCopy | Out-Null } catch { $installerOk = $false }
    }
    $checks += [pscustomobject]@{ name='installer-retained'; ok=[bool]$installerOk; path=$installerCopy }

    $statePath = Join-Path $Root 'rah-home-install-state.json'
    $stateOk = $false
    if (Test-Path -LiteralPath $statePath -PathType Leaf) {
        try {
            $state = Get-Content -Raw -LiteralPath $statePath | ConvertFrom-Json
            $stateOk = ($state.schema -eq 'rah-home-install-state' -and [int]$state.version -eq 1 -and $state.mode -eq 'Leader' -and [int]$state.port -eq 18766)
        }
        catch { $stateOk = $false }
    }
    $checks += [pscustomobject]@{ name='leader-install-state'; ok=[bool]$stateOk; path=$statePath }

    foreach ($name in $script:RahExpectedLeaderShortcuts) {
        $path = Join-Path $Desktop $name
        $ok = Test-Path -LiteralPath $path -PathType Leaf
        $checks += [pscustomobject]@{ name="shortcut:$name"; ok=[bool]$ok; path=$path }
    }

    return $checks
}

function Write-RahAcceptanceReport {
    param(
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][bool]$Pass,
        [Parameter(Mandatory)]$Checks,
        [string]$FailureMessage = ''
    )
    $reportRoot = Join-Path $Root 'reports'
    New-Item -ItemType Directory -Path $reportRoot -Force | Out-Null
    $created = (Get-Date).ToUniversalTime().ToString('o')
    $reportChecks = @($Checks | ForEach-Object { $_ })
    $report = [pscustomobject]@{
        schema = 'rah-home-acceptance'
        version = 1
        acceptanceVersion = $script:RahHomeAcceptanceVersion
        createdAt = $created
        computerName = $env:COMPUTERNAME
        windowsVersion = [Environment]::OSVersion.VersionString
        powershellVersion = $PSVersionTable.PSVersion.ToString()
        administrator = [bool](Test-RahAdministrator)
        installRoot = $Root
        pass = [bool]$Pass
        failure = if ([string]::IsNullOrWhiteSpace($FailureMessage)) { $null } else { $FailureMessage }
        checks = $reportChecks
    }
    $jsonPath = Join-Path $reportRoot 'rah-home-acceptance-latest.json'
    $txtPath = Join-Path $Root 'RAH-HOME-ACCEPTANCE.txt'
    [IO.File]::WriteAllText($jsonPath,($report | ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))

    $lines = @()
    $lines += 'RAH HOME ACCEPTANCE'
    $lines += '==================='
    $lines += "Computer : $($report.computerName)"
    $lines += "Result   : $(if($Pass){'PASS'}else{'FAIL'})"
    $lines += "Root     : $Root"
    $lines += "Created  : $created"
    if (-not [string]::IsNullOrWhiteSpace($FailureMessage)) { $lines += "Failure  : $FailureMessage" }
    $lines += ''
    foreach ($check in $reportChecks) { $lines += ("[{0}] {1}" -f $(if($check.ok){'OK'}else{'FAIL'}),$check.name) }
    [IO.File]::WriteAllLines($txtPath,[string[]]$lines,(New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{ json=$jsonPath; text=$txtPath }
}

function Invoke-RahAcceptanceSelfTest {
    if ($script:RahHomeAcceptanceVersion -ne '1.0.0') { throw 'SelfTest: feil acceptance-versjon.' }
    if ($script:RahInstallerUrl -notmatch '^https://raw\.githubusercontent\.com/NilsRa73/rah-platform/main/RAH-HOME-INSTALL\.ps1$') { throw 'SelfTest: uventet installer-URL.' }
    if ($script:RahExpectedComponents.Count -ne 7) { throw 'SelfTest: forventet syv stable Home-komponenter.' }
    if ($script:RahExpectedLeaderShortcuts.Count -ne 4) { throw 'SelfTest: forventet fire Leader-shortcuts.' }
    if ($script:RahExpectedComponents -contains 'cmd.exe') { throw 'SelfTest: ugyldig komponentliste.' }
    Write-Host 'PASS: RAH Home Acceptance v1 self-test' -ForegroundColor Green
}

if ($SelfTest) {
    Invoke-RahAcceptanceSelfTest
    exit 0
}

$root = [IO.Path]::GetFullPath($InstallRoot)
$desktop = Resolve-RahDesktopPath -Requested $DesktopPath
$bootstrapRoot = Join-Path $root 'bootstrap'
$checks = @()

Write-Host '=====================================================================' -ForegroundColor Yellow
Write-Host '                 RAH HOME - HOVED-PC ACCEPTANCE' -ForegroundColor Yellow
Write-Host '=====================================================================' -ForegroundColor Yellow
Write-Host "Målmappe : $root"
Write-Host "Skrivebord: $desktop"
Write-Host ''

try {
    New-Item -ItemType Directory -Path $root -Force | Out-Null
    New-Item -ItemType Directory -Path $desktop -Force | Out-Null

    Write-Host '[1/4] Henter og validerer Unified Installer v1 ...' -ForegroundColor Cyan
    $installer = Get-RahInstaller -LocalSourceDirectory $SourceDirectory -BootstrapRoot $bootstrapRoot
    Write-Host '      OK' -ForegroundColor Green

    Write-Host '[2/4] Kjører installer self-test ...' -ForegroundColor Cyan
    Invoke-RahChildPowerShell -Arguments @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$installer,'-SelfTest')
    Write-Host '      OK' -ForegroundColor Green

    Write-Host '[3/4] Installerer/verifiserer Leader i C:\RAH\Home ...' -ForegroundColor Cyan
    $args = @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$installer,'-Mode','Leader','-Port','18766','-InstallRoot',$root,'-DesktopPath',$desktop)
    if (-not [string]::IsNullOrWhiteSpace($SourceDirectory)) { $args += @('-SourceDirectory',[IO.Path]::GetFullPath($SourceDirectory)) }
    Invoke-RahChildPowerShell -Arguments $args
    Write-Host '      OK' -ForegroundColor Green

    Write-Host '[4/4] Kontrollerer komponenter, state og shortcuts ...' -ForegroundColor Cyan
    $checks = @(Test-RahInstallOutput -Root $root -Desktop $desktop)
    $failed = @($checks | Where-Object { -not $_.ok })
    if ($failed.Count -ne 0) { throw ("Acceptance fant {0} feil." -f $failed.Count) }

    $paths = Write-RahAcceptanceReport -Root $root -Pass $true -Checks $checks
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Green
    Write-Host '                    RAH HOME ACCEPTANCE: PASS' -ForegroundColor Green
    Write-Host '=====================================================================' -ForegroundColor Green
    Write-Host "Rapport: $($paths.text)"
    Write-Host "JSON   : $($paths.json)"
    Write-Host 'Skrivebordet skal nå ha RAH Home Nexus, Pair Worker, Cluster Plan og LAN-test.'
    exit 0
}
catch {
    $message = $_.Exception.Message
    try { $paths = Write-RahAcceptanceReport -Root $root -Pass $false -Checks $checks -FailureMessage $message } catch { $paths = $null }
    Write-Host ''
    Write-Host '=====================================================================' -ForegroundColor Red
    Write-Host '                    RAH HOME ACCEPTANCE: FAIL' -ForegroundColor Red
    Write-Host '=====================================================================' -ForegroundColor Red
    Write-Host $message -ForegroundColor Red
    if ($paths) { Write-Host "Rapport: $($paths.text)" }
    exit 1
}
