param(
    [string]$InstallRoot = 'C:\RAH\Home',
    [switch]$PersistUserSetting,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahPythonConsoleGuardVersion = '1.0.0'
$script:RahKnownIssueSignature = '_pyrepl Windows console WinError 123'

function Test-RahNeedsBasicRepl {
    param([Parameter(Mandatory)][version]$Version)
    return ($Version -ge [version]'3.13.0')
}

function Get-RahPythonExecutable {
    foreach ($name in @('python.exe','python')) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd -and $cmd.Source) { return [string]$cmd.Source }
    }
    return ''
}

function Invoke-RahPythonProbe {
    param([Parameter(Mandatory)][string]$Executable)
    $env:PYTHON_BASIC_REPL = '1'
    $oldPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $raw = & $Executable -c "import sys;print(sys.executable);print('.'.join(map(str,sys.version_info[:3])));print('RAH_PYTHON_NONINTERACTIVE_OK')" 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
    $lines = @(($raw | Out-String) -split "`r?`n" | Where-Object { $_ -and $_.Trim() })
    $versionText = ''
    foreach ($line in $lines) {
        if ($line.Trim() -match '^\d+\.\d+\.\d+$') { $versionText = $line.Trim(); break }
    }
    $version = $null
    if ($versionText) {
        try { $version = [version]$versionText } catch { $version = $null }
    }
    return [pscustomobject]@{
        ExitCode = [int]$code
        VersionText = $versionText
        Version = $version
        Output = (($lines -join ' | ').Trim())
    }
}

function Write-RahPythonGuardReport {
    param(
        [Parameter(Mandatory)][string]$Root,
        [string]$Executable,
        [string]$VersionText,
        [bool]$NeedsGuard,
        [bool]$ProbeOk,
        [bool]$Persisted,
        [string]$Status,
        [string]$Detail
    )
    $reportDir = Join-Path $Root 'reports'
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    $jsonPath = Join-Path $reportDir 'rah-python-console-guard.json'
    $textPath = Join-Path $Root 'RAH-PYTHON-CONSOLE-GUARD.txt'
    $doc = [pscustomobject]@{
        schema = 'rah-python-console-guard'
        version = 1
        guardVersion = $script:RahPythonConsoleGuardVersion
        knownIssue = $script:RahKnownIssueSignature
        createdAt = (Get-Date).ToUniversalTime().ToString('o')
        pythonDetected = [bool]$Executable
        pythonExecutable = $(if($Executable){$Executable}else{$null})
        pythonVersion = $(if($VersionText){$VersionText}else{$null})
        basicReplRequired = $NeedsGuard
        processSetting = $env:PYTHON_BASIC_REPL
        userSetting = [Environment]::GetEnvironmentVariable('PYTHON_BASIC_REPL','User')
        persisted = $Persisted
        probeOk = $ProbeOk
        status = $Status
        detail = $(if($Detail){$Detail}else{$null})
    }
    [IO.File]::WriteAllText($jsonPath,($doc | ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
    $text = @(
        'RAH PYTHON CONSOLE GUARD',
        '========================',
        "Status       : $Status",
        "Python       : $(if($Executable){$Executable}else{'not found'})",
        "Version      : $(if($VersionText){$VersionText}else{'-'})",
        "Basic REPL   : $($env:PYTHON_BASIC_REPL)",
        "Persisted    : $Persisted",
        "Probe OK     : $ProbeOk",
        "Known issue  : $script:RahKnownIssueSignature"
    )
    if ($Detail) { $text += "Detail       : $Detail" }
    [IO.File]::WriteAllLines($textPath,$text,(New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{Json=$jsonPath;Text=$textPath}
}

function Invoke-RahPythonGuardSelfTest {
    if (-not (Test-RahNeedsBasicRepl ([version]'3.13.0'))) { throw 'SelfTest: Python 3.13 must require basic REPL.' }
    if (-not (Test-RahNeedsBasicRepl ([version]'3.14.1'))) { throw 'SelfTest: Python 3.14 must require basic REPL.' }
    if (Test-RahNeedsBasicRepl ([version]'3.12.9')) { throw 'SelfTest: Python 3.12 must not require basic REPL.' }
    if ($script:RahKnownIssueSignature -notmatch '_pyrepl') { throw 'SelfTest: known issue marker missing.' }
    Write-Host 'PASS: RAH Python Console Guard v1 self-test' -ForegroundColor Green
}

if ($SelfTest) { Invoke-RahPythonGuardSelfTest; exit 0 }

$env:PYTHON_BASIC_REPL = '1'
$root = [IO.Path]::GetFullPath($InstallRoot)
$exe = Get-RahPythonExecutable
$versionText = ''
$needsGuard = $false
$probeOk = $true
$persisted = $false
$status = 'python-not-found'
$detail = ''

if ($exe) {
    $probe = Invoke-RahPythonProbe -Executable $exe
    $versionText = [string]$probe.VersionText
    $probeOk = ($probe.ExitCode -eq 0 -and $probe.Output -match 'RAH_PYTHON_NONINTERACTIVE_OK')
    if ($probe.Version) { $needsGuard = Test-RahNeedsBasicRepl -Version $probe.Version }
    if ($needsGuard -and $PersistUserSetting) {
        [Environment]::SetEnvironmentVariable('PYTHON_BASIC_REPL','1','User')
        $persisted = ([Environment]::GetEnvironmentVariable('PYTHON_BASIC_REPL','User') -eq '1')
        if (-not $persisted) { throw 'Kunne ikke verifisere PYTHON_BASIC_REPL=1 for current user.' }
    }
    if ($probeOk -and $needsGuard) { $status = $(if($persisted){'repaired-and-verified'}else{'guard-active-for-process'}) }
    elseif ($probeOk) { $status = 'python-ok-guard-not-required' }
    else { $status = 'warning-python-probe-failed'; $detail = $probe.Output }
}

$paths = Write-RahPythonGuardReport -Root $root -Executable $exe -VersionText $versionText -NeedsGuard $needsGuard -ProbeOk $probeOk -Persisted $persisted -Status $status -Detail $detail
if ($status -eq 'warning-python-probe-failed') {
    Write-Host "[RAH] Python console guard WARNING: $detail" -ForegroundColor Yellow
} else {
    Write-Host "[RAH] Python console guard: $status" -ForegroundColor Green
}
Write-Host "[RAH] Python guard report: $($paths.Text)"
exit 0
