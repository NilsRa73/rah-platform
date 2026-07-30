from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import doctor  # noqa: E402


class FakeResponse:
    def __init__(self, payload):
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def read(self):
        return json.dumps(self.payload).encode("utf-8")


class DoctorTests(unittest.TestCase):
    def test_lm_studio_reports_loaded_model(self):
        with patch("urllib.request.urlopen", return_value=FakeResponse({"data": [{"id": "vision-model"}]})):
            checks = doctor.lm_studio_checks("http://127.0.0.1:1234/v1")
        self.assertTrue(all(item.ok for item in checks))
        self.assertIn("vision-model", checks[-1].detail)

    def test_lm_studio_requires_loaded_model(self):
        with patch("urllib.request.urlopen", return_value=FakeResponse({"data": []})):
            checks = doctor.lm_studio_checks("http://127.0.0.1:1234/v1")
        self.assertTrue(checks[0].ok)
        self.assertFalse(checks[1].ok)

    def test_bridge_validates_health_and_capture(self):
        responses = [
            FakeResponse({"ok": True, "version": "1.3.0", "platform": "Windows"}),
            FakeResponse({
                "ok": True,
                "image": "data:image/png;base64,AAAA",
                "metadata": {"width": 800, "height": 600},
            }),
        ]
        with patch("urllib.request.urlopen", side_effect=responses):
            checks = doctor.bridge_checks("http://127.0.0.1:8765", capture=True)
        self.assertEqual(2, len(checks))
        self.assertTrue(all(item.ok for item in checks))


if __name__ == "__main__":
    unittest.main()
