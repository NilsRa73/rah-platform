import ast
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "apps" / "rah-world-media"


def read(name: str) -> str:
    return (APP / name).read_text(encoding="utf-8")


class RahWorldMediaV14IntegratedContract(unittest.TestCase):
    def test_python_source_parses_and_has_both_v14_feature_lines(self):
        src = read("RAH_WORLD_MEDIA.py")
        ast.parse(src)
        self.assertIn('VERSION = "14.0"', src)
        self.assertIn("class App:", src)
        self.assertIn("RAVEN WORLD GRID", src)
        self.assertIn("RAVEN SMART CLUSTER", src)

    def test_world_grid_contract_is_preserved(self):
        src = read("RAH_WORLD_MEDIA.py")
        for marker in (
            "openMosaic(16,true)",
            "openMosaic(36,true)",
            "openMosaic(64,true)",
            "openMosaic(100,true)",
            "openMosaic(500,true)",
            "function isHlsUrl(url)",
            'id="liveLimit"',
            "registerMosaicLive",
            "function rotateLiveBank",
            "AUTO 10s",
            "replaceMosaicSource",
            "quarantineSource",
            "DocumentFragment",
            "BACK TO MENU",
            "RAH LAYOUT DECK • 10 MODES",
            "STORM TV + RADIO",
            "XREAL ULTRAWIDE",
            "world_mix=world_all[:500]",
        ):
            self.assertIn(marker, src)

    def test_smart_cluster_contract_is_present(self):
        src = read("RAH_WORLD_MEDIA.py")
        for marker in (
            "CLUSTER_DEFAULT_SLOTS = 4",
            "CLUSTER_MAX_SLOTS = 12",
            "CLUSTER_POOL_LIMIT = 256",
            "cluster_html",
            "register_cluster_node",
            "public_cluster_state",
            "cluster_stream_pool",
            "toggle_smart_cluster",
            "AUTO TUNE",
            "enableWorker:true",
            "/cluster/heartbeat",
            "/cluster/state",
            "/cluster/clients",
            "/cluster/next",
        ):
            self.assertIn(marker, src)

    def test_cluster_does_not_duplicate_registry_timer(self):
        src = read("RAH_WORLD_MEDIA.py")
        self.assertEqual(src.count("self.root.after(1600,self.receiver_registry_tick)"), 1)

    def test_sync_receiver_contract_is_preserved(self):
        src = read("RAH_WORLD_MEDIA.py")
        for marker in (
            "SYNC_LEAD_SECONDS = 1.8",
            "RECEIVER_TTL_SECONDS = 14.0",
            "broadcast_sync_now",
            "broadcast_next",
            "broadcast_stop",
            "/heartbeat",
            "/clients",
            "/state",
            "/command",
        ):
            self.assertIn(marker, src)

    def test_remote_and_cluster_are_token_protected_and_lan_is_explicit(self):
        src = read("RAH_WORLD_MEDIA.py")
        low = src.lower()
        self.assertIn("secret token", low)
        self.assertIn("trusted lan", low)
        self.assertIn("do not port-forward", low)
        self.assertIn("host='0.0.0.0' if lan else '127.0.0.1'", src)
        self.assertIn("secrets.compare_digest(supplied,token)", src)
        self.assertNotIn("upnp", low)
        self.assertNotIn("nat-pmp", low)

    def test_cluster_is_assignment_only_not_transcoding(self):
        src = read("RAH_WORLD_MEDIA.py").lower()
        self.assertIn("hls.js", src)
        self.assertIn("fetch('/cluster/state?", src)
        self.assertNotIn("ffmpeg", src)
        self.assertNotIn("transcode", src)

    def test_heavy_playback_remains_user_initiated(self):
        src = read("RAH_WORLD_MEDIA.py")
        low = src.lower()
        self.assertIn("play_url(", src)
        self.assertIn("public/legal", read("README.txt").lower())
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
        self.assertIn("SELF-IMPROVE.cmd", build)
        self.assertNotIn("Invoke-Expression", build)


if __name__ == "__main__":
    unittest.main()
