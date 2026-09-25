from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HTML = ROOT / "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html"
MANIFEST = ROOT / "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json"
LAUNCHER = ROOT / "START-HER-RAH-RAVEN-STUDIO-V3.1-CANDIDATE.cmd"
STABLE = ROOT / "RAH-RAVEN-STUDIO-V3.0.html"


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing {label}: {needle!r}")


def main() -> None:
    html = HTML.read_text(encoding="utf-8")
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    launcher = LAUNCHER.read_text(encoding="utf-8")
    stable = STABLE.read_text(encoding="utf-8")

    assert manifest["product"] == "RAH Raven Studio"
    assert manifest["version"] == "3.1.0-candidate.3"
    assert manifest["stage"] == "candidate"
    assert manifest["based_on"] == "3.0.0"
    assert manifest["local_first"] is True
    assert manifest["features"]["quick_search"] is True
    assert manifest["features"]["status_request_timeout_ms"] == 2800
    assert manifest["features"]["overlapping_status_poll_prevented"] is True
    assert manifest["features"]["local_app_launcher"] is True
    assert manifest["features"]["local_app_launcher_mode"] == "fixed-allowlist-explicit-launch"
    assert manifest["features"]["local_app_launcher_arbitrary_commands"] is False
    assert manifest["features"]["local_app_launcher_caller_arguments"] is False
    assert manifest["features"]["local_app_launch_state"] == ["starting", "started", "failed"]
    assert manifest["features"]["local_app_last_error_visible"] is True
    assert manifest["features"]["local_app_last_error_retained_after_success"] is True
    assert manifest["features"]["local_app_launch_timeout_ms"] == 5000
    assert manifest["features"]["local_app_launcher_version"] == "0.2.0"
    assert manifest["candidate_policy"]["does_not_replace_stable"] is True
    assert manifest["candidate_policy"]["background_powershell_required"] is False

    require(html, "<title>RAH Raven Studio v3.1 Candidate</title>", "candidate title")
    require(html, 'id="appSearch"', "quick search input")
    require(html, "Ctrl+K", "keyboard hint")
    require(html, "renderSearchResults", "search implementation")
    require(html, "AbortController", "status timeout")
    require(html, "timeoutMs=2800", "status timeout default")
    require(html, "testInFlight", "overlap guard")
    require(html, "renderStatusSummary", "status summary")
    require(html, 'data-native-launch="world-media"', "World Media launcher")
    require(html, 'data-native-launch="rah-os"', "RAH OS launcher")
    require(html, 'data-native-launch="raven-browser"', "Raven Browser launcher")
    require(html, "http://127.0.0.1:18765/apps/catalog", "local app catalog")
    require(html, "http://127.0.0.1:18765/apps/launch", "local app launch endpoint")
    require(html, "{id,confirm:true}", "explicit launch confirmation")
    require(html, "raven-studio-launch-client.js", "launch client")
    require(html, 'id="nativeLaunchState-world-media"', "World Media launch state")
    require(html, 'id="nativeLaunchState-rah-os"', "RAH OS launch state")
    require(html, 'id="nativeLaunchState-raven-browser"', "Raven Browser launch state")
    require(html, 'id="nativeLaunchError-world-media"', "World Media last error")
    require(html, "renderNativeLaunch", "launch state renderer")
    require(html, "state:'starting'", "starting state")
    require(html, "state:'failed'", "failed state")
    require(html, "http://127.0.0.1:18765/apps/status", "Bridge launch status endpoint")
    require(html, "LAUNCH_CLIENT.requestJson", "tested launch request client")
    require(html, "5000", "launch request timeout")
    require(html, "RAH-COMMAND-CENTER-V2.4.html", "canonical Command Center")
    require(html, "http://127.0.0.1:18765/health", "loopback Bridge health")
    require(html, "http://127.0.0.1:1234/v1/models", "loopback LM fallback")

    if "https://" in html:
        raise AssertionError("Studio v3.1 candidate must not contain external HTTPS runtime/navigation URLs")

    urls = re.findall(r"http://[^\"'\\s<]+", html)
    for url in urls:
        if not (url.startswith("http://127.0.0.1:18765/") or url.startswith("http://127.0.0.1:1234/")):
            raise AssertionError(f"Unexpected non-loopback HTTP URL: {url}")

    require(launcher, "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html", "candidate target")
    if "powershell" in launcher.lower():
        raise AssertionError("Candidate launcher must not invoke PowerShell")
    if "RAH Raven Studio v3.0" not in stable:
        raise AssertionError("Stable v3.0 was unexpectedly altered")

    print("RAH RAVEN STUDIO 3.1 CANDIDATE CONTRACT: PASS")


if __name__ == "__main__":
    main()
