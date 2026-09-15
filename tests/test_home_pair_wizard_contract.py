from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'RAH-HOME-PAIR-WIZARD.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle.lower() not in text.lower():
        raise AssertionError(f'Mangler Pair Wizard-kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket Pair Wizard-adferd: {label}: {needle!r}')


def main() -> None:
    text = SCRIPT.read_text(encoding='utf-8')

    for needle, label in (
        ("$script:RahPairWizardVersion = '1.0.0'", 'v1-versjon'),
        ('Set-StrictMode -Version Latest', 'strict mode'),
        ('[string]$NodeAddress', 'ikke-interaktiv nodeadresse'),
        ('[string]$PairCode', 'ikke-interaktiv pair code'),
        ('[string]$OutputPath', 'styrbar receipt-output'),
        ('[switch]$NoOpen', 'CI/no-open-modus'),
        ('[switch]$SelfTest', 'self-test'),
        ('Test-RahPrivateIPv4', 'RFC1918-validering'),
        ("$numbers[0] -eq 10", '10/8'),
        ("$numbers[0] -eq 172", '172.16/12'),
        ("$numbers[0] -eq 192", '192.168/16'),
        ("Join-Path $PSScriptRoot 'RAH-HOME-NODE-CLIENT.ps1'", 'fast sibling Client'),
        ("Join-Path $PSHOME 'powershell.exe'", 'fast PowerShell-binær'),
        ("[ValidateSet('hello','pair','systemInfo')]", 'begrensede Client-kall'),
        ("[string]$Response.product -ne 'RAH Home Node Agent'", 'Agent-identitet'),
        ('$script:RahProtocolVersion = 2', 'protokollversjon'),
        ('Node-identiteten endret seg mellom hello og autentisert systemInfo', 'identitetsbinding'),
        ("schema = 'rah-home-pairing-receipt'", 'receipt schema'),
        ("source = $script:RahReceiptSource", 'receipt provenance'),
        ("$script:RahReceiptSource = 'explicit-pair-code-and-authenticated-system-info'", 'Trust-kompatibel provenance'),
        ('Pairing-evidens skal aldri inneholde token', 'tokenfri receipt guard'),
        ('Invoke-RahPairWizardSelfTest', 'self-test-funksjon'),
        ('Home Trust krever i tillegg eksplisitt lokal godkjenning', 'ingen trust-overclaim'),
        ('RAH-HOME-TRUST.html', 'Trust som neste steg'),
    ):
        require(text, needle, label)

    for needle, label in (
        ('Invoke-Expression', 'vilkårlig PowerShell-evaluering'),
        ('ScriptBlock::Create', 'dynamisk script'),
        ('cmd.exe', 'cmd shell'),
        ('0.0.0.0', 'wildcard target'),
        ('Invoke-WebRequest', 'uventet nedlasting'),
        ('Invoke-RestMethod', 'uventet HTTP API'),
        ('Net.Sockets.TcpClient', 'egen nettverksklient utenom herdede Client'),
        ("'token' =", 'token i receipt'),
        ('"token" =', 'token i receipt'),
    ):
        forbid(text, needle, label)

    print('PASS: RAH Home Pair Wizard v1 private-LAN authenticated receipt contract')


if __name__ == '__main__':
    main()
