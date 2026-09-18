[CmdletBinding()]
param(
    [switch]$NoLaunch,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$Version='1.0.0'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoApp=Join-Path $Root 'apps\rah-ai-investigator'
$RepoSource=Join-Path $RepoApp 'source'
$RepoManifest=Join-Path $RepoApp 'RAH-INVESTIGATOR-VERSION.json'

# Allow the same finalizer to work from a packaged flat Stable bundle.
if(-not(Test-Path -LiteralPath $RepoSource -PathType Container)){
    $RepoSource=$Root
}
if(-not(Test-Path -LiteralPath $RepoManifest -PathType Leaf)){
    $RepoManifest=Join-Path $Root 'RAH-INVESTIGATOR-VERSION.json'
}

$InstallRoot='C:\RAH\Investigator'
$LogRoot='C:\RAH\Logs'
$ReportPath=Join-Path $LogRoot 'RAH-AI-INVESTIGATOR-FINAL-LATEST.json'
$Checks=[System.Collections.Generic.List[object]]::new()
$RuntimeFiles=@(
    'RAH-AI-INVESTIGATOR.html',
    'rah_investigator.py',
    'CHECK-RAH-INVESTIGATOR.ps1',
    'CHECK-RAH-INVESTIGATOR-KALI.sh',
    'RUN-ME-FIRST-RAH-INVESTIGATOR.bat',
    'IMPORT-ARCHIVE-TO-RAH-INVESTIGATOR-v1.0.ps1'
)

function Test-Admin {
    $id=[Security.Principal.WindowsIdentity]::GetCurrent()
    $p=[Security.Principal.WindowsPrincipal]::new($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-Check([string]$Name,[bool]$Ok,[string]$Detail){
    $Checks.Add([pscustomobject]@{name=$Name;ok=$Ok;detail=$Detail})
    $tag=if($Ok){'PASS'}else{'FAIL'}
    Write-Host ("[{0}] {1} - {2}" -f $tag,$Name,$Detail)
    if(-not $Ok){throw ($Name+': '+$Detail)}
}

function Find-Python {
    foreach($name in @('py.exe','python.exe')){
        $cmd=Get-Command $name -ErrorAction SilentlyContinue
        if($cmd){return $cmd.Source}
    }
    return $null
}

function Save-Report([string]$Result,[string]$ErrorText,[string]$Python=''){
    New-Item -ItemType Directory -Force -Path $LogRoot|Out-Null
    [pscustomobject]@{
        schema='rah-ai-investigator-final-v1'
        product='RAH AI Investigator'
        version=$Version
        generatedAt=(Get-Date).ToString('o')
        computer=$env:COMPUTERNAME
        result=$Result
        error=$ErrorText
        installRoot=$InstallRoot
        python=$Python
        checks=@($Checks)
    }|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

function Test-SourceContract {
    Add-Check 'Manifest present' (Test-Path -LiteralPath $RepoManifest -PathType Leaf) $RepoManifest
    $m=Get-Content -LiteralPath $RepoManifest -Raw -Encoding UTF8|ConvertFrom-Json
    Add-Check 'Stable version' ([string]$m.version -eq '1.0.0' -and [string]$m.stage -eq 'stable') "$($m.version) / $($m.stage)"
    Add-Check 'Local first' ($m.local_first -eq $true) ([string]$m.local_first)
    Add-Check 'No core network' ($m.network_requests_in_core -eq $false) ([string]$m.network_requests_in_core)
    Add-Check 'No external-tool auto execution' ($m.external_tool_auto_execution -eq $false) ([string]$m.external_tool_auto_execution)
    Add-Check 'Authority delta none' ([string]$m.authority_delta -eq 'none') ([string]$m.authority_delta)
    Add-Check 'Command Center pin' ([string]$m.stable_command_center_reference -eq '2.4.0' -and [int]$m.stable_command_center_package_generation_reference -eq 9) "$($m.stable_command_center_reference) / gen $($m.stable_command_center_package_generation_reference)"
    Add-Check 'Node Agent pin' ([string]$m.stable_node_agent_reference -eq '1.4.0') ([string]$m.stable_node_agent_reference)

    foreach($name in $RuntimeFiles){
        Add-Check "Source $name" (Test-Path -LiteralPath (Join-Path $RepoSource $name) -PathType Leaf) (Join-Path $RepoSource $name)
    }

    $pySource=Get-Content -LiteralPath (Join-Path $RepoSource 'rah_investigator.py') -Raw -Encoding UTF8
    foreach($forbidden in @('import requests','from requests','urllib.request','http.client','import socket','from socket','import subprocess','from subprocess','os.system','os.popen')){
        Add-Check "Forbidden primitive absent: $forbidden" (-not $pySource.ToLowerInvariant().Contains($forbidden)) 'absent'
    }
}

function Invoke-SelfTest {
    Test-SourceContract
    $python=Find-Python
    Add-Check 'Python 3' (-not [string]::IsNullOrWhiteSpace($python)) ([string]$python)
    & $python (Join-Path $RepoSource 'rah_investigator.py') self-test
    Add-Check 'Python deterministic self-test' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"
    Write-Host 'RAH AI INVESTIGATOR 1.0 FINALIZER SELF-TEST: PASS'
}

if($SelfTest){
    Invoke-SelfTest
    exit 0
}

if(-not(Test-Admin)){
    Write-Host '[UAC] RAH AI Investigator trenger Administrator for C:\RAH installasjon.'
    $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $MyInvocation.MyCommand.Path))
    if($NoLaunch){$args+='-NoLaunch'}
    try{
        $child=Start-Process powershell.exe -ArgumentList $args -Verb RunAs -Wait -PassThru
        exit $child.ExitCode
    }catch{
        Write-Host "[FAIL] UAC feilet: $($_.Exception.Message)"
        exit 5
    }
}

$Final='FAIL'
$Err=$null
$Python=''
try{
    Write-Host '===================================================================='
    Write-Host ' RAH AI INVESTIGATOR 1.0 - FINAL / STABLE'
    Write-Host ' CONTRACT -> INSTALL -> SELFTEST -> NORMALIZE -> SHORTCUT -> START'
    Write-Host '===================================================================='

    Test-SourceContract
    $Python=Find-Python
    Add-Check 'Python 3' (-not [string]::IsNullOrWhiteSpace($Python)) ([string]$Python)

    New-Item -ItemType Directory -Force -Path $InstallRoot,$LogRoot|Out-Null
    foreach($name in $RuntimeFiles){
        Copy-Item -LiteralPath (Join-Path $RepoSource $name) -Destination (Join-Path $InstallRoot $name) -Force
    }
    Copy-Item -LiteralPath $RepoManifest -Destination (Join-Path $InstallRoot 'RAH-INVESTIGATOR-VERSION.json') -Force
    Add-Check 'Installed manifest' (Test-Path -LiteralPath (Join-Path $InstallRoot 'RAH-INVESTIGATOR-VERSION.json') -PathType Leaf) $InstallRoot

    & $Python -m py_compile (Join-Path $InstallRoot 'rah_investigator.py')
    Add-Check 'Python syntax' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"
    & $Python (Join-Path $InstallRoot 'rah_investigator.py') self-test
    Add-Check 'Deterministic self-test' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File (Join-Path $InstallRoot 'CHECK-RAH-INVESTIGATOR.ps1')
    Add-Check 'Installed Windows checker' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

    $sample=Join-Path $InstallRoot 'SELFTEST-SAMPLE.txt'
    $case=Join-Path $InstallRoot 'SELFTEST-CASE.json'
    @'
Account: https://example.com/Stable.User
Mail: stable.user@example.com
Phone: +47 900 00 000
Seen 2026-09-18
'@|Set-Content -LiteralPath $sample -Encoding UTF8
    & $Python (Join-Path $InstallRoot 'rah_investigator.py') normalize $sample --out $case
    Add-Check 'Normalize smoke' ($LASTEXITCODE -eq 0 -and (Test-Path -LiteralPath $case -PathType Leaf)) $case
    $result=Get-Content -LiteralPath $case -Raw -Encoding UTF8|ConvertFrom-Json
    Add-Check 'Stable case version' ([string]$result.version -eq '1.0.0') ([string]$result.version)
    Add-Check 'Local-only marker' ($result.normalizer.localOnly -eq $true -and $result.normalizer.networkRequests -eq $false -and $result.normalizer.externalToolExecution -eq $false -and $result.normalizer.sourceMutation -eq $false) 'local-only / no-network / no-auto-tool / no-source-mutation'
    Remove-Item -LiteralPath $sample,$case -Force -ErrorAction SilentlyContinue

    $desktop=[Environment]::GetFolderPath('Desktop')
    $link=Join-Path $desktop 'RAH AI Investigator.lnk'
    $target=Join-Path $InstallRoot 'RUN-ME-FIRST-RAH-INVESTIGATOR.bat'
    $w=New-Object -ComObject WScript.Shell
    $s=$w.CreateShortcut($link)
    $s.TargetPath=$target
    $s.WorkingDirectory=$InstallRoot
    $s.Description='RAH AI Investigator v1.0 Stable'
    $s.Save()
    Add-Check 'Desktop shortcut' (Test-Path -LiteralPath $link -PathType Leaf) $link

    if(-not $NoLaunch){
        Start-Process -FilePath (Join-Path $InstallRoot 'RAH-AI-INVESTIGATOR.html')
        Add-Check 'Investigator launch requested' $true 'HTML'
    }

    $Final='PASS'
    Write-Host ''
    Write-Host '===================================================================='
    Write-Host ' RAH AI INVESTIGATOR 1.0 FINAL/STABLE: PASS'
    Write-Host " Runtime: $InstallRoot"
    Write-Host ' Scope: explicit local inputs; no core network; no automatic OSINT tools.'
    Write-Host '===================================================================='
}catch{
    $Err=$_.Exception.Message
    Write-Host ''
    Write-Host '===================================================================='
    Write-Host ' RAH AI INVESTIGATOR 1.0 FINAL/STABLE: FAIL'
    Write-Host " $Err"
    Write-Host '===================================================================='
}finally{
    Save-Report $Final $Err $Python
}
if($Final -eq 'PASS'){exit 0}
exit 1
