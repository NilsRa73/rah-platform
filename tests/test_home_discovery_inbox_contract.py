from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INBOX = ROOT / 'RAH-HOME-DISCOVERY-INBOX.html'
RUNNER = ROOT / 'RAH-HOME-DISCOVERY-RUN.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f'Uønsket aktiv discovery i inbox: {label}: {needle!r}')


def main() -> None:
    html = INBOX.read_text(encoding='utf-8')
    ps1 = RUNNER.read_text(encoding='utf-8')

    require(html, "const HOME_KEY='rah-home-control-v03'", 'samme Home Control-lagringsnøkkel')
    require(html, "const DISCOVERY_SCHEMA='rah-home-discovery-cache'", 'discovery schema')
    require(html, 'x.passive===true', 'krever passivt dokument')
    require(html, "d.passive===true", 'krever passive kandidater')
    require(html, "btn.textContent=status.duplicate?'Allerede i Home Control':'Godkjenn til Home Control'", 'eksplisitt godkjenning')
    require(html, "state.devices.push(item)", 'godkjent kandidat legges i register')
    require(html, "if(!saveHome(state))", 'lagringsfeil håndteres')
    require(html, "state.devices.pop()", 'rollback ved lagringsfeil')
    require(html, "const sameIp=state.devices.find(d=>d.ip===device.ipAddress)", 'duplikat-IP avvises')
    require(html, "room:'Ikke valgt'", 'ny kandidat får nøytral romplassering')
    require(html, "role:'Ubestemt'", 'ny kandidat får nøytral rolle')
    require(html, "online:device.state==='Reachable'", 'lokal status avledes konservativt')
    require(html, "navigator.clipboard.readText()", 'praktisk utklippstavleimport')

    for token, label in (
        ('RTCPeerConnection', 'WebRTC'),
        ('new WebSocket', 'WebSocket'),
        ('navigator.bluetooth', 'Bluetooth'),
        ('navigator.usb', 'USB'),
        ('fetch(', 'nettverks-fetch'),
        ('XMLHttpRequest', 'XHR'),
    ):
        forbid(html, token, label)

    require(ps1, "RAH-HOME-DISCOVERY.ps1", 'runner bruker passiv discovery-script')
    require(ps1, "rah-home-discovery.json", 'runner skriver kjent JSON-fil')
    require(ps1, "RAH-HOME-DISCOVERY-INBOX.html", 'runner åpner inbox')

    print('PASS: RAH Home Discovery Inbox prototype contract')


if __name__ == '__main__':
    main()
