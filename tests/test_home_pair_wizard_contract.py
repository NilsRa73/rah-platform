from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'RAH-HOME-PAIR-WIZARD.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f'Uønsket adferd: {label}: {needle!r}')


def main() -> None:
    text = SCRIPT.read_text(encoding='utf-8')
    require(text, 'PrivateIP', 'privatnett-validering')
    require(text, "-Action hello", 'agent må svare før pairing')
    require(text, "-Action pair -PairCode", 'eksplisitt seks-sifret pairing')
    require(text, "-Action systemInfo", 'autentisert verifisering etter pairing')
    require(text, "schema='rah-home-pairing-receipt'", 'pairing receipt schema')
    require(text, "source='explicit-pair-code-and-authenticated-system-info'", 'receipt provenance')
    require(text, 'rah-home-pairing.json', 'forutsigbart receipt-filnavn')
    require(text, 'RAH-HOME-TRUST.html', 'åpner Trust for neste steg')
    for token, label in (
        ('Invoke-Expression', 'vilkårlig PowerShell-evaluering'),
        (' iex ', 'iex'),
        ('cmd /c', 'vilkårlig cmd'),
        ('Start-Process powershell', 'skjult ekstra PowerShell'),
        ('0.0.0.0', 'offentlig wildcard target'),
    ):
        forbid(text, token, label)
    print('PASS: RAH Home Pair Wizard private-LAN receipt contract')


if __name__ == '__main__':
    main()
