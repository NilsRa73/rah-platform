$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$agent=Join-Path $root 'RAH-HOME-NODE-AGENT.ps1'
$client=Join-Path $root 'RAH-HOME-NODE-CLIENT.ps1'
$port=28766
$testHome=Join-Path $env:RUNNER_TEMP 'rah-node-runtime-home'
New-Item -ItemType Directory -Path $testHome -Force|Out-Null
$oldLocal=$env:LOCALAPPDATA;$env:LOCALAPPDATA=$testHome
$out=Join-Path $testHome 'agent.out.txt';$err=Join-Path $testHome 'agent.err.txt'
$p=$null
function Run-Client { param([string[]]$ClientArgs) $o=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client @ClientArgs 2>&1;$code=$LASTEXITCODE;[pscustomobject]@{Code=$code;Text=($o|Out-String)} }
try{
 $p=Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$agent,'-ListenAddress','127.0.0.1','-Port',"$port") -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
 $code=$null
 for($i=0;$i-lt50;$i++){Start-Sleep -Milliseconds 200;if(Test-Path $out){$m=Select-String -Path $out -Pattern 'PAIR CODE: (\d{6})'|Select-Object -First 1;if($m){$code=$m.Matches[0].Groups[1].Value;break}};if($p.HasExited){throw "Agent exited early: $(Get-Content $err -Raw -ErrorAction SilentlyContinue)"}}
 if(-not$code){throw 'Fant ikke PAIR CODE fra agent.'}
 $hello=Run-Client -ClientArgs @('-NodeAddress','127.0.0.1','-Port',"$port",'-Action','hello');if($hello.Code-ne0-or$hello.Text-notmatch 'RAH Home Node Agent'){throw "hello failed: $($hello.Text)"}
 $wrong=Run-Client -ClientArgs @('-NodeAddress','127.0.0.1','-Port',"$port",'-Action','pair','-PairCode','000000');if($wrong.Code-eq0-or$wrong.Text-notmatch 'pair-code-rejected'){throw "wrong pair was not rejected: $($wrong.Text)"}
 $pair=Run-Client -ClientArgs @('-NodeAddress','127.0.0.1','-Port',"$port",'-Action','pair','-PairCode',$code);if($pair.Code-ne0){throw "pair failed: $($pair.Text)"}
 foreach($action in @('health','systemInfo','benchmark')){$r=Run-Client -ClientArgs @('-NodeAddress','127.0.0.1','-Port',"$port",'-Action',$action);if($r.Code-ne0-or$r.Text-notmatch '"ok"\s*:\s*true'){throw "$action failed: $($r.Text)"}}
 $peers=Join-Path $testHome 'RAH\home-node-peers.json';if(-not(Test-Path $peers)){throw 'Peer token file missing after pair.'}
 $saved=Get-Content $peers -Raw|ConvertFrom-Json;$saved.peers[0].token='definitely-wrong-token';$saved|ConvertTo-Json -Depth 6|Set-Content $peers -Encoding utf8
 $unauth=Run-Client -ClientArgs @('-NodeAddress','127.0.0.1','-Port',"$port",'-Action','health');if($unauth.Code-eq0-or$unauth.Text-notmatch 'unauthorized'){throw "unauthorized request was not rejected: $($unauth.Text)"}
 Write-Host 'PASS: real Windows Node Agent/Client runtime integration'
}finally{if($p-and-not$p.HasExited){Stop-Process -Id $p.Id -Force};$env:LOCALAPPDATA=$oldLocal}
