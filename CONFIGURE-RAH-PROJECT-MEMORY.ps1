param(
    [string]$BaseUrl = "",
    [string]$Workspace = "",
    [string]$WorkspaceName = "RAH Raven",
    [switch]$NoCreateWorkspace,
    [switch]$NoSyncTask
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = "C:\RAH\AI-Fabric"
$Secrets = Join-Path $Root "Secrets"
$ConfigFile = Join-Path $Root "project-memory.json"
$TokenFile = Join-Path $Secrets "anythingllm-token.txt"
$ReadyFile = "C:\RAH\PROJECT-MEMORY-READY.txt"
$SyncPs1 = "C:\RAH\SYNC-RAH-PROJECT-MEMORY.ps1"
$SyncTask = "RAH Raven Project Memory Sync"

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Elevate {
    if (Is-Admin) { return }
    $args = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$PSCommandPath`"")
    if ($BaseUrl) { $args += @("-BaseUrl",$BaseUrl) }
    if ($Workspace) { $args += @("-Workspace",$Workspace) }
    if ($WorkspaceName) { $args += @("-WorkspaceName",$WorkspaceName) }
    if ($NoCreateWorkspace) { $args += "-NoCreateWorkspace" }
    if ($NoSyncTask) { $args += "-NoSyncTask" }
    Start-Process powershell.exe -Verb RunAs -Wait -ArgumentList $args
    exit
}

function Say([string]$Text,[ConsoleColor]$Color=[ConsoleColor]::Gray) {
    Write-Host $Text -ForegroundColor $Color
}

function Start-AnythingLLM {
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "http://127.0.0.1:3001/api/docs" -TimeoutSec 2 | Out-Null
        Say "AnythingLLM: allerede online." Green
        return
    } catch {}

    $candidates = @(
        "$env:LOCALAPPDATA\Programs\AnythingLLM\AnythingLLM.exe",
        "$env:LOCALAPPDATA\Programs\anythingllm-desktop\AnythingLLM.exe",
        "$env:LOCALAPPDATA\Programs\AnythingLLM Desktop\AnythingLLM.exe",
        "$env:ProgramFiles\AnythingLLM\AnythingLLM.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            Say "Starter AnythingLLM..." Cyan
            Start-Process -FilePath $candidate -ErrorAction SilentlyContinue
            return
        }
    }

    $winget=Get-Command winget.exe -ErrorAction SilentlyContinue
    if ($winget) {
        Say "AnythingLLM er ikke installert. Installerer automatisk via Winget..." Cyan
        & $winget.Source install --id MintplexLabs.AnythingLLM -e --source winget --silent --accept-source-agreements --accept-package-agreements --disable-interactivity
        if($LASTEXITCODE-ne0){
            Say "Winget returnerte kode $LASTEXITCODE. Sjekker likevel om appen ble installert." Yellow
        }
        Start-Sleep -Seconds 2
        foreach ($candidate in $candidates) {
            if (Test-Path -LiteralPath $candidate) {
                Start-Process -FilePath $candidate -ErrorAction SilentlyContinue
                Say "AnythingLLM install/start: OK." Green
                return
            }
        }
    }

    Say "AnythingLLM kunne ikke auto-installeres/startes." Yellow
}

function Wait-Anything([string]$Url,[int]$Seconds=30) {
    $end=(Get-Date).AddSeconds($Seconds)
    do {
        try {
            Invoke-WebRequest -UseBasicParsing -Uri "$Url/api/docs" -TimeoutSec 3 | Out-Null
            return $true
        } catch {}
        Start-Sleep -Milliseconds 700
    } while ((Get-Date)-lt$end)
    return $false
}

function SecureString-ToPlain([Security.SecureString]$Secure) {
    $ptr=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

function Save-Token([string]$Token) {
    New-Item -ItemType Directory -Force -Path $Secrets | Out-Null
    [IO.File]::WriteAllText($TokenFile,$Token,[Text.UTF8Encoding]::new($false))

    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    $sid=$identity.User
    $acl=New-Object Security.AccessControl.FileSecurity
    $acl.SetAccessRuleProtection($true,$false)
    $rule=New-Object Security.AccessControl.FileSystemAccessRule(
        $sid,
        [Security.AccessControl.FileSystemRights]::FullControl,
        [Security.AccessControl.AccessControlType]::Allow
    )
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $TokenFile -AclObject $acl
}

function Api([string]$Method,[string]$Url,[string]$Token,[object]$Body=$null) {
    $headers=@{ Authorization="Bearer $Token"; Accept="application/json" }
    if ($null -eq $Body) {
        return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -TimeoutSec 15
    }
    return Invoke-RestMethod -Method $Method -Uri $Url -Headers $headers -ContentType "application/json" -Body ($Body|ConvertTo-Json -Depth 8) -TimeoutSec 30
}

function Register-SyncTask {
    if ($NoSyncTask -or -not (Test-Path -LiteralPath $SyncPs1)) { return }
    Import-Module ScheduledTasks -ErrorAction Stop
    $user=[Security.Principal.WindowsIdentity]::GetCurrent().Name
    $action=New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$SyncPs1`""
    $logon=New-ScheduledTaskTrigger -AtLogOn -User $user
    $repeat=New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(2)) -RepetitionInterval (New-TimeSpan -Hours 1)
    $principal=New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    Register-ScheduledTask -TaskName $SyncTask -Action $action -Trigger @($logon,$repeat) -Principal $principal -Settings $settings -Force | Out-Null
    Say "Project Memory Sync: autostart + hver time." Green
}

