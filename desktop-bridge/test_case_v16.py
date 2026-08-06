from __future__ import annotations

import io
import unittest

from server_v16 import APP_VERSION, app


class CaseCenterV16Tests(unittest.TestCase):
    def setUp(self) -> None:
        app.config.update(TESTING=True)
        self.client = app.test_client()

    def test_health_announces_case_center(self) -> None:
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertTrue(data["ok"])
        self.assertTrue(data["case_center"])
        self.assertEqual(data["version"], APP_VERSION)

    def test_case_page_is_available(self) -> None:
        response = self.client.get("/case")
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"RAH Raven Local Case Center", response.data)

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


if __name__ == "__main__":
    unittest.main()
