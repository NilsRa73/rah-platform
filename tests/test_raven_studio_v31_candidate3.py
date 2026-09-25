from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HTML = ROOT / "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.3.html"
MANIFEST = ROOT / "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.3.json"
LAUNCHER = ROOT / "START-HER-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.3.cmd"
ACCEPT = ROOT / "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.3.ps1"

def require(text: str, needle: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing: {needle!r}")

def main() -> None:
    html = HTML.read_text(encoding="utf-8")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    launcher = LAUNCHER.read_text(encoding="utf-8")
    accept = ACCEPT.read_text(encoding="utf-8")

    assert manifest["product"] == "RAH Raven Studio"
    assert manifest["version"] == "3.1.0-candidate.3"
    assert manifest["stage"] == "candidate"
    assert manifest["based_on"] == "3.0.0-stable"
    assert manifest["launch_lifecycle"]["states"] == ["STARTER", "STARTET", "FEILET"]
    assert manifest["launch_lifecycle"]["bridge_preflight_timeout_ms"] == 2500
    assert manifest["safety"]["stable_v3_0_untouched"] is True
    assert manifest["safety"]["no_background_powershell_windows"] is True

    for needle in (
        "<title>RAH Raven Studio v3.1 Candidate.3</title>",
        "LAUNCH_STATE_KEY",
        "LAUNCH_TIMEOUT_MS=2500",
        "STARTER",
        "STARTET",
        "FEILET",
        "AbortController",
        "requiresBridge:true",
        "http://127.0.0.1:18765/health",
        "Siste feilmelding",
    ):
        require(html, needle)

    if "https://" in html:
        raise AssertionError("Candidate runtime must not contain external HTTPS URLs")

    urls = re.findall(r"http://[^\"'\s<]+", html)
    for url in urls:
        if not (url.startswith("http://127.0.0.1:18765/") or url.startswith("http://127.0.0.1:1234/")):
            raise AssertionError(f"Unexpected non-loopback HTTP URL: {url}")

    require(launcher, "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.3.ps1")
    require(accept, "3.1.0-candidate.3")
    require(accept, "2500")
    print("RAH RAVEN STUDIO v3.1 CANDIDATE.3 CONTRACT: PASS")

if __name__ == "__main__":
    main()
