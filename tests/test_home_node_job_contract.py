from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
JOB = ROOT / 'RAH-HOME-NODE-JOB.ps1'


def require(text, needle, label):
    if needle.lower() not in text.lower():
        raise AssertionError(f'Mangler Node Job-kontrakt: {label}: {needle!r}')


def forbid(text, needle, label):
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket Node Job-kapasitet: {label}: {needle!r}')


def main():
    text = JOB.read_text(encoding='utf-8')

    for needle, label in [
        ("$script:RahNodeJobVersion = '1.0.0'", 'versjon'),
        ("[ValidateSet('health','systemInfo','benchmark')]", 'fast jobb-allowlist'),
        ('[switch]$SelfTest', 'self-test'),
        ('Test-RahPrivateIPv4', 'privat IPv4 guard'),
        ("$Address -eq '127.0.0.1'", 'loopback'),
        ("$numbers[0] -eq 10", '10/8'),
        ("$numbers[0] -eq 192", '192.168/16'),
        ("$numbers[0] -eq 172", '172.16/12'),
        ("Join-Path $PSScriptRoot 'RAH-HOME-NODE-CLIENT.ps1'", 'fast Node Client-fil'),
        ("Join-Path $PSHOME 'powershell.exe'", 'fast Windows PowerShell-binær'),
        ('-NoProfile -NonInteractive -ExecutionPolicy Bypass -File $clientPath', 'fast child invocation'),
        ('$script:RahMaxClientOutputChars = 1048576', 'output-grense'),
        ('ConvertFrom-Json -ErrorAction Stop', 'JSON-validering'),
        ('Assert-RahJobResponse', 'responsvalidering'),
        ("[string]$Response.status -ne 'ready'", 'health-kontrakt'),
        ('[int64]$Response.result.iterations', 'benchmark-kontrakt'),
        ('Invoke-RahNodeJobSelfTest', 'self-test-funksjon'),
    ]:
        require(text, needle, label)

    for needle, label in [
        ('Invoke-Expression', 'eval'),
        ('ScriptBlock::Create', 'dynamisk script'),
        ('Start-Process', 'prosess-start'),
        ('Invoke-WebRequest', 'HTTP nedlasting'),
        ('Invoke-RestMethod', 'HTTP API'),
        ('Net.Sockets.TcpClient', 'egen nettverksklient'),
        ('Remove-Item', 'fjernsletting'),
        ('cmd.exe', 'cmd shell'),
        ('-Command', 'dynamisk PowerShell command'),
    ]:
        forbid(text, needle, label)

    print('PASS: RAH Home Node Job v1 fixed-action private-LAN contract')


if __name__ == '__main__':
    main()
