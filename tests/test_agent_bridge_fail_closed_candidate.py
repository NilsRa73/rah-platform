"""Pure temporary-directory regression tests for the Agent Bridge candidate.

Never touches C:\\RAH, real tokens, Windows tasks, or production ports.
"""
from __future__ import annotations

from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import rah_agent_bridge as bridge


class FailClosedTokenTests(unittest.TestCase):
    def test_valid_existing_token_preserved(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "token.txt"
            original = "synthetic-test-token-not-a-secret-12345\n"
            p.write_text(original, encoding="utf-8")
            self.assertEqual(bridge.read_existing_token(p), original.strip())
            self.assertEqual(p.read_text(encoding="utf-8"), original)

    def test_missing_token_never_created(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "token.txt"
            with patch.object(Path, "write_text", side_effect=AssertionError("write forbidden")):
                with self.assertRaisesRegex(RuntimeError, "startup blocked"):
                    bridge.read_existing_token(p)
            self.assertFalse(p.exists())

    def test_invalid_token_not_replaced(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "token.txt"
            p.write_text("short", encoding="utf-8")
            with patch.object(Path, "write_text", side_effect=AssertionError("write forbidden")):
                with self.assertRaisesRegex(RuntimeError, "invalid"):
                    bridge.read_existing_token(p)
            self.assertEqual(p.read_text(encoding="utf-8"), "short")

    def test_denied_access_propagates_without_token_content(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "token.txt"
            with patch.object(Path, "read_text", side_effect=PermissionError("synthetic denied")):
                with patch.object(Path, "write_text", side_effect=AssertionError("write forbidden")):
                    with self.assertRaisesRegex(RuntimeError, "startup blocked"):
                        bridge.read_existing_token(p)

    def test_production_main_blocks_before_bus_creation(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d) / "bridge"
            bus = Path(d) / "bus"
            args = ["rah_agent_bridge.py", "--root", str(root), "--bus-root", str(bus), "--port", "18791"]
            with patch.object(sys, "argv", args):
                with self.assertRaisesRegex(RuntimeError, "startup blocked"):
                    bridge.main()
            self.assertFalse(root.exists())
            self.assertFalse(bus.exists())


class ClaimOwnershipTests(unittest.TestCase):
    def test_wrong_worker_cannot_finish(self):
        with tempfile.TemporaryDirectory() as d:
            bus = bridge.JobBus(Path(d) / "bus")
            q = bus.enqueue("text.task", "synthetic-ci", {"text": "harmless"})
            claimed = bus.claim("worker-A")
            self.assertEqual(q["id"], claimed["id"])
            with self.assertRaisesRegex(ValueError, "does not own"):
                bus.finish(q["id"], "worker-B", True, {"answer": "forged"})
            self.assertEqual(bus.counts()["running"], 1)
            self.assertEqual(bus.counts()["completed"], 0)
            real = bus.finish(q["id"], "worker-A", True, {"answer": "ok"})
            self.assertEqual(real["status"], "completed")
            self.assertEqual(bus.counts()["completed"], 1)


if __name__ == "__main__":
    unittest.main()
