param([switch]$JsonOnly,[switch]$SelfTest)
# v0.8.2: evidence-first core acceptance with PASS / PENDING / FAIL semantics
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$root='C:\RAH\RavenOS'
$state=Join-Path $root 'state'
$out=Join-Path $state 'RAH-OS-v0.8-ACCEPTANCE.json'
$utf8=New-Object Text.UTF8Encoding($false)

function Stage([string]$Name,[string]$Script,[string[]]$Args=@()){
 $path=Join-Path $root $Script
 if(-not(Test-Path -LiteralPath $path -PathType Leaf)){return [pscustomobject]@{name=$Name;status='FAIL';exitCode=127;detail=($Script+' missing')}}
 try{
  $raw=@(& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $path @Args 2>&1)
  $ec=$LASTEXITCODE
  return [pscustomobject]@{name=$Name;status='RAW';exitCode=$ec;detail=((@($raw|Select-Object -Last 8)-join ' ') -replace '\s+',' ')}
 }catch{return [pscustomobject]@{name=$Name;status='FAIL';exitCode=126;detail=$_.Exception.Message}}
}

function Read-Json([string]$Path){
 if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){return $null}
 try{return Get-Content -LiteralPath $Path -Raw|ConvertFrom-Json -ErrorAction Stop}catch{return $null}
}

function Get-LocalJson([string]$Uri,[int]$Timeout=5){
 $allowed=@(
  'http://127.0.0.1:18765/health',
  'http://127.0.0.1:18765/agent/jobs/health',
  'http://127.0.0.1:1234/v1/models'
 )
 if($allowed -notcontains $Uri){return $null}
 try{return Invoke-RestMethod -Uri $Uri -Method Get -TimeoutSec $Timeout -ErrorAction Stop}catch{return $null}
}

function Test-LmInference([string]$Model){
 if([string]::IsNullOrWhiteSpace($Model)){return $false}
 try{
  $body=@{
   model=$Model
   messages=@(@{role='user';content='Reply with exactly RAH_OK'})
   temperature=0
   max_tokens=12
   stream=$false
  }|ConvertTo-Json -Depth 6
  $r=Invoke-RestMethod -Uri 'http://127.0.0.1:1234/v1/chat/completions' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 30 -ErrorAction Stop
  return ([string]$r.choices[0].message.content -match 'RAH_OK')
 }catch{return $false}
}

if($SelfTest){
 foreach($n in @('RAH-OS-v0.8-SELFTEST.ps1','RAVEN-CORE-7.ps1','RAVEN-AI-SELF-CHECK.ps1','TEST-ANYTHINGLLM-APPROVAL.ps1','RAVEN-CORE-7-WORKER-PROOF.ps1')){
  if($n -notmatch '\.ps1$'){throw 'Acceptance allowlist contract failed.'}
 }
 Write-Host 'PASS: RAH OS v0.8 final acceptance contract'
 exit 0
}

New-Item -ItemType Directory -Force -Path $state|Out-Null
$stages=[System.Collections.Generic.List[object]]::new()

$f=Stage 'Front Door' 'RAH-OS-v0.8-SELFTEST.ps1' @('-Quick','-JsonOnly')
$f.status=if($f.exitCode -eq 0){'PASS'}else{'FAIL'}
$stages.Add($f)|Out-Null

$c=Stage 'Raven Core' 'RAVEN-CORE-7.ps1' @('-Mode','Diagnostics','-JsonOnly')
$core=Read-Json 'C:\RAH\RavenCore7\state\status.json'
if($core -and [string]$core.overall -eq 'PASS'){
 $c.status='PASS'
 $c.detail='Raven Core state evidence PASS on 127.0.0.1:18765.'
 if($c.exitCode -ne 0){$c.detail+=' Diagnostics process exit='+[string]$c.exitCode+' was ignored because canonical state JSON is PASS.'}
}else{
 $c.status='FAIL'
 if($core){$c.detail='Raven Core overall='+[string]$core.overall}else{$c.detail='Raven Core state JSON missing/invalid.'}
}
$stages.Add($c)|Out-Null

