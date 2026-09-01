from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PAGE = ROOT / 'RAH-HOME-NEXUS.html'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def main() -> None:
    text = PAGE.read_text(encoding='utf-8')
    for path in (
        'RAH-HOME-CONTROL.html',
        'RAH-HOME-DISCOVERY-INBOX.html',
        'RAH-HOME-TRUST.html',
        'RAH-HOME-CLUSTER.html',
        'RAH-HOME-DISCOVERY-RUN.ps1',
        'RAH-HOME-DISCOVERY-ACTIVE-RUN.ps1',
    ):
        require(text, path, f'launcher-link {path}')
    require(text, "HOME_KEY='rah-home-control-v03'", 'Home Control state summary')
    require(text, "TRUST_KEY='rah-home-trust-v01'", 'Trust state summary')
    require(text, "CLUSTER_KEY='rah-home-cluster-v01'", 'Cluster state summary')
    print('PASS: RAH Home Nexus integrated launcher contract')


if __name__ == '__main__':
    main()
