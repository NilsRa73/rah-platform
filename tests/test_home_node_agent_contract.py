from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
AGENT=ROOT/'RAH-HOME-NODE-AGENT.ps1';CLIENT=ROOT/'RAH-HOME-NODE-CLIENT.ps1';INSTALL=ROOT/'RAH-HOME-INSTALL.ps1'
def require(t,n,l):
    if n not in t: raise AssertionError(f'Mangler kontrakt: {l}: {n!r}')
def forbid(t,n,l):
    if n in t: raise AssertionError(f'Uønsket node-kapasitet: {l}: {n!r}')
def main():
    a=AGENT.read_text(encoding='utf-8');c=CLIENT.read_text(encoding='utf-8');i=INSTALL.read_text(encoding='utf-8')
    require(a,"[string]$ListenAddress = '127.0.0.1'",'loopback standard')
    require(a,'[switch]$AllowLan','eksplisitt LAN opt-in')
    require(a,"if($ListenAddress-eq'0.0.0.0')",'wildcard avvises')
    require(a,"if(-not$AllowLan)",'LAN krever opt-in')
    require(a,'Get-NetIPAddress -AddressFamily IPv4','bind må være lokal adresse')
    require(a,'$pairExpires=(Get-Date).AddMinutes(10)','pair code utløper')
    require(a,'$pairFailures-ge5','pairing forsøk begrenses')
    require(a,'AddSeconds(60)','pairing lockout')
    require(a,"[ValidateRange(1024,65535)][int]$Port = 18766",'begrenset port')
    for n,l in [("'hello'",'hello'),("'pair'",'pair'),('health{','health'),('systemInfo{','systemInfo'),('benchmark{','benchmark'),("'unsupported-action'",'ukjent handling avvises'),("'unauthorized'",'token kreves'),('RandomNumberGenerator','sterkt token')]: require(a,n,l)
    forbid(a,'userName=','Windows-brukernavn i systemInfo')
    require(c,"[ValidateSet('hello','pair','health','systemInfo','benchmark')]",'fast klient allowlist')
    require(c,'home-node-peers.json','lokal peer-lagring')
    require(i,'Get-NetIPConfiguration','installer finner aktivt LAN')
    require(i,'-AllowLan -Port 18766','worker starter eksplisitt LAN')
    forbid(i,'-ListenAddress 0.0.0.0','installer wildcard')
    for n,l in [('Invoke-Expression','eval'),('ScriptBlock::Create','dynamisk script'),('powershell.exe -Command','nestet shell'),('Start-Process','agent prosess-start'),('Remove-Item','fjernsletting')]: forbid(a,n,l)
    print('PASS: RAH Home Node hardened authenticated fixed-capability contract')
if __name__=='__main__': main()
