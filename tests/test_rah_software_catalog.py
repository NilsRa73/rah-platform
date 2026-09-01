import json
from pathlib import Path
from urllib.parse import urlparse

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'RAH-SOFTWARE-CATALOG.json'


def main() -> None:
    data = json.loads(CATALOG.read_text(encoding='utf-8'))
    assert data.get('schema') == 'rah-software-catalog'
    assert data.get('version') == 1
    programs = data.get('programs')
    assert isinstance(programs, list) and programs, 'Catalog must contain programs'

    ids = set()
    names = set()
    for p in programs:
        assert isinstance(p, dict)
        pid = p.get('id')
        name = p.get('name')
        assert isinstance(pid, str) and pid and pid not in ids
        assert isinstance(name, str) and name and name not in names
        ids.add(pid)
        names.add(name)
        assert p.get('status') in {'stable-mvp', 'working-prototype'}
        assert isinstance(p.get('platform'), str) and p['platform']
        assert isinstance(p.get('description'), str) and p['description']
        assert any(p.get(k) for k in ('launchUrl', 'downloadUrl'))
        for key in ('launchUrl', 'downloadUrl', 'sourceUrl'):
            if p.get(key):
                u = urlparse(p[key])
                assert u.scheme == 'https' and u.netloc, f'Invalid HTTPS URL for {name}: {key}'

    required = {
        'rah-home-control',
        'rah-home-discovery-inbox',
        'rah-home-discovery',
        'rah-home-discovery-run',
    }
    assert required.issubset(ids)
    print(f'PASS: RAH Software Catalog v1 ({len(programs)} published programs)')


if __name__ == '__main__':
    main()
