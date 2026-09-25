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
    def test_unknown_app_and_action_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = app_launcher.run_action("not-real", "start", tmp, platform_name="nt")
            self.assertEqual(result["code"], "unknown-app")
            result = app_launcher.run_action("world-media", "not-real", tmp, platform_name="nt")
            self.assertEqual(result["code"], "unknown-action")

    def test_non_windows_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = app_launcher.run_action("world-media", "start", tmp, platform_name="posix")
        self.assertFalse(result["ok"])
        self.assertEqual(result["code"], "windows-only")

    def test_catalog_detects_multiple_fixed_actions(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            folder = root / "apps" / "rah-world-media"
            folder.mkdir(parents=True)
            for name in ("START-HER.cmd", "SELFTEST.cmd", "REPAIR.cmd"):
                (folder / name).write_text("@echo off\n", encoding="utf-8")
            catalog = app_launcher.catalog(root)

        row = next(x for x in catalog["apps"] if x["id"] == "world-media")
        self.assertTrue(row["default_available"])
        self.assertEqual(row["version"], "14.0")
        self.assertEqual({x["id"] for x in row["actions"]}, {"start", "selftest", "repair"})
        self.assertTrue(all(x["available"] for x in row["actions"]))
        self.assertFalse(catalog["arbitrary_shell"])
        self.assertFalse(catalog["arbitrary_paths"])
        self.assertFalse(catalog["arbitrary_arguments"])

    def test_cmd_action_uses_fixed_argv_and_shell_false(self) -> None:
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
            result = app_launcher.run_action(
                "world-media",
                "start",
                root,
                platform_name="nt",
                popen=fake_popen,
                environ={"COMSPEC": r"C:\Windows\System32\cmd.exe"},
            )

        self.assertTrue(result["ok"])
        self.assertEqual(captured["argv"][0], r"C:\Windows\System32\cmd.exe")
        self.assertEqual(captured["argv"][1:3], ["/d", "/c"])
        self.assertTrue(captured["argv"][3].endswith("START-HER.cmd"))
        self.assertIs(captured["kwargs"]["shell"], False)

    def test_static_cmd_args_cannot_come_from_caller(self) -> None:
        captured = {}

        def fake_popen(argv, **kwargs):
            captured["argv"] = argv
            captured["kwargs"] = kwargs
            return FakeProcess()

        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            target = root / "START-HER-RAH-HOME.cmd"
            target.write_text("@echo off\n", encoding="utf-8")
            result = app_launcher.run_action(
                "rah-home",
                "selftest",
                root,
                platform_name="nt",
                popen=fake_popen,
                environ={"COMSPEC": r"C:\Windows\System32\cmd.exe"},
            )

        self.assertTrue(result["ok"])
        self.assertEqual(captured["argv"][-1], "--self-test")
        self.assertNotIn("user-command", captured["argv"])

    def test_powershell_action_uses_fixed_script_and_static_args(self) -> None:
        captured = {}

        def fake_popen(argv, **kwargs):
            captured["argv"] = argv
            captured["kwargs"] = kwargs
            return FakeProcess()

        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            target = root / "RAH-RAVEN-BROWSER-FINAL.ps1"
            target.write_text("# test\n", encoding="utf-8")
            result = app_launcher.run_action(
                "raven-browser",
                "selftest",
                root,
                platform_name="nt",
                popen=fake_popen,
                environ={"SystemRoot": r"C:\Windows"},
            )

        self.assertTrue(result["ok"])
        self.assertTrue(captured["argv"][0].endswith("powershell.exe"))
        self.assertIn("-File", captured["argv"])
        self.assertEqual(captured["argv"][-1], "-SelfTest")
        self.assertIs(captured["kwargs"]["shell"], False)

    def test_definition_surface_has_no_generic_action(self) -> None:
        self.assertEqual(
            set(app_launcher.APP_DEFINITIONS),
            {"world-media", "raven-browser", "rah-os", "rah-home"},
        )
        for definition in app_launcher.APP_DEFINITIONS.values():
            self.assertNotIn("*", definition["actions"])
            for action in definition["actions"].values():
                self.assertIn(action["runner"], {"cmd", "powershell"})
                self.assertIsInstance(action["args"], list)


if __name__ == "__main__":
    unittest.main(verbosity=2)
