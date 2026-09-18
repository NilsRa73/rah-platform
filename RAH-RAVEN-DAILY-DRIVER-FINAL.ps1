[CmdletBinding()]
param(
  [switch]$NoLaunch,
  [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$App=Join-Path $Root 'apps\rah-raven-daily-driver'
$Manifest=Join-Path $Root 'RAH-RAVEN-DAILY-DRIVER-VERSION.json'
$Package=Join-Path $Root 'RAH-RAVEN-DAILY-DRIVER-PACKAGE.json'
$CcManifest=Join-Path $Root 'RAH-COMMAND-CENTER-VERSION.json'
$Installer=Join-Path $Root 'INSTALL-RAH-RAVEN.bat'
$RuntimeCheck=Join-Path $App 'runtime_check.py'
$AppStart=Join-Path $App 'START-RAH-RAVEN.bat'
$RuntimeRoot='C:\RAH\DailyDriver\runtime'
$LogRoot='C:\RAH\Logs'
$Report=Join-Path $LogRoot 'RAVEN-DAILY-DRIVER-FINAL-LATEST.json'
$Checks=[System.Collections.Generic.List[object]]::new()

function Test-Admin {
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p=[Security.Principal.WindowsPrincipal]::new($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Add-Check([string]$Name,[bool]$Ok,[string]$Detail){
  $Checks.Add([pscustomobject]@{name=$Name;ok=$Ok;detail=$Detail})
  Write-Host ("[{0}] {1} - {2}" -f $(if($Ok){'PASS'}else{'FAIL'}),$Name,$Detail)
  if(-not $Ok){throw ($Name+': '+$Detail)}
}
function Read-Json([string]$Path,[string]$Label){
  Add-Check "$Label file" (Test-Path -LiteralPath $Path -PathType Leaf) $Path
  try{return Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop}
  catch{throw ($Label+' JSON invalid: '+$_.Exception.Message)}
}
function Save-Report([string]$Result,[string]$ErrorText){
  New-Item -ItemType Directory -Force -Path $LogRoot|Out-Null
  [pscustomobject]@{
    schema='rah-raven-daily-driver-final-v1'
    product='RAH Raven Daily Driver'
    version='1.0.0'
    generatedAt=(Get-Date).ToString('o')
    computer=$env:COMPUTERNAME
    result=$Result
    error=$ErrorText
    runtimeRoot=$RuntimeRoot
    checks=@($Checks)
  }|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $Report -Encoding UTF8
}
function Test-Contracts {
  $m=Read-Json $Manifest 'Daily Driver manifest'
  Add-Check 'Stable version' ([string]$m.version -eq '1.0.0' -and [string]$m.stage -eq 'stable') "$($m.version) / $($m.stage)"
  Add-Check 'Authority delta' ([string]$m.authority_delta -eq 'none') ([string]$m.authority_delta)
  Add-Check 'Stable gate passed' ([string]$m.stable_gate.status -eq 'passed') ([string]$m.stable_gate.status)
  Add-Check 'Live personal data optional' ($m.stable_gate.requires_real_facebook_archive -eq $false -and $m.stable_gate.requires_owned_tool_export_review -eq $false) 'release gate uses deterministic tests'

  $cc=Read-Json $CcManifest 'Command Center manifest'
  Add-Check 'Command Center 2.4 Stable' ([string]$cc.version -eq '2.4.0' -and [string]$cc.stage -eq 'stable') "$($cc.version) / $($cc.stage)"
  Add-Check 'Command Center generation 9' ([int]$cc.canonical_package_generation -eq 9) ([string]$cc.canonical_package_generation)

  $config=Read-Json (Join-Path $App 'config.json') 'Daily Driver config'
  Add-Check 'Runtime config Stable' ([string]$config.stage -eq 'Stable') ([string]$config.stage)
  foreach($name in @('Daily Driver Core','AI Router','Council Desktop','Investigator Desktop','Chronicle Desktop Store','Devices Desktop','Mission Desktop','Insights Desktop')){
    $node=$config.component_status.$name
    Add-Check "Component $name Stable" ($null -ne $node -and [string]$node.stage -eq 'Stable' -and $node.frozen -eq $true) ([string]$node.stage)
  }

  $source=Get-Content -LiteralPath (Join-Path $App 'command_center.py') -Raw
  Add-Check 'Canonical CC2.4 UI link' ($source.Contains('Stable CC 2.4') -and $source.Contains('RAH-COMMAND-CENTER-V2.4.html')) 'CC2.4'
  Add-Check 'C RAH runtime root' ($source.Contains('C:\\RAH\\DailyDriver\\runtime')) 'C:\RAH\DailyDriver\runtime'
}
function Invoke-SelfTest {
  Test-Contracts
  Add-Check 'Installer' (Test-Path -LiteralPath $Installer -PathType Leaf) $Installer
  Add-Check 'Runtime check' (Test-Path -LiteralPath $RuntimeCheck -PathType Leaf) $RuntimeCheck
  Add-Check 'App launcher' (Test-Path -LiteralPath $AppStart -PathType Leaf) $AppStart
  Write-Host 'RAH RAVEN DAILY DRIVER FINALIZER SELF-TEST: PASS'
}

if($SelfTest){Invoke-SelfTest;exit 0}

if(-not (Test-Admin)){
  Write-Host '[UAC] Daily Driver Stable finalizer trenger Administrator for C:\RAH.'
  $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $MyInvocation.MyCommand.Path))
  if($NoLaunch){$args+='-NoLaunch'}
  try{
    $p=Start-Process powershell.exe -ArgumentList $args -Verb RunAs -Wait -PassThru
    exit $p.ExitCode
  }catch{
    Write-Host "[FAIL] UAC: $($_.Exception.Message)"
    exit 5
  }
}

$Final='FAIL';$Err=$null
try{
  Write-Host '===================================================================='
  Write-Host ' RAH RAVEN DAILY DRIVER v1.0 - FINAL / STABLE'
  Write-Host ' CONTRACTS -> INSTALL/REPAIR -> TESTS -> RUNTIME GATE -> START'
  Write-Host '===================================================================='

  Test-Contracts
  New-Item -ItemType Directory -Force -Path $RuntimeRoot,$LogRoot|Out-Null

  $env:RAH_RAVEN_INSTALL_NO_START='1'
  & cmd.exe /d /c ('call "'+$Installer+'"')
  $installRc=$LASTEXITCODE
  $env:RAH_RAVEN_INSTALL_NO_START=$null
  Add-Check 'Install/repair' ($installRc -eq 0) "exit=$installRc"

  $Py=Join-Path $App '.venv\Scripts\python.exe'
  Add-Check 'Isolated Python' (Test-Path -LiteralPath $Py -PathType Leaf) $Py

  & $Py -m unittest discover -s (Join-Path $App 'tests') -p 'test_*.py' -v
  Add-Check 'Unit and smoke suite' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"

  $GateOut=Join-Path $RuntimeRoot 'state\runtime-gate.json'
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent $GateOut)|Out-Null
  $env:RAH_DAILY_DRIVER_RUNTIME=$RuntimeRoot
  & $Py $RuntimeCheck --output $GateOut
  $gateRc=$LASTEXITCODE
  Add-Check 'Deterministic runtime gate' ($gateRc -eq 0) "exit=$gateRc"
  $gate=Get-Content -LiteralPath $GateOut -Raw|ConvertFrom-Json
  Add-Check 'Runtime overall PASS' ([string]$gate.overall -eq 'PASS') ([string]$gate.overall)
  Add-Check 'Runtime recommends Stable' ([string]$gate.recommended_stage -eq 'Stable') ([string]$gate.recommended_stage)

  if(-not $NoLaunch){
    Start-Process -FilePath $AppStart -WorkingDirectory $App
    Add-Check 'Daily Driver launch requested' $true $AppStart
  }

  $Final='PASS'
  Write-Host ''
  Write-Host '===================================================================='
  Write-Host ' RAH RAVEN DAILY DRIVER v1.0 FINAL/STABLE: PASS'
  Write-Host " Runtime: $RuntimeRoot"
  Write-Host ' Live LM / private archive / owned-tool imports remain explicit optional tests.'
  Write-Host '===================================================================='
}catch{
  $Err=$_.Exception.Message
  Write-Host ''
  Write-Host '===================================================================='
  Write-Host ' RAH RAVEN DAILY DRIVER v1.0 FINAL/STABLE: FAIL'
  Write-Host " $Err"
  Write-Host '===================================================================='
}finally{
  Save-Report $Final $Err
}
if($Final -eq 'PASS'){exit 0}
exit 1
