param([Parameter(Mandatory=$true)][string]$SourceRef,[switch]$SelfTest)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue'
$root='C:\RAH\RavenOS';$state=Join-Path $root 'state';$report=Join-Path $state 'RAH-OS-v0.8-FINALIZE.json';$utf8=New-Object Text.UTF8Encoding($false)
if($SourceRef-ne'main'-and$SourceRef-notmatch'^[0-9a-fA-F]{40}$'){throw 'SourceRef must be main or a 40-character Git SHA.'}
$base='https://raw.githubusercontent.com/NilsRa73/rah-platform/'+$SourceRef
$env:RAH_OS_SOURCE_REF=$SourceRef
$files=@('START-HER-RAH-OS-v0.8.cmd','RAH-OS-v0.8-SELFTEST.ps1','RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1','RAVEN-CORE-7.ps1','RAVEN-AI-SELF-CHECK.ps1','TEST-ANYTHINGLLM-APPROVAL.ps1','CONFIGURE-RAH-PROJECT-MEMORY.ps1','CONFIGURE-RAH-PROJECT-MEMORY.cmd','SYNC-RAH-PROJECT-MEMORY.ps1','SYNC-RAH-PROJECT-MEMORY.cmd','RAVEN-CORE-7-WORKER-PROOF.ps1','RAH-RAVEN-2PC-GUI.ps1','RAH-2PC-CLIENT.ps1','RAH-2PC-ACCEPTANCE.ps1','RAH-HARDWARE-INVENTORY.ps1','RAH-HARDWARE-REGISTRY.ps1','START-RAH-AI-FABRIC.cmd','INSTALL-RAH-AI-FABRIC.ps1')
function Phase($n){Write-Host '';Write-Host '============================================================' -ForegroundColor DarkYellow;Write-Host (' '+$n) -ForegroundColor Yellow;Write-Host '============================================================' -ForegroundColor DarkYellow}
function Run($p,[string[]]$a=@(),[switch]$Interactive){if(!(Test-Path $p)){return 127};if($Interactive){& powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File $p @a}else{& powershell.exe -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $p @a};return $LASTEXITCODE}
function AiGate(){
 $p='C:\RAH\Status\AI-SELF-CHECK-LATEST.txt';if(!(Test-Path $p)){return $false};$t=Get-Content $p -Raw
 return ($t-match'(?im)^Bridge\s*:\s*PASS\s*$'-and$t-match'(?im)^Job Executor\s*:\s*PASS\s*$'-and$t-match'(?im)^LM Studio\s*:\s*READY\s*$')
}
function Repair{
 New-Item -ItemType Directory -Force -Path $root,$state,(Join-Path $root 'logs')|Out-Null
 $marker=Join-Path $root 'RAH-OS-SOURCE-REF.txt';$old=if(Test-Path $marker){(Get-Content $marker -Raw).Trim()}else{''}
 $refresh=$old-ne$SourceRef;foreach($f in$files){if(!(Test-Path (Join-Path $root $f))){$refresh=$true}}
 if($refresh){foreach($f in$files){$d=Join-Path $root $f;$tmp=$d+'.download';Invoke-WebRequest -UseBasicParsing -Uri ($base+'/'+$f) -OutFile $tmp -TimeoutSec 90;if((Get-Item $tmp).Length-lt20){throw 'Bad download: '+$f};Move-Item $tmp $d -Force};[IO.File]::WriteAllText($marker,$SourceRef,$utf8)}
 foreach($f in$files|Where-Object{$_-like'*.ps1'}){$e=$null;$tok=$null;[System.Management.Automation.Language.Parser]::ParseFile((Join-Path $root $f),[ref]$tok,[ref]$e)|Out-Null;if($e.Count){throw ($f+': '+(($e|ForEach-Object Message)-join'; '))}}
 Copy-Item (Join-Path $root 'RAH-OS-v0.8-SELFTEST.ps1') (Join-Path $root 'RAH-OS-SELFTEST.ps1') -Force
 foreach($f in@('RAVEN-AI-SELF-CHECK.ps1','TEST-ANYTHINGLLM-APPROVAL.ps1','CONFIGURE-RAH-PROJECT-MEMORY.ps1','CONFIGURE-RAH-PROJECT-MEMORY.cmd','SYNC-RAH-PROJECT-MEMORY.ps1','SYNC-RAH-PROJECT-MEMORY.cmd')){Copy-Item (Join-Path $root $f) (Join-Path 'C:\RAH' $f) -Force}
 foreach($n in@('RAH Raven Node Agent 18766','RAH Raven AI Providers','RAH Raven AI Fabric Watchdog','RAH Raven AI Self Check','RAH Raven Project Memory Sync')){try{$t=Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue;if($t){$a=@($t.Actions)[0];if($a.Execute-match'(?i)powershell' -and $a.Arguments-notmatch'(?i)-WindowStyle\s+Hidden'){Set-ScheduledTask -TaskName $n -Action (New-ScheduledTaskAction -Execute $a.Execute -Argument ('-WindowStyle Hidden '+$a.Arguments))|Out-Null}}}catch{}}
 if((Run (Join-Path $root 'RAH-OS-v0.8-SELFTEST.ps1') @('-Quick','-JsonOnly'))-ne0){throw 'Self-test failed after repair.'}
}
function StartAI{
 $self=Join-Path $root 'RAVEN-AI-SELF-CHECK.ps1';$null=Run $self @();if(AiGate){return}
 $inst=Join-Path $root 'INSTALL-RAH-AI-FABRIC.ps1';$null=Run $inst @('-Mode','Repair','-NoPause','-Ref',$SourceRef)
 foreach($n in@('RAH Raven Bridge','RAH Raven AI Providers','RAH Raven AI Fabric Watchdog','RAH Raven AI Self Check')){try{if(Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue){Start-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue}}catch{}}
 Start-Sleep 4;$null=Run $self @();if(!(AiGate)){throw 'Local AI failed: Bridge, Job Executor and LM Studio must be PASS/READY.'}
}
function Anything{
 $test=Join-Path $root 'TEST-ANYTHINGLLM-APPROVAL.ps1';$c=Run $test @();if($c-eq0){return};if($c-ne10){throw 'AnythingLLM test failed. Exit='+$c}
 Write-Host '';Write-Host 'ANYTHINGLLM ONE-TIME SETUP' -ForegroundColor Yellow;Write-Host 'Paste the Developer API token only in this local console; it is never sent to GitHub/ChatGPT.'
 $c=Run (Join-Path $root 'CONFIGURE-RAH-PROJECT-MEMORY.ps1') @() -Interactive;if($c-ne0){throw 'AnythingLLM setup failed. Exit='+$c}
 foreach($n in@('RAH Raven Bridge','RAH Raven AI Providers')){try{if(Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue){Start-ScheduledTask -TaskName $n}}catch{}};Start-Sleep 4
 if((Run $test @())-ne0){throw 'AnythingLLM approval still failed after setup.'}
}
function Worker{
 $proof=Join-Path $root 'RAVEN-CORE-7-WORKER-PROOF.ps1';$c=Run $proof @('-Mode','Validate','-JsonOnly');$j=$null;try{$j=Get-Content 'C:\RAH\RavenCore7\state\worker-proof.json' -Raw|ConvertFrom-Json}catch{};if($c-eq0-and$j-and$j.state-eq'PASS'-and$j.accepted-eq$true){return}
 Write-Host '';Write-Host 'WORKER PROOF - REAL HARDWARE' -ForegroundColor Yellow;Write-Host 'In the 2-PC window: start Lenovo worker, paste fresh token, RUN SYSTEM INVENTORY, then FINAL REAL-HARDWARE ACCEPTANCE.'
 $dir='C:\RAH\2PCProof';New-Item -ItemType Directory -Force -Path $dir|Out-Null;foreach($f in@('RAH-RAVEN-2PC-GUI.ps1','RAH-2PC-CLIENT.ps1','RAH-2PC-ACCEPTANCE.ps1','RAH-HARDWARE-INVENTORY.ps1','RAH-HARDWARE-REGISTRY.ps1')){Copy-Item (Join-Path $root $f) (Join-Path $dir $f) -Force};[IO.File]::WriteAllText((Join-Path $dir 'RAH-2PC-SOURCE-REF.txt'),$SourceRef,$utf8)
 $args=@('-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-STA','-File',('"'+(Join-Path $dir 'RAH-RAVEN-2PC-GUI.ps1')+'"'));$p=Start-Process powershell.exe -ArgumentList $args -WindowStyle Hidden -Wait -PassThru;if($p.ExitCode-ne0){throw '2-PC GUI failed. Exit='+$p.ExitCode}
 $c=Run $proof @('-Mode','Validate','-JsonOnly');$j=$null;try{$j=Get-Content 'C:\RAH\RavenCore7\state\worker-proof.json' -Raw|ConvertFrom-Json}catch{};if($c-ne0-or!$j-or$j.state-ne'PASS'-or$j.accepted-ne$true){throw 'Worker Proof is not validated PASS.'}
}
if($SelfTest){if($files.Count-ne@($files|Select-Object -Unique).Count){throw 'Duplicate manifest.'};Write-Host 'PASS: RAH OS v0.8 finalizer contract';exit 0}
$started=Get-Date;$r=[ordered]@{schema='rah-os-v08-finalizer-v1';version='0.8.1-final';sourceRef=$SourceRef;precheck='NOT_RUN';repair='NOT_RUN';start='NOT_RUN';postcheck='NOT_RUN';localAI='NOT_RUN';anythingLLM='NOT_RUN';workerProof='NOT_RUN';final='FAIL';detail=''}
try{
 Phase 'PRECHECK';$missing=@($files|Where-Object{!(Test-Path (Join-Path $root $_))});$r.precheck=if($missing.Count){'REPAIR_NEEDED'}else{'PASS'};Write-Host ('PRECHECK  '+$r.precheck)
 Phase 'REPAIR';Repair;$r.repair='PASS';Write-Host 'REPAIR    PASS' -ForegroundColor Green
 Phase 'START';StartAI;Copy-Item (Join-Path $root 'START-HER-RAH-OS-v0.8.cmd') 'C:\RAH\START-HER.cmd' -Force;$r.localAI='PASS';Write-Host 'LOCAL AI  PASS' -ForegroundColor Green;Anything;$r.anythingLLM='PASS';Write-Host 'ANYTHING  PASS' -ForegroundColor Green;Worker;$r.workerProof='PASS';Write-Host 'WORKER    PASS' -ForegroundColor Green;$r.start='PASS'
 Phase 'POSTCHECK';if((Run (Join-Path $root 'RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1') @('-JsonOnly'))-ne0){throw 'Final acceptance failed.'};$r.postcheck='PASS';$r.final='PASS'
}catch{$r.detail=$_.Exception.Message;if($r.repair-eq'NOT_RUN'){$r.repair='FAIL'};if($r.start-eq'NOT_RUN'){$r.start='FAIL'};if($r.postcheck-eq'NOT_RUN'){$r.postcheck='FAIL'}}finally{[IO.File]::WriteAllText($report,((([pscustomobject]$r)|ConvertTo-Json -Depth 8)+[Environment]::NewLine),$utf8)}
Write-Host '';Write-Host '============================================================' -ForegroundColor DarkYellow;Write-Host (' FINAL: '+$r.final) -ForegroundColor $(if($r.final-eq'PASS'){'Green'}else{'Red'});Write-Host '============================================================' -ForegroundColor DarkYellow;Write-Host ('PRECHECK  : '+$r.precheck);Write-Host ('REPAIR    : '+$r.repair);Write-Host ('START     : '+$r.start);Write-Host ('POSTCHECK : '+$r.postcheck);Write-Host ('Local AI  : '+$r.localAI);Write-Host ('Anything  : '+$r.anythingLLM);Write-Host ('Worker    : '+$r.workerProof);if($r.detail){Write-Host ('DETAIL    : '+$r.detail) -ForegroundColor Yellow};Write-Host ('Report    : '+$report) -ForegroundColor DarkGray
if($r.final-eq'PASS'){exit 0};exit 1
