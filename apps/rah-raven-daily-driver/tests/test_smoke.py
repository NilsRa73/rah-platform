import json
import os
import sys
import tempfile
import unittest
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP))

from chronicle import Chronicle
from devices import DeviceRegistry
from investigator import Investigator
from raven_agents import LMStudioAdapter, OpenAIAdapter
from stable_gate import StableGate


class DailyDriverSmoke(unittest.TestCase):
    def test_config(self):
        data = json.loads((APP / "config.json").read_text(encoding="utf-8"))
        self.assertEqual(data["stage"], "Candidate")
        self.assertIn("lmstudio_builder", data["agents"])
        self.assertFalse(data["agents"]["openai_cloud"]["enabled"])

    def test_chronicle_recovery_and_questions(self):
        with tempfile.TemporaryDirectory() as tmp:
            c = Chronicle(Path(tmp) / "c.db")
            c.decision("Keep stable runtime untouched", "Sidecar integration")
            c.upsert_account("old@example.com", "email", "Example", 0.8, ["demo"])
            self.assertEqual(c.accounts(["Pending"])[0]["identifier"], "old@example.com")
            self.assertTrue(c.ask("Hva bestemte vi forrige uke?"))

    def test_investigator_text(self):
        with tempfile.TemporaryDirectory() as tmp:
            c = Chronicle(Path(tmp) / "c.db")
            inv = Investigator(c)
            result = inv.analyze_text(
                "Email me at test.user73@yahoo.com. username: raven_user73 "
                "profile https://github.com/raven_user73 +47 900 00 000"
            )
            kinds = {e["kind"] for e in result["entities"]}
            self.assertIn("email", kinds)
            self.assertIn("username", kinds)
            self.assertIn("account", kinds)

    def test_facebook_zip_flow_and_identity_chain(self):
        import zipfile
        with tempfile.TemporaryDirectory() as tmp:
            tmp_path = Path(tmp)
            archive = tmp_path / "facebook-export.zip"
            with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as z:
                z.writestr(
                    "messages/inbox/family/message_1.json",
                    json.dumps({
                        "participants": [{"name": "Test Cousin"}],
                        "messages": [{
                            "sender_name": "Test User",
                            "content": "username: raven_user73 email test.user73@yahoo.com https://github.com/raven_user73"
                        }]
                    })
                )
            c = Chronicle(tmp_path / "c.db")
            inv = Investigator(c, {
                "display_name": "Test User",
                "known_emails": ["test.user73@yahoo.com"],
                "known_usernames": ["raven_user73"],
                "known_phones": [],
            })
            result = inv.import_zip(archive)
            kinds = {e["kind"] for e in result["entities"]}
            self.assertIn("artifact", kinds)
            self.assertIn("person", kinds)
            self.assertIn("account", kinds)
            relation_types = {r["relation"] for r in result["relations"]}
            self.assertIn("owns_identifier", relation_types)
            self.assertIn("observed_in_artifact", relation_types)

    def test_frozen_guard(self):
        with tempfile.TemporaryDirectory() as tmp:
            gate = StableGate(Path(tmp) / "gate.json", initial={
                "Frozen Demo": {"version": "1", "stage": "Frozen", "frozen": True}
            })
            with self.assertRaises(PermissionError):
                gate.transition("Frozen Demo", "Frozen", reason="normal")

    def test_local_url_guard(self):
        with self.assertRaises(Exception):
            LMStudioAdapter({"base_url": "https://example.com/v1"})

    def test_openai_key_status(self):
        old = os.environ.pop("RAH_TEST_FAKE_OPENAI_KEY", None)
        try:
            adapter = OpenAIAdapter({"api_key_env": "RAH_TEST_FAKE_OPENAI_KEY", "model": "demo"})
            self.assertFalse(adapter.status()["online"])
        finally:
            if old is not None:
                os.environ["RAH_TEST_FAKE_OPENAI_KEY"] = old

    def test_device_dispatch_guard(self):
        with tempfile.TemporaryDirectory() as tmp:
            devices = DeviceRegistry(Path(tmp) / "devices.json")
            with self.assertRaises(PermissionError):
                devices.dispatch("main-pc", "health_check", approved=False)


if __name__ == "__main__":
    unittest.main()
