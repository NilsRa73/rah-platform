from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'RAH-HOME-NODE-SETUP.ps1'
CMD = ROOT / 'RAH-HOME-NODE-SETUP.cmd'


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f'Mangler Legacy Setup-kontrakt: {label}: {needle!r}')


def forbid(text: str, needle: str, label: str) -> None:
    if needle.lower() in text.lower():
        raise AssertionError(f'Uønsket Legacy Setup-adferd: {label}: {needle!r}')


def main() -> None:
    text = SCRIPT.read_text(encoding='utf-8')
    cmd = CMD.read_text(encoding='utf-8')

    for needle, label in (
        ("RahLegacySetupVersion = '1.0.0'", 'stable wrapper version'),
        ('Set-StrictMode -Version Latest', 'strict mode'),
        ('Assert-RahInstallerV1', 'installer validation'),
        ("'$script:RahHomeInstallerVersion = ''1.0.0'''", 'stable installer marker'),
        ('Invoke-RahInstallerSelfTest', 'installer self-test marker'),
        ('Get-RahComponentManifest', 'fixed installer manifest marker'),
        ('New-RahWorkerShortcut', 'worker installer marker'),
        ('New-RahLeaderShortcuts', 'leader installer marker'),
        ("https://raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-INSTALL.ps1", 'fixed installer source'),
        ("Join-Path $env:SystemDrive 'RAH\\Home\\RAH-HOME-INSTALL.ps1'", 'C:\\RAH installer candidate'),
        ("Join-Path $env:LOCALAPPDATA 'RAH\\Home\\RAH-HOME-INSTALL.ps1'", 'LocalAppData fallback'),
        ("Join-Path $PSHOME 'powershell.exe'", 'fixed child PowerShell'),
        ("if ($Port -ne 18766)", 'legacy standard-port restriction'),
        ("'-Mode',$Mode", 'mode forwarding'),
        ("'-Port',[string]$Port", 'port forwarding'),
        ("'-InstallRoot',$InstallRoot", 'install-root forwarding'),
        ("'-DesktopPath',$DesktopPath", 'desktop forwarding'),
        ("'-SourceDirectory',$SourceDirectory", 'test/offline source forwarding'),
        ("'-WorkerAddress',$WorkerAddress", 'worker-address forwarding'),
        ('Invoke-RahLegacySelfTest', 'network-free self test'),
    ):
        require(text, needle, label)

    for needle, label in (
        ('Invoke-Expression', 'arbitrary eval'),
        ('ScriptBlock]::Create', 'dynamic script'),
        ('cmd /c', 'arbitrary cmd shell'),
        ('-ListenAddress', 'wrapper must not host agent'),
        ('TcpListener', 'wrapper must not open listener'),
        ('TcpClient', 'wrapper must not implement client transport'),
        ('0.0.0.0', 'wildcard binding'),
    ):
        forbid(text, needle, label)

    for needle, label in (
        ('RAH-HOME-NODE-SETUP.ps1', 'bootstrap script filename'),
        ('raw.githubusercontent.com/NilsRa73/rah-platform/main/RAH-HOME-NODE-SETUP.ps1', 'fixed wrapper source'),
        ("RahLegacySetupVersion = ''1.0.0''", 'bootstrap version validation'),
        ('Assert-RahInstallerV1', 'bootstrap wrapper contract validation'),
        ('set "RAH_FORWARD_ARGS=%*"', 'argument capture before elevation'),
        ('powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%RAH_BOOT%" %RAH_FORWARD_ARGS%', 'argument forwarding after elevation'),
        ('__RAH_ADMIN__', 'hardened UAC continuation'),
        ('-Verb RunAs', 'self elevation'),
        ('fltmc >nul 2>&1', 'admin verification'),
        (':FAIL_NOT_ADMIN', 'fail-closed after UAC'),
    ):
        require(cmd, needle, label)

    forbid(cmd, 'net session', 'legacy elevation detection')

    print('PASS: RAH Home Node Legacy Setup v1 compatibility-wrapper contract')


if __name__ == '__main__':
    main()
