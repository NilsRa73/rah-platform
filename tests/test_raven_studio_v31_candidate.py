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
    candidate_launcher = (ROOT / "START-TEST-RAH-RAVEN-STUDIO-V3.1.cmd").read_text(encoding="utf-8")

    assert stable["version"] == "3.0.0"
    assert stable["stage"] == "stable"
    assert stable["change_policy"] == "bugfix-only-until-explicit-reopen"

    assert candidate["version"] == "3.1.0-candidate.2"
    assert candidate["stage"] == "candidate"
    assert candidate["based_on"] == "3.0.0"
    assert candidate["stable_base_untouched"] is True
    assert candidate["app_launcher"]["version"] == "0.2.0"
    assert candidate["launcher"] == "START-TEST-RAH-RAVEN-STUDIO-V3.1.cmd"
    assert len(candidate["app_launcher"]["apps"]) == 4
    assert candidate["features"]["multi_action_app_hub"] is True
    assert candidate["features"]["static_action_arguments_only"] is True
    assert candidate["features"]["fixed_allowlist"] is True
    assert candidate["features"]["arbitrary_shell"] is False
    assert candidate["features"]["arbitrary_paths"] is False
    assert candidate["features"]["arbitrary_arguments"] is False
    assert candidate["features"]["automatic_mutating_actions"] is False

    for label in ("RAH World Media 14", "Raven Browser 1.3", "RAH Raven OS 0.6", "RAH Home System"):
        require(html, label, f"{label} tile")
    require(html, "http://127.0.0.1:18765/apps/catalog", "local app catalog")
    require(html, "/apps/action/", "fixed action endpoint")
    require(html, "JSON.stringify({confirm:true})", "server confirmation payload")
    require(html, "requires_confirmation", "mutating action confirmation")
    require(html, "data-app-action", "secondary app actions")

    for app_id in ('"world-media"', '"raven-browser"', '"rah-os"', '"rah-home"'):
        require(launcher, app_id, f"{app_id} allowlist")
    require(launcher, r"C:\RAH\WorldMedia\14.0\START-HER.cmd", "World Media fixed path")
    require(launcher, r"C:\RAH\Browser\START-RAH-RAVEN-BROWSER.cmd", "Browser fixed path")
    require(launcher, r"C:\RAH\RavenOS\START-HER-RAH-OS.cmd", "RAH OS fixed path")
    require(launcher, r"C:\RAH\Home\RAH-HOME-DIAGNOSTICS.ps1", "RAH Home fixed diagnostics")
    require(launcher, '"shell": False', "shell-disabled process launch")
    require(launcher, 'return run_action(app_id, str(definition["default_action"])', "compat default action")
    if "shell=True" in launcher or '"shell": True' in launcher:
        raise AssertionError("App launcher must never use shell=True")

    require(bridge, '"/apps/"', "protected apps prefix")
    require(bridge, '@app.get("/apps/catalog")', "catalog route")
    require(bridge, '@app.post("/apps/action/<app_id>/<action_id>")', "fixed action route")
    require(bridge, '@app.post("/apps/launch/<app_id>")', "compat launch route")
    require(bridge, 'data.get("confirm") is not True', "server-side action gate")
    require(bridge, '"app_launcher_mode": app_launcher.APP_LAUNCHER_MODE', "health marker")

    require(candidate_launcher, "RAH Raven Studio v3.1 Candidate.2", "candidate launcher title")
    require(candidate_launcher, "RAH-RAVEN-STUDIO-FINAL.ps1", "stable infrastructure finalizer")
    require(candidate_launcher, "-NoLaunch", "stable UI suppression")
    require(candidate_launcher, "RAH-RAVEN-STUDIO-V3.1-CANDIDATE.html", "candidate UI target")
    require(candidate_launcher, "Stable Studio 3.0 remains unchanged.", "stable preservation message")

    print("RAH RAVEN STUDIO 3.1 CANDIDATE.2 CONTRACT: PASS")


if __name__ == "__main__":
    main()
