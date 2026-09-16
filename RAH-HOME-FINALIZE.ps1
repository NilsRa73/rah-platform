param(
    [ValidateSet('Auto','Leader','Worker')][string]$Mode = 'Auto',
    [ValidateRange(1024,65535)][int]$Port = 18766,
    [string]$InstallRoot = 'C:\RAH\Home',
    [string]$DesktopPath = '',
    [string]$SourceDirectory = '',
    [string]$WorkerAddress = '',
    [string]$PairCode = '',
    [switch]$NoRemote,
    [switch]$SkipFirewall,
    [switch]$SkipAutostart,
    [switch]$NoStart,
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:RahHomeFinalizeVersion = '1.0.0'
$script:RahSourceBase = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/main'
$script:RahMaxScriptBytes = 4MB
$script:RahWorkerTaskName = 'RAH Home Worker'
$script:RahFirewallName = 'RAH Home Worker TCP 18766'

function Test-RahPrivateIPv4 {
    param([Parameter(Mandatory)][string]$Address)
    $parts = $Address.Split('.')
    if ($parts.Count -ne 4) { return $false }
    $n = @()
    foreach ($part in $parts) {
        if ($part -notmatch '^\d{1,3}$') { return $false }
        $v = [int]$part
        if ($v -lt 0 -or $v -gt 255 -or [string]$v -ne $part) { return $false }
        $n += $v
    }
    return ($n[0] -eq 10 -or ($n[0] -eq 172 -and $n[1] -ge 16 -and $n[1] -le 31) -or ($n[0] -eq 192 -and $n[1] -eq 168))
}

function Resolve-RahDesktopPath {
    param([string]$Requested)
    if ($Requested) { return [IO.Path]::GetFullPath($Requested) }
    $p = [Environment]::GetFolderPath('Desktop')
    if (-not $p) { throw 'Fant ikke skrivebordsmappen.' }
    return [IO.Path]::GetFullPath($p)
}

function Assert-RahPowerShellFile {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string[]]$Markers)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Mangler PowerShell-fil: $Path" }
    $item = Get-Item -LiteralPath $Path -ErrorAction Stop
    if ($item.Length -le 0 -or $item.Length -gt $script:RahMaxScriptBytes) { throw "Ugyldig filstorrelse: $Path" }
    $tokens=$null; $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($item.FullName,[ref]$tokens,[ref]$errors) | Out-Null
    if (@($errors).Count) { throw "PowerShell-parser avviste $Path : $($errors[0].Message)" }
    $text = [IO.File]::ReadAllText($item.FullName)
    foreach($marker in $Markers) { if (-not $text.Contains($marker)) { throw "Kontraktmarkor mangler i $Path : $marker" } }
    return $item.FullName
}

function Get-RahScript {
    param([string]$Name,[string[]]$Markers,[string]$BootstrapRoot)
    New-Item -ItemType Directory -Path $BootstrapRoot -Force | Out-Null
    $target = Join-Path $BootstrapRoot $Name
    if ($SourceDirectory) {
        $source = Join-Path ([IO.Path]::GetFullPath($SourceDirectory)) $Name
        if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { throw "SourceDirectory mangler $Name" }
        Copy-Item -LiteralPath $source -Destination $target -Force
    } else {
        Invoke-WebRequest -UseBasicParsing -Uri "$script:RahSourceBase/$Name" -OutFile $target -ErrorAction Stop
    }
    return Assert-RahPowerShellFile -Path $target -Markers $Markers
}

function Invoke-RahChildPowerShell {
    param([Parameter(Mandatory)][string[]]$Arguments,[switch]$Capture)
    $exe = Join-Path $PSHOME 'powershell.exe'
    if ($Capture) {
        $old = $ErrorActionPreference
        try { $ErrorActionPreference='Continue'; $raw=& $exe @Arguments 2>&1; $code=$LASTEXITCODE }
        finally { $ErrorActionPreference=$old }
        return [pscustomobject]@{ExitCode=$code;Text=(($raw|Out-String).Trim())}
    }
    & $exe @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Child PowerShell feilet med exit code $LASTEXITCODE." }
}

