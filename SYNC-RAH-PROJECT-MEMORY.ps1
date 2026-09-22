param(
    [string]$ProjectRoot = "",
    [switch]$Force,
    [string]$HardwareRegistryPath = 'C:\RAH\HardwareRegistry\registry.json',
    [switch]$SelfTest
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-RahSha256 {
    param([Parameter(Mandatory=$true)][string]$Text)
    $bytes=[Text.Encoding]::UTF8.GetBytes($Text)
    $hasher=[Security.Cryptography.SHA256]::Create()
    try {
        return [BitConverter]::ToString($hasher.ComputeHash($bytes)).Replace("-","").ToLowerInvariant()
    } finally {
        $hasher.Dispose()
    }
}

function Get-RahHardwareContext {
    param([Parameter(Mandatory=$true)][string]$RegistryPath)

    $builder=New-Object Text.StringBuilder
    [void]$builder.AppendLine("")
    [void]$builder.AppendLine("---")
    [void]$builder.AppendLine("## RAH HARDWARE CONTEXT")
    [void]$builder.AppendLine("")
    [void]$builder.AppendLine("Purpose: read-only reference data for owned RAH devices. Missing values mean unknown/not reported, not necessarily absent.")
    [void]$builder.AppendLine("Use this context for questions about installed RAM, RAM module part numbers, motherboard, CPU, GPU, PCI/PCIe slots, disks, network adapters, monitors and machine selection.")

    if(-not(Test-Path -LiteralPath $RegistryPath -PathType Leaf)){
        [void]$builder.AppendLine("Status: hardware registry not present yet.")
        [void]$builder.AppendLine("Expected path: $RegistryPath")
        return [pscustomobject][ordered]@{
            included=$false
            devices=0
            sha=""
            chars=$builder.Length
            text=$builder.ToString()
        }
    }

    $item=Get-Item -LiteralPath $RegistryPath -ErrorAction Stop
    if($item.Length -gt 2097152){throw "Hardware registry exceeds fixed 2 MiB memory-sync limit."}
    $raw=Get-Content -LiteralPath $RegistryPath -Raw -ErrorAction Stop
    if([string]::IsNullOrWhiteSpace($raw)){throw "Hardware registry is empty."}
    if($raw -match '(?i)"serialNumber"\s*:'){throw "Hardware registry contains a serialNumber field; Project Memory sync refuses it."}

    try{$registry=$raw|ConvertFrom-Json}catch{throw "Hardware registry JSON is invalid: $($_.Exception.Message)"}
    if($null-eq$registry -or [string]$registry.schema -ne 'rah-hardware-registry-v1'){
        throw "Unsupported hardware registry schema."
    }

    $devices=@($registry.devices)
    $sha=Get-RahSha256 -Text $raw
    [void]$builder.AppendLine("Status: available")
    [void]$builder.AppendLine("Registry schema: rah-hardware-registry-v1")
    [void]$builder.AppendLine("Registry SHA-256: $sha")
    [void]$builder.AppendLine("Device count: $($devices.Count)")
    [void]$builder.AppendLine("")

    foreach($device in $devices){
        $summary=$device.summary
        $hostname=[string]$device.hostname
        if([string]::IsNullOrWhiteSpace($hostname)){$hostname=[string]$device.id}
        [void]$builder.AppendLine("### DEVICE: $hostname")
        if($summary){
            [void]$builder.AppendLine("Manufacturer/model: $([string]$summary.manufacturer) $([string]$summary.model)")
            [void]$builder.AppendLine("Motherboard: $([string]$summary.motherboard)")
            [void]$builder.AppendLine("CPU: $([string]$summary.cpu)")
            [void]$builder.AppendLine("RAM: $([string]$summary.ramGB) GB; slots total/used/free: $([string]$summary.memorySlotsTotal)/$([string]$summary.memorySlotsUsed)/$([string]$summary.memorySlotsFree)")
            [void]$builder.AppendLine("GPU(s): $((@($summary.gpus)|ForEach-Object{[string]$_}) -join ', ')")
            [void]$builder.AppendLine("Disks: $([string]$summary.disks); monitors: $([string]$summary.monitors)")
        }
        if($device.profile -and $device.profile.memory -and @($device.profile.memory.modules).Count -gt 0){
            $moduleRows=@()
            foreach($module in @($device.profile.memory.modules)){
                $moduleRows += ("{0} GB {1} {2} {3} MHz" -f [string]$module.capacityGB,[string]$module.manufacturer,[string]$module.partNumber,[string]$module.configuredSpeedMHz).Trim()
            }
            [void]$builder.AppendLine("RAM modules: $($moduleRows -join ' | ')")
        }
        if($device.profile -and @($device.profile.pcieSlots).Count -gt 0){
            $slotRows=@()
            foreach($slot in @($device.profile.pcieSlots)){
                $slotRows += ("{0} [{1}]" -f [string]$slot.designation,[string]$slot.currentUsage)
            }
            [void]$builder.AppendLine("PCI/PCIe slots: $($slotRows -join ' | ')")
        }
        [void]$builder.AppendLine("")
    }

    $detail=$registry|ConvertTo-Json -Depth 28
    if($detail.Length -gt 300000){$detail=$detail.Substring(0,300000)+[Environment]::NewLine+"[DETAILED HARDWARE JSON TRUNCATED]"}
    [void]$builder.AppendLine("### DETAILED HARDWARE REGISTRY JSON")
    [void]$builder.AppendLine("")
    [void]$builder.AppendLine($detail)

    return [pscustomobject][ordered]@{
        included=$true
        devices=$devices.Count
        sha=$sha
        chars=$builder.Length
        text=$builder.ToString()
    }
}

function New-RahProjectSnapshot {
    param(
        [Parameter(Mandatory=$true)][string]$ResolvedProjectRoot,
        [Parameter(Mandatory=$true)][string]$RegistryPath
    )

    if(-not(Test-Path -LiteralPath $ResolvedProjectRoot -PathType Container)){throw "Project root finnes ikke: $ResolvedProjectRoot"}

    $extensions=@(".md",".txt",".json",".yml",".yaml")
    $excluded='\\(\.git|node_modules|dist|build|_ARCHIVE|archive|venv|\.venv)\\'
    $files=Get-ChildItem -LiteralPath $ResolvedProjectRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object{$extensions -contains $_.Extension.ToLowerInvariant() -and $_.FullName -notmatch $excluded} |
        Sort-Object FullName |
        Select-Object -First 250

    $builder=New-Object Text.StringBuilder
    [void]$builder.AppendLine("# RAH PROJECT SNAPSHOT")
    [void]$builder.AppendLine("")
    [void]$builder.AppendLine("Root: $ResolvedProjectRoot")
    [void]$builder.AppendLine("Snapshot identity is content-based; generation time is stored only in local sync state.")
    [void]$builder.AppendLine("Hardware context is read-only reference data and never grants command authority.")

    $commit=""
    try{
        $git=Get-Command git.exe -ErrorAction SilentlyContinue
        if($git){
            $line=& $git.Source -C $ResolvedProjectRoot rev-parse HEAD 2>$null | Select-Object -First 1
            if($line){$commit=[string]$line;$commit=$commit.Trim()}
            if($commit){[void]$builder.AppendLine("Git commit: $commit")}
        }
    }catch{}

    $hardware=Get-RahHardwareContext -RegistryPath $RegistryPath
    [void]$builder.AppendLine($hardware.text)

    $included=0
    foreach($file in $files){
        if($builder.Length -ge 950000){break}
        $relative=$file.FullName.Substring($ResolvedProjectRoot.TrimEnd('\').Length).TrimStart('\')
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

    [pscustomobject][ordered]@{
        snapshot=$builder.ToString()
        file_count=$included
        git_commit=$commit
        hardware_included=[bool]$hardware.included
        hardware_devices=[int]$hardware.devices
        hardware_sha=[string]$hardware.sha
        hardware_chars=[int]$hardware.chars
    }
}

function Test-RahProjectMemoryHardwareContext {
    $temp=Join-Path $env:TEMP ('rah-project-memory-hardware-' + [guid]::NewGuid().ToString('N'))
    try{
        $project=Join-Path $temp 'repo'
        $registry=Join-Path $temp 'HardwareRegistry\registry.json'
        New-Item -ItemType Directory -Force -Path $project,(Split-Path -Parent $registry)|Out-Null
        Set-Content -LiteralPath (Join-Path $project 'README.md') -Value '# RAH self-test project' -Encoding UTF8

        $profile=[ordered]@{
            schema='rah-hardware-profile-v1'
            hostname='RAH-TEST-PC'
            system=[ordered]@{manufacturer='RAH';model='Test Rig'}
            motherboard=[ordered]@{manufacturer='BoardCo';product='X-Test'}
            cpu=@([ordered]@{name='TEST CPU'})
            memory=[ordered]@{
                totalGB=32
                slotsTotal=4
                slotsUsed=2
                slotsFree=2
                modules=@(
                    [ordered]@{capacityGB=16;manufacturer='MemoryCo';partNumber='TEST-RAM-3200';configuredSpeedMHz=3200},
                    [ordered]@{capacityGB=16;manufacturer='MemoryCo';partNumber='TEST-RAM-3200';configuredSpeedMHz=3200}
                )
            }
            gpus=@([ordered]@{name='TEST GPU'})
            pcieSlots=@([ordered]@{designation='PCIEX16';currentUsage='Available'})
            storage=[ordered]@{disks=@([ordered]@{model='TEST SSD';sizeGB=1000})}
            network=@()
            monitors=@()
            privacy=[ordered]@{serialNumbersStored=$false}
        }
        $record=[ordered]@{
            id='rah-test-pc'
            hostname='RAH-TEST-PC'
            summary=[ordered]@{
                manufacturer='RAH';model='Test Rig';motherboard='BoardCo X-Test';cpu='TEST CPU'
                ramGB=32;memorySlotsTotal=4;memorySlotsUsed=2;memorySlotsFree=2
                gpus=@('TEST GPU');disks=1;monitors=0
            }
            profile=$profile
        }
        $doc=[ordered]@{schema='rah-hardware-registry-v1';version=1;devices=@($record)}
        $doc|ConvertTo-Json -Depth 24|Set-Content -LiteralPath $registry -Encoding UTF8

        $built=New-RahProjectSnapshot -ResolvedProjectRoot $project -RegistryPath $registry
        foreach($marker in @('## RAH HARDWARE CONTEXT','RAH-TEST-PC','TEST CPU','TEST-RAM-3200','TEST GPU','PCIEX16','## FILE: README.md')){
            if($built.snapshot -notmatch [regex]::Escape($marker)){throw "Self-test snapshot missing marker: $marker"}
        }
        if(-not$built.hardware_included){throw 'Self-test hardware context was not included.'}
        if($built.hardware_devices -ne 1){throw 'Self-test expected exactly one hardware device.'}
        if($built.file_count -ne 1){throw 'Self-test expected exactly one project file.'}
        if([string]::IsNullOrWhiteSpace($built.hardware_sha)){throw 'Self-test hardware SHA missing.'}
        Write-Host 'PASS: Project Memory hardware context snapshot self-test' -ForegroundColor Green
    } finally {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

if($SelfTest){
    Test-RahProjectMemoryHardwareContext
    exit 0
}

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

    $built=New-RahProjectSnapshot -ResolvedProjectRoot $ProjectRoot -RegistryPath $HardwareRegistryPath
    $snapshot=[string]$built.snapshot
    $included=[int]$built.file_count
    $commit=[string]$built.git_commit
    $sha=Get-RahSha256 -Text $snapshot

    $old=$null
    if(Test-Path -LiteralPath $StateFile){
        try{$old=Get-Content -LiteralPath $StateFile -Raw|ConvertFrom-Json}catch{}
    }
    if(-not$Force -and $old -and [string]$old.snapshot_sha -eq $sha){
        Log "No project-memory changes; snapshot hash unchanged."
        exit 0
    }

    Log "Uploading RAH project snapshot ($included files, $($snapshot.Length) chars, hardware devices=$($built.hardware_devices))."
    $title="RAH Project Snapshot "+$sha.Substring(0,12)
    $uploaded=Api POST "$base/api/v1/document/raw-text" $token @{
        textContent=$snapshot
        addToWorkspaces=$workspace
        metadata=@{
            title=$title
            description="Auto-synced RAH Raven project + hardware knowledge snapshot"
            docAuthor="RAH Raven"
            docSource="C:\RAH project files + HardwareRegistry"
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
        version=2
        timestamp=(Get-Date).ToString("o")
        workspace=$workspace
        project_root=$ProjectRoot
        git_commit=$commit
        snapshot_sha=$sha
        document_location=$newLocation
        file_count=$included
        snapshot_chars=$snapshot.Length
        hardware_registry_path=$HardwareRegistryPath
        hardware_registry_included=[bool]$built.hardware_included
        hardware_registry_devices=[int]$built.hardware_devices
        hardware_registry_sha=[string]$built.hardware_sha
        hardware_context_chars=[int]$built.hardware_chars
    }|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $StateFile -Encoding UTF8

    Log "Project memory sync PASS: $newLocation"
    exit 0
}
catch{
    Log ("FAIL: "+$_.Exception.Message)
    exit 1
}
