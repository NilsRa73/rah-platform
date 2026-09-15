from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'RAH-HOME-LAN-ACCEPTANCE.ps1'
INSTALL = ROOT / 'RAH-HOME-INSTALL.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler LAN acceptance-kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket LAN acceptance-adferd: {label}: {needle!r}')


def main() -> None:
    text = SCRIPT.read_text(encoding='utf-8')
    install = INSTALL.read_text(encoding='utf-8')

    for needle, label in (
        ("RahLanAcceptanceVersion = '1.0.0'", 'stable helper version'),
        ('Set-StrictMode -Version Latest', 'strict mode'),
        ("[string]$WorkerAddress = ''", 'worker address supports network-free self-test'),
        ('Invoke-RahLanAcceptanceSelfTest', 'network-free self-test'),
        ('WorkerAddress må være en privat RFC1918 IPv4-adresse', 'runtime requires private IPv4'),
        ("Get-RahNodeClientPath", 'installed client resolver'),
        ("Join-Path $PSScriptRoot 'RAH-HOME-NODE-CLIENT.ps1'", 'adjacent client preferred'),
        ("RahProtocolVersion = 2", 'agent protocol contract'),
        ("Invoke-RahClient -Client $client -Address $worker -Action 'hello'", 'hello before pairing'),
        ("Read-Host 'Skriv den seks-sifrede PAIR CODE", 'pair code must be manual'),
        ("Invoke-RahClient -Client $client -Address $worker -Action 'pair' -PairCode $pairCode", 'explicit pairing'),
        ("foreach ($action in @('health','systemInfo','benchmark'))", 'fixed authenticated test allowlist'),
        ("schema='rah-home-lan-acceptance'", 'report schema'),
        ('pass=$pass', 'explicit pass/fail'),
        ('$results.Count -eq 5', 'all five steps required'),
        ("Join-Path $PSHOME 'powershell.exe'", 'fixed Windows PowerShell child'),
    ):
        require(text, needle, label)

    require(install, "'RAH-HOME-LAN-ACCEPTANCE.ps1'", 'installer includes acceptance helper')
    require(install, 'RAH Test Worker LAN.cmd', 'leader receives one-click LAN test')

    for token, label in (
        ('-ListenAddress 0.0.0.0', 'wildcard bind'),
        ('Invoke-Expression', 'arbitrary PowerShell'),
        ('ScriptBlock]::Create', 'dynamic scriptblock'),
        ('cmd /c', 'arbitrary cmd shell'),
        ('nmap', 'port scanning'),
    ):
        forbid(text, token, label)

    print('PASS: RAH Home physical LAN acceptance v1 contract')


if __name__ == '__main__':
    main()
