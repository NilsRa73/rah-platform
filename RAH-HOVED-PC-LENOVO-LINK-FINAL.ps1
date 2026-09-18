[CmdletBinding()]
param(
  [string]$NodeAddress='',
  [string]$PairCode='',
  [ValidateRange(1024,65535)][int]$Port=18766,
  [switch]$SelfTest
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Version='1.0.0'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallRoot='C:\RAH\Home'
$NodeRoot='C:\RAH\Nodes'
$LogRoot='C:\RAH\Logs'
$Config=Join-Path $NodeRoot 'lenovo-worker.json'
$Report=Join-Path $LogRoot 'HOVED-PC-LENOVO-LINK-LATEST.json'

function Test-PrivateIPv4([string]$Address){
  $p=$Address.Split('.');if($p.Count-ne4){return $false};$n=@()
  foreach($x in $p){if($x-notmatch'^\d{1,3}$'){return $false};$v=[int]$x;if($v-lt0-or$v-gt255-or[string]$v-ne$x){return $false};$n+=$v}
  return ($n[0]-eq10-or($n[0]-eq192-and$n[1]-eq168)-or($n[0]-eq172-and$n[1]-ge16-and$n[1]-le31))
}
function Run-Capture([string]$File,[string[]]$Args){
  $old=$ErrorActionPreference
  try{$ErrorActionPreference='Continue';$o=& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $File @Args 2>&1;$code=$LASTEXITCODE}
  finally{$ErrorActionPreference=$old}
  [pscustomobject]@{code=$code;text=($o|Out-String).Trim()}
}
function Parse-JsonResult($Call,[string]$Name){
  if($Call.code-ne0){throw "$Name failed: $($Call.text)"}
  try{return $Call.text|ConvertFrom-Json -ErrorAction Stop}catch{throw "$Name returned invalid JSON"}
}
function Save-Json([object]$Object,[string]$Path){
  $dir=Split-Path -Parent $Path;New-Item -ItemType Directory -Force -Path $dir|Out-Null
  $tmp="$Path.tmp";$Object|ConvertTo-Json -Depth 10|Set-Content -LiteralPath $tmp -Encoding UTF8;Move-Item $tmp $Path -Force
}
if($SelfTest){
  foreach($ip in @('10.0.0.8','172.16.4.2','192.168.0.49')){if(-not(Test-PrivateIPv4 $ip)){throw "SelfTest rejected $ip"}}
  foreach($ip in @('8.8.8.8','127.0.0.1','0.0.0.0')){if(Test-PrivateIPv4 $ip){throw "SelfTest accepted $ip"}}
  Write-Host 'PASS: HOVED-PC Lenovo link FINAL self-test';exit 0
}

$Final='FAIL';$Err=$null;$Health=$null;$Info=$null;$Hello=$null
try{
  Write-Host 'RAH HOVED-PC -> LENOVO RAVEN LINK - FINAL'
  $Installer=Join-Path $Root 'RAH-HOME-INSTALL.ps1'
  if(-not(Test-Path $Installer)){throw 'RAH-HOME-INSTALL.ps1 missing'}
  $args=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$Installer,'-Mode','Leader','-Port',[string]$Port,'-InstallRoot',$InstallRoot)
  $needed=@('RAH-HOME-NODE-AGENT.ps1','RAH-HOME-NODE-CLIENT.ps1','RAH-HOME-NODE-JOB.ps1','RAH-HOME-CLUSTER-RUN.ps1','RAH-HOME-CLUSTER-CONTROLLER.ps1','RAH-HOME-PAIR-WIZARD.ps1','RAH-HOME-LAN-ACCEPTANCE.ps1')
  if(@($needed|Where-Object{-not(Test-Path(Join-Path $Root $_))}).Count-eq0){$args+=@('-SourceDirectory',$Root)}
  & powershell.exe @args
  if($LASTEXITCODE-ne0){throw "Leader install/repair failed: $LASTEXITCODE"}

  $Client=Join-Path $InstallRoot 'RAH-HOME-NODE-CLIENT.ps1'
  $Job=Join-Path $InstallRoot 'RAH-HOME-NODE-JOB.ps1'
  if(-not(Test-Path $Client)-or-not(Test-Path $Job)){throw 'Installed Node Client/Job missing'}

  $Address=$NodeAddress.Trim()
  if(-not$Address-and(Test-Path $Config)){
    try{$saved=Get-Content $Config -Raw|ConvertFrom-Json;$Address=[string]$saved.nodeAddress}catch{}
  }
  if(-not$Address){$Address=(Read-Host 'Lenovo Worker IP').Trim()}
  if(-not(Test-PrivateIPv4 $Address)){throw 'Lenovo address must be a private RFC1918 IPv4 address'}

  $helloCall=Run-Capture $Client @('-NodeAddress',$Address,'-Port',[string]$Port,'-Action','hello')
  $Hello=Parse-JsonResult $helloCall 'HELLO'
  if($Hello.product-ne'RAH Home Node Agent'){throw 'Unexpected node identity'}

  $healthCall=Run-Capture $Job @('-NodeAddress',$Address,'-Port',[string]$Port,'-Job','health','-JsonOnly')
  if($healthCall.code-ne0){
    $code=$PairCode.Trim()
    if(-not$code){$code=(Read-Host 'PAIR CODE from Lenovo Worker window').Trim()}
    if($code-notmatch'^\d{6}$'){throw 'PAIR CODE must be six digits'}
    $pair=Run-Capture $Client @('-NodeAddress',$Address,'-Port',[string]$Port,'-Action','pair','-PairCode',$code)
    if($pair.code-ne0){throw "PAIR failed: $($pair.text)"}
    $healthCall=Run-Capture $Job @('-NodeAddress',$Address,'-Port',[string]$Port,'-Job','health','-JsonOnly')
  }
  $Health=Parse-JsonResult $healthCall 'HEALTH'
  if($Health.ok-ne$true-or$Health.status-ne'ready'){throw 'Worker health not ready'}

  $infoCall=Run-Capture $Job @('-NodeAddress',$Address,'-Port',[string]$Port,'-Job','systemInfo','-JsonOnly')
  $Info=Parse-JsonResult $infoCall 'SYSTEMINFO'
  if($Info.ok-ne$true-or-not$Info.result.computerName){throw 'systemInfo invalid'}

  Save-Json ([pscustomobject]@{schema='rah-lenovo-worker-link-v1';nodeAddress=$Address;port=$Port;computerName=[string]$Info.result.computerName;linkedAt=(Get-Date).ToString('o')}) $Config
  $Final='PASS'
  Write-Host "RAH 2-PC RAVEN LINK: PASS - HOVED-PC -> $($Info.result.computerName) ($Address`:$Port)" -ForegroundColor Green
  Write-Host "CPU: $($Info.result.cpu)"
  Write-Host "RAM GB: $($Info.result.memoryGB)"
}catch{$Err=$_.Exception.Message;Write-Host "RAH 2-PC RAVEN LINK: FAIL - $Err" -ForegroundColor Red}
finally{
  Save-Json ([pscustomobject]@{schema='rah-hovedpc-lenovo-link-final-v1';version=$Version;generatedAt=(Get-Date).ToString('o');result=$Final;error=$Err;node=$Hello;health=$Health;systemInfo=$Info}) $Report
}
if($Final-eq'PASS'){exit 0}else{exit 1}
