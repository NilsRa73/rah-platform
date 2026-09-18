[CmdletBinding()]
param(
    [switch]$NoLaunch,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$Version = '1.3.0'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$BrowserRoot = 'C:\RAH\Browser'
$ExtensionRoot = Join-Path $BrowserRoot 'Extension'
$ProfileRoot = Join-Path $BrowserRoot 'Profile'
$LogRoot = 'C:\RAH\Logs'
$ReportPath = Join-Path $LogRoot 'RAVEN-BROWSER-FINAL-LATEST.json'
$AgentRoot = Join-Path $env:LOCALAPPDATA 'RAH\LocalAgent'
$TokenFile = Join-Path $AgentRoot 'token.txt'
$AgentHealth = 'http://127.0.0.1:18779/health'
$AgentInstaller = Join-Path $Root 'INSTALL-RAH-LOCAL-AGENT.ps1'
$ExtensionFiles = @('manifest.json','config.js','background.js','content.js','popup.html','popup.js','README.txt')
$Checks = [System.Collections.Generic.List[object]]::new()

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = [Security.Principal.WindowsPrincipal]::new($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-Check([string]$Name,[bool]$Ok,[string]$Detail) {
    $Checks.Add([pscustomobject]@{name=$Name;ok=$Ok;detail=$Detail})
    $tag = if($Ok){'PASS'}else{'FAIL'}
    Write-Host "[$tag] $Name - $Detail"
    if(-not $Ok){ throw "$($Name): $Detail" }
}

function Save-Report([string]$Result,[string]$ErrorText,[string]$BrowserExe='') {
    New-Item -ItemType Directory -Force -Path $LogRoot | Out-Null
    [pscustomobject]@{
        schema='rah-raven-browser-final-v1'
        product='RAH Raven Browser'
        version=$Version
        generatedAt=(Get-Date).ToString('o')
        computer=$env:COMPUTERNAME
        result=$Result
        error=$ErrorText
        browserExe=$BrowserExe
        browserRoot=$BrowserRoot
        extensionRoot=$ExtensionRoot
        profileRoot=$ProfileRoot
        agentHealth=$AgentHealth
        checks=@($Checks)
    } | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

function Get-BrowserExecutable {
    $pf=[Environment]::GetFolderPath('ProgramFiles')
    $pfx86=[Environment]::GetFolderPath('ProgramFilesX86')
    $local=$env:LOCALAPPDATA
    $candidates=@(
        (Join-Path $pf 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $pfx86 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $local 'Google\Chrome\Application\chrome.exe'),
        (Join-Path $pf 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $pfx86 'Microsoft\Edge\Application\msedge.exe'),
        (Join-Path $pf 'BraveSoftware\Brave-Browser\Application\brave.exe'),
        (Join-Path $local 'BraveSoftware\Brave-Browser\Application\brave.exe')
    )
    foreach($candidate in $candidates){
        if($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)){ return $candidate }
    }
    return $null
}

function Test-Agent {
    try {
        $h=Invoke-RestMethod -Method Get -Uri $AgentHealth -TimeoutSec 4
        return ($h.ok -eq $true)
    } catch { return $false }
}

function Repair-Agent {
    if((Test-Agent) -and (Test-Path -LiteralPath $TokenFile -PathType Leaf)){ return }
    if(-not (Test-Path -LiteralPath $AgentInstaller -PathType Leaf)){
        throw "Local Agent installer mangler: $AgentInstaller"
    }
    Write-Host '[REPAIR] Installerer/reparerer RAH Local Agent...'
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $AgentInstaller
    if($LASTEXITCODE -ne 0){ throw "Local Agent installer exit=$LASTEXITCODE" }
    for($i=0;$i -lt 20;$i++){
        Start-Sleep -Milliseconds 500
        if((Test-Agent) -and (Test-Path -LiteralPath $TokenFile -PathType Leaf)){ return }
    }
    throw 'RAH Local Agent ble ikke frisk etter repair.'
}

function Copy-Extension {
    New-Item -ItemType Directory -Force -Path $ExtensionRoot | Out-Null
    $source=Join-Path $Root 'browser-bridge-v1'
    Add-Check 'Extension source' (Test-Path -LiteralPath $source -PathType Container) $source
    foreach($name in $ExtensionFiles){
        $src=Join-Path $source $name
        Add-Check "Source $name" (Test-Path -LiteralPath $src -PathType Leaf) $src
        Copy-Item -LiteralPath $src -Destination (Join-Path $ExtensionRoot $name) -Force
    }
    $token=(Get-Content -LiteralPath $TokenFile -Raw).Trim()
    Add-Check 'Agent token format' ($token.Length -ge 32) 'lokalt token finnes'
    $cfg=Join-Path $ExtensionRoot 'config.js'
    $text=Get-Content -LiteralPath $cfg -Raw
    $text=$text.Replace('__RAH_TOKEN__',$token)
    Set-Content -LiteralPath $cfg -Value $text -Encoding UTF8
}

function Validate-Extension {
    $manifestPath=Join-Path $ExtensionRoot 'manifest.json'
    $manifest=Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    Add-Check 'Extension version' ([string]$manifest.version -eq $Version) ([string]$manifest.version)
    $hosts=@($manifest.host_permissions)
    Add-Check 'Loopback agent permission' ($hosts -contains 'http://127.0.0.1:18779/*') '127.0.0.1:18779'
    Add-Check 'ChatGPT permission' (($hosts -contains 'https://chatgpt.com/*') -and ($hosts -contains 'https://chat.openai.com/*')) 'ChatGPT only + loopback'
    Add-Check 'No wildcard hosts' (@($hosts | Where-Object { $_ -match '^\*|<all_urls>' }).Count -eq 0) 'ingen wildcard host permissions'

    $content=Get-Content -LiteralPath (Join-Path $ExtensionRoot 'content.js') -Raw
    $autoStart=$content.IndexOf('const AUTO_TOOLS=new Set([')
    $autoEnd=$content.IndexOf(']);',$autoStart)
    if($autoStart -lt 0 -or $autoEnd -lt 0){ throw 'AUTO_TOOLS block mangler.' }
    $auto=$content.Substring($autoStart,$autoEnd-$autoStart)
    foreach($forbidden in @('fs.write_text','fs.write_bytes','fs.mkdir','fs.copy','fs.move','fs.delete','process.start','process.stop','service.start','service.stop','shell.powershell','shell.exec')){
        if($auto.Contains("'$forbidden'")){ throw "Mutating tool er feilaktig AUTO: $forbidden" }
    }
    Add-Check 'Read-only automatic tools' $true 'alle endringer krever eksplisitt browser-godkjenning'
    Add-Check 'Explicit mutation approval' ($content.Contains('if(!AUTO_TOOLS.has(tool))') -and $content.Contains('confirm(')) 'confirm gate'
}

function Invoke-SelfTest {
    $source=Join-Path $Root 'browser-bridge-v1'
    foreach($name in $ExtensionFiles){
        if(-not (Test-Path -LiteralPath (Join-Path $source $name) -PathType Leaf)){ throw "SelfTest mangler $name" }
    }
    $m=Get-Content -LiteralPath (Join-Path $source 'manifest.json') -Raw | ConvertFrom-Json
    if([string]$m.version -ne $Version){ throw 'SelfTest version mismatch' }
    $c=Get-Content -LiteralPath (Join-Path $source 'content.js') -Raw
    $s=$c.IndexOf('const AUTO_TOOLS=new Set([');$e=$c.IndexOf(']);',$s)
    if($s -lt 0 -or $e -lt 0){ throw 'SelfTest AUTO_TOOLS missing' }
    $a=$c.Substring($s,$e-$s)
    foreach($x in @('fs.write_text','fs.write_bytes','fs.mkdir','fs.copy','fs.move','fs.delete','process.start','service.start','shell.exec')){
        if($a.Contains("'$x'")){ throw "SelfTest unsafe AUTO tool: $x" }
    }
    Write-Host 'PASS: RAH Raven Browser v1.3 finalizer self-test'
}

if($SelfTest){ Invoke-SelfTest; exit 0 }

if(-not (Test-IsAdmin)){
    Write-Host '[UAC] RAH Raven Browser trenger Administrator for C:\RAH og Local Agent repair.'
    $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $MyInvocation.MyCommand.Path))
    if($NoLaunch){$args+='-NoLaunch'}
    try{
        $child=Start-Process -FilePath 'powershell.exe' -ArgumentList $args -Verb RunAs -Wait -PassThru
        exit $child.ExitCode
    }catch{
        Write-Host "[FAIL] UAC feilet: $($_.Exception.Message)"
        exit 5
    }
}

