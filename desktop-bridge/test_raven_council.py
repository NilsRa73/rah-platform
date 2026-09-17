from __future__ import annotations

import os
import unittest
from unittest import mock

os.environ.setdefault("RAH_JOB_REQUIRE_ADMIN", "0")

import raven_council


class RavenCouncilTests(unittest.TestCase):
    def test_choose_prefers_tool_or_instruct_model(self):
        models = [
            {"type": "llm", "modelKey": "plain-3b", "sizeBytes": 2_000_000_000},
            {"type": "llm", "modelKey": "qwen-instruct-7b", "trainedForToolUse": True, "sizeBytes": 5_000_000_000},
        ]
        self.assertEqual(raven_council._choose_local_model(models), "qwen-instruct-7b")

    def test_no_arbitrary_shell_surface(self):
        client = raven_council.app.test_client()
        routes = {rule.rule for rule in raven_council.app.url_map.iter_rules()}
        self.assertIn("/ai/council/status", routes)
        self.assertIn("/ai/council/ask", routes)
        self.assertIn("/ai/council/plan", routes)
        self.assertFalse(any("shell" in route for route in routes))

    def test_plan_routes_machine_to_raven(self):
        fake = [
            raven_council.raven_ai_fabric.ProviderStatus("raven", "actions", True, True, "ready"),
            raven_council.raven_ai_fabric.ProviderStatus("lmstudio", "reasoning", True, True, "ready", model="rah-default"),
            raven_council.raven_ai_fabric.ProviderStatus("anythingllm", "knowledge", True, False, "token missing"),
        ]
        with mock.patch.object(raven_council.raven_ai_fabric, "provider_statuses", return_value=fake):
            client = raven_council.app.test_client()
            response = client.post("/ai/council/plan", json={"task": "test Windows system status"})
            self.assertEqual(response.status_code, 200)
            data = response.get_json()
            providers = [item["provider"] for item in data["route"]]
            self.assertIn("raven", providers)

    def test_ask_rejects_empty_message(self):
        client = raven_council.app.test_client()
        response = client.post("/ai/council/ask", json={"message": ""})
        self.assertEqual(response.status_code, 400)

    def test_ensure_does_not_download_models(self):
        source = open(raven_council.__file__, "r", encoding="utf-8").read()
        self.assertNotIn('"get"', source)
        self.assertNotIn("lms get", source.lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)
