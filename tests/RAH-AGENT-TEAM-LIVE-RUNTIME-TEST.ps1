Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$bridgePy = Join-Path $repo 'rah_agent_bridge.py'
$workerPy = Join-Path $repo 'rah_agent_worker.py'
$mockPy = Join-Path $repo 'tests\rah_agent_team_live_mock_fabric.py'
$livePs = Join-Path $repo 'RAH-AGENT-TEAM-LIVE-TEST.ps1'

$base = Join-Path $env:RUNNER_TEMP ('rah-agent-live-' + [guid]::NewGuid().ToString('N'))
$bridgeRoot = Join-Path $base 'bridge'
$workerRoot = Join-Path $base 'worker'
$busRoot = Join-Path $base 'bus'
$bridgePort = 18801
$fabricPort = 18802
$bridgeProc = $null
$workerProc = $null
$fabricProc = $null

function Wait-Json {
    param([string]$Url,[int]$Seconds=20)
    $end=(Get-Date).AddSeconds($Seconds)
    do {
        try { return Invoke-RestMethod -Uri $Url -TimeoutSec 2 -ErrorAction Stop } catch {}
        Start-Sleep -Milliseconds 200
    } while((Get-Date)-lt$end)
    return $null
}

try {
    $python=(Get-Command python.exe -ErrorAction Stop).Source
    New-Item -ItemType Directory -Path $bridgeRoot,$workerRoot,$busRoot -Force | Out-Null

    $tokens=$null
    $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($livePs,[ref]$tokens,[ref]$errors) | Out-Null
    if(@($errors).Count){throw ('Live test parse failed: '+$errors[0].Message)}

    & $python -m py_compile $bridgePy $workerPy $mockPy
    if($LASTEXITCODE -ne 0){throw 'Python compile failed.'}

    $bridgeProc=Start-Process -FilePath $python -ArgumentList @(
        $bridgePy,
        '--root',$bridgeRoot,
        '--bus-root',$busRoot,
        '--host','127.0.0.1',
        '--port',[string]$bridgePort
    ) -PassThru -WindowStyle Hidden

    $fabricProc=Start-Process -FilePath $python -ArgumentList @(
        $mockPy,
        '--port',[string]$fabricPort
    ) -PassThru -WindowStyle Hidden

    $bh=Wait-Json "http://127.0.0.1:$bridgePort/health" 15
    $fh=Wait-Json "http://127.0.0.1:$fabricPort/health" 15
    if(-not$bh -or -not$bh.ok){throw 'Bridge did not become healthy.'}
    if(-not$fh -or -not$fh.ok){throw 'Mock Fabric did not become healthy.'}

    $tokenFile=Join-Path $bridgeRoot 'token.txt'
    if(-not(Test-Path -LiteralPath $tokenFile -PathType Leaf)){throw 'Bridge token file missing.'}

    $stateFile=Join-Path $workerRoot 'worker-state.json'
    $workerProc=Start-Process -FilePath $python -ArgumentList @(
        $workerPy,
        '--bridge',"http://127.0.0.1:$bridgePort",
        '--fabric',"http://127.0.0.1:$fabricPort",
        '--token-file',$tokenFile,
        '--state-file',$stateFile,
        '--poll-seconds','0.2'
    ) -PassThru -WindowStyle Hidden

    $stateOk=$false
    for($i=0;$i -lt 50;$i++){
        Start-Sleep -Milliseconds 200
        if(Test-Path -LiteralPath $stateFile -PathType Leaf){
            try{
                $s=Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
                if([string]$s.version -eq '1.0.0' -and $s.execCapability -eq $false){$stateOk=$true;break}
            }catch{}
        }
    }
    if(-not$stateOk){throw 'Worker state did not become ready.'}

    $liveArgs=@(
        '-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass',
        '-File',$livePs,
        '-BridgeRoot',$bridgeRoot,
        '-WorkerRoot',$workerRoot,
        '-BusRoot',$busRoot,
        '-BridgeUrl',"http://127.0.0.1:$bridgePort",
        '-FabricUrl',"http://127.0.0.1:$fabricPort",
        '-TimeoutSeconds','30',
        '-SkipTaskStart'
    )
    & powershell.exe @liveArgs
    if($LASTEXITCODE -ne 0){throw ('Live test failed with exit '+$LASTEXITCODE)}

    $json=Join-Path $workerRoot 'reports\rah-agent-team-live-latest.json'
    $txt=Join-Path $workerRoot 'reports\RAH-AGENT-TEAM-LIVE.txt'
    if(-not(Test-Path -LiteralPath $json -PathType Leaf)){throw 'Live JSON report missing.'}
    if(-not(Test-Path -LiteralPath $txt -PathType Leaf)){throw 'Live TXT report missing.'}

    $doc=Get-Content -LiteralPath $json -Raw | ConvertFrom-Json
    if([string]$doc.overall -ne 'PASS'){throw 'Live report overall was not PASS.'}
    if([string]$doc.ravenJob -ne 'PASS'){throw 'Raven job was not PASS.'}
    if([string]$doc.aiJob -ne 'PASS'){throw 'AI job was not PASS.'}
    if([string]$doc.ravenHandledBy -ne 'raven'){throw 'Raven handledBy trace mismatch.'}
    if([int]$doc.ravenAttemptCount -lt 1){throw 'Raven attempt trace missing.'}
    if([string]$doc.aiProvider -ne 'mock-anythingllm'){throw 'Unexpected AI provider.'}
    if([string]$doc.aiHandledBy -ne 'mock-anythingllm'){throw 'AI handledBy trace mismatch.'}
    if([string]$doc.aiBackend -ne 'mock-anythingllm-backend'){throw 'AI backend trace mismatch.'}
    if([int]$doc.aiAttemptCount -ne 1){throw 'AI attempt count mismatch.'}
    if($doc.aiFallbackUsed -ne $false){throw 'Unexpected fallback flag.'}
    if(@($doc.aiAttempts).Count -ne 1){throw 'AI attempts array mismatch.'}
    if([string]$doc.aiAttempts[0].provider -ne 'mock-anythingllm'){throw 'AI attempt provider mismatch.'}
    if([string]$doc.aiAttempts[0].result -ne 'PASS'){throw 'AI attempt result mismatch.'}
    if([string]$doc.aiReply -notmatch 'RAH LIVE AGENT OK'){throw 'AI reply marker missing.'}
    if($doc.bridgeTokenCollected -ne $false){throw 'Token collection safety flag failed.'}
    if($doc.arbitraryCommands -ne $false){throw 'Arbitrary command safety flag failed.'}

    $token=(Get-Content -LiteralPath $tokenFile -Raw).Trim()
    $allReport=(Get-Content -LiteralPath $json -Raw)+(Get-Content -LiteralPath $txt -Raw)
    if($allReport.Contains($token)){throw 'Bridge token leaked into live-test report.'}

    Write-Host 'PASS: RAH Agent Team LIVE v1 full queue runtime' -ForegroundColor Green
}
finally {
    foreach($p in @($workerProc,$bridgeProc,$fabricProc)){
        if($p -and -not$p.HasExited){
            Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}
