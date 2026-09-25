from __future__ import annotations

import pathlib
import tempfile
from unittest.mock import Mock, patch

import app_launcher


def main() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-app-launcher-") as temp:
        root = pathlib.Path(temp)
        for spec in app_launcher.APP_ALLOWLIST.values():
            target = root / spec["path"]
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text("@echo off\nexit /b 0\n", encoding="utf-8")

        items = app_launcher.catalog(root)
        assert len(items) == 3
        assert all(item["available"] is True for item in items)
        assert {item["id"] for item in items} == {"world-media", "rah-os", "raven-browser"}

        try:
            app_launcher._target(root, "cmd /c del *")
        except KeyError:
            pass
        else:
            raise AssertionError("Arbitrary launcher ID was accepted.")

        with patch.object(app_launcher, "_is_windows", return_value=True), \
             patch.object(app_launcher.subprocess, "Popen") as popen:
            popen.return_value = Mock(pid=4242)
            result = app_launcher.launch(root, "world-media")
            assert result["ok"] is True
            assert result["state"] == "started"
            assert result["last_error"] is None
            assert result["last_attempt_at"]
            assert result["last_started_at"]
            assert result["pid"] == 4242
            assert result["shell_window"] is False
            assert result["arbitrary_commands"] is False
            assert result["caller_arguments"] is False

            args, kwargs = popen.call_args
            command = args[0]
            assert command[1:5] == ["/d", "/s", "/c", "call"]
            assert command[-1].endswith("apps\\rah-world-media\\START-HER.cmd") or command[-1].endswith("apps/rah-world-media/START-HER.cmd")
            assert kwargs["shell"] is False
            assert kwargs["stdin"] is app_launcher.subprocess.DEVNULL
            assert kwargs["stdout"] is app_launcher.subprocess.DEVNULL
            assert kwargs["stderr"] is app_launcher.subprocess.DEVNULL

            current = app_launcher.status("world-media")
            assert current["state"] == "started"
            assert current["pid"] == 4242
            assert current["last_error"] is None

        with patch.object(app_launcher, "_is_windows", return_value=True), \
             patch.object(app_launcher.subprocess, "Popen", side_effect=OSError("synthetic launch failure")):
            failed = app_launcher.launch(root, "rah-os")
            assert failed["ok"] is False
            assert failed["state"] == "failed"
            assert failed["last_error"] == "synthetic launch failure"
            failed_status = app_launcher.status("rah-os")
            assert failed_status["state"] == "failed"
            assert failed_status["last_error"] == "synthetic launch failure"
            assert failed_status["last_attempt_at"]

        missing_target = root / app_launcher.APP_ALLOWLIST["raven-browser"]["path"]
        missing_target.unlink()
        missing = app_launcher.launch(root, "raven-browser")
        assert missing["ok"] is False
        assert missing["state"] == "failed"
        assert "mangler lokal launcher" in missing["last_error"]

        all_status = app_launcher.status()
        assert set(all_status) == {"world-media", "rah-os", "raven-browser"}
        assert all_status["world-media"]["state"] == "started"
        assert all_status["rah-os"]["state"] == "failed"
        assert all_status["raven-browser"]["state"] == "failed"

    print("RAH Raven App Launcher fixed allowlist / hidden CMD / launch-state contract: OK")


if __name__ == "__main__":
    main()
