#!/usr/bin/env python3
"""Source regression checks for session lifetime and browser profile continuity."""
import json
import os
import pathlib
import subprocess
import tempfile
import time
import unittest
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[1]
INCLUDES = ROOT / "config/includes.chroot"


class SessionRegression(unittest.TestCase):
    def test_browser_close_does_not_end_login_session(self):
        with tempfile.TemporaryDirectory() as directory:
            work = pathlib.Path(directory)
            for name, body in {
                "openbox": 'echo ready > "$HOME/wm-ready"; while [ ! -f "$HOME/wm-stop" ]; do sleep .1; done',
                "browser": 'echo closed > "$HOME/browser-closed"; exit 0',
                "nm-applet": "exit 0", "tint2": "exit 0",
            }.items():
                path = work / name
                path.write_text("#!/bin/sh\n" + body + "\n")
                path.chmod(0o755)
            source = (INCLUDES / "usr/local/bin/raven-flash-session").read_text()
            source = source.replace("/usr/local/bin/raven-flash-browser", str(work / "browser"))
            session = work / "session"
            session.write_text(source)
            env = {**os.environ, "HOME": str(work), "PATH": str(work) + ":" + os.environ["PATH"],
                   "XDG_STATE_HOME": str(work / "state")}
            process = subprocess.Popen(["sh", str(session)], env=env)
            try:
                deadline = time.monotonic() + 5
                while time.monotonic() < deadline:
                    if (work / "wm-ready").exists() and (work / "browser-closed").exists():
                        break
                    time.sleep(.05)
                self.assertTrue((work / "browser-closed").exists())
                self.assertTrue((work / "wm-ready").exists())
                self.assertIsNone(process.poll(), "Browser close terminated the login session")
            finally:
                (work / "wm-stop").touch()
                process.wait(timeout=5)

    def test_relaunch_keeps_profile_and_does_not_replace_tabs(self):
        with tempfile.TemporaryDirectory() as directory:
            work = pathlib.Path(directory)
            fake = work / "chromium"
            fake.write_text('#!/bin/sh\nprintf "%s\\0" "$@" > "$HOME/args"\n')
            fake.chmod(0o755)
            env = {**os.environ, "HOME": str(work), "PATH": str(work) + ":" + os.environ["PATH"],
                   "XDG_DATA_HOME": str(work / "data")}
            launcher = INCLUDES / "usr/local/bin/raven-flash-browser"
            subprocess.run(["sh", str(launcher)], env={**env, "XDG_RUNTIME_DIR": "/run/old"}, check=True)
            initial = (work / "args").read_bytes().decode().strip("\0").split("\0")
            self.assertIn("file:///opt/raven-flash/start.html", initial)
            profile = work / "data/raven-flash/chromium/Default"
            profile.mkdir()
            (profile / "Preferences").write_text('{"session":{"restore_on_startup":1}}')
            subprocess.run(["sh", str(launcher)], env={**env, "XDG_RUNTIME_DIR": "/run/new"}, check=True)
            reopened = (work / "args").read_bytes().decode().strip("\0").split("\0")
            self.assertIn("--restore-last-session", reopened)
            self.assertNotIn("file:///opt/raven-flash/start.html", reopened)
            self.assertEqual([x for x in initial if x.startswith("--user-data-dir=")],
                             [x for x in reopened if x.startswith("--user-data-dir=")])
            subprocess.run(["sh", str(launcher), "--new-tab", "https://example.invalid"], env=env, check=True)
            self.assertIn(b"https://example.invalid\0", (work / "args").read_bytes())

    def test_desktop_configuration_parses(self):
        for path in (INCLUDES / "opt/raven-flash").glob("*.xml"):
            ET.parse(path)
        settings = json.loads((INCLUDES / "etc/chromium/policies/recommended/raven-flash.json").read_text())
        self.assertEqual(settings["RestoreOnStartup"], 1)


if __name__ == "__main__":
    unittest.main()
