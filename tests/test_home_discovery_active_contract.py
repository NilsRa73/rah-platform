from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ACTIVE = ROOT / 'RAH-HOME-DISCOVERY-ACTIVE.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f'Uønsket mekanisme i aktiv discovery: {label}: {needle!r}')


def main() -> None:
    text = ACTIVE.read_text(encoding='utf-8')

    require(text, '[switch]$Start', 'aktiv discovery krever eksplisitt start-switch')
    require(text, "if (-not $Start)", 'ingen scanning uten Start')
    require(text, 'Kjør bare på eget eller autorisert lokalnett', 'autorisasjonstekst')
    require(text, 'function Test-RahPrivateIPv4', 'RFC1918-vakt')
    require(text, '$selected.prefixLength -lt 24 -or $selected.prefixLength -gt 30', 'subnett avgrenses til /24-/30')
    require(text, 'if ($MaxHosts -lt 1 -or $MaxHosts -gt 254)', 'maks 254 hosts')
    require(text, '[int]$DelayMs = 20', 'rate-limit delay finnes')
    require(text, '[int]$TimeoutMs = 250', 'kort ping timeout finnes')
    require(text, '[System.Net.NetworkInformation.Ping]::new()', 'kun ICMP echo-probing')
    require(text, "protocol = 'ICMP echo only'", 'output dokumenterer ICMP-only')
    require(text, "mode = 'active-local-subnet'", 'aktiv mode i JSON')
    require(text, 'passive = $false', 'aktiv markering')
    require(text, "authorization = 'explicit-start-local-private-subnet'", 'output dokumenterer eksplisitt start')
    require(text, "source = 'rah-active-icmp-local-subnet'", 'kandidatkilde')

    for token, label in (
        ('Test-NetConnection', 'port probing'),
        ('TcpClient', 'rå TCP probing'),
        ('HttpClient', 'HTTP probing'),
        ('Invoke-WebRequest', 'HTTP probing'),
        ('Invoke-RestMethod', 'REST probing'),
        ('nmap', 'ekstern portskanner'),
        ('UdpClient', 'UDP probing'),
    ):
        forbid(text, token, label)

    print('PASS: RAH Home Discovery active local-subnet safety contract')


if __name__ == '__main__':
    main()
