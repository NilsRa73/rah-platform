param(
    [string]$ProjectRoot = "",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root="C:\RAH\AI-Fabric"
$ConfigFile=Join-Path $Root "project-memory.json"
$StateFile=Join-Path $Root "project-memory-sync.json"
$LogDir=Join-Path $Root "Logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$Log=Join-Path $LogDir ("memory-sync-"+(Get-Date -Format "yyyyMMdd-HHmmss")+".log")

function Log([string]$Text) {
    Add-Content -LiteralPath $Log -Value ("[{0}] {1}" -f (Get-Date -Format "s"),$Text) -Encoding UTF8
}

function Api([string]$Method,[string]$Url,[string]$Token,[object]$Body=$null,[int]$Timeout=90) {
    $headers=@{ Authorization="Bearer $Token"; Accept="application/json" }
    if($null-eq$Body){
        return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -TimeoutSec $Timeout
    }
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType "application/json" -Body ($Body|ConvertTo-Json -Depth 10) -TimeoutSec $Timeout
}

try {
    if(-not(Test-Path -LiteralPath $ConfigFile)){throw "Project Memory config mangler: $ConfigFile"}
    $cfg=Get-Content -LiteralPath $ConfigFile -Raw|ConvertFrom-Json
    if($cfg.enabled -ne $true){Log "Memory disabled; skip";exit 0}

    $base=[string]$cfg.base_url
    $workspace=[string]$cfg.workspace
    $tokenFile=[string]$cfg.token_file
    if(-not(Test-Path -LiteralPath $tokenFile)){throw "AnythingLLM token-file mangler"}
    $token=[IO.File]::ReadAllText($tokenFile).Trim()
    if(-not$token){throw "AnythingLLM token er tom"}

    $auth=Api GET "$base/api/v1/auth" $token $null 10
    if($auth.authenticated-ne$true){throw "AnythingLLM auth feilet"}

    if(-not$ProjectRoot){
        if($cfg.project_root){$ProjectRoot=[string]$cfg.project_root}
        elseif(Test-Path "C:\RAH\rah-platform"){$ProjectRoot="C:\RAH\rah-platform"}
        else{$ProjectRoot="C:\RAH\AI-Fabric\rah-platform"}
    }
    if(-not(Test-Path -LiteralPath $ProjectRoot -PathType Container)){throw "Project root finnes ikke: $ProjectRoot"}

    $extensions=@(".md",".txt",".json",".yml",".yaml")
    $excluded='\\(\.git|node_modules|dist|build|_ARCHIVE|archive|venv|\.venv)\\'
    $files=Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object{$extensions -contains $_.Extension.ToLowerInvariant() -and $_.FullName -notmatch $excluded} |
        Sort-Object FullName |
        Select-Object -First 250

    $builder=New-Object Text.StringBuilder
    [void]$builder.AppendLine("# RAH PROJECT SNAPSHOT")
    [void]$builder.AppendLine("")
    [void]$builder.AppendLine("Generated: $((Get-Date).ToString("o"))")
    [void]$builder.AppendLine("Root: $ProjectRoot")

    $commit=""
    try{
        $git=Get-Command git.exe -ErrorAction SilentlyContinue
        if($git){
            $line=& $git.Source -C $ProjectRoot rev-parse HEAD 2>$null | Select-Object -First 1
            if($line){$commit=[string]$line;$commit=$commit.Trim()}
            if($commit){[void]$builder.AppendLine("Git commit: $commit")}
        }
    }catch{}

    [void]$builder.AppendLine("")
    $included=0
    foreach($file in $files){
        if($builder.Length -ge 950000){break}
        $relative=$file.FullName.Substring($ProjectRoot.TrimEnd('\').Length).TrimStart('\')
        try{$text=Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop}catch{continue}
        if([string]::IsNullOrWhiteSpace($text)){continue}
        if($text.Length -gt 50000){$text=$text.Substring(0,50000)+[Environment]::NewLine+"[TRUNCATED]"}
        [void]$builder.AppendLine("")
        [void]$builder.AppendLine("---")
        [void]$builder.AppendLine("## FILE: $relative")
        [void]$builder.AppendLine("")
        [void]$builder.AppendLine($text)
        $included++
    }

    $snapshot=$builder.ToString()
    $bytes=[Text.Encoding]::UTF8.GetBytes($snapshot)
    $hasher=[Security.Cryptography.SHA256]::Create()
    try{$sha=[BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace("-","").ToLowerInvariant()}
    finally{$hasher.Dispose()}

    $old=$null
    if(Test-Path -LiteralPath $StateFile){
        try{$old=Get-Content -LiteralPath $StateFile -Raw|ConvertFrom-Json}catch{}
    }
    if(-not$Force -and $old -and [string]$old.snapshot_sha -eq $sha){
        Log "No project-memory changes; snapshot hash unchanged."
        exit 0
    }

    Log "Uploading RAH project snapshot ($included files, $($snapshot.Length) chars)."
    $title="RAH Project Snapshot "+$sha.Substring(0,12)
    $uploaded=Api POST "$base/api/v1/document/raw-text" $token @{
        textContent=$snapshot
        addToWorkspaces=$workspace
        metadata=@{
            title=$title
            description="Auto-synced RAH Raven project snapshot"
            docAuthor="RAH Raven"
            docSource="C:\RAH project files"
        }
    } 120

    if($uploaded.success-ne$true -or -not$uploaded.documents){throw "AnythingLLM raw-text upload feilet"}
    $newLocation=[string]@($uploaded.documents)[0].location
    if(-not$newLocation){throw "AnythingLLM returnerte ingen document location"}

    $oldLocation=if($old){[string]$old.document_location}else{""}
    if($oldLocation -and $oldLocation-ne$newLocation){
        try{
            Api POST "$base/api/v1/workspace/$([uri]::EscapeDataString($workspace))/update-embeddings" $token @{
                adds=@()
                deletes=@($oldLocation)
            } 60 | Out-Null
            Log "Removed previous snapshot embedding: $oldLocation"
        }catch{
            Log "WARN: old embedding cleanup failed: $($_.Exception.Message)"
        }
    }

    [ordered]@{
        schema="rah-raven-project-memory-sync"
        version=1
        timestamp=(Get-Date).ToString("o")
        workspace=$workspace
        project_root=$ProjectRoot
        git_commit=$commit
        snapshot_sha=$sha
        document_location=$newLocation
        file_count=$included
        snapshot_chars=$snapshot.Length
    }|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $StateFile -Encoding UTF8

    Log "Project memory sync PASS: $newLocation"
    exit 0
}
catch{
    Log ("FAIL: "+$_.Exception.Message)
    exit 1
}