function Get-RahPrivateLocalAddresses {
    if (-not (Get-Command Get-NetIPAddress -ErrorAction SilentlyContinue)) { return @() }
    $defaultIf = @()
    if (Get-Command Get-NetRoute -ErrorAction SilentlyContinue) {
        $defaultIf = @(Get-NetRoute -AddressFamily IPv4 -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
            Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
            Sort-Object RouteMetric,InterfaceMetric |
            Select-Object -ExpandProperty InterfaceIndex -Unique)
    }
    $result = @()
    foreach($ip in @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue)) {
        $address=[string]$ip.IPAddress
        if (-not (Test-RahPrivateIPv4 $address)) { continue }
        if ($ip.AddressState -and [string]$ip.AddressState -ne 'Preferred') { continue }
        $result += [pscustomobject]@{
            Address=$address
            HasGateway=[bool]($defaultIf -contains [int]$ip.InterfaceIndex)
            Alias=[string]$ip.InterfaceAlias
        }
    }
    return @($result | Sort-Object Address -Unique)
}

function Select-RahWorkerAddress {
    param([string]$Requested)
    $candidates=@(Get-RahPrivateLocalAddresses)
    if ($Requested) {
        $value=$Requested.Trim()
        if (-not (Test-RahPrivateIPv4 $value)) { throw 'WorkerAddress ma vaere privat RFC1918 IPv4.' }
        if (@($candidates|Where-Object Address -eq $value).Count -eq 0) { throw 'WorkerAddress finnes ikke pa en aktiv lokal adapter.' }
        return $value
    }
    $gw=@($candidates|Where-Object HasGateway)
    if ($gw.Count -eq 1) { return [string]$gw[0].Address }
    if ($candidates.Count -eq 1) { return [string]$candidates[0].Address }
    if ($candidates.Count -eq 0) { throw 'Fant ingen aktiv privat RFC1918-adresse.' }
    Write-Host 'Flere private adresser ble funnet:' -ForegroundColor Yellow
    for($i=0;$i -lt $candidates.Count;$i++){ Write-Host ("[{0}] {1}  {2}" -f ($i+1),$candidates[$i].Address,$candidates[$i].Alias) }
    $choice=0; $raw=Read-Host 'Velg RAH-hjemmenett-adresse'
    if (-not [int]::TryParse($raw,[ref]$choice) -or $choice -lt 1 -or $choice -gt $candidates.Count) { throw 'Ugyldig adressevalg.' }
    return [string]$candidates[$choice-1].Address
}

function Test-RahTcpPort {
    param([string]$Address,[int]$TargetPort,[int]$TimeoutMs=1000)
    $tcp=New-Object Net.Sockets.TcpClient
    try {
        $op=$tcp.BeginConnect($Address,$TargetPort,$null,$null); $h=$op.AsyncWaitHandle
        try { if(-not $h.WaitOne($TimeoutMs)){return $false}; $tcp.EndConnect($op); return $true } catch { return $false } finally { $h.Close() }
    } finally { $tcp.Dispose() }
}

function Stop-RahOwnWorkerAgents {
    param([string]$AgentPath)
    $needle=[IO.Path]::GetFileName($AgentPath)
    foreach($p in @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue | Where-Object { ($_.Name -ieq 'powershell.exe' -or $_.Name -ieq 'pwsh.exe') -and $_.CommandLine -and $_.CommandLine.Contains($needle) })) {
        try { Stop-Process -Id ([int]$p.ProcessId) -Force -ErrorAction Stop } catch { }
    }
    Start-Sleep -Milliseconds 400
}

