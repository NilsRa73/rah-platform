[CmdletBinding()]
param(
    [switch]$SelfTest,
    [int]$BridgeTimeoutSeconds = 35,
    [int]$AgentTimeoutSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:AcceptanceVersion = '1.0.0'
$script:Root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
$script:BridgeDir = Join-Path $script:Root 'desktop-bridge'
$script:VenvPython = Join-Path $script:BridgeDir '.venv\Scripts\python.exe'
$script:BridgeScript = Join-Path $script:BridgeDir 'raven_bridge.py'
$script:DoctorScript = Join-Path $script:BridgeDir 'doctor.py'
$script:AgentLiveScript = Join-Path $script:Root 'RAH-AGENT-TEAM-LIVE-TEST.ps1'
$script:BridgeUrl = 'http://127.0.0.1:18765'
$script:LogRoot = Join-Path $script:Root 'Logs'
$script:JsonReport = Join-Path $script:LogRoot 'RAVEN-V1-ACCEPTANCE-LATEST.json'
$script:TxtReport = Join-Path $script:LogRoot 'RAVEN-V1-ACCEPTANCE-LATEST.txt'
$script:BridgeStdout = Join-Path $script:LogRoot 'RAVEN-BRIDGE-START-LATEST.log'
$script:BridgeStderr = Join-Path $script:LogRoot 'RAVEN-BRIDGE-ERROR-LATEST.log'
$script:FreezeScript = Join-Path $PSScriptRoot 'FREEZE-RAVEN-V1-CANDIDATE.ps1'
$script:Utf8 = New-Object Text.UTF8Encoding($false)

function Test-RahLoopbackUrl {
    param([string]$Url)
    try {
        $u = [Uri]$Url
        return ($u.Scheme -eq 'http' -and $u.Host -in @('127.0.0.1','localhost','::1'))
    } catch {
        return $false
    }
}

function Get-RahJson {
    param([string]$Url,[int]$TimeoutSeconds=4)
    try {
        return Invoke-RestMethod -Uri $Url -TimeoutSec $TimeoutSeconds -ErrorAction Stop
    } catch {
        return $null
    }
}

function Wait-RahBridge {
    param([int]$Seconds)
    $end=(Get-Date).AddSeconds([math]::Max(1,$Seconds))
    do {
        $health=Get-RahJson ($script:BridgeUrl + '/health') 3
        if($health -and $health.ok -eq $true){ return $health }
        Start-Sleep -Milliseconds 700
    } while((Get-Date)-lt$end)
    return $null
}

function Invoke-RahProcess {
    param(
        [string]$File,
        [string[]]$Arguments,
        [string]$WorkingDirectory,
        [int]$TimeoutSeconds=120
    )
    $tmp=Join-Path $env:TEMP ('rah-accept-'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    $stdout=Join-Path $tmp 'stdout.txt'
    $stderr=Join-Path $tmp 'stderr.txt'
    try {
        $quoted=@()
        foreach($arg in $Arguments){
            $a=[string]$arg
            if($a -match '[\s"]'){ $a='"'+($a -replace '"','\"')+'"' }
            $quoted += $a
        }
        $p=Start-Process -FilePath $File -ArgumentList ($quoted -join ' ') -WorkingDirectory $WorkingDirectory -NoNewWindow -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        if(-not $p.WaitForExit([math]::Max(1,$TimeoutSeconds)*1000)){
            try{$p.Kill()}catch{}
            return [pscustomobject]@{exitCode=124;timedOut=$true;stdout='';stderr='timeout'}
        }
        $out=if(Test-Path -LiteralPath $stdout){Get-Content -LiteralPath $stdout -Raw -ErrorAction SilentlyContinue}else{''}
        $err=if(Test-Path -LiteralPath $stderr){Get-Content -LiteralPath $stderr -Raw -ErrorAction SilentlyContinue}else{''}
        return [pscustomobject]@{exitCode=[int]$p.ExitCode;timedOut=$false;stdout=[string]$out;stderr=[string]$err}
    }
    finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Start-RahBridgeHidden {
    if(-not(Test-Path -LiteralPath $script:VenvPython -PathType Leaf)){
        throw "Raven Bridge Python mangler: $script:VenvPython"
    }
    if(-not(Test-Path -LiteralPath $script:BridgeScript -PathType Leaf)){
        throw "raven_bridge.py mangler: $script:BridgeScript"
    }
    New-Item -ItemType Directory -Path $script:LogRoot -Force | Out-Null
    Set-Content -LiteralPath $script:BridgeStdout -Value '' -Encoding UTF8
    Set-Content -LiteralPath $script:BridgeStderr -Value '' -Encoding UTF8
    return Start-Process -FilePath $script:VenvPython -ArgumentList 'raven_bridge.py' -WorkingDirectory $script:BridgeDir -WindowStyle Hidden -RedirectStandardOutput $script:BridgeStdout -RedirectStandardError $script:BridgeStderr -PassThru
}

function Get-RahDoctorResult {
    if(-not(Test-Path -LiteralPath $script:DoctorScript -PathType Leaf)){
        throw "doctor.py mangler: $script:DoctorScript"
    }
    $result=Invoke-RahProcess -File $script:VenvPython -Arguments @('doctor.py','--json') -WorkingDirectory $script:BridgeDir -TimeoutSeconds 45
    $checks=@()
    if($result.stdout){
        try{$checks=@($result.stdout | ConvertFrom-Json)}catch{}
    }
    $requiredFailures=@($checks | Where-Object { $_.required -eq $true -and $_.ok -ne $true })
    $capture=@($checks | Where-Object { $_.name -eq 'Window capture' } | Select-Object -First 1)
    return [pscustomobject]@{
        exitCode=$result.exitCode
        checks=@($checks)
        requiredFailures=@($requiredFailures)
        capturePass=[bool]($capture.Count -gt 0 -and $capture[0].ok -eq $true)
        stderr=[string]$result.stderr
    }
}

function Invoke-RahAgentLive {
    if(-not(Test-Path -LiteralPath $script:AgentLiveScript -PathType Leaf)){
        throw "Agent Team LIVE script mangler: $script:AgentLiveScript"
    }
    $args=@(
        '-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
        '-File',$script:AgentLiveScript,
        '-BridgeRoot','C:\RAH\AgentBridge',
        '-WorkerRoot','C:\RAH\AgentWorker',
        '-BusRoot','C:\RAH\AgentBus',
        '-FabricUrl',$script:BridgeUrl,
        '-TimeoutSeconds',([string]$AgentTimeoutSeconds)
    )
    $result=Invoke-RahProcess -File 'powershell.exe' -Arguments $args -WorkingDirectory $script:Root -TimeoutSeconds ($AgentTimeoutSeconds + 60)
    $agentReport='C:\RAH\AgentWorker\reports\rah-agent-team-live-latest.json'
    $doc=$null
    if(Test-Path -LiteralPath $agentReport -PathType Leaf){
        try{$doc=Get-Content -LiteralPath $agentReport -Raw | ConvertFrom-Json}catch{}
    }
    return [pscustomobject]@{
        exitCode=$result.exitCode
        stdout=[string]$result.stdout
        stderr=[string]$result.stderr
        report=$agentReport
        doc=$doc
        pass=[bool]($result.exitCode -eq 0 -and $doc -and [string]$doc.overall -eq 'PASS')
        smallestFix=$(if($doc){[string]$doc.smallestFix}else{''})
    }
}

function Write-RahAcceptanceReport {
    param([object]$Doc)
    New-Item -ItemType Directory -Path $script:LogRoot -Force | Out-Null
    [IO.File]::WriteAllText($script:JsonReport,($Doc|ConvertTo-Json -Depth 14),$script:Utf8)
    $lines=@(
        'RAH RAVEN V1 FINAL ACCEPTANCE',
        '=============================',
        ('Version       : '+$script:AcceptanceVersion),
        ('Computer      : '+$env:COMPUTERNAME),
        ('Bridge        : '+$Doc.bridge),
        ('Doctor        : '+$Doc.doctor),
        ('Capture       : '+$Doc.capture),
        ('Agent Team    : '+$Doc.agentTeam),
        ('LM Studio     : '+$Doc.lmStudio),
        ('Model         : '+$Doc.model),
        ('Overall       : '+$Doc.overall),
        ('Freeze        : '+$Doc.freeze),
        ('Snapshot      : '+$Doc.freezeSnapshot),
        ('Smallest fix  : '+$Doc.smallestFix),
        '',
        ('JSON report   : '+$script:JsonReport),
        ('Bridge stdout : '+$script:BridgeStdout),
        ('Bridge stderr : '+$script:BridgeStderr)
    )
    [IO.File]::WriteAllLines($script:TxtReport,$lines,$script:Utf8)
}

function Invoke-RahSelfTest {
    if($script:AcceptanceVersion -ne '1.0.0'){throw 'version marker mismatch'}
    if(-not(Test-RahLoopbackUrl $script:BridgeUrl)){throw 'bridge URL is not loopback'}
    if(Test-RahLoopbackUrl 'http://0.0.0.0:18765'){throw 'unsafe bind accepted'}
    foreach($path in @(
        $script:BridgeScript,
        $script:DoctorScript,
        $script:AgentLiveScript
    )){
        if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw ('missing required file: '+$path)}
    }
    $tmp=Join-Path $env:TEMP ('rah-accept-selftest-'+[guid]::NewGuid().ToString('N'))
    try{
        New-Item -ItemType Directory -Path $tmp -Force | Out-Null
        $oldRoot=$script:LogRoot
        $oldJson=$script:JsonReport
        $oldTxt=$script:TxtReport
        $oldOut=$script:BridgeStdout
        $oldErr=$script:BridgeStderr
        $script:LogRoot=$tmp
        $script:JsonReport=Join-Path $tmp 'accept.json'
        $script:TxtReport=Join-Path $tmp 'accept.txt'
        $script:BridgeStdout=Join-Path $tmp 'bridge.out'
        $script:BridgeStderr=Join-Path $tmp 'bridge.err'
        Write-RahAcceptanceReport ([pscustomobject]@{
            bridge='PASS';doctor='PASS';capture='PASS';agentTeam='PASS'
            lmStudio='PASS';model='self-test';overall='PASS'
            freeze='NOT_RUN';freezeSnapshot='';smallestFix=''
        })
        if(-not(Test-Path -LiteralPath $script:JsonReport)){throw 'JSON report self-test failed'}
        if(-not(Test-Path -LiteralPath $script:TxtReport)){throw 'TXT report self-test failed'}
        $script:LogRoot=$oldRoot
        $script:JsonReport=$oldJson
        $script:TxtReport=$oldTxt
        $script:BridgeStdout=$oldOut
        $script:BridgeStderr=$oldErr
    }
    finally{
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
    Write-Host 'RAH RAVEN V1 ACCEPTANCE SELFTEST: PASS'
}

if($SelfTest){
    Invoke-RahSelfTest
    exit 0
}

if(-not(Test-RahLoopbackUrl $script:BridgeUrl)){throw 'Bridge URL must stay loopback-only.'}

$bridgeHealth=Wait-RahBridge 2
$bridgeState='PASS'
$smallestFix=''

if(-not $bridgeHealth){
    Write-Host '[RAH] Desktop Bridge er nede. Starter skjult ...'
    $null=Start-RahBridgeHidden
    $bridgeHealth=Wait-RahBridge $BridgeTimeoutSeconds
}
if(-not $bridgeHealth){
    $bridgeState='FAIL'
    $smallestFix='Desktop Bridge kom ikke opp paa 127.0.0.1:18765. Se RAVEN-BRIDGE-ERROR-LATEST.log.'
}

$doctorState='NOT_RUN'
$captureState='NOT_RUN'
$doctor=$null
if($bridgeState -eq 'PASS'){
    $doctor=Get-RahDoctorResult
    if($doctor.exitCode -eq 0 -and $doctor.requiredFailures.Count -eq 0){
        $doctorState='PASS'
    } else {
        $doctorState='FAIL'
        if(-not $smallestFix){$smallestFix='Raven Doctor har minst én required failure.'}
    }
    $captureState=$(if($doctor.capturePass){'PASS'}else{'FAIL'})
    if($captureState -eq 'FAIL' -and -not $smallestFix){
        $smallestFix='Window capture feilet. Hold et normalt skrivebordsvindu aktivt og kjoer acceptance igjen.'
    }
}

$agentState='NOT_RUN'
$agent=$null
if($bridgeState -eq 'PASS' -and $doctorState -eq 'PASS' -and $captureState -eq 'PASS'){
    $agent=Invoke-RahAgentLive
    $agentState=$(if($agent.pass){'PASS'}else{'FAIL'})
    if($agentState -eq 'FAIL' -and -not $smallestFix){
        $smallestFix=$(if($agent.smallestFix){$agent.smallestFix}else{'Agent Team LIVE feilet. Se AgentWorker-rapporten.'})
    }
}

$lm=Get-RahJson 'http://127.0.0.1:1234/v1/models' 4
$model=''
$lmState='WARN'
if($lm -and $lm.data -and @($lm.data).Count -gt 0){
    $model=[string]$lm.data[0].id
    $lmState='PASS'
}

$runtimePass=[bool](
    $bridgeState -eq 'PASS' -and
    $doctorState -eq 'PASS' -and
    $captureState -eq 'PASS' -and
    $agentState -eq 'PASS'
)

$freezeState='NOT_RUN'
$freezeSnapshot=''
$overall=$(if($runtimePass){'PASS'}else{'FAIL'})

$doc=[pscustomobject]@{
    schema='rah-raven-v1-acceptance'
    version=1
    acceptanceVersion=$script:AcceptanceVersion
    createdAt=(Get-Date).ToUniversalTime().ToString('o')
    computerName=$env:COMPUTERNAME
    bridge=$bridgeState
    doctor=$doctorState
    capture=$captureState
    agentTeam=$agentState
    lmStudio=$lmState
    model=$model
    overall=$overall
    freeze=$freezeState
    freezeSnapshot=$freezeSnapshot
    smallestFix=$smallestFix
    doctorChecks=$(if($doctor){@($doctor.checks)}else{@()})
    agentReport=$(if($agent){$agent.report}else{''})
    agent=$(if($agent -and $agent.doc){$agent.doc}else{$null})
    arbitraryCommands=$false
    stablePromotion=$false
    automaticMerge=$false
}
Write-RahAcceptanceReport $doc

if($runtimePass){
    if(-not(Test-Path -LiteralPath $script:FreezeScript -PathType Leaf)){
        $freezeState='FAIL'
        $overall='FAIL'
        $smallestFix='Freeze-script mangler; runtime PASS ble ikke frosset som kjent-god Candidate.'
    } else {
        $freezeRun=Invoke-RahProcess -File 'powershell.exe' -Arguments @(
            '-NoLogo','-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
            '-File',$script:FreezeScript,
            '-SourceRoot',$script:Root
        ) -WorkingDirectory $script:Root -TimeoutSeconds 120
        if($freezeRun.exitCode -eq 0){
            $freezeState='PASS'
            $latest=Join-Path $script:Root '_STABLE_CANDIDATES\RAVEN-AGENT-EFFECT-PACK-V1\LATEST.txt'
            if(Test-Path -LiteralPath $latest -PathType Leaf){
                $freezeSnapshot=(Get-Content -LiteralPath $latest -Raw).Trim()
            }
        } else {
            $freezeState='FAIL'
            $overall='FAIL'
            $smallestFix='Runtime PASS, men Candidate freeze feilet.'
        }
    }

    $doc.freeze=$freezeState
    $doc.freezeSnapshot=$freezeSnapshot
    $doc.overall=$overall
    $doc.smallestFix=$smallestFix
    Write-RahAcceptanceReport $doc
}

Get-Content -LiteralPath $script:TxtReport | ForEach-Object { Write-Host $_ }

if($overall -eq 'PASS' -and $freezeState -eq 'PASS'){
    Write-Host ''
    Write-Host 'RAH RAVEN V1: FULL PASS + FROZEN CANDIDATE' -ForegroundColor Green
    exit 0
}

Write-Host ''
Write-Host ('RAH RAVEN V1: FAIL - '+$smallestFix) -ForegroundColor Red
exit 1