Elevate
New-Item -ItemType Directory -Force -Path $Root,$Secrets | Out-Null

Start-AnythingLLM

if (-not $BaseUrl) {
    $default="http://127.0.0.1:3001"
    $entered=Read-Host "AnythingLLM URL [$default]"
    $BaseUrl=if($entered){$entered}else{$default}
}
$BaseUrl=$BaseUrl.TrimEnd("/")

if ($BaseUrl -notmatch '^https?://(127\.0\.0\.1|localhost)(:\d+)?$') {
    Say "ADVARSEL: AnythingLLM er ikke localhost. Developer API-tokenet har hoy tilgang." Yellow
    $confirm=Read-Host "Skriv JA for a bruke ekstern URL"
    if ($confirm -ne "JA") { throw "Avbrutt: ekstern AnythingLLM URL ikke godkjent." }
}

if (-not (Wait-Anything -Url $BaseUrl -Seconds 30)) {
    throw "AnythingLLM svarer ikke pa $BaseUrl. Start/installér AnythingLLM og kjor filen igjen."
}

$Token=""
if (Test-Path -LiteralPath $TokenFile) {
    $existing=[IO.File]::ReadAllText($TokenFile).Trim()
    if ($existing) {
        try {
            $auth=Api GET "$BaseUrl/api/v1/auth" $existing
            if ($auth.authenticated -eq $true) {
                $Token=$existing
                Say "Eksisterende API-token: valid." Green
            }
        } catch {}
    }
}

if (-not $Token) {
    Say ""
    Say "I AnythingLLM: Settings -> Developer API -> lag/kopier API key." Cyan
    Say "IKKE send tokenet i ChatGPT. Lim det kun inn i dette lokale vinduet." Yellow
    Start-Process $BaseUrl -ErrorAction SilentlyContinue
    $secure=Read-Host "Lim inn Developer API-token (skjult)" -AsSecureString
    $Token=SecureString-ToPlain $secure
    if (-not $Token) { throw "Tom API-token." }

    $auth=Api GET "$BaseUrl/api/v1/auth" $Token
    if ($auth.authenticated -ne $true) { throw "AnythingLLM avviste API-tokenet." }
    Save-Token $Token
    Say "API-token lagret lokalt med beskyttet Windows ACL." Green
}

$auth=Api GET "$BaseUrl/api/v1/auth" $Token
if ($auth.authenticated -ne $true) { throw "API auth feilet." }

$list=Api GET "$BaseUrl/api/v1/workspaces" $Token
$workspaces=@($list.workspaces)

