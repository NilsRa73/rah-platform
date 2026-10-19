[CmdletBinding()]
param([switch]$SelfTest,[switch]$NoLaunch)
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $MyInvocation.MyCommand.Path
$Files=@(
 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.html',
 'RAH-RAVEN-STUDIO-DIAGNOSTICS-V3.1-CANDIDATE.5.html',
 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.json',
 'RAH-RAVEN-STUDIO-ONECLICK-V3.1-CANDIDATE.5.ps1',
 'SAFE-REPAIR-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.ps1',
 'START-HER-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.cmd'
)
function Need([bool]$Ok,[string]$Text){if(-not $Ok){throw $Text};Write-Host "[PASS] $Text"}
try{
 foreach($f in $Files){Need (Test-Path -LiteralPath (Join-Path $Root $f) -PathType Leaf) "Exists: $f"}
 $m=Get-Content -LiteralPath (Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.json') -Raw -Encoding UTF8|ConvertFrom-Json
 Need ([string]$m.version -eq '3.1.0-candidate.5') 'Candidate.5 manifest version'
 Need ($m.one_click_startup.precheck -eq $true) 'PRECHECK enabled'
 Need ($m.one_click_startup.safe_repair -eq $true) 'SAFE REPAIR enabled'
 Need ($m.one_click_startup.postcheck -eq $true) 'POSTCHECK enabled'
 Need ($m.one_click_startup.opens_studio -eq $true) 'Studio auto-open enabled'
 $o=Get-Content -LiteralPath (Join-Path $Root 'RAH-RAVEN-STUDIO-ONECLICK-V3.1-CANDIDATE.5.ps1') -Raw -Encoding UTF8
 foreach($x in @('PRECHECK','Safe Repair','POSTCHECK','STARTUP $result','RAVEN-STUDIO-ONECLICK-LATEST.json')){Need ($o.Contains($x)) "Orchestrator marker: $x"}
 Need (-not $o.Contains('pip install')) 'Orchestrator does not install packages'
 Need (-not $o.Contains('Stop-Process')) 'Orchestrator does not kill processes'
 $s=Get-Content -LiteralPath (Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.html') -Raw -Encoding UTF8
 Need ($s.Contains('STARTUP PASS')) 'Studio PASS banner contract'
 Need ($s.Contains('STARTUP FAIL')) 'Studio FAIL banner contract'
 Write-Host 'RAH RAVEN STUDIO v3.1 CANDIDATE.5 SELF-TEST: PASS'
 if(-not $SelfTest -and -not $NoLaunch){Start-Process -FilePath (Join-Path $Root 'RAH-RAVEN-STUDIO-V3.1-CANDIDATE.5.html')}
 exit 0
}catch{Write-Host "[FAIL] $($_.Exception.Message)";exit 1}
