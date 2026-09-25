from __future__ import annotations

import importlib.util
import pathlib
import tempfile
import unittest

MODULE_PATH = pathlib.Path(__file__).with_name("app_launcher.py")
SPEC = importlib.util.spec_from_file_location("rah_app_launcher", MODULE_PATH)
assert SPEC and SPEC.loader
app_launcher = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(app_launcher)


class FakeProcess:
    pid = 4242


class AppLauncherTests(unittest.TestCase):
    def test_unknown_app_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = app_launcher.launch("not-real", tmp, platform_name="nt")
        self.assertFalse(result["ok"])
        self.assertEqual(result["code"], "unknown-app")

    def test_non_windows_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = app_launcher.launch("world-media", tmp, platform_name="posix")
        self.assertFalse(result["ok"])
        self.assertEqual(result["code"], "windows-only")

    def test_catalog_detects_repo_copy(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            target = root / "apps" / "rah-world-media" / "START-HER.cmd"
            target.parent.mkdir(parents=True)
            target.write_text("@echo off\n", encoding="utf-8")
            catalog = app_launcher.catalog(root)
        row = next(x for x in catalog["apps"] if x["id"] == "world-media")
        self.assertTrue(row["installed"])
        self.assertEqual(row["version"], "14.0")
        self.assertFalse(catalog["arbitrary_shell"])

    def test_launch_uses_fixed_argv_and_shell_false(self) -> None:
        captured = {}

        def fake_popen(argv, **kwargs):
            captured["argv"] = argv
            captured["kwargs"] = kwargs
            return FakeProcess()

        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            target = root / "apps" / "rah-world-media" / "START-HER.cmd"
            target.parent.mkdir(parents=True)
            target.write_text("@echo off\n", encoding="utf-8")
            result = app_launcher.launch(
                "world-media",
                root,
                platform_name="nt",
                popen=fake_popen,
                environ={"COMSPEC": r"C:\Windows\System32\cmd.exe"},
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["pid"], 4242)
        self.assertEqual(captured["argv"][0], r"C:\Windows\System32\cmd.exe")
        self.assertEqual(captured["argv"][1:3], ["/d", "/c"])
        self.assertTrue(captured["argv"][3].endswith("START-HER.cmd"))
        self.assertIs(captured["kwargs"]["shell"], False)
        self.assertNotIn("args", captured["kwargs"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
