from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'RAH-HOME-TRUST.html'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f'Uønsket nettverksadferd i trust-prototype: {label}: {needle!r}')


def main() -> None:
    text = PAGE.read_text(encoding='utf-8')
    require(text, "const HOME_KEY='rah-home-control-v03',TRUST_KEY='rah-home-trust-v01'", 'separat trust-lagring')
    require(text, "explicit-local-user-approval", 'manuell eksplisitt godkjenning støttes')
    require(text, "approvedAt:new Date().toISOString()", 'godkjenning tidsstemples')
    require(text, "btn.textContent=trusted?'Fjern klarering':'Klarer denne enheten'", 'klarering kan settes og fjernes')
    require(text, "if(!saveTrust(trust))", 'lagringsfeil håndteres')
    require(text, "KLARERT", 'klarert status vises')
    require(text, "rah-home-pairing-receipt", 'pairing receipt schema')
    require(text, "verified-pairing-receipt", 'verifisert pairing-kilde dokumenteres')
    require(text, "matches.length!==1", 'pairing krever entydig IP-match')
    require(text, "confirm('Pairing-beviset gjelder ", 'brukeren bekrefter klarering etter import')
    require(text, "pairingSource:x.source", 'pairing metadata beholdes uten token')

    for token, label in (
        ('fetch(', 'HTTP'),
        ('XMLHttpRequest', 'XHR'),
        ('WebSocket', 'WebSocket'),
        ('RTCPeerConnection', 'WebRTC'),
        ('navigator.bluetooth', 'Bluetooth'),
        ('navigator.usb', 'USB'),
    ):
        forbid(text, token, label)

    print('PASS: RAH Home Trust local trust + pairing receipt contract')


if __name__ == '__main__':
    main()
