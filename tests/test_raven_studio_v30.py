from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HTML = ROOT / "RAH-RAVEN-STUDIO-V3.0.html"
MANIFEST = ROOT / "RAH-RAVEN-STUDIO-V3.0.json"
LEGACY = ROOT / "RAH-RAVEN-STUDIO-VERSION.json"
FINALIZER = ROOT / "RAH-RAVEN-STUDIO-FINAL.ps1"
LAUNCHER = ROOT / "START-HER-RAH-RAVEN-STUDIO.cmd"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing {label}: {needle!r}")


def load(name: str) -> dict:
    return json.loads((ROOT / name).read_text(encoding="utf-8"))


def main() -> None:
    html = HTML.read_text(encoding="utf-8")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    legacy = json.loads(LEGACY.read_text(encoding="utf-8"))
    finalizer = FINALIZER.read_text(encoding="utf-8")
    launcher = LAUNCHER.read_text(encoding="utf-8")

    assert manifest["product"] == "RAH Raven Studio"
    assert manifest["version"] == "3.0.0"
    assert manifest["stage"] in {"candidate", "stable"}
    assert manifest["architecture"] == "canonical-app-hub"
    assert manifest["local_first"] is True

    deps = manifest["canonical_dependencies"]
    assert deps["command_center"]["version"] == "2.4.0"
    assert deps["command_center"]["generation"] == 9
    assert deps["raven_browser"]["version"] == "1.3.0"
    assert deps["raven_now"]["version"] == "2.17.0"
    assert deps["raven_vision"]["version"] == "0.6.0"
    assert deps["mission_control"]["version"] == "2.9.0"
    assert deps["raven_council"]["version"] == "0.3.0"
    assert deps["agent_runner"]["version"] == "0.3.0"
    assert deps["chronicle"]["version"] == "1.7.1"

    cc = load("RAH-COMMAND-CENTER-VERSION.json")
    browser = load("RAH-RAVEN-BROWSER-VERSION.json")
    now = load("RAH-RAVEN-NOW-VERSION.json")
    vision = load("RAH-RAVEN-VISION-VERSION.json")
    mission = load("RAH-RAVEN-MISSION-CONTROL-VERSION.json")
    council = load("RAH-RAVEN-COUNCIL-VERSION.json")
    agent = load("RAH-RAVEN-AGENT-RUNNER-VERSION.json")
    chronicle = load("RAH-RAVEN-CHRONICLE-VERSION.json")

    assert cc["version"] == "2.4.0" and cc["stage"] == "stable"
    assert cc["canonical_package_generation"] == 9
    assert browser["version"] == "1.3.0" and browser["stage"] == "stable"
    assert now["version"] == "2.17.0" and now["stage"] == "stable"
    assert vision["version"] == "0.6.0" and vision["stage"] == "stable"
    assert mission["version"] == "2.9.0" and mission["stage"] == "stable"
    assert council["version"] == "0.3.0" and council["stage"] == "stable"
    assert agent["version"] == "0.3.0" and agent["stage"] == "stable"
    assert chronicle["version"] == "1.7.1" and chronicle["stage"] == "stable"

    # Historical Raven 2.0.32 base stays frozen while Studio 3.0 is validated separately.
    assert legacy["version"] == "2.8.0"
    assert legacy["stage"] == "stable"

    require(html, "<title>RAH Raven Studio v3.0</title>", "Studio 3 title")
    require(html, "RAH-COMMAND-CENTER-V2.4.html", "canonical Command Center")
    require(html, "Command Center 2.4", "Command Center label")
    require(html, "RAH-RAVEN-MEMORY-SYNC.html", "Project Memory surface")
    require(html, "RAH-RAVEN-BROWSER-VERSION.json", "Raven Browser stable surface")
    require(html, "http://127.0.0.1:18765/health", "loopback Bridge health")
    require(html, "http://127.0.0.1:1234/v1/models", "loopback LM fallback")
    if "https://" in html:
        raise AssertionError("Studio 3.0 must not contain external HTTPS runtime/navigation URLs")

    urls = re.findall(r"http://[^\"'\s<]+", html)
    for url in urls:
        if not (url.startswith("http://127.0.0.1:18765/") or url.startswith("http://127.0.0.1:1234/")):
            raise AssertionError(f"Unexpected non-loopback HTTP URL: {url}")

    assert manifest["features"]["automatic_mutating_actions"] is False
    assert manifest["features"]["automatic_sending"] is False
    assert manifest["features"]["hidden_capture"] is False

    for needle in (
        "RAH-RAVEN-HOVED-PC-FINAL.ps1",
        "RAH-COMMAND-CENTER-VERSION.json",
        "RAH-RAVEN-BROWSER-VERSION.json",
        "Command Center generation 9",
        "RAVEN-STUDIO-FINAL-LATEST.json",
        "START-HER-RAH-RAVEN-STUDIO.cmd",
    ):
        require(finalizer, needle, "finalizer contract")

    require(launcher, "RAH-RAVEN-STUDIO-FINAL.ps1", "one-click finalizer target")
    require(launcher, "RAVEN-STUDIO-FINAL-LATEST.json", "one-click report")

    print("RAH RAVEN STUDIO 3.0 CONTRACT: PASS")


if __name__ == "__main__":
    main()
