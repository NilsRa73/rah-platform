[CmdletBinding()]
param([switch]$NoOpenDiagnostics)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$BridgeDir=Join-Path $Root 'desktop-bridge'
$BridgePy=Join-Path $BridgeDir '.venv\Scripts\python.exe'
$BridgeScript=Join-Path $BridgeDir 'raven_bridge.py'
$Diagnostics=Join-Path $Root 'RAH-RAVEN-STUDIO-DIAGNOSTICS-V3.1-CANDIDATE.5.html'
$LogRoot='C:\RAH\Logs'
$Report=Join-Path $LogRoot 'RAVEN-STUDIO-DIAGNOSTICS-LATEST.json'
$BridgeUrl='http://127.0.0.1:18765/health'
$LmUrl='http://127.0.0.1:1234/v1/models'
$actions=[System.Collections.Generic.List[string]]::new()

function Find-BridgeInstall {
  $candidates=@(
    (Join-Path $Root 'desktop-bridge'),
    'C:\RAH\desktop-bridge',
    'C:\RAH\rah-platform\desktop-bridge',
    'C:\RAH\RAH-Platform\desktop-bridge',
    (Join-Path $env:USERPROFILE 'Documents\GitHub\rah-platform\desktop-bridge')
  )
  foreach($dir in $candidates){
    if([string]::IsNullOrWhiteSpace($dir)){continue}
    $py=Join-Path $dir '.venv\Scripts\python.exe'
    $script=Join-Path $dir 'raven_bridge.py'
    if((Test-Path -LiteralPath $py -PathType Leaf) -and (Test-Path -LiteralPath $script -PathType Leaf)){
      return [pscustomobject]@{dir=$dir;python=$py;script=$script}
    }
  }
  return $null
}

function Test-JsonUrl([string]$Url,[int]$TimeoutSec=2){
  try{return Invoke-RestMethod -Uri $Url -Method Get -TimeoutSec $TimeoutSec -ErrorAction Stop}
  catch{return $null}
}

function Save-Report([string]$Overall,$Bridge,$Lm,[string]$ErrorText=''){
  New-Item -ItemType Directory -Force -Path $LogRoot|Out-Null
  [pscustomobject]@{
    schema='rah-raven-studio-diagnostics-v1'
    candidate='3.1.0-candidate.5'
    generatedAt=(Get-Date).ToString('o')
    computer=$env:COMPUTERNAME
    overall=$Overall
    error=$ErrorText
    actions=@($actions | ForEach-Object { $_ })
    bridge=[pscustomobject]@{
      ok=[bool]($Bridge -and $Bridge.ok -eq $true)
      version=if($Bridge){$Bridge.version}else{$null}
      agent_runner=if($Bridge){$Bridge.agent_runner}else{$null}
      agent_runner_mode=if($Bridge){$Bridge.agent_runner_mode}else{$null}
    }
    lm_studio=[pscustomobject]@{
      reachable=[bool]$Lm
      model_count=if($Lm -and $Lm.data){@($Lm.data).Count}else{0}
    }
    policy=[pscustomobject]@{
      installs=$false
      firewall_changes=$false
      network_changes=$false
      model_downloads=$false
      process_kills=$false
      bridge_start_only_when_offline=$true
    }
  }|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $Report -Encoding UTF8
}

$Bridge=$null;$Lm=$null;$Overall='FAILED';$Err=''
try{
  Write-Host '============================================================'
  Write-Host ' RAH RAVEN STUDIO v3.1 CANDIDATE.5 - SAFE REPAIR'
  Write-Host ' NO INSTALLS / NO FIREWALL / NO NETWORK CHANGES / NO KILLS'
  Write-Host '============================================================'

  $Bridge=Test-JsonUrl $BridgeUrl 2
  if($Bridge -and $Bridge.ok -eq $true){
    Write-Host '[PASS] Desktop Bridge already answers on 18765.'
    $actions.Add('Bridge already healthy; no restart performed.')
  }else{
    Write-Host '[WARN] Desktop Bridge is offline.'
    $install=Find-BridgeInstall
    if(-not $install){throw 'Mangler eksisterende canonical Bridge i godkjente lokale RAH-stier.'}
    Write-Host ("[REPAIR] Starting existing canonical Bridge hidden from " + $install.dir + "...")
    Start-Process -FilePath $install.python -ArgumentList @($install.script) -WorkingDirectory $install.dir -WindowStyle Hidden
    $actions.Add('Started existing canonical Bridge hidden from allowlisted local path.')
    for($i=0;$i -lt 10;$i++){
      Start-Sleep -Milliseconds 500
      $Bridge=Test-JsonUrl $BridgeUrl 1
      if($Bridge -and $Bridge.ok -eq $true){break}
    }
    if(-not ($Bridge -and $Bridge.ok -eq $true)){throw 'Bridge did not become healthy within 5 seconds.'}
    Write-Host '[PASS] Bridge became healthy.'
  }

  if($Bridge.agent_runner -eq $true -and [string]$Bridge.agent_runner_mode -eq 'read-only-allowlist'){
    Write-Host "[PASS] Agent Runner $($Bridge.agent_runner_version) read-only allowlist."
  }else{
    Write-Host '[WARN] Agent Runner safe mode was not confirmed. No automatic replacement performed.'
    $actions.Add('Agent Runner mismatch detected; no automatic replacement performed.')
  }

  $Lm=Test-JsonUrl $LmUrl 2
  if($Lm){
    $count=if($Lm.data){@($Lm.data).Count}else{0}
    if($count -gt 0){Write-Host "[PASS] LM Studio reachable; models=$count."}
    else{Write-Host '[WARN] LM Studio reachable, but no model is loaded. No model action performed.'}
  }else{
    Write-Host '[INFO] LM Studio offline/optional. No automatic launch or install performed.'
  }

  $Overall=if($Bridge.agent_runner -eq $true -and [string]$Bridge.agent_runner_mode -eq 'read-only-allowlist'){'READY'}else{'DEGRADED'}
}catch{
  $Err=$_.Exception.Message
  Write-Host "[FAIL] $Err"
  $Overall='FAILED'
}finally{
  Save-Report $Overall $Bridge $Lm $Err
  Write-Host ''
  Write-Host "RESULT: $Overall"
  Write-Host "Report: $Report"
  if(-not $NoOpenDiagnostics -and (Test-Path -LiteralPath $Diagnostics)){Start-Process -FilePath $Diagnostics}
}

if($Overall -eq 'FAILED'){exit 1}
exit 0
