from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CLIENT=(ROOT/'RAH-HOME-NODE-CLIENT.ps1').read_text(encoding='utf-8')

def require(n,l):
    if n not in CLIENT: raise AssertionError(f'Mangler Client v1 kontrakt: {l}: {n!r}')

def forbid(n,l):
    if n.lower() in CLIENT.lower(): raise AssertionError(f'Uønsket Client-kapasitet: {l}: {n!r}')

def main():
    for n,l in [
        ("RahNodeClientVersion = '1.0.0'",'stable client version'),
        ("[ValidateSet('hello','pair','health','systemInfo','benchmark')]",'fast action allowlist'),
        ('[switch]$SelfTest','innebygd self-test'),
        ('RahMaxResponseBytes = 1048576','1 MB responsgrense'),
        ('RahMaxPeers = 128','peer-registergrense'),
        ('Normalize-RahNodeAddress','normalisert privat adresse'),
        ('Normalize-RahPeerKey','validerte peer keys'),
        ("-cmatch '^[0-9a-f]{64}$'",'kanonisk token'),
        ('Read-RahBoundedLine','bounded server response'),
        ('Assert-RahHelloResponse','server identity gate'),
        ("product -ne 'RAH Home Node Agent'",'RAH agent identity'),
        ('Assert-RahPairResponse','pairing response validation'),
        ('Assert-RahActionResponse','action response validation'),
        ('client-request-too-large','client request cap'),
        ('Move-Item -LiteralPath $temp -Destination $peersPath -Force','atomic peer save'),
        ('Test-RahIsoTimestamp','peer timestamp validation'),
        ('Test-RahSafeText','safe node name validation'),
        ("Invoke-Node -Request @{action='hello'}",'pairing preflight hello'),
        ('Invoke-RahNodeClientSelfTest','self-test implementation'),
    ]: require(n,l)
    for n,l in [
        ('Invoke-Expression','eval'),('ScriptBlock::Create','dynamic script'),
        ('powershell.exe -Command','nested shell'),('Start-Process','subprocess launch'),
        ('Invoke-WebRequest','HTTP'),('Invoke-RestMethod','REST'),('Remove-Item','deletion'),
    ]: forbid(n,l)
    print('PASS: RAH Home Node Client v1 private authenticated client contract')

if __name__=='__main__': main()
