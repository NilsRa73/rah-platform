Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repo = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$diag = Join-Path $repo 'RAH-HOME-DIAGNOSTICS.ps1'
$base = Join-Path $env:TEMP ('RAH-Home-Diagnostics-Runtime-' + [guid]::NewGuid().ToString('N'))
$root = Join-Path $base 'home'
$logs = Join-Path $root 'logs'
$reports = Join-Path $root 'reports'
New-Item -ItemType Directory -Path $root,$logs,$reports -Force | Out-Null

try {
    $tokens=$null; $errors=$null
    [Management.Automation.Language.Parser]::ParseFile($diag,[ref]$tokens,[ref]$errors) | Out-Null
    if (@($errors).Count) { throw "Diagnostics parse failed: $($errors[0].Message)" }

    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $diag -SelfTest
    if ($LASTEXITCODE -ne 0) { throw "Diagnostics self-test failed: $LASTEXITCODE" }

    Copy-Item -LiteralPath $diag -Destination (Join-Path $root 'RAH-HOME-DIAGNOSTICS.ps1') -Force
    [IO.File]::WriteAllText((Join-Path $root 'rah-home-install-state.json'),'{"schema":"rah-home-install-state","version":1,"mode":"Worker","port":18766,"workerAddress":"192.168.50.10","token":"STATE-SECRET-7788"}',(New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $logs 'worker-agent.log'),"PAIR CODE : 123456`r`ntoken=LOG-SECRET-7788`r`nBearer bearer.secret.value`r`nAgent ready",(New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $logs 'worker-agent.err.log'),"authorization=AUTH-SECRET-7788`r`nSynthetic diagnostic error",(New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $root 'RAH-HOME-FINAL-REPORT.txt'),"PAIR CODE = 654321`r`nsecret=REPORT-SECRET-7788",(New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $reports 'rah-home-finalize-latest.json'),'{"ok":false,"pairCode":"112233","token":"JSON-SECRET-7788"}',(New-Object Text.UTF8Encoding($false)))

    $env:PYTHON_BASIC_REPL='1'
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $diag -InstallRoot $root -Reason 'ci-runtime-secret-redaction'
    if ($LASTEXITCODE -ne 0) { throw "Diagnostics runtime failed: $LASTEXITCODE" }

    $latestPath = Join-Path $root 'support\rah-home-support-latest.json'
    if (-not (Test-Path -LiteralPath $latestPath -PathType Leaf)) { throw 'Missing latest support metadata.' }
    $latest = Get-Content -LiteralPath $latestPath -Raw | ConvertFrom-Json
    foreach ($path in @([string]$latest.bundleDirectory,[string]$latest.zipPath,[string]$latest.diagnosticsJson,[string]$latest.diagnosticsText)) {
        if (-not $path -or -not (Test-Path -LiteralPath $path)) { throw "Missing support output: $path" }
    }

    $doc = Get-Content -LiteralPath ([string]$latest.diagnosticsJson) -Raw | ConvertFrom-Json
    if ($doc.schema -ne 'rah-home-diagnostics' -or [int]$doc.version -ne 1) { throw 'Diagnostics schema/version mismatch.' }
    if ($doc.reason -ne 'ci-runtime-secret-redaction') { throw 'Diagnostics reason mismatch.' }
    if ($doc.peerStoreContentCollected -ne $false) { throw 'Peer store content must never be collected.' }
    if ([string]$doc.pythonBasicRepl -ne '1') { throw 'PYTHON_BASIC_REPL was not captured.' }

    $allText = ''
    foreach ($file in @(Get-ChildItem -LiteralPath ([string]$latest.bundleDirectory) -File -Recurse)) {
        $allText += "`n" + (Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop)
    }
    foreach ($secret in @('123456','654321','112233','LOG-SECRET-7788','AUTH-SECRET-7788','REPORT-SECRET-7788','JSON-SECRET-7788','bearer.secret.value')) {
        if ($allText.Contains($secret)) { throw "Secret leaked into support bundle: $secret" }
    }
    if (-not $allText.Contains('[REDACTED]')) { throw 'Expected redaction marker was not found.' }

    $zip = Get-Item -LiteralPath ([string]$latest.zipPath)
    if ($zip.Length -le 0) { throw 'Support ZIP is empty.' }

    Write-Host 'PASS: RAH Home Diagnostics v1 Windows runtime + redaction' -ForegroundColor Green
}
finally {
    Remove-Item -LiteralPath $base -Recurse -Force -ErrorAction SilentlyContinue
}
