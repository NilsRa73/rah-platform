$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$DiscoveryScript = Join-Path $Root 'RAH-HOME-DISCOVERY-ACTIVE.ps1'
$Output = Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Downloads\rah-home-discovery-active.json'
$InboxUrl = 'https://nilsra73.github.io/rah-platform/RAH-HOME-DISCOVERY-INBOX.html'

if (-not (Test-Path -LiteralPath $DiscoveryScript)) {
    throw "Fant ikke RAH-HOME-DISCOVERY-ACTIVE.ps1 ved siden av denne filen."
}

Write-Host 'RAH Home Discovery – AKTIV LOKALNETT PROTOTYPE' -ForegroundColor Yellow
Write-Host 'Dette sender ICMP echo til adresser i ditt aktive private lokalnett.'
Write-Host 'Ingen portskanning eller tjenesteprobing utføres.'
Write-Host ''
$answer = Read-Host 'Kjør bare på eget/autoriserte nett. Skriv JA for å starte'
if ($answer -ne 'JA') {
    Write-Host 'Avbrutt. Ingen aktiv discovery ble kjørt.' -ForegroundColor DarkYellow
    exit 0
}

& $DiscoveryScript -Start -OutputPath $Output

Write-Host ''
Write-Host 'RAH aktiv Home Discovery er ferdig.' -ForegroundColor Green
Write-Host "JSON-fil: $Output"
Write-Host 'Inbox åpnes i nettleseren. Godkjenn bare enhetene du kjenner igjen.'

Start-Process $InboxUrl
Start-Process explorer.exe "/select,`"$Output`""
