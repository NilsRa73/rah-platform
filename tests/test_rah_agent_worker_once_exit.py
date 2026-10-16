"""RAH Agent Worker --once exit-status regression tests (offline, no services)."""
import contextlib
from pathlib import Path
import sys
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
import rah_agent_worker as worker


class OnceExitContractTests(unittest.TestCase):
    def setUp(self):
        self.stack = contextlib.ExitStack()
        self.addCleanup(self.stack.close)
        self.stack.enter_context(mock.patch.object(sys, "argv", [
            "rah_agent_worker.py", "--once", "--state-file", "unused.json"
        ]))
        self.stack.enter_context(mock.patch.object(worker, "_load_token", return_value="fake-test-token"))
        self.claim = self.stack.enter_context(mock.patch.object(worker, "_claim"))
        self.handle = self.stack.enter_context(mock.patch.object(worker, "_handle_job"))
        self.complete = self.stack.enter_context(mock.patch.object(worker, "_complete"))
        self.fail = self.stack.enter_context(mock.patch.object(worker, "_fail"))
        self.state = self.stack.enter_context(mock.patch.object(worker, "_write_state"))
        self.job = {"id": "J-synthetic", "kind": "text.task", "payload": {"text": "synthetic"}}
        self.claim.return_value = self.job
        self.handle.return_value = {"text": "synthetic output"}

    def test_one_shot_success_exits_zero(self):
        self.assertEqual(worker.main(), 0)
        self.complete.assert_called_once()
        self.fail.assert_not_called()
        self.assertEqual(self.state.call_args.args[1]["status"], "completed")

    def test_one_shot_job_failure_exits_nonzero(self):
        self.handle.side_effect = RuntimeError("synthetic route failure")
        self.assertEqual(worker.main(), 4)
        self.complete.assert_not_called()
        self.fail.assert_called_once()
        self.assertEqual(self.state.call_args.args[1]["status"], "failed")

    def test_one_shot_empty_queue_exits_zero(self):
        self.claim.return_value = None
        self.assertEqual(worker.main(), 0)
        self.complete.assert_not_called()
        self.fail.assert_not_called()

    def test_one_shot_bridge_error_exits_three(self):
        self.claim.side_effect = RuntimeError("synthetic transport failure")
        self.assertEqual(worker.main(), 3)
        self.complete.assert_not_called()
        self.assertEqual(self.state.call_args.args[1]["status"], "bridge-error")


if __name__ == "__main__":
    unittest.main()
