from __future__ import annotations

import re
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
GUI = ROOT / "RAH-RAVEN-2PC-GUI.ps1"
PS_CLIENT = ROOT / "RAH-2PC-CLIENT.ps1"
PS_ACCEPTANCE = ROOT / "RAH-2PC-ACCEPTANCE.ps1"
HW_INVENTORY = ROOT / "RAH-HARDWARE-INVENTORY.ps1"
HW_REGISTRY = ROOT / "RAH-HARDWARE-REGISTRY.ps1"
START = ROOT / "START-HER-RAH-2PC-GRID.cmd"
VERIFY = ROOT / "VERIFY-RAH-2PC-GRID.cmd"
INSTALL = ROOT / "INSTALL-RAH-2PC-GRID.cmd"
COMPLETE = ROOT / "COMPLETE-RAH-2PC-GRID.cmd"
README = ROOT / "RAH-2PC-GRID.md"
AGENT_RUNNER = ROOT / "desktop-bridge" / "agent_runner.py"
RAVEN_JOBS = ROOT / "desktop-bridge" / "raven_jobs.py"
APPROVAL = ROOT / "desktop-bridge" / "anythingllm_approval.py"
AI_INSTALLER = ROOT / "INSTALL-RAH-AI-FABRIC.ps1"
DAILY_DEVICES = ROOT / "apps" / "rah-raven-daily-driver" / "devices.py"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace")


def test_operator_runtime_is_python_free():
    installer = read(INSTALL)
    verify = read(VERIFY)
    complete = read(COMPLETE)
    gui = read(GUI)

    for text in (installer, verify, complete, gui):
        assert "rah_2pc_inventory_client.py" not in text
        assert "rah_2pc_acceptance.py" not in text

    assert "where python" not in verify.lower()
    assert "where py " not in verify.lower()
    assert "Get-PythonPath" not in gui
    assert "Python NOT required" in verify
    assert "RAH-2PC-CLIENT.ps1" in installer
    assert "RAH-2PC-ACCEPTANCE.ps1" in installer
    assert "RAH-HARDWARE-INVENTORY.ps1" in installer
    assert "RAH-HARDWARE-REGISTRY.ps1" in installer
    assert 'set "REF=main"' in installer
    assert "RAH-2PC-SOURCE-REF.txt" in installer


def test_fixed_hmac_client_surface():
    text = read(PS_CLIENT)
    assert "$script:Rah2PcPort = 18766" in text
    assert "$script:Rah2PcRoute = '/raven/status'" in text
    assert "$script:Rah2PcCapability = 'system-inventory'" in text
    assert "HMACSHA256" in text
    assert "X-RAH-Auth-Nonce" in text
    assert "X-RAH-Auth-Proof" in text
    assert "hardware_profile" in text
    for forbidden in ("Invoke-Expression", "Start-Process cmd", "New-NetFirewallRule", "netsh advfirewall"):
        assert forbidden.lower() not in text.lower()


def test_hardware_profile_is_upgrade_useful_and_privacy_bounded():
    text = read(HW_INVENTORY)
    for marker in (
        "Win32_BaseBoard",
        "Win32_PhysicalMemory",
        "Win32_PhysicalMemoryArray",
        "Win32_VideoController",
        "Win32_SystemSlot",
        "Win32_DiskDrive",
        "partNumber",
        "slotsFree",
        "pcieSlotsAvailableReported",
        "rah-hardware-profile-v1",
    ):
        assert marker in text, marker
    assert "serialNumbersStored = $false" in text
    assert ".SerialNumber" not in text
    assert "serialNumber =" not in text
    assert "function Get-RahObjectProperty" in text
    assert "function Convert-RahSystemSlot" in text
    assert "Legacy BIOS slot without optional fields" in text
    assert "$slot.Purpose" not in text


