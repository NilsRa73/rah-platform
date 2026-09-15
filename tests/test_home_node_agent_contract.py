from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
AGENT=ROOT/'RAH-HOME-NODE-AGENT.ps1'
CLIENT=ROOT/'RAH-HOME-NODE-CLIENT.ps1'
INSTALL=ROOT/'RAH-HOME-INSTALL.ps1'

def require(t,n,l):
    if n not in t: raise AssertionError(f'Mangler kontrakt: {l}: {n!r}')

def forbid(t,n,l):
    if n.lower() in t.lower(): raise AssertionError(f'Uønsket node-kapasitet: {l}: {n!r}')

def main():
    a=AGENT.read_text(encoding='utf-8');c=CLIENT.read_text(encoding='utf-8');i=INSTALL.read_text(encoding='utf-8')

    for n,l in [
        ("[string]$ListenAddress = '127.0.0.1'",'loopback standard'),
        ('[switch]$AllowLan','eksplisitt LAN opt-in'),
        ('[switch]$SelfTest','innebygd self-test'),
        ("RahNodeAgentVersion = '1.0.0'",'stable agent version'),
        ("RahAllowedActions = @('hello','pair','health','systemInfo','benchmark')",'fast action allowlist'),
        ('RahMaxRequestBytes = 8192','bounded request'),
        ("if ($ListenAddress -eq '0.0.0.0')",'wildcard avvises'),
        ('if (-not $AllowLan)','LAN krever opt-in'),
        ('Get-NetIPAddress -AddressFamily IPv4','bind må være lokal adresse'),
        ('New-RahPairCode','kryptografisk pairingkode'),
        ('RandomNumberGenerator','kryptografisk RNG'),
        ('AddMinutes(10)','pair code utløper'),
        ('$pairFailures -ge 5','pairing forsøk begrenses'),
        ('AddSeconds(60)','pairing lockout'),
        ("[ValidateRange(1024,65535)][int]$Port = 18766",'begrenset port'),
        ('Test-RahTokenFormat','kanonisk tokenformat'),
        ('Test-RahTokenEqual','fast-lengde token sammenligning'),
        ("-cmatch '^[0-9a-f]{64}$'",'64 hex token'),
        ('Read-RahBoundedLine','bounded reader før JSON'),
        ('Test-RahRequestShape','eksakt request schema'),
        ("command='whoami'",'self-test avviser command-smuggling'),
        ("action='shell'",'self-test avviser shell-action'),
        ("'unsupported-action'",'ukjent handling avvises'),
        ("'unauthorized'",'token kreves'),
        ('Write-RahAgentState','kontrollert lokal state'),
        ('Move-Item -LiteralPath $temp -Destination $Path -Force','atomisk state replacement'),
        ('AcceptTcpClient()','serveren aksepterer innkommende klienter'),
    ]: require(a,n,l)

    forbid(a,'userName=','Windows-brukernavn i systemInfo')
    for n,l in [
        ('Invoke-Expression','eval'),('ScriptBlock::Create','dynamisk script'),
        ('powershell.exe -Command','nestet shell'),('Start-Process','agent prosess-start'),
        ('Remove-Item','fjernsletting'),('Invoke-WebRequest','HTTP klient'),
        ('Invoke-RestMethod','REST klient'),('New-Object Net.Sockets.TcpClient','utgående TCP klient'),
        ('[Net.Sockets.TcpClient]::new','utgående TCP klient constructor'),
    ]: forbid(a,n,l)

    require(c,"[ValidateSet('hello','pair','health','systemInfo','benchmark')]",'fast klient allowlist')
    require(c,'home-node-peers.json','lokal peer-lagring')
    require(i,'Get-NetIPConfiguration','installer finner aktivt LAN')
    require(i,'-AllowLan -Port 18766','worker starter eksplisitt LAN')
    forbid(i,'-ListenAddress 0.0.0.0','installer wildcard')
    print('PASS: RAH Home Node Agent v1 authenticated fixed-capability contract')

if __name__=='__main__': main()
