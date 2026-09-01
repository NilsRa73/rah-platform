from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'RAH-HOME-CLUSTER.html'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f'Uønsket nettverksadferd i cluster-prototype: {label}: {needle!r}')


def main() -> None:
    text = PAGE.read_text(encoding='utf-8')
    require(text, "TRUST_KEY='rah-home-trust-v01'", 'cluster bruker trust-register')
    require(text, "CLUSTER_KEY='rah-home-cluster-v01'", 'egen cluster-lagring')
    require(text, "tr.devices[fp(d)]&&tr.devices[fp(d)].trusted", 'kun klarerte enheter er kvalifisert')
    require(text, "x.leaderId=d.id", 'eksplisitt ledervalg')
    require(text, "x.enabledIds", 'worker-liste lagres')
    require(text, "status:'I kø'", 'lokal jobbkø')
    require(text, "t.status='Planlagt'", 'fordeling merkes som planlagt før eksport')
    require(text, "schema:'rah-home-cluster-plan'", 'sikker eksportplan har eksplisitt schema')
    require(text, "new Set(['health','systemInfo','benchmark'])", 'web-eksport har fast jobb-allowlist')
    require(text, "nodes.length>16", 'web-eksport begrenser antall node-jobber')
    require(text, "x.schema!=='rah-home-cluster-results'", 'resultatimport validerer schema')
    require(text, "Nettleseren sender aldri nettverksjobber direkte", 'UI er tydelig på lokal controller-grense')
    require(text, "if(!save(CLUSTER_KEY,c))", 'rollback ved lagringsfeil')

    for token, label in (
        ('fetch(', 'HTTP'),
        ('XMLHttpRequest', 'XHR'),
        ('WebSocket', 'WebSocket'),
        ('RTCPeerConnection', 'WebRTC'),
        ('navigator.bluetooth', 'Bluetooth'),
        ('navigator.usb', 'USB'),
    ):
        forbid(text, token, label)

    print('PASS: RAH Home Cluster secure planner/export contract')


if __name__ == '__main__':
    main()
