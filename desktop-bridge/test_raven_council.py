from __future__ import annotations

import os
import unittest
from unittest import mock

os.environ.setdefault("RAH_JOB_REQUIRE_ADMIN", "0")

import raven_council


class RavenCouncilTests(unittest.TestCase):
    def setUp(self):
        self.memory_patcher = mock.patch.object(
            raven_council.raven_project_memory,
            "retrieve_context",
            return_value={
                "ok": True,
                "used": False,
                "workspace": "rah-raven",
                "context": "",
                "sources": [],
                "source_count": 0,
                "context_chars": 0,
                "detail": "no relevant project memory",
            },
        )
        self.memory_patcher.start()
        self.addCleanup(self.memory_patcher.stop)

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
        self.assertIn("/ai/council/run", routes)
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
            self.assertIn("council", providers)

    def test_ask_rejects_empty_message(self):
        client = raven_council.app.test_client()
        response = client.post("/ai/council/ask", json={"message": ""})
        self.assertEqual(response.status_code, 400)

    def test_run_rejects_non_allowlisted_adviser(self):
        client = raven_council.app.test_client()
        response = client.post(
            "/ai/council/run",
            json={"message": "test", "providers": ["powershell"]},
        )
        self.assertEqual(response.status_code, 400)
        self.assertIn("non-allowlisted", response.get_json()["error"])

    def test_parallel_multi_provider_synthesizes(self):
        class Ready:
            ready = True

        with (
            mock.patch.object(raven_council.raven_ai_fabric, "_lm_status", return_value=Ready()),
            mock.patch.object(
                raven_council.raven_ai_fabric,
                "_anything_chat",
                return_value={"text": "Anything says use project memory."},
            ),
            mock.patch.object(
                raven_council.raven_ai_fabric,
                "_lm_chat",
                side_effect=[
                    {"text": "LM says run local checks first."},
                    {"text": "Consensus: use project memory and local checks."},
                ],
            ),
        ):
            result = raven_council.run_multi_council(
                "How should Raven inspect the project?",
                providers=["lmstudio", "anythingllm"],
            )

        self.assertTrue(result["ok"])
        self.assertEqual(result["providers"], ["lmstudio", "anythingllm"])
        self.assertEqual(result["synthesizer"], "lmstudio")
        self.assertIn("Consensus", result["consensus"])
        self.assertFalse(result["machine_actions_executed"])
        self.assertEqual(result["machine_actions_route"], "/ai/raven/job")

    def test_single_provider_returns_direct_answer(self):
        with mock.patch.object(
            raven_council.raven_ai_fabric,
            "_lm_chat",
            return_value={"text": "Local answer"},
        ):
            result = raven_council.run_multi_council("test", providers=["lmstudio"])

        self.assertTrue(result["ok"])
        self.assertEqual(result["consensus"], "Local answer")
        self.assertEqual(result["synthesizer"], "lmstudio")

    def test_project_memory_is_injected_into_adviser_system(self):
        memory = {
            "ok": True,
            "used": True,
            "workspace": "rah-raven",
            "context": "PR 333 added Raven multi-AI Council.",
            "sources": [{"title": "RAH Project Snapshot"}],
            "source_count": 1,
            "context_chars": 38,
            "detail": "retrieved",
        }
        with (
            mock.patch.object(
                raven_council.raven_project_memory,
                "retrieve_context",
                return_value=memory,
            ),
            mock.patch.object(
                raven_council.raven_ai_fabric,
                "_lm_chat",
                return_value={"text": "Memory-aware answer"},
            ) as lm_chat,
        ):
            result = raven_council.run_multi_council(
                "What changed in RAH?",
                providers=["lmstudio"],
            )

        self.assertTrue(result["ok"])
        self.assertTrue(result["project_memory"]["used"])
        system_arg = lm_chat.call_args.args[1]
        self.assertIn("RAH PROJECT MEMORY", system_arg)
        self.assertIn("PR 333", system_arg)

    def test_ensure_does_not_download_models(self):
        source = open(raven_council.__file__, "r", encoding="utf-8").read()
        self.assertNotIn('"get"', source)
        self.assertNotIn("lms get", source.lower())


if __name__ == "__main__":
    unittest.main(verbosity=2)
