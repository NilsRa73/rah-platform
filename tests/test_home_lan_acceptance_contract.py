from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'RAH-HOME-LAN-ACCEPTANCE.ps1'
INSTALL = ROOT / 'RAH-HOME-INSTALL.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler LAN acceptance-kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f'Uønsket LAN acceptance-adferd: {label}: {needle!r}')


def main() -> None:
    text = SCRIPT.read_text(encoding='utf-8')
    install = INSTALL.read_text(encoding='utf-8')

    require(text, "[Parameter(Mandatory=$true)][string]$WorkerAddress", 'worker-adresse må oppgis eksplisitt')
    require(text, "[ValidateRange(1024,65535)][int]$Port=18766", 'port er avgrenset')
    require(text, "WorkerAddress må være en privat RFC1918 IPv4-adresse", 'kun privat IPv4')
    require(text, "-Action hello", 'hello før pairing')
    require(text, "Read-Host 'Skriv den seks-sifrede PAIR CODE", 'pair code må oppgis manuelt')
    require(text, "-Action pair -PairCode $pairCode", 'eksplisitt pairing')
    require(text, "@('health','systemInfo','benchmark')", 'fast autentisert test-allowlist')
    require(text, "schema='rah-home-lan-acceptance'", 'rapport-schema')
    require(text, "pass=$pass", 'eksplisitt pass/fail i rapport')
    require(text, "results.Count-eq5", 'alle fem steg må lykkes')
    require(install, "'RAH-HOME-LAN-ACCEPTANCE.ps1'", 'installer inkluderer acceptance-script')
    require(install, "RAH Test Worker LAN.cmd", 'leader får one-click LAN-test')

    for token, label in (
        ('0.0.0.0', 'wildcard bind'),
        ('Invoke-Expression', 'vilkårlig PowerShell'),
        ('ScriptBlock]::Create', 'dynamisk scriptblock'),
        ('cmd /c', 'arbitrary cmd shell'),
        ('nmap', 'portskanning'),
    ):
        forbid(text, token, label)

    print('PASS: RAH Home physical LAN acceptance contract')


if __name__ == '__main__':
    main()
