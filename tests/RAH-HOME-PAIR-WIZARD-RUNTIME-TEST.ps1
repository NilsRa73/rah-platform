$ErrorActionPreference='Stop'
$root=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$agent=Join-Path $root 'RAH-HOME-NODE-AGENT.ps1'
$client=Join-Path $root 'RAH-HOME-NODE-CLIENT.ps1'
$wizard=Join-Path $root 'RAH-HOME-PAIR-WIZARD.ps1'
$port=28768
$testHome=Join-Path $env:RUNNER_TEMP 'rah-pair-wizard-runtime-home'
New-Item -ItemType Directory -Path $testHome -Force|Out-Null
$oldLocal=$env:LOCALAPPDATA;$env:LOCALAPPDATA=$testHome
$out=Join-Path $testHome 'agent.out.txt';$err=Join-Path $testHome 'agent.err.txt'
$receiptPath=Join-Path $testHome 'rah-home-pairing.json'
$p=$null

function Test-Rfc1918([string]$ip){
 $parts=$ip.Split('.');if($parts.Count-ne4){return $false}
 try{$n=@($parts|ForEach-Object{[int]$_})}catch{return $false}
 if($n.Count-ne4-or($n|Where-Object{$_-lt0-or$_-gt255})){return $false}
 return($n[0]-eq10)-or($n[0]-eq192-and$n[1]-eq168)-or($n[0]-eq172-and$n[1]-ge16-and$n[1]-le31)
}

try{
 $privateIp=Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop |
  Where-Object { $_.IPAddress -and (Test-Rfc1918 $_.IPAddress) } |
  Sort-Object InterfaceMetric,SkipAsSource |
  Select-Object -ExpandProperty IPAddress -First 1
 if(-not$privateIp){throw 'Fant ingen RFC1918 IPv4 på Windows-runneren for Pair Wizard LAN-test.'}

 $p=Start-Process powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$agent,'-ListenAddress',$privateIp,'-AllowLan','-Port',"$port") -RedirectStandardOutput $out -RedirectStandardError $err -PassThru
 $code=$null
 for($i=0;$i-lt60;$i++){
  Start-Sleep -Milliseconds 200
  if(Test-Path $out){$m=Select-String -Path $out -Pattern 'PAIR CODE: (\d{6})'|Select-Object -First 1;if($m){$code=$m.Matches[0].Groups[1].Value;break}}
  if($p.HasExited){throw "Agent exited early: $(Get-Content $err -Raw -ErrorAction SilentlyContinue)"}
 }
 if(-not$code){throw 'Fant ikke PAIR CODE fra LAN-bundet agent.'}

 $wizardOutput=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wizard -NodeAddress $privateIp -Port $port -PairCode $code -OutputPath $receiptPath -NoOpen 2>&1
 $wizardCode=$LASTEXITCODE
 $wizardText=$wizardOutput|Out-String
 if($wizardCode-ne0){throw "Pair Wizard feilet: $wizardText"}
 if($wizardText-notmatch 'autentisert mot RAH Home Node Agent'){throw "Pair Wizard manglet autentisert ferdigstatus: $wizardText"}
 if($wizardText-notmatch 'ikke signert'){throw 'Pair Wizard må tydelig merke receipt som usignert pairing-evidens.'}
 if(-not(Test-Path -LiteralPath $receiptPath -PathType Leaf)){throw 'Pair Wizard opprettet ikke receipt-filen.'}

 $raw=Get-Content -LiteralPath $receiptPath -Raw
 if($raw.Length-gt65536){throw 'Receipt er urimelig stor.'}
 if($raw-match '"token"\s*:'){throw 'Receipt lekker token.'}
 $receipt=$raw|ConvertFrom-Json
 $names=@($receipt.PSObject.Properties.Name|Sort-Object)
 $expected=@('computerName','nodeAddress','pairedAt','port','schema','source','version'|Sort-Object)
 if(($names -join '|')-ne($expected -join '|')){throw "Receipt har feil feltsett: $($names -join ', ')"}
 if($receipt.schema-ne'rah-home-pairing-receipt'-or[int]$receipt.version-ne1){throw 'Receipt schema/version er ugyldig.'}
 if([string]$receipt.nodeAddress-ne$privateIp-or[int]$receipt.port-ne$port){throw 'Receipt peker ikke på den testede noden.'}
 if($receipt.source-ne'explicit-pair-code-and-authenticated-system-info'){throw 'Receipt provenance er ugyldig.'}
 if([string]::IsNullOrWhiteSpace([string]$receipt.computerName)){throw 'Receipt mangler computerName.'}
 $pairedAt=[DateTimeOffset]::Parse([string]$receipt.pairedAt)
 if([Math]::Abs(((Get-Date).ToUniversalTime()-$pairedAt.UtcDateTime).TotalMinutes)-gt5){throw 'Receipt pairedAt er ikke fersk.'}

 $auth=& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $client -NodeAddress $privateIp -Port $port -Action systemInfo 2>&1
 $authCode=$LASTEXITCODE;$authText=$auth|Out-String
 if($authCode-ne0-or$authText-notmatch '"ok"\s*:\s*true'){throw "Autentisert systemInfo etter Wizard feilet: $authText"}
 $info=$authText|ConvertFrom-Json
 if([string]$info.result.computerName-cne[string]$receipt.computerName){throw 'Receipt computerName matcher ikke autentisert systemInfo.'}

 Write-Host "PASS: real Windows Pair Wizard LAN pairing + token-free receipt ($privateIp)"
}
finally{
 if($p-and-not$p.HasExited){Stop-Process -Id $p.Id -Force}
 $env:LOCALAPPDATA=$oldLocal
}
