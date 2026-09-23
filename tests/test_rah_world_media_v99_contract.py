import ast
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "apps" / "rah-world-media"

def read(name: str) -> str:
    return (APP / name).read_text(encoding="utf-8")

class RahWorldMedia991Contract(unittest.TestCase):
    def test_python_source_parses_and_version_is_991(self):
        src = read("RAH_WORLD_MEDIA.py")
        ast.parse(src)
        self.assertIn('VERSION = "9.9.1"', src)
        self.assertIn("class App:", src)

    def test_super_mode_features_are_present(self):
        src = read("RAH_WORLD_MEDIA.py")
        for marker in (
            "SUPER MODE",
            "WORLD LIVE",
            "SUPER SEARCH",
            "open_media_wall",
            "world_live_tick",
            "WEBCAMS",
            "RADIO_APIS",
            "TV_API",
            "probe_selected_stream",
            "FAVORITES WALL",
            "cached_stream_health",
            "health-aware hover previews",
        ):
            self.assertIn(marker, src)

    def test_runtime_keeps_heavy_playback_explicit(self):
        src = read("RAH_WORLD_MEDIA.py")
        low = src.lower()
        self.assertNotIn("drm bypass", low.replace("no drm bypass", ""))
        self.assertNotIn("widevine", low)
        self.assertNotIn("playready", low)
        self.assertIn("play_url(", src)

    def test_package_entrypoints_are_present(self):
        for name in (
            "START-HER.cmd",
            "START-RAH-WORLD-MEDIA.cmd",
            "INSTALL.cmd",
            "REPAIR.cmd",
            "SELFTEST.cmd",
            "UNINSTALL.cmd",
            "RAH_BOOTSTRAP.ps1",
            "RAH_INSTALL.ps1",
            "world_countries_simplified.json",
            "README.txt",
            "RUN-CHECKLIST.txt",
        ):
            self.assertTrue((APP / name).is_file(), name)

    def test_build_script_uses_fixed_file_allowlist(self):
        build = read("BUILD-PACKAGE.ps1")
        self.assertIn("$Files = @(", build)
        self.assertIn("MANIFEST.sha256", build)
        self.assertIn("Compress-Archive", build)
        self.assertIn("RAH_WORLD_MEDIA_v9_9_1_SMART_PREVIEW", build)
        self.assertIn("CHANGELOG_v9_9_1.txt", build)

    def test_windows_package_is_side_by_side_991(self):
        install = read("RAH_INSTALL.ps1")
        launcher = read("START-HER.cmd")
        bootstrap = read("RAH_BOOTSTRAP.ps1")
        self.assertIn(r"C:\\RAH\\WorldMedia\\9.9.1", install)
        self.assertIn("RAH World Media 9.9.1", install)
        self.assertIn("9.9.1", launcher)
        self.assertIn("v9.9.1", bootstrap)
        self.assertNotIn("Invoke-Expression", build)

if __name__ == "__main__":
    unittest.main()
