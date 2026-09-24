import ast
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "apps" / "rah-world-media"


def read(name: str) -> str:
    return (APP / name).read_text(encoding="utf-8")


class RahWorldMediaV14Contract(unittest.TestCase):
    def test_python_source_parses_and_version_is_v14(self):
        src = read("RAH_WORLD_MEDIA.py")
        ast.parse(src)
        self.assertIn('VERSION = "14.0"', src)
        self.assertIn("class App:", src)

    def test_v14_keeps_sync_receiver_contract(self):
        src = read("RAH_WORLD_MEDIA.py")
        for marker in (
            "RAVEN WORLD GRID",
            "SYNC_LEAD_SECONDS = 1.8",
            "RECEIVER_TTL_SECONDS = 14.0",
            "BROADCAST_QUEUE_FILE",
            "BROADCAST_STATE_FILE",
            "SYNC NOW",
            "QUEUE NEXT",
            "broadcast_sync_now",
            "broadcast_next",
            "broadcast_stop",
            "Receiver Registry",
            "/heartbeat",
            "/clients",
            "/state",
            "/command",
        ):
            self.assertIn(marker, src)


    def test_v14_resilient_catalog_contract(self):
        src = read("RAH_WORLD_MEDIA.py")
        for marker in (
            "stale-cache safety net",
            "metadata failure cannot empty the TV list",
            "HENT KANALER",
            "metadata fallback active",
        ):
            self.assertIn(marker, src)

    def test_v14_world_grid_contract(self):
        src = read("RAH_WORLD_MEDIA.py")
        for marker in (
            "RAVEN WORLD GRID",
            "500 WORLD",
            'id="liveLimit"',
            "registerMosaicLive",
            "AUTO 10s",
            "XREAL 32:9",
            "NEXT BANK",
            "STANDBY",
            "world_mix=hls_all[:500]",
        ):
            self.assertIn(marker, src)
        self.assertIn("liveLimit=16", src)
        self.assertIn("Math.min(500", src)
        self.assertIn("Math.min(256", src)

    def test_remote_receiver_is_token_protected_and_lan_is_explicit(self):
        src = read("RAH_WORLD_MEDIA.py")
        low = src.lower()
        self.assertIn("secret token", low)
        self.assertIn("trusted lan", low)
        self.assertIn("do not port-forward", low)
        self.assertIn("host='0.0.0.0' if lan else '127.0.0.1'", src)
        self.assertNotIn("upnp", low)
        self.assertNotIn("nat-pmp", low)

    def test_heavy_playback_remains_user_initiated(self):
        src = read("RAH_WORLD_MEDIA.py")
        low = src.lower()
        self.assertIn("play_url(", src)
        self.assertIn("explicit", read("README.txt").lower())
        self.assertNotIn("widevine", low)
        self.assertNotIn("playready", low)
        self.assertNotIn("drm bypass", low.replace("no drm bypass", ""))

    def test_package_entrypoints_are_present(self):
        for name in (
            "START-HER.cmd",
            "START-RAH-WORLD-MEDIA.cmd",
            "INSTALL.cmd",
            "REPAIR.cmd",
            "SELFTEST.cmd",
            "DIAGNOSTICS.cmd",
            "UNINSTALL.cmd",
            "RAH_BOOTSTRAP.ps1",
            "RAH_INSTALL.ps1",
            "world_countries_simplified.json",
            "README.txt",
            "RUN-CHECKLIST.txt",
            "CHANGELOG_v14.txt",
        ):
            self.assertTrue((APP / name).is_file(), name)

    def test_build_script_is_v14_and_fixed_allowlist_only(self):
        build = read("BUILD-PACKAGE.ps1")
        self.assertIn("$Files = @(", build)
        self.assertIn("MANIFEST.sha256", build)
        self.assertIn("Compress-Archive", build)
        self.assertIn("RAH_WORLD_MEDIA_v14_RAVEN_WORLD_GRID", build)
        self.assertIn("CHANGELOG_v14.txt", build)
        self.assertIn("DIAGNOSTICS.cmd", build)
        self.assertNotIn("Invoke-Expression", build)


if __name__ == "__main__":
    unittest.main()
