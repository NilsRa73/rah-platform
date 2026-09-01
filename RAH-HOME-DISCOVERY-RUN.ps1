$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DiscoveryScript = Join-Path $Root 'RAH-HOME-DISCOVERY.ps1'
$Output = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\rah-home-discovery.json'
$InboxUrl = 'https://nilsra73.github.io/rah-platform/RAH-HOME-DISCOVERY-INBOX.html'

if (-not (Test-Path -LiteralPath $DiscoveryScript)) {
    throw "Fant ikke RAH-HOME-DISCOVERY.ps1 ved siden av denne filen."
}

& $DiscoveryScript -OutputPath $Output

Write-Host ''
Write-Host 'RAH Home Discovery er ferdig.' -ForegroundColor Yellow
Write-Host "JSON-fil: $Output"
Write-Host 'Inbox åpnes i nettleseren. Velg JSON-filen og godkjenn bare enhetene du kjenner igjen.'

Start-Process $InboxUrl
Start-Process explorer.exe "/select,`"$Output`""
