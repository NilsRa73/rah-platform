from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXT = ROOT / "browser-bridge-v1"
VERSION = ROOT / "RAH-RAVEN-BROWSER-VERSION.json"
FINALIZER = ROOT / "RAH-RAVEN-BROWSER-FINAL.ps1"
LAUNCHER = ROOT / "START-HER-RAH-RAVEN-BROWSER.cmd"

READ_ONLY_AUTO = {
    "agent.status",
    "system.snapshot",
    "system.cpu",
    "system.memory",
    "system.gpu",
    "system.disks",
    "system.network",
    "system.displays",
    "fs.list",
    "fs.read_text",
    "fs.read_bytes",
    "fs.search",
    "fs.hash",
    "process.list",
    "service.list",
}

MUTATING = {
    "fs.write_text",
    "fs.write_bytes",
    "fs.mkdir",
    "fs.copy",
    "fs.move",
    "fs.delete",
    "process.start",
    "process.stop",
    "service.start",
    "service.stop",
    "shell.powershell",
    "shell.exec",
}


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing {label}: {needle!r}")


def main() -> None:
    manifest = json.loads((EXT / "manifest.json").read_text(encoding="utf-8"))
    config = (EXT / "config.js").read_text(encoding="utf-8")
    content = (EXT / "content.js").read_text(encoding="utf-8")
    background = (EXT / "background.js").read_text(encoding="utf-8")
    release = json.loads(VERSION.read_text(encoding="utf-8"))
    finalizer = FINALIZER.read_text(encoding="utf-8")
    launcher = LAUNCHER.read_text(encoding="utf-8")

    assert manifest["manifest_version"] == 3
    assert manifest["version"] == "1.3.0"
    assert set(manifest["permissions"]) <= {"storage", "tabs"}
    assert set(manifest["host_permissions"]) == {
        "http://127.0.0.1:18779/*",
        "https://chatgpt.com/*",
        "https://chat.openai.com/*",
    }
    assert "<all_urls>" not in json.dumps(manifest)
    assert "*://*/*" not in json.dumps(manifest)

    require(config, "http://127.0.0.1:18779", "fixed loopback agent")
    require(config, "__RAH_TOKEN__", "installer token placeholder")
    require(config, "version:'1.3.0'", "config version")

    m = re.search(r"const AUTO_TOOLS=new Set\(\[(.*?)\]\);", content, re.S)
    if not m:
        raise AssertionError("AUTO_TOOLS block missing")
    auto = set(re.findall(r"'([^']+)'", m.group(1)))
    if auto != READ_ONLY_AUTO:
        raise AssertionError(f"AUTO_TOOLS mismatch: {sorted(auto)}")
    overlap = auto & MUTATING
    if overlap:
        raise AssertionError(f"Mutating tools must not auto-run: {sorted(overlap)}")

    require(content, "if(!AUTO_TOOLS.has(tool))", "explicit non-auto gate")
    require(content, "confirm(", "visible approval prompt")
    require(content, "RAH requests a LOCAL CHANGE or privileged action", "approval wording")
    require(content, "const VERSION='1.3.0'", "content version")
    require(background, "RAH_BROWSER_BRIDGE_V13", "v1.3 result marker")

    assert release["product"] == "RAH Raven Browser"
    assert release["version"] == "1.3.0"
    assert release["stage"] == "stable"
    assert release["features"]["automatic_read_only_tools"] is True
    assert release["features"]["mutating_tools_require_explicit_confirmation"] is True
    assert release["features"]["automatic_file_writes"] is False
    assert release["features"]["wildcard_host_permissions"] is False

    for needle in (
        "C:\\RAH\\Browser",
        "C:\\RAH\\Logs",
        "INSTALL-RAH-LOCAL-AGENT.ps1",
        "--disable-extensions-except",
        "--load-extension",
        "RAVEN-BROWSER-FINAL-LATEST.json",
        "Read-only automatic tools",
        "Explicit mutation approval",
    ):
        require(finalizer, needle, "finalizer contract")

    require(launcher, "RAH-RAVEN-BROWSER-FINAL.ps1", "one-click target")
    require(launcher, "RAVEN-BROWSER-FINAL-LATEST.json", "one-click report")

    print("RAH RAVEN BROWSER v1.3 STABLE CONTRACT: PASS")


if __name__ == "__main__":
    main()