function Start-RahWorkerAgent {
    param([string]$Root,[string]$Address,[int]$TargetPort)
    $agent=Join-Path $Root 'RAH-HOME-NODE-AGENT.ps1'
    Assert-RahPowerShellFile $agent @("RahNodeAgentVersion = '1.0.0'",'RahAllowedActions') | Out-Null
    Stop-RahOwnWorkerAgents $agent
    $logDir=Join-Path $Root 'logs'; New-Item -ItemType Directory -Path $logDir -Force|Out-Null
    $out=Join-Path $logDir 'worker-agent.log'; $err=Join-Path $logDir 'worker-agent.err.log'
    Remove-Item -LiteralPath $out,$err -Force -ErrorAction SilentlyContinue
    $exe=Join-Path $PSHOME 'powershell.exe'
    $args='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$agent+'" -ListenAddress '+$Address+' -AllowLan -Port '+$TargetPort
    $proc=Start-Process -FilePath $exe -ArgumentList $args -RedirectStandardOutput $out -RedirectStandardError $err -WindowStyle Hidden -PassThru
    $code=''; $ready=$false; $deadline=(Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 250
        if($proc.HasExited){ $detail=if(Test-Path $err){Get-Content -Raw $err}else{''}; throw "Worker Agent stoppet under oppstart. $detail" }
        if(Test-Path $out){ $text=Get-Content -Raw $out -ErrorAction SilentlyContinue; if($text -match 'PAIR CODE:\s*(\d{6})'){$code=$Matches[1]} }
        $ready=Test-RahTcpPort $Address $TargetPort 500
    } while(((-not $code)-or(-not $ready))-and(Get-Date)-lt$deadline)
    if(-not $code){throw 'Worker Agent startet, men pairingkode ble ikke fanget.'}
    if(-not $ready){throw 'Worker Agent startet, men TCP-porten ble ikke klar.'}
    return [pscustomobject]@{PairCode=$code;ProcessId=$proc.Id;Stdout=$out;Stderr=$err}
}

function Set-RahWorkerFirewall {
    param([string]$Address,[int]$TargetPort)
    if($SkipFirewall){return 'skipped'}
    Get-NetFirewallRule -DisplayName $script:RahFirewallName -ErrorAction SilentlyContinue|Remove-NetFirewallRule -ErrorAction SilentlyContinue
    New-NetFirewallRule -DisplayName $script:RahFirewallName -Direction Inbound -Action Allow -Protocol TCP -LocalPort $TargetPort -LocalAddress $Address -Profile Private|Out-Null
    return 'ready'
}

function Set-RahWorkerAutostart {
    param([string]$Root,[string]$Address,[int]$TargetPort)
    if($SkipAutostart){return 'skipped'}
    $agent=Join-Path $Root 'RAH-HOME-NODE-AGENT.ps1'; $exe=Join-Path $PSHOME 'powershell.exe'
    $args='-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "'+$agent+'" -ListenAddress '+$Address+' -AllowLan -Port '+$TargetPort
    $action=New-ScheduledTaskAction -Execute $exe -Argument $args
    $trigger=New-ScheduledTaskTrigger -AtLogOn
    $principal=New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Highest
    Register-ScheduledTask -TaskName $script:RahWorkerTaskName -Action $action -Trigger $trigger -Principal $principal -Force|Out-Null
    if(-not(Get-ScheduledTask -TaskName $script:RahWorkerTaskName -ErrorAction Stop)){throw 'Autostart-task ble ikke opprettet.'}
    return 'ready'
}

function Get-RahPeerAddress {
    param([int]$TargetPort)
    $path=Join-Path $env:LOCALAPPDATA 'RAH\home-node-peers.json'
    if(-not(Test-Path $path)){return ''}
    try {
        $doc=Get-Content -Raw $path|ConvertFrom-Json; $found=@()
        foreach($peer in @($doc.peers)){
            $key=[string]$peer.key
            if($key -match '^((?:\d{1,3}\.){3}\d{1,3}):(\d+)$'){
                $ip=$Matches[1]; $p=[int]$Matches[2]
                if($p -eq $TargetPort -and (Test-RahPrivateIPv4 $ip)){$found+=$ip}
            }
        }
        $found=@($found|Select-Object -Unique); if($found.Count -eq 1){return [string]$found[0]}
    } catch {}
    return ''
}

function Invoke-RahClientAction {
    param([string]$ClientPath,[string]$Address,[string]$Action,[string]$Code='')
    $args=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$ClientPath,'-NodeAddress',$Address,'-Port',[string]$Port,'-Action',$Action,'-TimeoutMs','10000')
    if($Action -eq 'pair'){$args+=@('-PairCode',$Code)}
    return Invoke-RahChildPowerShell -Arguments $args -Capture
}