def test_registry_is_fixed_local_multi_device_history():
    text = read(HW_REGISTRY)
    assert r"C:\RAH\HardwareRegistry" in text
    assert "rah-hardware-registry-v1" in text
    assert "historyCount" in text
    assert "profileHash" in text
    assert "changedOnLastScan" in text
    assert "Update-RahHardwareRegistry" in text


def test_raven_agent_knows_registry_without_arbitrary_path():
    runner = read(AGENT_RUNNER)
    jobs = read(RAVEN_JOBS)
    approval = read(APPROVAL)
    installer = read(AI_INSTALLER)

    assert '"hardware-registry": Capability(' in runner
    assert r'C:\RAH\HardwareRegistry\registry.json' in runner
    assert "Hardware registry exceeds the fixed 2 MiB read limit." in runner
    assert 'capability.id == "hardware-registry"' in runner
    assert 'capability.id == "hardware-registry"' in jobs
    assert '"hardware-registry"' in approval
    assert '"RAH-HARDWARE-INVENTORY.ps1"' in installer
    assert '"RAH-HARDWARE-REGISTRY.ps1"' in installer


def test_daily_driver_consumes_same_hardware_registry():
    text = read(DAILY_DEVICES)
    assert r"C:\RAH\HardwareRegistry\registry.json" in text
    assert "hardware_registry" in text
    assert '"hardware-node"' in text
    assert '"hardware-registry"' in text


def test_gui_is_raven_os_style_and_registry_aware():
    text = read(GUI)
    for marker in (
        "RAH RAVEN OS",
        "RAVEN GRID CONTROL",
        "#07090C",
        "#D9B65B",
        "RUN SYSTEM INVENTORY",
        "FINAL REAL-HARDWARE ACCEPTANCE",
        "REFRESH THIS PC HARDWARE",
        "HARDWARE REGISTRY",
        r"C:\RAH\HardwareRegistry",
        "No shell",
        "no token storage",
        "DESKTOP-R2HTAGJ",
        "RFC1918",
    ):
        assert marker in text, marker

    assert "New-NetFirewallRule" not in text
    assert "Invoke-Expression" not in text
    assert "100.123.249.19" not in text
    assert "RAH-2PC-SOURCE-REF.txt" in text
    assert "refs/tags/" in text
    assert "AI-Fabric\\venv\\Scripts\\python.exe" in text

    match = re.search(r"\[xml\]\$xaml\s*=\s*@'\n(.*?)\n'@", text, re.S)
    assert match, "WPF XAML here-string not found"
    ET.fromstring(match.group(1))


def test_one_click_contract_and_docs():
    start = read(START)
    verify = read(VERIFY)
    installer = read(INSTALL)
    complete = read(COMPLETE)
    readme = read(README)

    assert "RAH-RAVEN-2PC-GUI.ps1" in start
    assert "-STA" in start
    assert "RAH-RAVEN-2PC-GUI.ps1" in verify
    assert "raw.githubusercontent.com/NilsRa73/rah-platform/'+$ref" in installer
    assert "Source ref : %REF%" in installer
    assert "VERIFY-RAH-2PC-GRID.cmd" in installer
    assert "REAL-HARDWARE-ACCEPTANCE.json" in complete
    assert "requires no Python" in readme
    assert r"C:\RAH\HardwareRegistry\registry.json" in readme
    assert "Test-PythonExecutable" in read(AI_INSTALLER)
    assert 'Get-Command python.exe' in read(AI_INSTALLER)


if __name__ == "__main__":
    test_operator_runtime_is_python_free()
    test_fixed_hmac_client_surface()
    test_hardware_profile_is_upgrade_useful_and_privacy_bounded()
    test_registry_is_fixed_local_multi_device_history()
    test_raven_agent_knows_registry_without_arbitrary_path()
    test_daily_driver_consumes_same_hardware_registry()
    test_gui_is_raven_os_style_and_registry_aware()
    test_one_click_contract_and_docs()
    print("RAH Raven 2-PC Grid v1.2 + Hardware Registry contract tests: OK")
