from __future__ import annotations

import importlib.util
import re
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
CLIENT = ROOT / "rah_2pc_inventory_client.py"
GUI = ROOT / "RAH-RAVEN-2PC-GUI.ps1"
START = ROOT / "START-HER-RAH-2PC-GRID.cmd"
VERIFY = ROOT / "VERIFY-RAH-2PC-GRID.cmd"
INSTALL = ROOT / "INSTALL-RAH-2PC-GRID.cmd"
README = ROOT / "RAH-2PC-GRID.md"


def load_client():
    spec = importlib.util.spec_from_file_location("rah_2pc_inventory_client", CLIENT)
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load 2-PC client")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def test_client_fixed_authority_surface():
    text = CLIENT.read_text(encoding="utf-8")
    assert 'RAVEN_STATUS_ROUTE = "/raven/status"' in text
    assert 'RAVEN_STATUS_CAPABILITY = "system-inventory"' in text
    assert "PORT = 18766" in text
    assert "sys.stdin.readline()" in text
    assert 'parser.add_argument("--token"' not in text
    for forbidden in ("import subprocess", "os.system(", "eval(", "exec(", "/shell", "--command"):
        assert forbidden not in text, forbidden


def test_hmac_contract_and_payload_sanitizer():
    mod = load_client()
    session = "Session_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234"
    nonce = "Nonce_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
    canonical = mod.build_canonical(session, nonce)
    assert canonical.startswith("RAH-AUTH-V2\n")
    assert "\nGET\n/raven/status\n" in canonical
    proof = mod.build_proof("Token_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456", canonical)
    assert re.fullmatch(r"[A-Za-z0-9_-]{40,64}", proof)

    payload = {
        "ok": True,
        "protocol": mod.RAVEN_STATUS_PROTOCOL,
        "source": mod.RAVEN_STATUS_SOURCE,
        "capability": mod.RAVEN_STATUS_CAPABILITY,
        "arbitraryCommands": False,
        "argumentsAllowed": False,
        "localOnlyHop": True,
        "nodeJobId": "job-1",
        "result": {
            "ok": True,
            "read_only": True,
            "files_modified": False,
            "arbitrary_commands": False,
            "stdout": "ok",
            "inventory": {
                "hostname": "LENOVO",
                "os": {"system": "Windows", "release": "11", "architecture": "AMD64"},
                "cpu": {"name": "CPU", "logical_cores": 8},
                "ram_gb": 16,
                "gpus": ["GPU"],
                "monitor_count": 2,
                "raven_bridge": {"version": "2.0.32", "port": 18765, "health_route": True, "agent_route": True},
                "safety": {"read_only": True, "arbitrary_commands": False, "file_writes": False, "automatic_execution": False},
            },
        },
    }
    clean = mod.sanitize_raven_status(payload)
    assert clean["status"] == "PASS"
    assert clean["safety"] == {
        "readOnly": True,
        "arbitraryCommands": False,
        "callerArguments": False,
        "tokenPersisted": False,
        "localRavenHopOnly": True,
    }


def test_gui_is_raven_os_style_and_safe():
    text = GUI.read_text(encoding="utf-8")
    for marker in (
        "RAH RAVEN OS",
        "RAVEN GRID CONTROL",
        "#07090C",
        "#D9B65B",
        "RUN SYSTEM INVENTORY",
        "No shell",
        "no token storage",
        r"C:\RAH\2PCProof",
        "system-inventory",
        "/raven/status",
        "DESKTOP-R2HTAGJ",
        "RFC1918",
    ):
        assert marker in text, marker

    assert "New-NetFirewallRule" not in text
    assert "netsh advfirewall" not in text.lower()
    assert "Invoke-Expression" not in text
    assert "DownloadString" not in text
    assert "RedirectStandardInput = $true" in text
    assert "StandardInput.WriteLine($Token)" in text
    assert "100.123.249.19" not in text

    match = re.search(r"\[xml\]\$xaml\s*=\s*@'\n(.*?)\n'@", text, re.S)
    assert match, "WPF XAML here-string not found"
    ET.fromstring(match.group(1))


def test_one_click_contract():
    start = START.read_text(encoding="utf-8", errors="replace")
    verify = VERIFY.read_text(encoding="utf-8", errors="replace")
    installer = INSTALL.read_text(encoding="utf-8", errors="replace")
    readme = README.read_text(encoding="utf-8")

    assert "RAH-RAVEN-2PC-GUI.ps1" in start
    assert "-STA" in start
    assert "RAH-RAVEN-2PC-GUI.ps1" in verify
    assert "rah_2pc_inventory_client.py" in verify
    assert "START-HER-RAH-2PC-GRID.cmd" in readme
    assert r"C:\RAH\2PCProof\results" in readme

    assert "raw.githubusercontent.com/NilsRa73/rah-platform/main" in installer
    assert "VERIFY-RAH-2PC-GRID.cmd" in installer
    assert "START-HER-RAH-2PC-GRID.cmd" in installer
    assert "RAH-RAVEN-2PC-GUI.ps1" in installer
    assert "rah_2pc_inventory_client.py" in installer


if __name__ == "__main__":
    test_client_fixed_authority_surface()
    test_hmac_contract_and_payload_sanitizer()
    test_gui_is_raven_os_style_and_safe()
    test_one_click_contract()
    print("RAH Raven 2-PC Grid contract tests: OK")