$Final='FAIL'
$ErrorText=$null
$BrowserExe=''
try {
    Write-Host '===================================================================='
    Write-Host ' RAH RAVEN BROWSER v1.3 - FINAL / STABLE'
    Write-Host ' PRECHECK -> REPAIR -> INSTALL -> SAFETY -> START'
    Write-Host '===================================================================='

    New-Item -ItemType Directory -Force -Path $BrowserRoot,$ProfileRoot,$LogRoot | Out-Null
    Repair-Agent
    Add-Check 'Local Agent health' (Test-Agent) $AgentHealth
    Add-Check 'Local Agent token' (Test-Path -LiteralPath $TokenFile -PathType Leaf) $TokenFile

    Copy-Extension
    Validate-Extension

    $BrowserExe=Get-BrowserExecutable
    Add-Check 'Chromium browser' (-not [string]::IsNullOrWhiteSpace($BrowserExe)) $BrowserExe

    $runCmd=Join-Path $BrowserRoot 'START-RAH-RAVEN-BROWSER.cmd'
    $cmd=@"
@echo off
setlocal
start "" "$BrowserExe" --user-data-dir="$ProfileRoot" --disable-extensions-except="$ExtensionRoot" --load-extension="$ExtensionRoot" --no-first-run "https://chatgpt.com/"
"@
    [IO.File]::WriteAllText($runCmd,$cmd,[Text.Encoding]::ASCII)
    Add-Check 'Installed launcher' (Test-Path -LiteralPath $runCmd -PathType Leaf) $runCmd

    $desktop=[Environment]::GetFolderPath('Desktop')
    $lnk=Join-Path $desktop 'RAH Raven Browser.lnk'
    $w=New-Object -ComObject WScript.Shell
    $s=$w.CreateShortcut($lnk)
    $s.TargetPath=$runCmd
    $s.WorkingDirectory=$BrowserRoot
    $s.IconLocation="$BrowserExe,0"
    $s.Description='RAH Raven Browser v1.3 Stable'
    $s.Save()
    Add-Check 'Desktop shortcut' (Test-Path -LiteralPath $lnk -PathType Leaf) $lnk

    if(-not $NoLaunch){
        Start-Process -FilePath $runCmd -WorkingDirectory $BrowserRoot
        Start-Sleep -Seconds 2
        $procName=[IO.Path]::GetFileNameWithoutExtension($BrowserExe)
        $running=@(Get-Process -Name $procName -ErrorAction SilentlyContinue).Count -gt 0
        Add-Check 'Browser process started' $running $procName
    }

    $Final='PASS'
    Write-Host ''
    Write-Host '===================================================================='
    Write-Host ' RAH RAVEN BROWSER v1.3 FINAL/STABLE: PASS'
    Write-Host " Runtime : $BrowserRoot"
    Write-Host " Agent   : $AgentHealth"
    Write-Host ' Safety  : read-only AUTO; local changes require explicit approval.'
    Write-Host '===================================================================='
}
catch {
    $ErrorText=$_.Exception.Message
    Write-Host ''
    Write-Host '===================================================================='
    Write-Host ' RAH RAVEN BROWSER v1.3 FINAL/STABLE: FAIL'
    Write-Host " $ErrorText"
    Write-Host '===================================================================='
}
finally {
    Save-Report -Result $Final -ErrorText $ErrorText -BrowserExe $BrowserExe
}

if($Final -eq 'PASS'){ exit 0 }
exit 1
