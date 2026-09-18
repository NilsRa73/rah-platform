[CmdletBinding()]
param(
    [switch]$NoLaunch,
    [switch]$SkipInfrastructure,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$Version='3.0.0'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$StudioHtml=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.0.html'
$StudioManifest=Join-Path $Root 'RAH-RAVEN-STUDIO-V3.0.json'
$CommandManifest=Join-Path $Root 'RAH-COMMAND-CENTER-VERSION.json'
$BrowserManifest=Join-Path $Root 'RAH-RAVEN-BROWSER-VERSION.json'
$NowManifest=Join-Path $Root 'RAH-RAVEN-NOW-VERSION.json'
$VisionManifest=Join-Path $Root 'RAH-RAVEN-VISION-VERSION.json'
$MissionManifest=Join-Path $Root 'RAH-RAVEN-MISSION-CONTROL-VERSION.json'
$CouncilManifest=Join-Path $Root 'RAH-RAVEN-COUNCIL-VERSION.json'
$AgentManifest=Join-Path $Root 'RAH-RAVEN-AGENT-RUNNER-VERSION.json'
$ChronicleManifest=Join-Path $Root 'RAH-RAVEN-CHRONICLE-VERSION.json'
$InfraFinal=Join-Path $Root 'RAH-RAVEN-HOVED-PC-FINAL.ps1'
$LogRoot='C:\RAH\Logs'
$InstallRoot='C:\RAH\Studio'
$ReportPath=Join-Path $LogRoot 'RAVEN-STUDIO-FINAL-LATEST.json'
$Checks=[System.Collections.Generic.List[object]]::new()

function Test-Admin {
  $id=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p=[Security.Principal.WindowsPrincipal]::new($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-Check([string]$Name,[bool]$Ok,[string]$Detail){
  $Checks.Add([pscustomobject]@{name=$Name;ok=$Ok;detail=$Detail})
  $tag=if($Ok){'PASS'}else{'FAIL'}
  Write-Host "[$tag] $Name - $Detail"
  if(-not $Ok){throw ($Name + ': ' + $Detail)}
}

function Read-Json([string]$Path,[string]$Label){
  Add-Check "$Label file" (Test-Path -LiteralPath $Path -PathType Leaf) $Path
  try{return Get-Content -LiteralPath $Path -Raw -Encoding UTF8|ConvertFrom-Json -ErrorAction Stop}
  catch{throw ($Label + ' JSON er ugyldig: ' + $_.Exception.Message)}
}

function Save-Report([string]$Result,[string]$ErrorText){
  New-Item -ItemType Directory -Force -Path $LogRoot|Out-Null
  [pscustomobject]@{
    schema='rah-raven-studio-final-v1'
    product='RAH Raven Studio'
    version=$Version
    generatedAt=(Get-Date).ToString('o')
    computer=$env:COMPUTERNAME
    result=$Result
    error=$ErrorText
    entry=$StudioHtml
    checks=@($Checks)
  }|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $ReportPath -Encoding UTF8
}

function Test-Contracts {
  Add-Check 'Studio HTML' (Test-Path -LiteralPath $StudioHtml -PathType Leaf) $StudioHtml
  $studio=Read-Json $StudioManifest 'Studio manifest'
  Add-Check 'Studio version' ([string]$studio.version -eq '3.0.0') ([string]$studio.version)
  Add-Check 'Studio stage Stable' ([string]$studio.stage -eq 'stable') ([string]$studio.stage)

  $cc=Read-Json $CommandManifest 'Command Center manifest'
  Add-Check 'Command Center 2.4 Stable' ([string]$cc.version -eq '2.4.0' -and [string]$cc.stage -eq 'stable') "$($cc.version) / $($cc.stage)"
  Add-Check 'Command Center generation 9' ([int]$cc.canonical_package_generation -eq 9) ([string]$cc.canonical_package_generation)

  $browser=Read-Json $BrowserManifest 'Raven Browser manifest'
  Add-Check 'Raven Browser 1.3 Stable' ([string]$browser.version -eq '1.3.0' -and [string]$browser.stage -eq 'stable') "$($browser.version) / $($browser.stage)"

  $now=Read-Json $NowManifest 'Raven Now manifest'
  Add-Check 'Raven Now 2.17 Stable' ([string]$now.version -eq '2.17.0' -and [string]$now.stage -eq 'stable') "$($now.version) / $($now.stage)"

  $vision=Read-Json $VisionManifest 'Vision manifest'
  Add-Check 'Vision 0.6 Stable' ([string]$vision.version -eq '0.6.0' -and [string]$vision.stage -eq 'stable') "$($vision.version) / $($vision.stage)"

  $mission=Read-Json $MissionManifest 'Mission Control manifest'
  Add-Check 'Mission Control 2.9 Stable' ([string]$mission.version -eq '2.9.0' -and [string]$mission.stage -eq 'stable') "$($mission.version) / $($mission.stage)"

  $council=Read-Json $CouncilManifest 'Council manifest'
  Add-Check 'Council 0.3 Stable' ([string]$council.version -eq '0.3.0' -and [string]$council.stage -eq 'stable') "$($council.version) / $($council.stage)"

  $agent=Read-Json $AgentManifest 'Agent Runner manifest'
  Add-Check 'Agent Runner 0.3 Stable' ([string]$agent.version -eq '0.3.0' -and [string]$agent.stage -eq 'stable') "$($agent.version) / $($agent.stage)"

  $chronicle=Read-Json $ChronicleManifest 'Chronicle manifest'
  Add-Check 'Chronicle 1.7.1 Stable' ([string]$chronicle.version -eq '1.7.1' -and [string]$chronicle.stage -eq 'stable') "$($chronicle.version) / $($chronicle.stage)"

  $html=Get-Content -LiteralPath $StudioHtml -Raw -Encoding UTF8
  Add-Check 'Studio canonical CC link' ($html.Contains('RAH-COMMAND-CENTER-V2.4.html')) 'CC2.4'
  Add-Check 'Studio Project Memory surface' ($html.Contains('RAH-RAVEN-MEMORY-SYNC.html')) 'Memory Sync'
  Add-Check 'Studio loopback-only status' (-not ($html -match 'https://')) 'ingen eksterne status-URL-er'
}

function Invoke-SelfTest {
  Test-Contracts
  Write-Host 'RAH RAVEN STUDIO 3.0 FINALIZER SELF-TEST: PASS'
}

if($SelfTest){
  Invoke-SelfTest
  exit 0
}

if(-not (Test-Admin)){
  Write-Host '[UAC] RAH Raven Studio finalisering trenger Administrator.'
  $args=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"' -f $MyInvocation.MyCommand.Path))
  if($NoLaunch){$args+='-NoLaunch'}
  if($SkipInfrastructure){$args+='-SkipInfrastructure'}
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
try{
  Write-Host '===================================================================='
  Write-Host ' RAH RAVEN STUDIO 3.0 - FINAL / STABLE'
  Write-Host ' CONTRACTS -> INFRA REPAIR -> SHORTCUT -> START'
  Write-Host '===================================================================='

  Test-Contracts

  if(-not $SkipInfrastructure){
    Add-Check 'HOVED-PC finalizer present' (Test-Path -LiteralPath $InfraFinal -PathType Leaf) $InfraFinal
    Write-Host '[INFRA] Kjører canonical HOVED-PC PRECHECK/REPAIR/POSTCHECK...'
    & powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $InfraFinal
    Add-Check 'HOVED-PC Raven gate' ($LASTEXITCODE -eq 0) "exit=$LASTEXITCODE"
  }

  New-Item -ItemType Directory -Force -Path $InstallRoot,$LogRoot|Out-Null
  Set-Content -LiteralPath (Join-Path $InstallRoot 'SOURCE.txt') -Value $Root -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $InstallRoot 'VERSION.txt') -Value $Version -Encoding ASCII

  $desktop=[Environment]::GetFolderPath('Desktop')
  $lnk=Join-Path $desktop 'RAH Raven Studio 3.lnk'
  $launcher=Join-Path $Root 'START-HER-RAH-RAVEN-STUDIO.cmd'
  Add-Check 'Studio one-click launcher' (Test-Path -LiteralPath $launcher -PathType Leaf) $launcher
  $w=New-Object -ComObject WScript.Shell
  $s=$w.CreateShortcut($lnk)
  $s.TargetPath=$launcher
  $s.WorkingDirectory=$Root
  $s.Description='RAH Raven Studio 3.0 Stable'
  $s.Save()
  Add-Check 'Desktop shortcut' (Test-Path -LiteralPath $lnk -PathType Leaf) $lnk

  if(-not $NoLaunch){
    Start-Process -FilePath $StudioHtml
    Add-Check 'Studio launch requested' $true $StudioHtml
  }

  $Final='PASS'
  Write-Host ''
  Write-Host '===================================================================='
  Write-Host ' RAH RAVEN STUDIO 3.0 FINAL/STABLE: PASS'
  Write-Host ' Canonical: Command Center 2.4 / generation 9'
  Write-Host ' Browser  : Raven Browser 1.3 Stable'
  Write-Host '===================================================================='
}catch{
  $Err=$_.Exception.Message
  Write-Host ''
  Write-Host '===================================================================='
  Write-Host ' RAH RAVEN STUDIO 3.0 FINAL/STABLE: FAIL'
  Write-Host " $Err"
  Write-Host '===================================================================='
}finally{
  Save-Report $Final $Err
}

if($Final -eq 'PASS'){exit 0}
exit 1
