from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT = ROOT / 'RAH-HOME-NODE-AGENT.ps1'
CLIENT = ROOT / 'RAH-HOME-NODE-CLIENT.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f'Uønsket node-agent-kapasitet: {label}: {needle!r}')


def main() -> None:
    agent = AGENT.read_text(encoding='utf-8')
    client = CLIENT.read_text(encoding='utf-8')

    require(agent, "[ValidateRange(1024,65535)][int]$Port = 18766", 'begrenset standardport')
    require(agent, "Test-PrivateIPv4", 'privatnett-validering')
    require(agent, "PAIR CODE:", 'synlig engangskode')
    require(agent, "RandomNumberGenerator", 'sterkt autentiseringstoken')
    require(agent, "'hello'", 'hello-handling')
    require(agent, "'pair'", 'pairing-handling')
    require(agent, "'health'", 'health-handling')
    require(agent, "'systemInfo'", 'systemInfo-handling')
    require(agent, "'benchmark'", 'benchmark-handling')
    require(agent, "'unsupported-action'", 'ukjent handling avvises')
    require(agent, "'unauthorized'", 'manglende token avvises')
    require(agent, "home-node-agent.json", 'lokal agenttilstand')

    require(client, "home-node-peers.json", 'lokal peer-lagring')
    require(client, "[ValidateSet('hello','pair','health','systemInfo','benchmark')]", 'klient tillater bare faste handlinger')
    require(client, "NodeAddress må være localhost eller en privat RFC1918 IPv4-adresse.", 'klient begrenser mål til privatnett')
    require(client, "-Action pair -PairCode <kode>", 'pairing kreves før autentiserte kall')

    for token, label in (
        ('Invoke-Expression', 'vilkårlig PowerShell-evaluering'),
        ('ScriptBlock::Create', 'dynamisk scriptblock'),
        ('cmd.exe', 'cmd shell'),
        ('powershell.exe -Command', 'nestet powershell shell'),
        ('Start-Process', 'prosess-start fra agent'),
        ('Remove-Item', 'fjernsletting'),
        ('Set-Content -Path', 'vilkårlig filskriving'),
    ):
        forbid(agent, token, label)

    print('PASS: RAH Home Node authenticated fixed-capability contract')


if __name__ == '__main__':
    main()
