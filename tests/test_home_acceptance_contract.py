from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PS = (ROOT / 'RAH-HOME-ACCEPTANCE.ps1').read_text(encoding='utf-8')
CMD = (ROOT / 'RAH-HOME-ACCEPTANCE.cmd').read_text(encoding='utf-8')


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler acceptance-kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket acceptance-adferd: {label}: {needle!r}')


def main() -> None:
    for needle, label in (
        ("RahHomeAcceptanceVersion = '1.0.0'", 'stable acceptance version'),
        ("[string]$InstallRoot = 'C:\\RAH\\Home'", 'C:\\RAH\\Home default'),
        ('RAH-HOME-INSTALL.ps1', 'Unified Installer dependency'),
        ("RahHomeInstallerVersion = '1.0.0'", 'installer stable-v1 validation'),
        ('Invoke-RahInstallerSelfTest', 'installer self-test contract'),
        ("'-SelfTest'", 'self-test before install'),
        ("'-Mode','Leader'", 'Leader acceptance only'),
        ("'-Port','18766'", 'safe standard port'),
        ('rah-home-install-state', 'install state validation'),
        ('RAH-HOME-ACCEPTANCE.txt', 'human report'),
        ('rah-home-acceptance-latest.json', 'machine report'),
        ('RAH Home Nexus.url', 'Nexus shortcut validation'),
        ('RAH Pair Worker.cmd', 'Pair shortcut validation'),
        ('RAH Run Cluster Plan.cmd', 'Cluster shortcut validation'),
        ('RAH Test Worker LAN.cmd', 'LAN test shortcut validation'),
    ):
        require(PS, needle, label)

    for needle, label in (
        ('RAH-HOME-ACCEPTANCE.ps1', 'CMD downloads acceptance script'),
        ('--self-test', 'CMD bootstrap self-test mode'),
        ('__RAH_ADMIN__', 'CMD hardened UAC continuation'),
        ('-Verb RunAs', 'CMD self elevation'),
        ('fltmc >nul 2>&1', 'CMD admin verification'),
        (':FAIL_NOT_ADMIN', 'CMD fail-closed after UAC'),
        ('C:\\RAH\\Home', 'CMD fixed install target'),
        ("RahHomeAcceptanceVersion = '1.0.0'", 'CMD validates version marker'),
    ):
        require(CMD, needle, label)

    forbid(CMD, 'net session', 'legacy elevation detection')

    for needle, label in (
        ('0.0.0.0', 'wildcard bind'),
        ('Invoke-Expression', 'PowerShell eval'),
        ('ScriptBlock]::Create', 'dynamic scriptblock'),
        ('nmap', 'scanner'),
        ('New-Object Net.Sockets.TcpClient', 'direct TCP client'),
        ('Start-Process powershell', 'arbitrary nested PowerShell'),
    ):
        forbid(PS, needle, label)

    print('PASS: RAH Home Acceptance v1 contract')


if __name__ == '__main__':
    main()
