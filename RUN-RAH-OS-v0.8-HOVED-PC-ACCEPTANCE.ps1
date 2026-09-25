param([switch]$JsonOnly,[switch]$SelfTest)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='C:\RAH\RavenOS'
$state=Join-Path $root 'state'
$out=Join-Path $state 'RAH-OS-v0.8-ACCEPTANCE.json'
$utf8=New-Object Text.UTF8Encoding($false)

if($SelfTest){
 foreach($n in @('RAH-OS-SELFTEST.ps1','RAVEN-CORE-7.ps1','RAVEN-AI-SELF-CHECK.ps1','TEST-ANYTHINGLLM-APPROVAL.ps1','RAVEN-CORE-7-WORKER-PROOF.ps1')){
  if($n -notmatch '\.ps1$'){throw 'Acceptance allowlist contract failed.'}
 }
 Write-Host 'PASS: RAH OS v0.8 acceptance contract'
 exit 0
}

function Stage([string]$Name,[string]$Script,[string[]]$Args=@()){
 $path=Join-Path $root $Script
 if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return [pscustomobject]@{name=$Name;status='FAIL';exitCode=127;detail=($Script+' missing')}}
 try{
  $raw=@(& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $path @Args 2>&1)
  $ec=$LASTEXITCODE
  return [pscustomobject]@{name=$Name;status='RAW';exitCode=$ec;detail=((@($raw|Select-Object -Last 8)-join ' ') -replace '\s+',' ')}
 }catch{return [pscustomobject]@{name=$Name;status='FAIL';exitCode=126;detail=$_.Exception.Message}}
}
New-Item -ItemType Directory -Force -Path $state|Out-Null
$stages=[System.Collections.Generic.List[object]]::new()

$f=Stage 'Front Door' 'RAH-OS-SELFTEST.ps1' @('-Quick','-JsonOnly')
$f.status=if($f.exitCode -eq 0){'PASS'}else{'FAIL'};$stages.Add($f)|Out-Null

$c=Stage 'Raven Core' 'RAVEN-CORE-7.ps1' @('-Mode','Diagnostics','-JsonOnly')
if($c.exitCode -eq 0){
 $coreStatus='C:\RAH\RavenCore7\state\status.json'
 if(Test-Path $coreStatus){try{$cj=Get-Content $coreStatus -Raw|ConvertFrom-Json;$c.status=if([string]$cj.overall -eq 'PASS'){'PASS'}else{'PENDING'};$c.detail='Core diagnostics: '+[string]$cj.overall}catch{$c.status='PENDING'}}
 else{$c.status='PENDING';$c.detail='Core diagnostics ran; status evidence not found.'}
}else{$c.status='FAIL'}
$stages.Add($c)|Out-Null

$a=Stage 'Local AI' 'RAVEN-AI-SELF-CHECK.ps1' @('-NoRepair')
$a.status=if($a.exitCode -eq 0){'PASS'}elseif($a.exitCode -eq 2){'PENDING'}else{'FAIL'}
$stages.Add($a)|Out-Null

$n=Stage 'AnythingLLM' 'TEST-ANYTHINGLLM-APPROVAL.ps1'
$n.status=if($n.exitCode -eq 0){'PASS'}elseif($n.exitCode -eq 10){'PENDING'}else{'FAIL'}
$stages.Add($n)|Out-Null

$w=Stage 'Worker Proof' 'RAVEN-CORE-7-WORKER-PROOF.ps1' @('-Mode','Validate','-JsonOnly')
$w.status=if($w.exitCode -eq 0){'PASS'}elseif($w.exitCode -eq 2){'PENDING'}else{'FAIL'}
$stages.Add($w)|Out-Null

$stageItems=@($stages|ForEach-Object{$_})
$overall=if(@($stageItems|Where-Object status -eq 'FAIL').Count){'FAIL'}elseif(@($stageItems|Where-Object status -ne 'PASS').Count){'PENDING'}else{'PASS'}
$doc=[pscustomobject][ordered]@{
 schema='rah-os-v08-hoved-pc-acceptance';version='0.8.0-candidate';
 computer=$env:COMPUTERNAME;timestamp=(Get-Date).ToUniversalTime().ToString('o');
 overall=$overall;areas=$stageItems;
 safety=[pscustomobject][ordered]@{usbChanges=$false;partitionChanges=$false;automaticNodeStart=$false;arbitraryShell=$false;backgroundNetworkDiscovery=$false}
}
[IO.File]::WriteAllText($out,(($doc|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)

if($JsonOnly){$doc|ConvertTo-Json -Depth 10}else{
 Write-Host ''
 Write-Host '============================================================' -ForegroundColor DarkYellow
 Write-Host '        RAH OS v0.8 - HOVED-PC ACCEPTANCE' -ForegroundColor Yellow
 Write-Host '============================================================' -ForegroundColor DarkYellow
 foreach($x in $stageItems){$col=switch($x.status){'PASS'{'Green'}'PENDING'{'Yellow'}default{'Red'}};Write-Host (('{0,-8} {1,-16} exit={2}  {3}' -f $x.status,$x.name,$x.exitCode,$x.detail)) -ForegroundColor $col}
 Write-Host ''
 Write-Host ('FINAL: '+$overall) -ForegroundColor $(if($overall -eq 'PASS'){'Green'}elseif($overall -eq 'PENDING'){'Yellow'}else{'Red'})
 Write-Host ('Report: '+$out) -ForegroundColor DarkGray
}
if($overall -eq 'PASS'){exit 0};if($overall -eq 'PENDING'){exit 2};exit 1