function Convert-RahClientJson {
    param($Invocation,[string]$Context)
    if($Invocation.ExitCode -ne 0){throw "$Context feilet: $($Invocation.Text)"}
    try{return $Invocation.Text|ConvertFrom-Json -ErrorAction Stop}catch{throw "$Context returnerte ikke gyldig JSON."}
}

function Write-RahFinalizeReport {
    param([string]$Root,[string]$FinalMode,[bool]$Pass,$Checks,[string]$Failure='',[string]$RemoteAddress='')
    $dir=Join-Path $Root 'reports'; New-Item -ItemType Directory -Path $dir -Force|Out-Null
    $doc=[pscustomobject]@{schema='rah-home-finalize';version=1;finalizeVersion=$script:RahHomeFinalizeVersion;mode=$FinalMode;computerName=$env:COMPUTERNAME;createdAt=(Get-Date).ToUniversalTime().ToString('o');installRoot=$Root;remoteAddress=$(if($RemoteAddress){$RemoteAddress}else{$null});pass=$Pass;failure=$(if($Failure){$Failure}else{$null});checks=@($Checks)}
    $json=Join-Path $dir 'rah-home-finalize-latest.json'; $txt=Join-Path $Root 'RAH-HOME-FINAL-REPORT.txt'
    [IO.File]::WriteAllText($json,($doc|ConvertTo-Json -Depth 10),(New-Object Text.UTF8Encoding($false)))
    $lines=@('RAH HOME FINAL REPORT','=====================',"Computer : $env:COMPUTERNAME","Mode     : $FinalMode","Result   : $(if($Pass){'PASS'}else{'FAIL'})","Root     : $Root","Remote   : $(if($RemoteAddress){$RemoteAddress}else{'-'})","Created  : $($doc.createdAt)")
    if($Failure){$lines+="Failure  : $Failure"}; $lines+=''
    foreach($c in @($Checks)){$lines+=("[{0}] {1}" -f $(if($c.ok){'OK'}else{'FAIL'}),$c.name)}
    [IO.File]::WriteAllLines($txt,$lines,(New-Object Text.UTF8Encoding($false)))
    return [pscustomobject]@{Json=$json;Text=$txt}
}

function Invoke-RahFinalizeSelfTest {
    foreach($good in @('10.0.0.2','172.16.5.6','192.168.1.9')){if(-not(Test-RahPrivateIPv4 $good)){throw "SelfTest: privat IP avvist: $good"}}
    foreach($bad in @('127.0.0.1','8.8.8.8','0.0.0.0','192.168.001.1')){if(Test-RahPrivateIPv4 $bad){throw "SelfTest: ugyldig IP tillatt: $bad"}}
    if($script:RahHomeFinalizeVersion -ne '1.0.0'){throw 'SelfTest: feil finalize-versjon.'}
    Write-Host 'PASS: RAH Home Finalize v1 self-test' -ForegroundColor Green
}

if($SelfTest){Invoke-RahFinalizeSelfTest;exit 0}
if($Port -ne 18766){throw 'Finalize v1 bruker stable RAH Home-port 18766.'}
$resolvedMode=$Mode
if($resolvedMode -eq 'Auto'){$resolvedMode=if($env:COMPUTERNAME -ieq 'HOVED-PC'){'Leader'}else{'Worker'}}
$root=[IO.Path]::GetFullPath($InstallRoot); $desktop=Resolve-RahDesktopPath $DesktopPath; $bootstrap=Join-Path $root 'bootstrap'
$checks=@();$remote=''
Write-Host '=====================================================================' -ForegroundColor Yellow
Write-Host '                  RAH HOME FINALIZE v1.0.0' -ForegroundColor Yellow
Write-Host '=====================================================================' -ForegroundColor Yellow
Write-Host "PC   : $env:COMPUTERNAME";Write-Host "Mode : $resolvedMode";Write-Host "Root : $root";Write-Host ''

