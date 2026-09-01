from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INBOX = ROOT / 'RAH-HOME-DISCOVERY-INBOX.html'
RUNNER = ROOT / 'RAH-HOME-DISCOVERY-RUN.ps1'
ACTIVE_RUNNER = ROOT / 'RAH-HOME-DISCOVERY-ACTIVE-RUN.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f'Uønsket discovery i inbox: {label}: {needle!r}')


def main() -> None:
    html = INBOX.read_text(encoding='utf-8')
    ps1 = RUNNER.read_text(encoding='utf-8')
    active_ps1 = ACTIVE_RUNNER.read_text(encoding='utf-8')

    require(html, "const HOME_KEY='rah-home-control-v03'", 'samme Home Control-lagringsnøkkel')
    require(html, "const DISCOVERY_SCHEMA='rah-home-discovery-cache'", 'discovery schema')
    require(html, "const ALLOWED_MODES=['passive-neighbor-cache','active-local-subnet']", 'kun eksplisitt støttede modes')
    require(html, "x.mode==='passive-neighbor-cache'&&x.passive===true", 'passiv mode må være passiv')
    require(html, "x.mode==='active-local-subnet'&&x.passive===false", 'aktiv mode må være aktiv')
    require(html, "d.passive===x.passive", 'kandidater må matche dokumentets mode')
    require(html, "btn.textContent=status.duplicate?'Allerede i Home Control':'Godkjenn til Home Control'", 'eksplisitt godkjenning')
    require(html, "state.devices.push(item)", 'godkjent kandidat legges i register')
    require(html, "if(!saveHome(state))", 'lagringsfeil håndteres')
    require(html, "state.devices.pop()", 'rollback ved lagringsfeil')
    require(html, "const sameIp=state.devices.find(d=>d.ip===device.ipAddress)", 'duplikat-IP avvises')
    require(html, "room:'Ikke valgt'", 'ny kandidat får nøytral romplassering')
    require(html, "role:'Ubestemt'", 'ny kandidat får nøytral rolle')
    require(html, "online:device.state==='Reachable'", 'lokal status avledes konservativt')
    require(html, "navigator.clipboard.readText()", 'praktisk utklippstavleimport')
    require(html, "discovery.passive?'PASSIV KANDIDAT':'AKTIV KANDIDAT'", 'mode vises tydelig')

    for token, label in (
        ('RTCPeerConnection', 'WebRTC'),
        ('new WebSocket', 'WebSocket'),
        ('navigator.bluetooth', 'Bluetooth'),
        ('navigator.usb', 'USB'),
        ('fetch(', 'nettverks-fetch'),
        ('XMLHttpRequest', 'XHR'),
        ('new Ping', 'ping fra nettsiden'),
    ):
        forbid(html, token, label)

    require(ps1, "RAH-HOME-DISCOVERY.ps1", 'passiv runner bruker passiv discovery-script')
    require(ps1, "rah-home-discovery.json", 'passiv runner skriver kjent JSON-fil')
    require(ps1, "RAH-HOME-DISCOVERY-INBOX.html", 'passiv runner åpner inbox')

    require(active_ps1, "RAH-HOME-DISCOVERY-ACTIVE.ps1", 'aktiv runner bruker aktivt discovery-script')
    require(active_ps1, "Read-Host 'Kjør bare på eget/autoriserte nett. Skriv JA for å starte'", 'aktiv runner krever menneskelig bekreftelse')
    require(active_ps1, "if ($answer -ne 'JA')", 'aktiv runner avbryter uten eksplisitt JA')
    require(active_ps1, "-Start -OutputPath $Output", 'aktiv script får eksplisitt Start')
    require(active_ps1, "RAH-HOME-DISCOVERY-INBOX.html", 'aktiv runner åpner samme inbox')

    print('PASS: RAH Home Discovery Inbox v0.2 contract')


if __name__ == '__main__':
    main()
