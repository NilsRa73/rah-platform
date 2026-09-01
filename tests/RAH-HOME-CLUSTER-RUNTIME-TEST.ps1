$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$agent=Join-Path $root 'RAH-HOME-NODE-AGENT.ps1'
$client=Join-Path $root 'RAH-HOME-NODE-CLIENT.ps1'
$controller=Join-Path $root 'RAH-HOME-CLUSTER-CONTROLLER.ps1'
$port=28767
$testHome=Join-Path $env:RUNNER_TEMP 'rah-cluster-runtime-home'
New-Item -ItemType Directory -Path $testHome -Force|Out-Null
$oldLocal=$env:LOCALAPPDATA;$env:LOCALAPPDATA=$testHome
$out=Join-Path $testHome 'agent.out.txt';$err=Join-Path $testHome 'agent.err.txt';$p=$null
try{
 $p=Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$agent,'-ListenAddress','127.0.0.1','-Port',"$port") -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
 $code=$null
 for($i=0;$i-lt50;$i++){Start-Sleep -Milliseconds 200;if(Test-Path $out){$m=Select-String -Path $out -Pattern 'PAIR CODE: (\d{6})'|Select-Object -First 1;if($m){$code=$m.Matches[0].Groups[1].Value;break}};if($p.HasExited){throw "Agent exited early: $(Get-Content $err -Raw -ErrorAction SilentlyContinue)"}}
 if(-not $code){throw 'Fant ikke PAIR CODE.'}
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress 127.0.0.1 -Port $port -Action pair -PairCode $code | Out-Null
 if($LASTEXITCODE-ne0){throw 'Pairing failed.'}
 $planPath=Join-Path $testHome 'plan.json';$resultPath=Join-Path $testHome 'results.json'
 [pscustomobject]@{schema='rah-home-cluster-plan';version=1;nodes=@(
  [pscustomobject]@{nodeAddress='127.0.0.1';port=$port;job='health'},
  [pscustomobject]@{nodeAddress='127.0.0.1';port=$port;job='systemInfo'},
  [pscustomobject]@{nodeAddress='127.0.0.1';port=$port;job='benchmark'}
 )}|ConvertTo-Json -Depth 6|Set-Content $planPath -Encoding utf8
 & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $controller -PlanPath $planPath -OutputPath $resultPath
 if($LASTEXITCODE-ne0){throw 'Controller failed.'}
 if(-not(Test-Path $resultPath)){throw 'Result file missing.'}
 $r=Get-Content $resultPath -Raw|ConvertFrom-Json
 if($r.schema-ne'rah-home-cluster-results'-or$r.version-ne1){throw 'Bad result schema.'}
 if(@($r.results).Count-ne3){throw 'Expected 3 results.'}
 foreach($x in @($r.results)){if(-not$x.ok){throw "Cluster job failed: $($x.job)"}}
 Write-Host 'PASS: real Windows Cluster Controller runtime integration'
}finally{if($p-and-not$p.HasExited){Stop-Process -Id $p.Id -Force};$env:LOCALAPPDATA=$oldLocal}
