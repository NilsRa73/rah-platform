#!/usr/bin/env python3
import importlib.util
import json
import threading
import unittest
from pathlib import Path
from unittest import mock
from urllib.error import HTTPError
from urllib.request import urlopen


MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "config"
    / "includes.chroot"
    / "usr"
    / "local"
    / "lib"
    / "rah"
    / "raven-agent.py"
)

spec = importlib.util.spec_from_file_location("rah_raven_agent", MODULE_PATH)
if spec is None or spec.loader is None:
    raise RuntimeError(f"Unable to load Raven agent from {MODULE_PATH}")
agent = importlib.util.module_from_spec(spec)
spec.loader.exec_module(agent)


class RavenPayloadTests(unittest.TestCase):
    def test_system_payload_has_expected_core_fields(self):
        payload = agent.system_payload()
        for key in (
            "hostname",
            "os",
            "rah_version",
            "base",
            "kernel",
            "architecture",
            "cpu_threads",
            "root_total_gb",
            "root_free_gb",
            "boot_mode",
        ):
            self.assertIn(key, payload)
        self.assertEqual(payload["os"], "RAH OS Raven")
        self.assertEqual(payload["rah_version"], agent.VERSION)

    def test_diagnostics_payload_is_read_only_and_well_formed(self):
        payload = agent.diagnostics_payload()
        self.assertEqual(payload["rah_version"], agent.VERSION)
        self.assertIn("summary", payload)
        self.assertIn("checks", payload)
        self.assertGreaterEqual(len(payload["checks"]), 8)
        self.assertIn("Read-only", payload["note"])
        for item in payload["checks"]:
            self.assertIn(item["state"], {"PASS", "WARN", "INFO"})
            self.assertTrue(item["key"])
            self.assertTrue(item["title"])

    def test_missing_external_command_is_non_fatal(self):
        result = agent.run_text(["rah-command-that-does-not-exist-9f61"], timeout=1)
        self.assertEqual(result, "")


class RavenHTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.server = agent.ThreadingHTTPServer(("127.0.0.1", 0), agent.Handler)
        cls.port = cls.server.server_address[1]
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown()
        cls.server.server_close()
        cls.thread.join(timeout=5)

    def fetch(self, path):
        with urlopen(f"http://127.0.0.1:{self.port}{path}", timeout=3) as response:
            return response.status, dict(response.headers), response.read()

    def test_health_endpoint(self):
        status, headers, body = self.fetch("/health")
        self.assertEqual(status, 200)
        self.assertIn("application/json", headers["Content-Type"])
        data = json.loads(body)
        self.assertEqual(data["status"], "ok")
        self.assertEqual(data["service"], "rah-raven-agent")
        self.assertEqual(data["version"], agent.VERSION)

    def test_system_endpoint(self):
        fixture = {"hostname": "ci-host", "rah_version": agent.VERSION}
        with mock.patch.object(agent, "system_payload", return_value=fixture):
            status, _, body = self.fetch("/system")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), fixture)

    def test_diagnostics_endpoint(self):
        fixture = {
            "rah_version": agent.VERSION,
            "summary": {"PASS": 1, "WARN": 0, "INFO": 0},
            "checks": [{"state": "PASS", "key": "raven", "title": "Raven", "detail": "OK"}],
        }
        with mock.patch.object(agent, "diagnostics_payload", return_value=fixture):
            status, _, body = self.fetch("/api/diagnostics")
        self.assertEqual(status, 200)
        self.assertEqual(json.loads(body), fixture)

    def test_report_is_downloadable_json(self):
        fixture = {"rah_version": agent.VERSION, "checks": []}
        with mock.patch.object(agent, "diagnostics_payload", return_value=fixture):
            status, headers, body = self.fetch("/report")
        self.assertEqual(status, 200)
        self.assertIn("attachment;", headers["Content-Disposition"])
        self.assertEqual(json.loads(body), fixture)

    def test_command_center_home(self):
        status, headers, body = self.fetch("/")
        self.assertEqual(status, 200)
        self.assertIn("text/html", headers["Content-Type"])
        text = body.decode("utf-8")
        self.assertIn("Raven Command Center", text)
        self.assertIn("/api/diagnostics", text)

    def test_unknown_route_is_404(self):
        with self.assertRaises(HTTPError) as ctx:
            urlopen(f"http://127.0.0.1:{self.port}/not-a-route", timeout=3)
        self.assertEqual(ctx.exception.code, 404)
        self.assertEqual(json.loads(ctx.exception.read())["error"], "not_found")


if __name__ == "__main__":
    unittest.main(verbosity=2)
