param(
  [ValidateSet('Validate','Repair')]
  [string]$Mode='Validate',
  [switch]$JsonOnly,
  [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'

$Version='1.0.0'
$Root='C:\RAH\RavenCore7'
$State=Join-Path $Root 'state'
$Out=Join-Path $State 'job-executor-proof.json'
$Utf8=New-Object Text.UTF8Encoding($false)
$Base='http://127.0.0.1:18765'
$Health=$Base+'/agent/jobs/health'
$Jobs=$Base+'/agent/jobs'
$TaskName='RAH Raven Bridge'

function Get-Json([string]$Uri,[int]$Timeout=5){
  if($Uri -notlike 'http://127.0.0.1:18765/*'){return $null}
  try{return Invoke-RestMethod -Uri $Uri -TimeoutSec $Timeout -ErrorAction Stop}catch{return $null}
}

function Test-ExecutorReady {
  $j=Get-Json $Health 4
  return ($j -and $j.ready -eq $true -and $j.elevated -eq $true -and [string]$j.mode -eq 'queued-read-only-allowlist')
}

function Test-HighestTask {
  try{
    $t=Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    return ([string]$t.Principal.RunLevel -eq 'Highest')
  }catch{return $false}
}

function Write-Proof([string]$Overall,[string]$Detail,$Evidence=$null){
  New-Item -ItemType Directory -Force -Path $State|Out-Null
  $doc=[pscustomobject][ordered]@{
    schema='rah-raven-job-executor-proof-v1'
    version=$Version
    timestamp=(Get-Date).ToUniversalTime().ToString('o')
    computer=$env:COMPUTERNAME
    overall=$Overall
    detail=$Detail
    evidence=$Evidence
    safety=[pscustomobject][ordered]@{
      readOnly=$true
      filesModified=$false
      arbitraryCommands=$false
      arbitraryPaths=$false
      callerArguments=$false
      externalNetwork=$false
      secretsRead=$false
    }
  }
  [IO.File]::WriteAllText($Out,(($doc|ConvertTo-Json -Depth 10)+[Environment]::NewLine),$Utf8)
  if($JsonOnly){$doc|ConvertTo-Json -Depth 10}else{
    $color=if($Overall -eq 'PASS'){'Green'}else{'Red'}
    Write-Host ('JOB EXECUTOR PROOF: '+$Overall) -ForegroundColor $color
    Write-Host $Detail
    Write-Host ('Report: '+$Out) -ForegroundColor DarkGray
  }
  if($Overall -eq 'PASS'){exit 0}
  exit 1
}

if($SelfTest){
  if($Base -ne 'http://127.0.0.1:18765'){throw 'Loopback contract failed.'}
  if($TaskName -ne 'RAH Raven Bridge'){throw 'Task contract failed.'}
  Write-Host 'PASS: Raven Job Executor Proof self-test'
  exit 0
}

if(-not(Test-ExecutorReady)){
  if($Mode -ne 'Repair'){
    Write-Proof 'FAIL' 'Job Executor is not ready/elevated. Run Repair mode or start the canonical Highest Raven task.'
  }
  if(-not(Test-HighestTask)){
    Write-Proof 'FAIL' 'Canonical RAH Raven Bridge scheduled task is missing or not RunLevel Highest.'
  }
  try{Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop}catch{
    Write-Proof 'FAIL' ('Could not start canonical Raven task: '+$_.Exception.Message)
  }
  $deadline=(Get-Date).AddSeconds(45)
  do{
    Start-Sleep -Milliseconds 500
    if(Test-ExecutorReady){break}
  }while((Get-Date)-lt$deadline)
  if(-not(Test-ExecutorReady)){
    Write-Proof 'FAIL' 'Job Executor did not become ready/elevated after starting the canonical Highest Raven task.'
  }
}

try{
  $client='job-proof-'+[guid]::NewGuid().ToString('N').Substring(0,12)
  $body=@{
    capability='system-inventory'
    confirm=$true
    client_request_id=$client
  }|ConvertTo-Json
  $submit=Invoke-RestMethod -Method Post -Uri $Jobs -ContentType 'application/json' -Body $body -TimeoutSec 15 -ErrorAction Stop
  if($submit.accepted -ne $true -or [string]::IsNullOrWhiteSpace([string]$submit.job.id)){
    throw 'Job was not accepted.'
  }
  $jobId=[string]$submit.job.id
  $deadline=(Get-Date).AddSeconds(45)
  $poll=$null
  do{
    Start-Sleep -Milliseconds 300
    $poll=Get-Json ($Jobs+'/'+$jobId) 8
    if($poll -and [string]$poll.job.status -in @('succeeded','failed')){break}
  }while((Get-Date)-lt$deadline)

  if(-not$poll){throw 'Job poll returned no JSON.'}
  if([string]$poll.job.status -ne 'succeeded'){throw ('Job status='+[string]$poll.job.status)}
  $r=$poll.job.result
  if($r.ok -ne $true){throw 'result.ok is not true.'}
  if($r.read_only -ne $true){throw 'read_only is not true.'}
  if($r.files_modified -ne $false){throw 'files_modified is not false.'}
  if($r.arbitrary_commands -ne $false){throw 'arbitrary_commands is not false.'}
  if([string]$r.execution_mode -ne 'queued-after-explicit-confirm'){throw ('Unexpected execution_mode='+[string]$r.execution_mode)}
  if(@($r.tools_executed) -notcontains 'system-inventory'){throw 'system-inventory was not recorded in tools_executed.'}

  $evidence=[pscustomobject][ordered]@{
    jobId=$jobId
    capability='system-inventory'
    status=[string]$poll.job.status
    executorPid=$poll.executor.pid
    executorElevated=$poll.executor.elevated
    executorReady=$poll.executor.ready
    readOnly=$r.read_only
    filesModified=$r.files_modified
    arbitraryCommands=$r.arbitrary_commands
    executionMode=[string]$r.execution_mode
    toolsExecuted=@($r.tools_executed)
  }
  Write-Proof 'PASS' 'Real queued system-inventory job completed under elevated Raven with the read-only safety contract intact.' $evidence
}catch{
  Write-Proof 'FAIL' ('Real Job Executor proof failed: '+$_.Exception.Message)
}
