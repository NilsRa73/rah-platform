from __future__ import annotations

import unittest
import tempfile
from pathlib import Path
from unittest import mock

import raven_bridge_agent  # noqa: F401 - registers Jobs + AI Fabric routes
import raven_ai_fabric
from server_v17 import app


class RavenAIFabricTests(unittest.TestCase):
    def setUp(self) -> None:
        app.config.update(TESTING=True)
        self.client = app.test_client()

    def test_routes_registered(self) -> None:
        routes = {rule.rule for rule in app.url_map.iter_rules()}
        self.assertIn("/ai/health", routes)
        self.assertIn("/ai/providers", routes)
        self.assertIn("/ai/chat", routes)
        self.assertIn("/ai/raven/job", routes)
        self.assertIn("/ai/plan", routes)

    def test_canonical_health_reports_ai_fabric(self) -> None:
        response = self.client.get("/health")
        self.assertEqual(response.status_code, 200)
        payload = response.get_json()
        self.assertTrue(payload.get("ai_fabric"))
        self.assertEqual(payload.get("ai_fabric_version"), raven_ai_fabric.AI_FABRIC_VERSION)

    def test_raven_job_rejects_arbitrary_capability(self) -> None:
        response = self.client.post("/ai/raven/job", json={"capability": "powershell -enc evil"})
        self.assertEqual(response.status_code, 403)
        payload = response.get_json()
        self.assertFalse(payload.get("ok"))

    def test_lm_chat_requires_model(self) -> None:
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=[]):
            with self.assertRaises(RuntimeError):
                raven_ai_fabric._lm_chat("hello")

    def test_auto_chat_prefers_anything_for_project_context(self) -> None:
        anything = raven_ai_fabric.ProviderStatus(
            "anythingllm", "knowledge", True, True, "authenticated", "http://127.0.0.1:3001"
        )
        lm = raven_ai_fabric.ProviderStatus(
            "lmstudio", "local", True, True, "online", "http://127.0.0.1:1234", "model-x"
        )
        cloud = raven_ai_fabric.ProviderStatus("openai-compatible", "cloud", False, False, "off")
        with mock.patch.object(raven_ai_fabric, "_anything_status", return_value=anything), \
             mock.patch.object(raven_ai_fabric, "_lm_status", return_value=lm), \
             mock.patch.object(raven_ai_fabric, "_openai_status", return_value=cloud), \
             mock.patch.object(raven_ai_fabric, "_anything_chat", return_value={"provider": "anythingllm", "text": "ok"}) as call:
            result = raven_ai_fabric._auto_chat("Hva er status i RAH prosjektet?", "", "", "")
        self.assertEqual(result["provider"], "anythingllm")
        call.assert_called_once()

    def test_auto_chat_uses_lmstudio_for_general_prompt(self) -> None:
        anything = raven_ai_fabric.ProviderStatus(
            "anythingllm", "knowledge", True, True, "authenticated", "http://127.0.0.1:3001"
        )
        lm = raven_ai_fabric.ProviderStatus(
            "lmstudio", "local", True, True, "online", "http://127.0.0.1:1234", "model-x"
        )
        cloud = raven_ai_fabric.ProviderStatus("openai-compatible", "cloud", False, False, "off")
        with mock.patch.object(raven_ai_fabric, "_anything_status", return_value=anything), \
             mock.patch.object(raven_ai_fabric, "_lm_status", return_value=lm), \
             mock.patch.object(raven_ai_fabric, "_openai_status", return_value=cloud), \
             mock.patch.object(raven_ai_fabric, "_lm_chat", return_value={"provider": "lmstudio", "text": "ok"}) as call:
            result = raven_ai_fabric._auto_chat("Skriv en kort testsetning", "", "", "")
        self.assertEqual(result["provider"], "lmstudio")
        call.assert_called_once()


    def test_anything_key_loads_from_project_memory_secret_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            token_file = Path(tmp) / "anything-token.txt"
            token_file.write_text("secret-token-value", encoding="utf-8")
            with mock.patch.dict(
                raven_ai_fabric.os.environ,
                {"RAH_ANYTHINGLLM_API_KEY": "", "ANYTHINGLLM_API_KEY": ""},
                clear=False,
            ), mock.patch.object(
                raven_ai_fabric,
                "_project_memory_config",
                return_value={"token_file": str(token_file)},
            ):
                key = raven_ai_fabric._anything_key()

        self.assertEqual(key, "secret-token-value")

    def test_anything_workspace_and_base_use_project_memory_config(self) -> None:
        cfg = {
            "workspace": "rah-raven",
            "base_url": "http://127.0.0.1:3001",
        }
        with mock.patch.dict(
            raven_ai_fabric.os.environ,
            {"RAH_ANYTHINGLLM_WORKSPACE": "", "RAH_ANYTHINGLLM_BASE_URL": ""},
            clear=False,
        ), mock.patch.object(
            raven_ai_fabric,
            "_project_memory_config",
            return_value=cfg,
        ):
            self.assertEqual(raven_ai_fabric._anything_workspace(), "rah-raven")
            self.assertEqual(raven_ai_fabric._anything_base(), "http://127.0.0.1:3001")

    def test_memory_routes_registered(self) -> None:
        routes = {rule.rule for rule in app.url_map.iter_rules()}
        self.assertIn("/ai/memory/status", routes)
        self.assertIn("/ai/memory/config", routes)
        self.assertIn("/ai/memory/context", routes)


if __name__ == "__main__":
    unittest.main()
