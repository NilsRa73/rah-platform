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
            "ROTATE LIVE",
            "NEW SCREEN",
            "STANDBY",
            "healthSweep",
            "replaceMosaicSource",
            "quarantineSource",
            "DocumentFragment",
            "AUTO SCAN ON",
            "BACK TO MENU",
            "returnToMenu",
            "world_mix=world_all[:500]",
            "VISIBLE '+visible",
            "mthumb",
            "<option>32</option>",
            "<option>48</option>",
        ):
            self.assertIn(marker, src)
        self.assertIn("liveLimit=16", src)
        self.assertIn("Math.min(500", src)
        self.assertIn("Math.min(256", src)


    def test_v14_auto_heal_does_not_reuse_failed_tile_url_contract(self):
        src = read("RAH_WORLD_MEDIA.py")
        self.assertIn("tile._rahItem=replacement", src)
        self.assertIn("let current=d._rahItem||x", src)
        self.assertIn("quarantine.set(url,Date.now()+ms)", src)
        self.assertIn("now-entry.progressAt>22000", src)
        self.assertIn("rotateLiveBank()", src)

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
            "SELF-IMPROVE.cmd",
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
        self.assertIn("SELF-IMPROVE.cmd", build)
        self.assertNotIn("Invoke-Expression", build)

    def test_v14_builtin_selftest_and_safe_self_improve_contract(self):
        src = read("RAH_WORLD_MEDIA.py")
        bootstrap = read("RAH_BOOTSTRAP.ps1")
        improve = read("SELF-IMPROVE.cmd")
        for marker in (
            "def runtime_selftest(",
            "def runtime_self_improve(",
            'SELFTEST_REPORT_FILE = BASE_DIR / "selftest_v14.json"',
            'SELFIMPROVE_REPORT_FILE = BASE_DIR / "self_improve_v14.json"',
            '"--selftest"',
            '"--self-improve"',
            "BACKUP+REMOVE invalid cache",
            "world_mix=world_all[:500]",
            "VISIBLE '+visible",
        ):
            self.assertIn(marker, src)
        self.assertIn("[switch]$SelfImprove", bootstrap)
        self.assertIn("--self-improve", bootstrap)
        self.assertIn("MANIFEST.sha256", bootstrap)
        self.assertIn("-SelfImprove", improve)


if __name__ == "__main__":
    unittest.main()
