"""GOLD route compatibility regression tests: mocked HTTP, zero host access."""
from __future__ import annotations

from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import rah_agent_worker as worker

BASE = "http://127.0.0.1:18765"


class RavenGoldCompatibility(unittest.TestCase):
    def test_explicit_lmstudio_404_uses_canonical_local_lm(self):
        calls = []

        def fake(url, **kwargs):
            calls.append((url, kwargs.get("body")))
            if url.endswith("/ai/chat"):
                return 404, {"error": "not found"}
            if url.endswith("/lm/chat"):
                return 200, {"ok": True, "answer": "gemma local ok", "model": "gemma-3-4b-it"}
            raise AssertionError("Unexpected network path")

        with patch.object(worker, "_json_request", side_effect=fake):
            result = worker._ai_chat(BASE, "text.task", {
                "provider": "lmstudio", "text": "hello", "model": "gemma-3-4b-it",
            })
        self.assertEqual(result["text"], "gemma local ok")
        self.assertEqual(result["handledBy"], "lmstudio")
        self.assertFalse(result["fallbackUsed"])
        self.assertEqual(len(calls), 2)
        self.assertEqual(calls[1][1]["model"], "gemma-3-4b-it")
        self.assertEqual([c[0].split("/")[-2:] for c in calls],
                         [["ai", "chat"], ["lm", "chat"]])

    def test_auto_provider_never_routes_to_canonical_gold_lm(self):
        paths = []

        def fake(url, **kwargs):
            paths.append(url)
            return 404, {"error": "not found"}

        with patch.object(worker, "_json_request", side_effect=fake):
            with self.assertRaises(worker.WorkerJobError):
                worker._ai_chat(BASE, "text.task", {"provider": "auto", "text": "hello"})
        self.assertEqual(len(paths), 1)
        self.assertTrue(paths[0].endswith("/ai/chat"))

    def test_missing_gold_lm_does_not_try_cloud(self):
        paths = []

        def fake(url, **kwargs):
            paths.append(url)
            return 404, {"error": "missing"}

        with patch.object(worker, "_json_request", side_effect=fake):
            with self.assertRaises(worker.WorkerJobError):
                worker._ai_chat(BASE, "text.task", {"provider": "lmstudio", "text": "hello"})
        self.assertEqual(len(paths), 2)
        self.assertTrue(paths[-1].endswith("/lm/chat"))

    def test_system_inventory_uses_gold_readonly_agent(self):
        paths = []

        def fake(url, **kwargs):
            paths.append((url, kwargs.get("body")))
            if url.endswith("/agent/jobs"):
                return 404, {"error": "missing"}
            if url.endswith("/agent/run"):
                return 200, {
                    "ok": True, "read_only": True, "files_modified": False,
                    "stdout": "synthetic inventory", "tools_executed": ["system-inventory"],
                }
            raise AssertionError("Unexpected path")

        with patch.object(worker, "_json_request", side_effect=fake):
            result = worker._run_raven_capability(BASE, "system-inventory", "synthetic-job")
        self.assertEqual(result["route"], "raven-gold")
        self.assertTrue(result["readOnly"])
        self.assertEqual(paths[-1][1], {"capability": "system-inventory", "confirm": True})

    def test_other_capability_never_auto_uses_gold_agent(self):
        paths = []

        def fake(url, **kwargs):
            paths.append(url)
            return 404, {"error": "not found"}

        with patch.object(worker, "_json_request", side_effect=fake):
            with self.assertRaises(worker.WorkerJobError):
                worker._run_raven_capability(BASE, "git-status", "synthetic-job")
        self.assertEqual(len(paths), 1)
        self.assertTrue(paths[0].endswith("/agent/jobs"))

    def test_gold_readonly_assertions_fail_closed(self):
        for reply in (
            {"ok": True, "read_only": False, "files_modified": False},
            {"ok": True, "read_only": True, "files_modified": True},
            {"ok": True, "read_only": True},
        ):
            with self.subTest(reply=reply):
                with patch.object(worker, "_json_request",
                    side_effect=[(404, {"error": "missing"}), (200, reply)]):
                    with self.assertRaises(worker.WorkerJobError):
                        worker._run_raven_capability(BASE, "hovedpc-local-status", "synthetic")

    def test_no_gold_retry_when_fabric_route_works(self):
        with patch.object(worker, "_json_request", return_value=(200, {
            "ok": True, "provider": "lmstudio", "text": "ok",
            "attempts": [{"provider": "lmstudio", "result": "PASS"}],
        })) as request:
            result = worker._ai_chat(BASE, "text.task",
                                     {"provider": "lmstudio", "text": "hello"})
        self.assertEqual(request.call_count, 1)
        self.assertEqual(result["route"], "ai-fabric")


if __name__ == "__main__":
    unittest.main()
