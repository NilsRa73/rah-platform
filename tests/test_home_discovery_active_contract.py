from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACTIVE = ROOT / 'RAH-HOME-DISCOVERY-ACTIVE.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket mekanisme i aktiv discovery: {label}: {needle!r}')


def main() -> None:
    text = ACTIVE.read_text(encoding='utf-8')

    require(text, '[switch]$Start', 'aktiv discovery krever eksplisitt start-switch')
    require(text, '[switch]$SelfTest', 'innebygd self-test')
    require(text, '[int]$InterfaceIndex = 0', 'eksplisitt adaptervalg støttes')
    require(text, 'if (-not $Start)', 'ingen scanning uten Start')
    require(text, 'Kjør bare på eget eller autorisert lokalnett', 'autorisasjonstekst')
    require(text, 'function Test-RahPrivateIPv4', 'RFC1918-vakt')
    require(text, '[System.Net.IPAddress]::TryParse', 'robust IPv4-parsing')
    require(text, 'function Get-RahSubnetPlan', 'testbar subnettberegning')
    require(text, 'function Get-RahScanTargets', 'avgrenset targetliste')
    require(text, '$PrefixLength -lt 24 -or $PrefixLength -gt 30', 'subnett avgrenses til /24-/30')
    require(text, '$HostLimit -lt 1 -or $HostLimit -gt 254', 'maks 254 hosts')
    require(text, '[int]$DelayMs = 20', 'rate-limit delay finnes')
    require(text, '[int]$TimeoutMs = 250', 'kort ping timeout finnes')
    require(text, '[System.Net.NetworkInformation.Ping]::new()', 'kun ICMP echo-probing')
    require(text, "$ping.Dispose()", 'Ping-ressurs frigis')
    require(text, "protocol = 'ICMP echo only'", 'output dokumenterer ICMP-only')
    require(text, "mode = 'active-local-subnet'", 'aktiv mode i JSON')
    require(text, 'passive = $false', 'aktiv markering')
    require(text, "authorization = 'explicit-start-local-private-subnet'", 'output dokumenterer eksplisitt start')
    require(text, "source = 'rah-active-icmp-local-subnet'", 'kandidatkilde')
    require(text, "scriptVersion = $script:RahActiveDiscoveryVersion", 'script-versjon i output')
    require(text, 'function Normalize-RahNeighborState', 'neighbor state normaliseres til Inbox-kontrakt')
    require(text, 'Flere private adaptere er aktive. Kjør på nytt med -InterfaceIndex.', 'uklart adaptervalg avvises')

    for token, label in (
        ('Test-NetConnection', 'port probing'),
        ('TcpClient', 'rå TCP probing'),
        ('HttpClient', 'HTTP probing'),
        ('Invoke-WebRequest', 'HTTP probing'),
        ('Invoke-RestMethod', 'REST probing'),
        ('nmap', 'ekstern portskanner'),
        ('UdpClient', 'UDP probing'),
        ('Start-Process', 'ekstern prosessstart'),
        ('Invoke-Expression', 'vilkårlig PowerShell-kjøring'),
    ):
        forbid(text, token, label)

    print('PASS: RAH Home Discovery Active v1 safety contract')


if __name__ == '__main__':
    main()
