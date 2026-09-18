from __future__ import annotations

import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import raven_project_memory


class ProjectMemoryTests(unittest.TestCase):
    def test_public_config_never_returns_secret(self):
        with mock.patch.object(raven_project_memory.raven_ai_fabric, "_anything_key", return_value="super-secret"):
            cfg = raven_project_memory.public_config()
        self.assertTrue(cfg["token_configured"])
        self.assertNotIn("super-secret", json.dumps(cfg))

    def test_retrieve_context_uses_workspace_and_resets_session(self):
        cfg = dict(raven_project_memory.DEFAULT_CONFIG)
        cfg["workspace"] = "rah-raven"
        cfg["always_for_council"] = True

        ready = {"ready": True}
        payload = {
            "textResponse": "PR 333 added multi-AI Council.",
            "sources": [{"title": "RAH-PROJECT-SNAPSHOT"}],
        }

        with (
            mock.patch.object(raven_project_memory, "load_config", return_value=cfg),
            mock.patch.object(raven_project_memory, "memory_status", return_value=ready),
            mock.patch.object(raven_project_memory, "_auth_headers", return_value={"Authorization": "Bearer x"}),
            mock.patch.object(
                raven_project_memory.raven_ai_fabric,
                "_json_request",
                return_value=(200, payload),
            ) as request_call,
        ):
            result = raven_project_memory.retrieve_context("Hva er nytt i Raven?")

        self.assertTrue(result["used"])
        self.assertEqual(result["workspace"], "rah-raven")
        kwargs = request_call.call_args.kwargs
        self.assertTrue(kwargs["body"]["reset"])
        self.assertEqual(kwargs["body"]["sessionId"], "rah-raven-project-memory")
        self.assertIn("REFERENCE", raven_project_memory.augment_system("", result))

    def test_disabled_memory_does_not_retrieve(self):
        cfg = dict(raven_project_memory.DEFAULT_CONFIG)
        cfg["enabled"] = False
        with mock.patch.object(raven_project_memory, "load_config", return_value=cfg):
            result = raven_project_memory.retrieve_context("RAH status")
        self.assertFalse(result["used"])

    def test_config_file_workspace_can_be_loaded(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "memory.json"
            path.write_text(
                json.dumps({"workspace": "custom-rah", "max_context_chars": 5000}),
                encoding="utf-8",
            )
            with mock.patch.object(raven_project_memory, "CONFIG_PATH", path):
                cfg = raven_project_memory.load_config()
        self.assertEqual(cfg["workspace"], "custom-rah")
        self.assertEqual(cfg["max_context_chars"], 5000)


if __name__ == "__main__":
    unittest.main(verbosity=2)
