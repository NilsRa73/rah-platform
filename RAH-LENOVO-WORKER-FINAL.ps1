[CmdletBinding()]
param(
  [string]$WorkerAddress='',
  [ValidateRange(1024,65535)][int]$Port=18766,
  [switch]$SelfTest
)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Version='1.0.0'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$InstallRoot='C:\RAH\Home'
$LogRoot='C:\RAH\Logs'
$Report=Join-Path $LogRoot 'LENOVO-WORKER-FINAL-LATEST.json'
$TaskName='RAH Lenovo Raven Worker'
$FirewallName='RAH Raven Lenovo Worker 18766'

function Test-PrivateIPv4([string]$Address){
  $p=$Address.Split('.'); if($p.Count-ne4){return $false}; $n=@()
  foreach($x in $p){if($x-notmatch'^\d{1,3}$'){return $false};$v=[int]$x;if($v-lt0-or$v-gt255-or[string]$v-ne$x){return $false};$n+=$v}
  return ($n[0]-eq10-or($n[0]-eq192-and$n[1]-eq168)-or($n[0]-eq172-and$n[1]-ge16-and$n[1]-le31))
}
function Test-Admin {
  $i=[Security.Principal.WindowsIdentity]::GetCurrent()
  $p=[Security.Principal.WindowsPrincipal]::new($i)
  $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Add-Check([string]$Name,[bool]$Ok,[string]$Detail){
  $script:Checks += [pscustomobject]@{name=$Name;ok=$Ok;detail=$Detail}
  Write-Host ("[{0}] {1} - {2}" -f $(if($Ok){'PASS'}else{'FAIL'}),$Name,$Detail)
  if(-not$Ok){throw "${Name}: $Detail"}
}
function Save-Report([string]$Result,[string]$ErrorText,[string]$Address){
  New-Item -ItemType Directory -Force -Path $LogRoot|Out-Null
  [pscustomobject]@{schema='rah-lenovo-raven-worker-final-v1';version=$Version;generatedAt=(Get-Date).ToString('o');computer=$env:COMPUTERNAME;result=$Result;error=$ErrorText;workerAddress=$Address;port=$Port;checks=@($script:Checks)}|
    ConvertTo-Json -Depth 8|Set-Content -LiteralPath $Report -Encoding UTF8
}
if($SelfTest){
  foreach($ip in @('10.1.2.3','172.31.2.3','192.168.50.9')){if(-not(Test-PrivateIPv4 $ip)){throw "SelfTest rejected $ip"}}
  foreach($ip in @('8.8.8.8','127.0.0.1','0.0.0.0','192.168.001.2')){if(Test-PrivateIPv4 $ip){throw "SelfTest accepted $ip"}}
  Write-Host 'PASS: Lenovo Raven Worker FINAL self-test'; exit 0
}
if(-not(Test-Admin)){
  $a=@('-NoLogo','-NoProfile','-ExecutionPolicy','Bypass','-File',('"{0}"'-f$MyInvocation.MyCommand.Path),'-Port',[string]$Port)
  if($WorkerAddress){$a+=@('-WorkerAddress',$WorkerAddress)}
  try{$p=Start-Process powershell.exe -ArgumentList $a -Verb RunAs -Wait -PassThru;exit $p.ExitCode}catch{exit 5}
}
$script:Checks=@();$Final='FAIL';$Err=$null;$Bound=''
try{
  Write-Host 'RAH LENOVO RAVEN WORKER - FINAL'
  $Installer=Join-Path $Root 'RAH-HOME-INSTALL.ps1'
  Add-Check 'Unified installer' (Test-Path $Installer) $Installer
  $args=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$Installer,'-Mode','Worker','-Port',[string]$Port,'-InstallRoot',$InstallRoot)
  $needed=@('RAH-HOME-NODE-AGENT.ps1','RAH-HOME-NODE-CLIENT.ps1','RAH-HOME-NODE-JOB.ps1','RAH-HOME-CLUSTER-RUN.ps1','RAH-HOME-CLUSTER-CONTROLLER.ps1','RAH-HOME-PAIR-WIZARD.ps1','RAH-HOME-LAN-ACCEPTANCE.ps1')
  if(@($needed|Where-Object{-not(Test-Path(Join-Path $Root $_))}).Count-eq0){$args+=@('-SourceDirectory',$Root)}
  if($WorkerAddress){$args+=@('-WorkerAddress',$WorkerAddress)}
  & powershell.exe @args
  Add-Check 'Worker install/repair' ($LASTEXITCODE-eq0) "exit=$LASTEXITCODE"
  $State=Get-Content (Join-Path $InstallRoot 'rah-home-install-state.json') -Raw|ConvertFrom-Json
  $Bound=[string]$State.workerAddress
  Add-Check 'Explicit private bind' (Test-PrivateIPv4 $Bound) $Bound
  $Agent=Join-Path $InstallRoot 'RAH-HOME-NODE-AGENT.ps1'
  Add-Check 'Agent file' (Test-Path $Agent) $Agent

  Get-NetFirewallRule -DisplayName $FirewallName -ErrorAction SilentlyContinue|Remove-NetFirewallRule -ErrorAction SilentlyContinue
  New-NetFirewallRule -DisplayName $FirewallName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $Port -LocalAddress $Bound -RemoteAddress LocalSubnet -Profile Private|Out-Null
  Add-Check 'Firewall LocalSubnet' $true "$Bound`:$Port / Private"

  $User=[Security.Principal.WindowsIdentity]::GetCurrent().Name
  $taskArgs="-NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Agent`" -ListenAddress $Bound -AllowLan -Port $Port"
  $Action=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $taskArgs -WorkingDirectory $InstallRoot
  $Trigger=New-ScheduledTaskTrigger -AtLogOn -User $User
  $Principal=New-ScheduledTaskPrincipal -UserId $User -LogonType Interactive -RunLevel Limited
  Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable -MultipleInstances IgnoreNew) -Force|Out-Null
  Add-Check 'Autostart task' $true 'AtLogOn / Limited'

  $Listening=@(Get-NetTCPConnection -LocalAddress $Bound -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
  if($Listening.Count-eq0){
    Write-Host '[START] Worker-vinduet viser PAIR CODE.' -ForegroundColor Cyan
    Start-Process powershell.exe -WorkingDirectory $InstallRoot -ArgumentList @('-NoExit','-NoProfile','-ExecutionPolicy','Bypass','-File',$Agent,'-ListenAddress',$Bound,'-AllowLan','-Port',[string]$Port)|Out-Null
    for($i=0;$i-lt30;$i++){Start-Sleep -Milliseconds 500;$Listening=@(Get-NetTCPConnection -LocalAddress $Bound -LocalPort $Port -State Listen -ErrorAction SilentlyContinue);if($Listening){break}}
  }
  Add-Check 'Worker listener' ($Listening.Count-gt0) "$Bound`:$Port"
  $Final='PASS'
  Write-Host "RAH LENOVO RAVEN WORKER FINAL: PASS - $Bound`:$Port" -ForegroundColor Green
  Write-Host 'PAIR CODE vises i Worker-vinduet. Autostart er klar for neste innlogging.'
}catch{$Err=$_.Exception.Message;Write-Host "RAH LENOVO RAVEN WORKER FINAL: FAIL - $Err" -ForegroundColor Red}
finally{Save-Report $Final $Err $Bound}
if($Final-eq'PASS'){exit 0}else{exit 1}
