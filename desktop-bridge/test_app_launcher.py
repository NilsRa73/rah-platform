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

        with patch.object(app_launcher.os, "name", "nt"), \
             patch.object(app_launcher.subprocess, "Popen") as popen:
            popen.return_value = Mock(pid=4242)
            result = app_launcher.launch(root, "world-media")
            assert result["ok"] is True
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

    print("RAH Raven App Launcher fixed allowlist / hidden CMD contract: OK")


if __name__ == "__main__":
    main()