try {
    New-Item -ItemType Directory -Path $root,$desktop,$bootstrap -Force|Out-Null
    if($resolvedMode -eq 'Worker'){
        Write-Host '[1/6] PRECHECK: privat Worker-adresse ...' -ForegroundColor Cyan
        $address=Select-RahWorkerAddress $WorkerAddress; $checks+=[pscustomobject]@{name="private-address:$address";ok=$true}; Write-Host "      $address" -ForegroundColor Green
        Write-Host '[2/6] Installerer/reparerer stable Worker ...' -ForegroundColor Cyan
        $installer=Get-RahScript 'RAH-HOME-INSTALL.ps1' @("RahHomeInstallerVersion = '1.0.0'",'Get-RahComponentManifest','New-RahWorkerShortcut') $bootstrap
        Invoke-RahChildPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$installer,'-SelfTest')
        $ia=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$installer,'-Mode','Worker','-Port','18766','-InstallRoot',$root,'-DesktopPath',$desktop,'-WorkerAddress',$address)
        if($SourceDirectory){$ia+=@('-SourceDirectory',[IO.Path]::GetFullPath($SourceDirectory))}; Invoke-RahChildPowerShell $ia; $checks+=[pscustomobject]@{name='worker-install';ok=$true}
        Write-Host '[3/6] Agent + Client self-test ...' -ForegroundColor Cyan
        Invoke-RahChildPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'RAH-HOME-NODE-AGENT.ps1'),'-SelfTest')
        Invoke-RahChildPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'RAH-HOME-NODE-CLIENT.ps1'),'-NodeAddress','127.0.0.1','-SelfTest');$checks+=[pscustomobject]@{name='agent-client-selftests';ok=$true}
        Write-Host '[4/6] Firewall + autostart ...' -ForegroundColor Cyan
        $fw=Set-RahWorkerFirewall $address 18766;$auto=Set-RahWorkerAutostart $root $address 18766;$checks+=[pscustomobject]@{name="firewall:$fw";ok=$true};$checks+=[pscustomobject]@{name="autostart:$auto";ok=$true}
        Write-Host '[5/6] Starter Worker Agent ...' -ForegroundColor Cyan
        if($NoStart){$agentStart=$null;$checks+=[pscustomobject]@{name='worker-start:skipped';ok=$true}}else{$agentStart=Start-RahWorkerAgent $root $address 18766;$checks+=[pscustomobject]@{name='worker-agent-listening';ok=$true}}
        Write-Host '[6/6] Validerer state + skriver handoff ...' -ForegroundColor Cyan
        $state=Get-Content -Raw (Join-Path $root 'rah-home-install-state.json')|ConvertFrom-Json
        if($state.mode -ne 'Worker' -or [string]$state.workerAddress -ne $address -or [int]$state.port -ne 18766){throw 'Worker install-state stemmer ikke.'};$checks+=[pscustomobject]@{name='worker-install-state';ok=$true}
        if($agentStart){
            $ready=Join-Path $root 'RAH-HOME-WORKER-READY.txt';$expires=(Get-Date).AddMinutes(10).ToString('yyyy-MM-dd HH:mm:ss')
            [IO.File]::WriteAllLines($ready,@('RAH HOME WORKER READY','=====================',"PC        : $env:COMPUTERNAME","IP        : $address","PORT      : 18766","PAIR CODE : $($agentStart.PairCode)","GYLDIG TIL: $expires",'','Pa HOVED-PC: kjor samme START-HER.cmd og skriv IP + PAIR CODE nar den spor.'),(New-Object Text.UTF8Encoding($false)))
            Write-Host '';Write-Host '=============================================================' -ForegroundColor Green;Write-Host 'RAH HOME WORKER: READY' -ForegroundColor Green;Write-Host "IP        : $address";Write-Host "PAIR CODE : $($agentStart.PairCode)" -ForegroundColor Cyan;Write-Host "Ready-fil : $ready";Write-Host '=============================================================' -ForegroundColor Green
        }
        $paths=Write-RahFinalizeReport $root 'Worker' $true $checks;Write-Host "Rapport: $($paths.Text)";exit 0
    }

    Write-Host '[1/5] Lokal HOVED-PC acceptance ...' -ForegroundColor Cyan
    $accept=Get-RahScript 'RAH-HOME-ACCEPTANCE.ps1' @("RahHomeAcceptanceVersion = '1.0.0'",'Test-RahInstallOutput','rah-home-acceptance') $bootstrap
    Invoke-RahChildPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$accept,'-SelfTest')
    $aa=@('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$accept,'-InstallRoot',$root,'-DesktopPath',$desktop);if($SourceDirectory){$aa+=@('-SourceDirectory',[IO.Path]::GetFullPath($SourceDirectory))};Invoke-RahChildPowerShell $aa;$checks+=[pscustomobject]@{name='hoved-pc-local-acceptance';ok=$true}
    Write-Host '[2/5] Client/Job/Controller self-tests ...' -ForegroundColor Cyan
    $client=Join-Path $root 'RAH-HOME-NODE-CLIENT.ps1'
    Invoke-RahChildPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',$client,'-NodeAddress','127.0.0.1','-SelfTest')
    Invoke-RahChildPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'RAH-HOME-NODE-JOB.ps1'),'-NodeAddress','127.0.0.1','-SelfTest')
    Invoke-RahChildPowerShell @('-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'RAH-HOME-CLUSTER-CONTROLLER.ps1'),'-SelfTest');$checks+=[pscustomobject]@{name='leader-component-selftests';ok=$true}
    if($NoRemote){$checks+=[pscustomobject]@{name='physical-worker:skipped-by-request';ok=$true};$paths=Write-RahFinalizeReport $root 'Leader' $true $checks;Write-Host "LOCAL LEADER PASS. Rapport: $($paths.Text)" -ForegroundColor Green;exit 0}
    Write-Host '[3/5] Finner Worker ...' -ForegroundColor Cyan
    $remote=$WorkerAddress.Trim();if(-not$remote){$remote=Get-RahPeerAddress 18766};if(-not$remote){$remote=(Read-Host 'Worker IP-adresse (fra WORKER READY)').Trim()};if(-not(Test-RahPrivateIPv4 $remote)){throw 'Worker IP ma vaere privat RFC1918 IPv4.'};$checks+=[pscustomobject]@{name="worker-address:$remote";ok=$true}
    Write-Host '[4/5] Autentiserer/pairer Worker ...' -ForegroundColor Cyan
    $health=Invoke-RahClientAction $client $remote 'health'
    if($health.ExitCode -ne 0){$code=$PairCode.Trim();if(-not$code){$code=(Read-Host 'PAIR CODE (6 siffer fra Worker)').Trim()};if($code -notmatch '^\d{6}$'){throw 'PAIR CODE ma vaere seks siffer.'};$pair=Invoke-RahClientAction $client $remote 'pair' $code;if($pair.ExitCode -ne 0){throw "Pairing feilet: $($pair.Text)"};$checks+=[pscustomobject]@{name='worker-pairing';ok=$true}}else{$checks+=[pscustomobject]@{name='worker-existing-pairing';ok=$true}}
    Write-Host '[5/5] Ekte health + systemInfo + benchmark ...' -ForegroundColor Cyan
    foreach($action in @('health','systemInfo','benchmark')){$call=Invoke-RahClientAction $client $remote $action;$parsed=Convert-RahClientJson $call $action;if($parsed.ok -ne $true){throw "$action returnerte ok=false."};$checks+=[pscustomobject]@{name="remote-$action";ok=$true};Write-Host "      $action`: OK" -ForegroundColor Green}
    $paths=Write-RahFinalizeReport $root 'Leader' $true $checks '' $remote
    Write-Host '';Write-Host '=====================================================================' -ForegroundColor Green;Write-Host '                 RAH HOME 2-PC: FULL PASS' -ForegroundColor Green;Write-Host '=====================================================================' -ForegroundColor Green;Write-Host "Worker : $remote`:18766";Write-Host "Rapport: $($paths.Text)";exit 0
}
catch {
    $message=$_.Exception.Message;$checks+=[pscustomobject]@{name='finalize-error';ok=$false}
    try{$paths=Write-RahFinalizeReport $root $resolvedMode $false $checks $message $remote}catch{$paths=$null}
    Write-Host '';Write-Host '=====================================================================' -ForegroundColor Red;Write-Host '                    RAH HOME FINALIZE: FAIL' -ForegroundColor Red;Write-Host '=====================================================================' -ForegroundColor Red;Write-Host $message -ForegroundColor Red;if($paths){Write-Host "Rapport: $($paths.Text)"};exit 1
}
