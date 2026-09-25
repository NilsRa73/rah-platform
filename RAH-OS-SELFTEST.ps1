param(
    [switch]$Quick,
    [switch]$Repair,
    [switch]$JsonOnly,
    [switch]$ContractOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$script:Version = '0.8.0-candidate'
$script:Root = 'C:\RAH\RavenOS'
$script:Ref = if($env:RAH_OS_SOURCE_REF){$env:RAH_OS_SOURCE_REF}else{'rah-os-v0.8-consolidation'}
$script:Base = 'https://raw.githubusercontent.com/NilsRa73/rah-platform/' + $script:Ref
$script:Files = @(
 'START-HER-RAH-OS.cmd','INSTALL-RAH-OS.cmd','REPAIR-RAH-OS.cmd',
 'RAH-OS-CONTROL.ps1','RAH-OS-SELFTEST.ps1',
 'RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.cmd','RUN-RAH-OS-v0.8-HOVED-PC-ACCEPTANCE.ps1',
 'RAVEN-CORE-7.ps1','RAVEN-AI-SELF-CHECK.ps1','TEST-ANYTHINGLLM-APPROVAL.ps1',
 'RAVEN-CORE-7-WORKER-PROOF.ps1','START-RAH-AI-FABRIC.cmd','WORKER-PROOF.cmd','DIAGNOSTICS.cmd',
 'RAH-OS-v0.8-PLAN.md'
)

if($ContractOnly){
    if($script:Version -ne '0.8.0-candidate'){throw 'Version contract failed.'}
    if(@($script:Files | Select-Object -Unique).Count -ne $script:Files.Count){throw 'Duplicate manifest entry.'}
    foreach($name in $script:Files){
        if($name -match '[\\/]' -or $name -match '^\.' ){throw ('Unsafe manifest entry: ' + $name)}
    }
    Write-Host 'PASS: RAH OS v0.8 self-test contract'
    exit 0
}

$results=[System.Collections.Generic.List[object]]::new()
function Add([string]$Name,[string]$Status,[string]$Detail){
    $results.Add([pscustomobject][ordered]@{name=$Name;status=$Status;detail=$Detail})|Out-Null
}
function Port([int]$P){
    try{$c=New-Object Net.Sockets.TcpClient;$a=$c.BeginConnect('127.0.0.1',$P,$null,$null);$ok=$a.AsyncWaitHandle.WaitOne(300,$false);if($ok -and $c.Connected){$c.EndConnect($a);$c.Close();return $true};$c.Close()}catch{}
    return $false
}

if($Repair){
    New-Item -ItemType Directory -Force -Path $script:Root,(Join-Path $script:Root 'logs'),(Join-Path $script:Root 'state')|Out-Null
    foreach($f in $script:Files){
        if($f -eq 'RAH-OS-SELFTEST.ps1'){continue}
        $dst=Join-Path $script:Root $f
        $tmp=$dst+'.download'
        try{
            Invoke-WebRequest -UseBasicParsing -Uri ($script:Base+'/'+$f) -OutFile $tmp
            if((Get-Item -LiteralPath $tmp).Length -lt 20){throw 'download too small'}
            Move-Item -LiteralPath $tmp -Destination $dst -Force
            Add ('repair:'+ $f) 'PASS' 'refreshed'
        }catch{
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            Add ('repair:'+ $f) 'FAIL' $_.Exception.Message
        }
    }
}

if($PSVersionTable.PSVersion.Major -ge 5){Add 'PowerShell' 'PASS' ([string]$PSVersionTable.PSVersion)}else{Add 'PowerShell' 'FAIL' 'PowerShell 5+ required'}
try{Add-Type -AssemblyName PresentationFramework -ErrorAction Stop;Add 'WPF' 'PASS' 'available'}catch{Add 'WPF' 'FAIL' $_.Exception.Message}

foreach($f in $script:Files){
    $p=Join-Path $script:Root $f
    if(Test-Path -LiteralPath $p -PathType Leaf){
        $len=(Get-Item -LiteralPath $p).Length
        if($len -ge 20){Add $f 'PASS' ($len.ToString()+' bytes')}else{Add $f 'FAIL' 'file too small'}
    }else{Add $f 'FAIL' 'missing'}
}

if(-not $Quick){
    Add 'Raven Core :18765' $(if(Port 18765){'PASS'}else{'INFO'}) $(if(Port 18765){'online'}else{'offline / can be started'})
    Add 'Node Agent :18766' 'INFO' $(if(Port 18766){'online / explicit'}else{'offline / explicit by design'})
    Add 'LM Studio :1234' $(if(Port 1234){'PASS'}else{'INFO'}) $(if(Port 1234){'online'}else{'offline / optional until AI start'})
    Add 'AnythingLLM :3001' $(if(Port 3001){'PASS'}else{'INFO'}) $(if(Port 3001){'online'}else{'offline / approval may remain pending'})
}

$fail=@($results|Where-Object status -eq 'FAIL').Count
$summary=[pscustomobject][ordered]@{
 schema='rah-os-v08-selftest';version=$script:Version;computer=$env:COMPUTERNAME;
 timestamp=(Get-Date).ToUniversalTime().ToString('o');
 result=$(if($fail){'FAIL'}else{'PASS'});checks=@($results);
 safety=@('fixed manifest only','loopback status only','no USB changes','no partition changes','no automatic Node Agent start')
}
New-Item -ItemType Directory -Force -Path (Join-Path $script:Root 'state')|Out-Null
$summary|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $script:Root 'state\RAH-OS-v0.8-SELFTEST.json') -Encoding UTF8

if($JsonOnly){$summary|ConvertTo-Json -Depth 8}else{
 Write-Host ''
 Write-Host '============================================================' -ForegroundColor DarkYellow
 Write-Host '              RAH OS v0.8 - SELF TEST' -ForegroundColor Yellow
 Write-Host '============================================================' -ForegroundColor DarkYellow
 foreach($r in $results){$c=switch($r.status){'PASS'{'Green'}'FAIL'{'Red'}'INFO'{'DarkGray'}default{'Yellow'}};Write-Host (('{0,-5} {1,-42} {2}' -f $r.status,$r.name,$r.detail)) -ForegroundColor $c}
 Write-Host ''
 Write-Host ('RESULT: '+$summary.result) -ForegroundColor $(if($fail){'Red'}else{'Green'})
}
if($fail){exit 1}else{exit 0}
