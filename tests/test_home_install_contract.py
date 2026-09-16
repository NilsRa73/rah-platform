from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INSTALLER = ROOT / 'RAH-HOME-INSTALL.ps1'
BOOTSTRAP = ROOT / 'RAH-HOME-INSTALL.cmd'
ACCEPTANCE = ROOT / 'RAH-HOME-LAN-ACCEPTANCE.ps1'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket adferd: {label}: {needle!r}')


def main() -> None:
    installer = INSTALLER.read_text(encoding='utf-8')
    cmd = BOOTSTRAP.read_text(encoding='utf-8')
    acceptance = ACCEPTANCE.read_text(encoding='utf-8')

    for needle, label in (
        ("RahHomeInstallerVersion = '1.0.0'", 'installer version'),
        ('Set-StrictMode -Version Latest', 'strict mode'),
        ('Invoke-RahInstallerSelfTest', 'network-free self test'),
        ('Get-RahComponentManifest', 'fixed component manifest'),
        ("'RAH-HOME-NODE-AGENT.ps1'", 'stable node agent'),
        ("'RAH-HOME-NODE-CLIENT.ps1'", 'stable node client'),
        ("'RAH-HOME-NODE-JOB.ps1'", 'stable node job'),
        ("'RAH-HOME-CLUSTER-RUN.ps1'", 'stable cluster runner'),
        ("'RAH-HOME-CLUSTER-CONTROLLER.ps1'", 'stable cluster controller'),
        ("'RAH-HOME-PAIR-WIZARD.ps1'", 'stable pair wizard'),
        ("'RAH-HOME-LAN-ACCEPTANCE.ps1'", 'LAN acceptance helper'),
        ('Management.Automation.Language.Parser', 'downloaded PowerShell syntax validation'),
        ("https://raw.githubusercontent.com/NilsRa73/rah-platform/main", 'fixed repository source'),
        ("Join-Path $env:SystemDrive 'RAH\\Home'", 'C:\\RAH default'),
        ("Join-Path $env:LOCALAPPDATA 'RAH\\Home'", 'LocalAppData fallback'),
        ('SourceDirectory', 'offline/test staging source'),
        ('WorkerAddress finnes ikke på en aktiv lokal adapter', 'worker must bind local address'),
        ('-ListenAddress $Address -AllowLan', 'explicit private worker bind'),
        ("schema = 'rah-home-install-state'", 'install state'),
        ('New-RahLeaderShortcuts', 'leader shortcuts'),
        ('New-RahWorkerShortcut', 'worker shortcut'),
    ):
        require(installer, needle, label)

    for needle, label in (
        ('Invoke-Expression', 'arbitrary PowerShell evaluation'),
        ('Start-Process powershell', 'hidden PowerShell launcher'),
        ('cmd /c', 'arbitrary cmd launcher'),
        ('-ListenAddress 0.0.0.0', 'wildcard worker binding'),
    ):
        forbid(installer, needle, label)

    for needle, label in (
        ('RAH-HOME-INSTALL.ps1', 'bootstrap installer filename'),
        ('raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-INSTALL.ps1', 'fixed bootstrap source'),
        ("RahHomeInstallerVersion = ''1.0.0''", 'bootstrap version validation'),
        ('Invoke-RahInstallerSelfTest', 'bootstrap contract marker'),
        ('set "RAH_FORWARD_ARGS=%*"', 'argument capture before elevation'),
        ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_BOOT%" %RAH_FORWARD_ARGS%', 'argument forwarding after elevation'),
        ('__RAH_ADMIN__', 'hardened UAC continuation'),
        ('-Verb RunAs', 'self elevation'),
        ('fltmc >nul 2>&1', 'admin verification'),
        (':FAIL_NOT_ADMIN', 'fail-closed after UAC'),
    ):
        require(cmd, needle, label)
    forbid(cmd, 'net session', 'legacy elevation detection')

    for needle, label in (
        ("RahLanAcceptanceVersion = '1.0.0'", 'acceptance version'),
        ('Set-StrictMode -Version Latest', 'acceptance strict mode'),
        ('Get-RahNodeClientPath', 'client path resolver'),
        ("Join-Path $PSScriptRoot 'RAH-HOME-NODE-CLIENT.ps1'", 'adjacent installed client first'),
        ("RahProtocolVersion = 2", 'agent protocol validation'),
        ("schema='rah-home-lan-acceptance'", 'acceptance result schema'),
        ('Invoke-RahLanAcceptanceSelfTest', 'acceptance self test'),
    ):
        require(acceptance, needle, label)

    for text, name in ((cmd, 'CMD bootstrap'), (acceptance, 'LAN acceptance')):
        for needle, label in (
            ('Invoke-Expression', 'arbitrary PowerShell evaluation'),
            ('cmd /c', 'arbitrary cmd'),
            ('-ListenAddress 0.0.0.0', 'wildcard bind'),
        ):
            forbid(text, needle, f'{name}: {label}')

    print('PASS: RAH Home Unified Installer v1 contract')


if __name__ == '__main__':
    main()
