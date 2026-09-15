from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNNER = ROOT / 'RAH-HOME-CLUSTER-RUN.ps1'


def require(text, needle, label):
    if needle.lower() not in text.lower():
        raise AssertionError(f'Mangler Cluster Runner-kontrakt: {label}: {needle!r}')


def forbid(text, needle, label):
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket Cluster Runner-kapasitet: {label}: {needle!r}')


def main():
    text = RUNNER.read_text(encoding='utf-8')
    for needle, label in [
        ("$script:RahClusterRunnerVersion = '1.0.0'", 'versjon'),
        ("[ValidateSet('health','systemInfo','benchmark')]", 'fast allowlist'),
        ('[switch]$SelfTest', 'self-test'),
        ('Test-RahPrivateIPv4', 'privat IPv4 guard'),
        ("Join-Path $PSScriptRoot 'RAH-HOME-NODE-JOB.ps1'", 'fast Node Job-fil'),
        ("Join-Path $PSHOME 'powershell.exe'", 'fast PowerShell-binær'),
        ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File $runner', 'fast child invocation'),
        ('-Job $RequestedJob -JsonOnly', 'maskinlesbar Node Job-modus'),
        ('$script:RahMaxRunnerOutputChars = 1048576', 'output-grense'),
        ('ConvertFrom-Json -ErrorAction Stop', 'JSON-validering'),
        ('Assert-RahClusterResult', 'resultatvalidering'),
        ('Invoke-RahClusterRunnerSelfTest', 'self-test-funksjon'),
    ]:
        require(text, needle, label)

    for needle, label in [
        ('Invoke-Expression', 'eval'),
        ('ScriptBlock::Create', 'dynamisk script'),
        ('Start-Process', 'prosess-start'),
        ('Invoke-WebRequest', 'HTTP'),
        ('Invoke-RestMethod', 'HTTP API'),
        ('Net.Sockets.TcpClient', 'egen nettverksklient'),
        ('Remove-Item', 'fjernsletting'),
        ('cmd.exe', 'cmd shell'),
        ('-Command', 'dynamisk PowerShell command'),
    ]:
        forbid(text, needle, label)

    print('PASS: RAH Home Cluster Runner v1 fixed-action private-LAN contract')


if __name__ == '__main__':
    main()
