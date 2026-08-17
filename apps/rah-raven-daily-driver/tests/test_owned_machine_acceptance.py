import json
import sys
import tempfile
import unittest
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP))

import owned_machine_acceptance as oma


class FakeResponse:
    def __init__(self, data):
        self._data = data

    def raise_for_status(self):
        return None

    def json(self):
        return self._data


class FakeHttp:
    def __init__(self):
        self.posts = []
        self.gets = []

    def get(self, url, timeout=None):
        self.gets.append((url, timeout))
        return FakeResponse({"data": [{"id": "local-test-model"}]})

    def post(self, url, json=None, timeout=None):
        self.posts.append((url, json, timeout))
        return FakeResponse({"choices": [{"message": {"content": "RAH-OK private text must not persist"}}]})


class OwnedMachineAcceptanceTests(unittest.TestCase):
    def config(self):
        return {
            "agents": {
                "technical": {
                    "name": "Technical",
                    "role": "Technical Council",
                    "adapter": "lmstudio",
                    "enabled": True,
                    "base_url": "http://127.0.0.1:1234/v1",
                    "model": "auto",
                },
                "critic": {
                    "name": "Critic",
                    "role": "Critical Council",
                    "adapter": "lmstudio",
                    "enabled": True,
                    "base_url": "http://localhost:1234/v1",
                    "model": "auto",
                },
                "cloud": {
                    "name": "Cloud",
                    "adapter": "openai",
                    "enabled": False,
                },
            }
        }

    def test_two_local_roles_answer_without_persisting_answer_text(self):
        fake = FakeHttp()
        data = oma.run_lm_acceptance(self.config(), http=fake)
        self.assertEqual(data["status"], "PASS")
        self.assertEqual(data["stablePromotion"], "BLOCKED")
        self.assertFalse(data["answerTextPersisted"])
        self.assertFalse(data["cloudRequestAllowed"])
        self.assertEqual(len(data["roles"]), 2)
        self.assertEqual(len(fake.posts), 2)
        serialized = json.dumps(data)
        self.assertNotIn("private text", serialized)
        for url, payload, _timeout in fake.posts:
            self.assertTrue(url.startswith(("http://127.0.0.1:", "http://localhost:")))
            self.assertEqual(payload["messages"][-1]["content"], oma.FIXED_PROMPT)
            self.assertEqual(payload["temperature"], 0.0)
            self.assertEqual(payload["max_tokens"], 64)

    def test_external_lm_studio_url_fails_closed_before_http(self):
        config = self.config()
        config["agents"]["technical"]["base_url"] = "https://example.com/v1"
        fake = FakeHttp()
        with self.assertRaises(oma.AcceptanceError):
            oma.run_lm_acceptance(config, http=fake)
        self.assertEqual(fake.gets, [])
        self.assertEqual(fake.posts, [])

    def test_credentials_query_fragment_and_non_v1_path_rejected(self):
        bad = [
            "http://user:pass@127.0.0.1:1234/v1",
            "http://127.0.0.1:1234/v1?x=1",
            "http://127.0.0.1:1234/v1#x",
            "http://127.0.0.1:1234/admin",
        ]
        for value in bad:
            with self.subTest(value=value):
                with self.assertRaises(oma.AcceptanceError):
                    oma._loopback_base_url(value)

    def test_requires_two_enabled_lm_roles(self):
        config = self.config()
        config["agents"]["critic"]["enabled"] = False
        with self.assertRaises(oma.AcceptanceError):
            oma.run_lm_acceptance(config, http=FakeHttp())

    def test_written_summary_contains_no_answer_body(self):
        data = oma.run_lm_acceptance(self.config(), http=FakeHttp())
        with tempfile.TemporaryDirectory() as tmp:
            out = oma.write_summary(data, Path(tmp) / "acceptance.json")
            text = out.read_text(encoding="utf-8")
            self.assertIn('"stablePromotion": "BLOCKED"', text)
            self.assertIn('"answerTextPersisted": false', text)
            self.assertNotIn("RAH-OK private text", text)


if __name__ == "__main__":
    unittest.main()