if (-not $Workspace) {
    if (Test-Path -LiteralPath $ConfigFile) {
        try {
            $old=Get-Content -LiteralPath $ConfigFile -Raw|ConvertFrom-Json
            if ($old.workspace) { $Workspace=[string]$old.workspace }
        } catch {}
    }
}
if (-not $Workspace) { $Workspace="rah-raven" }

$match=@($workspaces|Where-Object{[string]$_.slug -eq $Workspace})|Select-Object -First 1
if (-not $match -and -not $NoCreateWorkspace) {
    Say "Workspace '$Workspace' finnes ikke. Oppretter RAH-workspace..." Cyan
    $created=Api POST "$BaseUrl/api/v1/workspace/new" $Token @{
        name=$WorkspaceName
        chatMode="chat"
        topN=6
        openAiHistory=12
        openAiTemp=0.2
        openAiPrompt="Use workspace documents as RAH project knowledge. State uncertainty and cite source names when possible."
    }
    if (-not $created.workspace) { throw "AnythingLLM opprettet ikke workspace." }
    $Workspace=[string]$created.workspace.slug
    Say "Workspace opprettet: $Workspace" Green
} elseif (-not $match) {
    throw "Workspace '$Workspace' finnes ikke og auto-oppretting er deaktivert."
} else {
    Say "Workspace funnet: $Workspace" Green
}

$projectRoot = if(Test-Path "C:\RAH\rah-platform"){"C:\RAH\rah-platform"}elseif(Test-Path "C:\RAH\AI-Fabric\rah-platform"){"C:\RAH\AI-Fabric\rah-platform"}else{"C:\RAH\rah-platform"}

$config=[ordered]@{
    schema="rah-raven-project-memory"
    version=1
    enabled=$true
    provider="anythingllm"
    base_url=$BaseUrl
    workspace=$Workspace
    workspace_name=$WorkspaceName
    token_file=$TokenFile
    auto_context=$true
    always_for_council=$true
    max_context_chars=12000
    session_id="rah-raven-project-memory"
    reset_session_each_query=$true
    source_policy="workspace-documents-only"
    project_root=$projectRoot
    sync_interval_minutes=60
}
$config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $ConfigFile -Encoding UTF8
Say "Config: $ConfigFile" Green

try {
    $workspaceInfo=Api GET "$BaseUrl/api/v1/workspace/$([uri]::EscapeDataString($Workspace))" $Token
    $count=0
    if($workspaceInfo.workspace){
        $ws=@($workspaceInfo.workspace)|Select-Object -First 1
        $count=@($ws.documents).Count
    }
    Say "Workspace dokumenter: $count" Cyan
} catch {
    Say "Workspace finnes, men detaljtest feilet: $($_.Exception.Message)" Yellow
}

Register-SyncTask

if (Test-Path -LiteralPath $SyncPs1) {
    Say "Kjorer forste RAH Project Memory sync..." Cyan
    & powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $SyncPs1
    if ($LASTEXITCODE -ne 0) {
        Say "Forste sync feilet. Config/token er likevel lagret; sync-task vil prove igjen." Yellow
    }
}

try {
    if(Get-ScheduledTask -TaskName "RAH Raven Bridge" -ErrorAction SilentlyContinue){
        Start-ScheduledTask -TaskName "RAH Raven Bridge" -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
} catch {}

$ready=@"
RAH RAVEN PROJECT MEMORY CONFIGURED
===================================
AnythingLLM : $BaseUrl
Workspace   : $Workspace
Config      : $ConfigFile
Token       : stored locally in protected Secrets file (not shown)
Auto context: ON for Raven Council
Auto sync   : $(if($NoSyncTask){"OFF"}else{"ON / hourly"})
Project root: $projectRoot

Raven endpoints:
http://127.0.0.1:18765/ai/memory/status
http://127.0.0.1:18765/ai/memory/context
http://127.0.0.1:18765/ai/council/run
"@
[IO.File]::WriteAllText($ReadyFile,$ready,[Text.UTF8Encoding]::new($false))

Say ""
Say "RAH PROJECT MEMORY: CONFIGURED" Green
Say "Workspace: $Workspace" Green
Say "Raven Council henter na relevant workspace-kunnskap automatisk." Green