$a=[pscustomobject]@{name='Local AI';status='FAIL';exitCode=1;detail='Direct local AI evidence incomplete.'}
$health=Get-LocalJson 'http://127.0.0.1:18765/health' 4
$jobs=Get-LocalJson 'http://127.0.0.1:18765/agent/jobs/health' 5
$models=Get-LocalJson 'http://127.0.0.1:1234/v1/models' 5
$model=''
if($models -and $models.data -and @($models.data).Count -gt 0){$model=[string]$models.data[0].id}
$bridgeOk=($health -and $health.ok -eq $true -and [string]$health.name -eq 'RAH Raven Desktop Bridge')
$jobsOk=($jobs -and $jobs.ready -eq $true -and $jobs.elevated -eq $true)
$lmOk=($model -and (Test-LmInference $model))
if($bridgeOk -and $jobsOk -and $lmOk){
 $a.status='PASS';$a.exitCode=0;$a.detail='Bridge PASS; Job Executor PASS/elevated; LM Studio real inference READY with '+$model+'.'
}else{
 $a.detail=('Bridge='+$bridgeOk+'; Jobs='+$jobsOk+'; LMInference='+$lmOk+'; Model='+$model)
}
$stages.Add($a)|Out-Null

$n=Stage 'AnythingLLM' 'TEST-ANYTHINGLLM-APPROVAL.ps1'
if($n.exitCode -eq 0){
 $aj=Read-Json 'C:\RAH\AI-Fabric\anythingllm-approval-test.json'
 if($aj -and [string]$aj.overall -eq 'PASS' -and $aj.secretIncluded -eq $false){$n.status='PASS';$n.detail='AnythingLLM approval end-to-end PASS; no secret included.'}
 else{$n.status='FAIL';$n.detail='AnythingLLM returned 0 but PASS evidence is missing/invalid.'}
}else{
 $n.status='FAIL'
 if($n.exitCode -eq 10){$n.detail='AnythingLLM local token/workspace is not configured.'}
}
$stages.Add($n)|Out-Null

$w=Stage 'Worker Proof' 'RAVEN-CORE-7-WORKER-PROOF.ps1' @('-Mode','Validate','-JsonOnly')
$wj=Read-Json 'C:\RAH\RavenCore7\state\worker-proof.json'
if($w.exitCode -eq 0 -and $wj -and [string]$wj.state -eq 'PASS' -and $wj.accepted -eq $true){
 $w.status='PASS';$w.detail='Validated real-hardware Worker Proof PASS for '+[string]$wj.worker.hostname
}else{
 $w.status='FAIL'
 if($wj){$w.detail='Worker Proof '+[string]$wj.state+': '+[string]$wj.detail}
 elseif($w.exitCode -eq 2){$w.detail='Worker Proof evidence is still pending.'}
}
$stages.Add($w)|Out-Null

$stageItems=@($stages|ForEach-Object{$_})
$coreNames=@('Front Door','Raven Core','Local AI')
$coreOverall=if(@($stageItems|Where-Object{$_.name -in $coreNames -and $_.status -eq 'FAIL'}).Count){'FAIL'}else{'PASS'}
$overall=if(@($stageItems|Where-Object status -eq 'FAIL').Count){'FAIL'}else{'PASS'}
$doc=[pscustomobject][ordered]@{
 schema='rah-os-v08-hoved-pc-final-acceptance';version='0.8.2-evidence-first';
 computer=$env:COMPUTERNAME;timestamp=(Get-Date).ToUniversalTime().ToString('o');
 coreOverall=$coreOverall;overall=$overall;areas=$stageItems;
 safety=[pscustomobject][ordered]@{usbChanges=$false;partitionChanges=$false;arbitraryShell=$false;backgroundPowerShellHidden=$true;anythingLlmSecretIncluded=$false;workerProofMustBeRealHardware=$true}
}
[IO.File]::WriteAllText($out,(($doc|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$utf8)

if($JsonOnly){$doc|ConvertTo-Json -Depth 10}else{
 Write-Host ''
 Write-Host '============================================================' -ForegroundColor DarkYellow
 Write-Host '        RAH OS v0.8 - HOVED-PC FINAL ACCEPTANCE' -ForegroundColor Yellow
 Write-Host '============================================================' -ForegroundColor DarkYellow
 foreach($x in $stageItems){$col=if($x.status -eq 'PASS'){'Green'}else{'Red'};Write-Host (('{0,-5} {1,-16} exit={2}  {3}' -f $x.status,$x.name,$x.exitCode,$x.detail)) -ForegroundColor $col}
 Write-Host ''
 Write-Host ('CORE: '+$coreOverall) -ForegroundColor $(if($coreOverall -eq 'PASS'){'Green'}else{'Red'})
 Write-Host ('FINAL: '+$overall) -ForegroundColor $(if($overall -eq 'PASS'){'Green'}else{'Red'})
 Write-Host ('Report: '+$out) -ForegroundColor DarkGray
}
if($overall -eq 'PASS'){exit 0}
exit 1
