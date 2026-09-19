Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$bridge = Join-Path $repo 'rah_agent_bridge.py'
$worker = Join-Path $repo 'rah_agent_worker.py'
$mock = Join-Path $repo 'tests\rah_agent_worker_mock_fabric.py'
$root = Join-Path $env:RUNNER_TEMP ('rah-agent-worker-root-' + [guid]::NewGuid().ToString('N'))
$bus = Join-Path $env:RUNNER_TEMP ('rah-agent-worker-bus-' + [guid]::NewGuid().ToString('N'))
$state = Join-Path $env:RUNNER_TEMP ('rah-agent-worker-state-' + [guid]::NewGuid().ToString('N') + '.json')
$bridgePort = 18793
$fabricPort = 18794
$bridgeProc = $null
$fabricProc = $null

function Wait-Json {
    param([string]$Url,[int]$Seconds=15)
    $end=(Get-Date).AddSeconds($Seconds)
    do{
        try{return Invoke-RestMethod -Uri $Url -TimeoutSec 2}catch{}
        Start-Sleep -Milliseconds 200
    }while((Get-Date)-lt$end)
    return $null
}

function Enqueue-Job {
    param([string]$Kind,[hashtable]$Payload,[hashtable]$Headers)
    $body=@{kind=$Kind;source='ci-worker-runtime';payload=$Payload}|ConvertTo-Json -Depth 8
    return Invoke-RestMethod -Uri "http://127.0.0.1:$bridgePort/v1/jobs/enqueue" -Method Post -Headers $Headers -ContentType 'application/json' -Body $body -TimeoutSec 5
}

function Run-Worker-Once {
    param([string]$TokenPath)
    & python.exe $worker --bridge "http://127.0.0.1:$bridgePort" --fabric "http://127.0.0.1:$fabricPort" --token-file $TokenPath --state-file $state --once
    if($LASTEXITCODE -ne 0){ throw "Worker --once failed: $LASTEXITCODE" }
}

function Get-Completed {
    param([string]$JobId)
    $path=Join-Path $bus "results\$JobId.json"
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Completed result missing: $JobId"}
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

function Get-Failed {
    param([string]$JobId)
    $path=Join-Path $bus "failed\$JobId.json"
    if(-not(Test-Path -LiteralPath $path -PathType Leaf)){throw "Failed result missing: $JobId"}
    return Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
}

try {
    & python.exe -m py_compile $bridge $worker $mock
    if($LASTEXITCODE -ne 0){throw 'py_compile failed.'}
    & python.exe $worker --self-test
    if($LASTEXITCODE -ne 0){throw 'Agent Worker self-test failed.'}

    New-Item -ItemType Directory -Path $root,$bus -Force | Out-Null
    $bridgeProc=Start-Process -FilePath python.exe -ArgumentList @(
        $bridge,'--root',$root,'--bus-root',$bus,'--host','127.0.0.1','--port',[string]$bridgePort
    ) -PassThru -WindowStyle Hidden
    $fabricProc=Start-Process -FilePath python.exe -ArgumentList @(
        $mock,'--port',[string]$fabricPort
    ) -PassThru -WindowStyle Hidden

    $bh=Wait-Json "http://127.0.0.1:$bridgePort/health"
    $fh=Wait-Json "http://127.0.0.1:$fabricPort/ai/health"
    if(-not$bh -or -not$bh.ok){throw 'Bridge health failed.'}
    if(-not$fh -or -not$fh.ok){throw 'Mock Fabric health failed.'}

    $tokenPath=Join-Path $root 'token.txt'
    $token=(Get-Content -LiteralPath $tokenPath -Raw).Trim()
    $headers=@{Authorization="Bearer $token"}

    # 1. text.task -> AI Fabric chat -> completed
    $q=Enqueue-Job -Kind 'text.task' -Payload @{text='hello agent worker'} -Headers $headers
    $id=[string]$q.job.id
    Run-Worker-Once $tokenPath
    $done=Get-Completed $id
    if($done.status -ne 'completed'){throw 'text.task did not complete.'}
    if([string]$done.result.route -ne 'ai-fabric'){throw 'text.task route mismatch.'}
    if([string]$done.result.text -notmatch '^MOCK-ANSWER: hello agent worker'){throw 'text.task result mismatch.'}

    # 2. project.review prefers AnythingLLM route
    $q=Enqueue-Job -Kind 'project.review' -Payload @{message='review rah-platform';workspace='rah-platform'} -Headers $headers
    $id=[string]$q.job.id
    Run-Worker-Once $tokenPath
    $done=Get-Completed $id
    if([string]$done.result.provider -ne 'mock-anythingllm'){throw 'project.review did not prefer AnythingLLM.'}

    # 3. system.inventory -> fixed Raven capability
    $q=Enqueue-Job -Kind 'system.inventory' -Payload @{} -Headers $headers
    $id=[string]$q.job.id
    Run-Worker-Once $tokenPath
    $done=Get-Completed $id
    if([string]$done.result.route -ne 'raven'){throw 'system.inventory route mismatch.'}
    if([string]$done.result.capability -ne 'system-inventory'){throw 'system.inventory capability mismatch.'}

    # 4. allowed test.request -> fixed Raven test capability
    $q=Enqueue-Job -Kind 'test.request' -Payload @{capability='git-status'} -Headers $headers
    $id=[string]$q.job.id
    Run-Worker-Once $tokenPath
    $done=Get-Completed $id
    if([string]$done.result.capability -ne 'git-status'){throw 'allowed test capability mismatch.'}

    # 5. forbidden test capability must fail, never execute
    $q=Enqueue-Job -Kind 'test.request' -Payload @{capability='shell.exec'} -Headers $headers
    $id=[string]$q.job.id
    Run-Worker-Once $tokenPath
    $failed=Get-Failed $id
    if($failed.status -ne 'failed'){throw 'forbidden capability was not failed.'}
    if([string]$failed.error.message -notmatch 'fixed allowlist'){throw 'forbidden capability failure reason mismatch.'}

    if(-not(Test-Path -LiteralPath $state -PathType Leaf)){throw 'Worker state file missing.'}
    $stateDoc=Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
    if([string]$stateDoc.version -ne '1.0.0'){throw 'Worker state version mismatch.'}
    if($stateDoc.execCapability -ne $false){throw 'Worker state unexpectedly exposes exec capability.'}

    Write-Host 'PASS: RAH Agent Worker v1 queue-to-AI-Fabric runtime' -ForegroundColor Green
}
finally {
    foreach($p in @($bridgeProc,$fabricProc)){
        if($p -and -not$p.HasExited){Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue}
    }
    Remove-Item -LiteralPath $root,$bus,$state -Recurse -Force -ErrorAction SilentlyContinue
}
