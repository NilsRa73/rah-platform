from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"Missing {label}: {needle!r}")


def main() -> None:
    stable = json.loads((ROOT / "RAH-RAVEN-STUDIO-V3.0.json").read_text(encoding="utf-8"))
    candidate = json.loads((ROOT / "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.json").read_text(encoding="utf-8"))
    html = (ROOT / "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html").read_text(encoding="utf-8")
    launcher = (ROOT / "desktop-bridge" / "app_launcher.py").read_text(encoding="utf-8")
    bridge = (ROOT / "desktop-bridge" / "raven_bridge.py").read_text(encoding="utf-8")

    assert stable["version"] == "3.0.0"
    assert stable["stage"] == "stable"
    assert stable["change_policy"] == "bugfix-only-until-explicit-reopen"

    assert candidate["version"] == "3.1.0-candidate.1"
    assert candidate["stage"] == "candidate"
    assert candidate["based_on"] == "3.0.0"
    assert candidate["stable_base_untouched"] is True
    assert candidate["features"]["explicit_user_launch_only"] is True
    assert candidate["features"]["fixed_allowlist"] is True
    assert candidate["features"]["arbitrary_shell"] is False
    assert candidate["features"]["automatic_mutating_actions"] is False

    require(html, "RAH Raven Studio v3.1 Candidate", "candidate title")
    require(html, "RAH World Media 14", "World Media tile")
    require(html, "http://127.0.0.1:18765/apps/catalog", "local app catalog")
    require(html, "/apps/launch/", "explicit launch endpoint")
    require(html, "JSON.stringify({confirm:true})", "explicit launch confirmation payload")
    require(html, "window.confirm(", "human confirmation dialog")

    require(launcher, '"world-media"', "fixed World Media allowlist entry")
    require(launcher, r"C:\RAH\WorldMedia\14.0\START-HER.cmd", "fixed installed path")
    require(launcher, '"shell": False', "shell-disabled process launch")
    if "shell=True" in launcher or '"shell": True' in launcher:
        raise AssertionError("App launcher must never use shell=True")

    require(bridge, '"/apps/"', "protected apps prefix")
    require(bridge, '@app.get("/apps/catalog")', "catalog route")
    require(bridge, '@app.post("/apps/launch/<app_id>")', "launch route")
    require(bridge, 'data.get("confirm") is not True', "server-side confirmation gate")
    require(bridge, '"app_launcher_mode": app_launcher.APP_LAUNCHER_MODE', "health marker")

    print("RAH RAVEN STUDIO 3.1 CANDIDATE CONTRACT: PASS")


if __name__ == "__main__":
    main()
