from __future__ import annotations

import io
import unittest
from unittest.mock import patch

from server_v16 import (
    APP_VERSION,
    CASE_CENTER_VERSION,
    DIRECT_RUN_DISABLED,
    _normalize_loopback_base,
    _normalize_loopback_host,
    app,
)


class CaseCenterV16Tests(unittest.TestCase):
    def setUp(self) -> None:
        app.config.update(TESTING=True)
        self.client = app.test_client()

    def test_health_announces_case_center_version(self) -> None:
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertTrue(data["ok"])
        self.assertTrue(data["case_center"])
        self.assertEqual(data["version"], APP_VERSION)
        self.assertEqual(data["case_center_version"], CASE_CENTER_VERSION)
        self.assertEqual(CASE_CENTER_VERSION, "1.6.0")

    def test_direct_legacy_server_entrypoint_is_disabled(self) -> None:
        self.assertTrue(DIRECT_RUN_DISABLED)

    def test_loopback_host_boundary(self) -> None:
        self.assertEqual(_normalize_loopback_host("127.0.0.1"), "127.0.0.1")
        self.assertEqual(_normalize_loopback_host("localhost"), "localhost")
        self.assertEqual(_normalize_loopback_host("[::1]"), "::1")
        with self.assertRaises(RuntimeError):
            _normalize_loopback_host("0.0.0.0")
        with self.assertRaises(RuntimeError):
            _normalize_loopback_host("192.168.1.20")

    def test_local_ai_base_boundary(self) -> None:
        self.assertEqual(_normalize_loopback_base("http://127.0.0.1:1234", "LM"), "http://127.0.0.1:1234")
        self.assertEqual(_normalize_loopback_base("http://localhost:1234/", "LM"), "http://localhost:1234")
        with self.assertRaises(RuntimeError):
            _normalize_loopback_base("https://example.com", "LM")
        with self.assertRaises(RuntimeError):
            _normalize_loopback_base("http://user:pass@127.0.0.1:1234", "LM")
        with self.assertRaises(RuntimeError):
            _normalize_loopback_base("http://127.0.0.1:1234/v1", "LM")
        with self.assertRaises(RuntimeError):
            _normalize_loopback_base("http://127.0.0.1:1234?x=1", "LM")

    def test_case_page_is_available_and_memory_only(self) -> None:
        response = self.client.get("/case")
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"RAH Raven Local Case Center v1.6", response.data)
        self.assertIn(b"Menneskelig kontroll kreves", response.data)
        self.assertNotIn(b"localStorage", response.data)
        self.assertNotIn(b"sessionStorage", response.data)

    def test_extract_plain_text_without_persisting(self) -> None:
        response = self.client.post(
            "/case/extract",
            data={"file": (io.BytesIO("Dato 2026-08-06: Testnotat".encode("utf-8")), "notat.txt")},
            content_type="multipart/form-data",
        )
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertTrue(data["ok"])
        self.assertIn("Testnotat", data["text"])
        self.assertFalse(data["stored"])
        self.assertEqual(len(data["sha256"]), 64)

    def test_analyze_requires_documents(self) -> None:
        response = self.client.post("/case/analyze", json={"documents": []})
        self.assertEqual(response.status_code, 400)
        self.assertFalse(response.get_json()["ok"])

    @patch("server_v16._lm_chat", return_value=("Kildebasert svar [K1]", "local-model"))
    def test_completed_analysis_requires_human_review(self, _mock_chat) -> None:
        response = self.client.post(
            "/case/analyze",
            json={"documents": [{"name": "notat.txt", "text": "2026-08-06 Test"}]},
        )
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertTrue(data["ok"])
        self.assertTrue(data["human_review_required"])
        self.assertFalse(data["stored"])


if __name__ == "__main__":
    unittest.main()
