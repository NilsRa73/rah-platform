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
        raven_ai_fabric._LM_FAILED_UNTIL.clear()

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

    def test_lm_chat_falls_back_after_model_load_failure(self) -> None:
        bad_payload = {
            "error": {
                "message": 'Failed to load model "bad-model". Engine exited before becoming healthy.'
            }
        }
        good_payload = {
            "choices": [{"message": {"content": "fallback ok"}}]
        }
        with tempfile.TemporaryDirectory() as tmp:
            model_file = Path(tmp) / "lmstudio-model.txt"
            with mock.patch.object(raven_ai_fabric, "LM_MODEL_FILE", model_file), \
                 mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["bad-model", "good-model"]), \
                 mock.patch.object(raven_ai_fabric, "_lm_loaded_models", return_value=["bad-model"]), \
                 mock.patch.object(raven_ai_fabric, "_lm_preferred_model", return_value="bad-model"), \
                 mock.patch.object(
                     raven_ai_fabric,
                     "_json_request",
                     side_effect=[(400, bad_payload), (200, good_payload)],
                 ) as request_call:
                result = raven_ai_fabric._lm_chat("hello")
        self.assertEqual(result["provider"], "lmstudio")
        self.assertEqual(result["model"], "good-model")
        self.assertEqual(result["text"], "fallback ok")
        self.assertEqual(request_call.call_count, 2)
        self.assertTrue(raven_ai_fabric._lm_is_quarantined("bad-model"))

    def test_lm_chat_explicit_model_does_not_switch_model(self) -> None:
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["bad-model", "good-model"]), \
             mock.patch.object(raven_ai_fabric, "_json_request", return_value=(400, {"error": "load failed"})) as request_call:
            with self.assertRaises(RuntimeError):
                raven_ai_fabric._lm_chat("hello", model="bad-model")
        self.assertEqual(request_call.call_count, 1)

    def test_auto_chat_falls_back_from_lmstudio_to_anythingllm(self) -> None:
        anything = raven_ai_fabric.ProviderStatus(
            "anythingllm", "knowledge", True, True, "authenticated", "http://127.0.0.1:3001"
        )
        lm = raven_ai_fabric.ProviderStatus(
            "lmstudio", "local", True, True, "loaded and ready", "http://127.0.0.1:1234", "bad-model"
        )
        cloud = raven_ai_fabric.ProviderStatus("openai-compatible", "cloud", False, False, "off")
        with mock.patch.object(raven_ai_fabric, "_anything_status", return_value=anything), \
             mock.patch.object(raven_ai_fabric, "_lm_status", return_value=lm), \
             mock.patch.object(raven_ai_fabric, "_openai_status", return_value=cloud), \
             mock.patch.object(raven_ai_fabric, "_lm_chat", side_effect=RuntimeError("model crashed")), \
             mock.patch.object(raven_ai_fabric, "_anything_chat", return_value={"provider": "anythingllm", "text": "fallback ok"}) as anything_call:
            result = raven_ai_fabric._auto_chat("Skriv en kort testsetning", "", "", "")
        self.assertEqual(result["provider"], "anythingllm")
        anything_call.assert_called_once()

    def test_lm_status_quarantines_failed_loaded_model(self) -> None:
        raven_ai_fabric._lm_quarantine("bad-model")
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["bad-model"]), \
             mock.patch.object(raven_ai_fabric, "_lm_loaded_models", return_value=["bad-model"]), \
             mock.patch.object(raven_ai_fabric, "_lm_preferred_model", return_value="bad-model"):
            status = raven_ai_fabric._lm_status()
        self.assertTrue(status.online)
        self.assertFalse(status.ready)
        self.assertIn("quarantined", status.detail)

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


    def test_lm_status_requires_loaded_instance(self) -> None:
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["model-a"]), \
             mock.patch.object(raven_ai_fabric, "_lm_loaded_models", return_value=[]):
            status = raven_ai_fabric._lm_status(start_if_needed=False)
        self.assertTrue(status.online)
        self.assertFalse(status.ready)
        self.assertIn("no loaded LLM instance", status.detail)

    def test_lm_status_prefers_pinned_loaded_model(self) -> None:
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["model-a", "model-b"]), \
             mock.patch.object(raven_ai_fabric, "_lm_loaded_models", return_value=["model-b"]), \
             mock.patch.object(raven_ai_fabric, "_lm_preferred_model", return_value="model-b"):
            status = raven_ai_fabric._lm_status(start_if_needed=False)
        self.assertTrue(status.ready)
        self.assertEqual(status.model, "model-b")

    def test_lm_chat_prefers_pinned_model(self) -> None:
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["model-a", "model-b"]), \
             mock.patch.object(raven_ai_fabric, "_lm_preferred_model", return_value="model-b"), \
             mock.patch.object(
                 raven_ai_fabric,
                 "_json_request",
                 return_value=(200, {"choices": [{"message": {"content": "OK"}}]}),
             ) as request_call:
            result = raven_ai_fabric._lm_chat("test")
        self.assertEqual(result["model"], "model-b")
        self.assertEqual(request_call.call_args.kwargs["body"]["model"], "model-b")


    def test_lm_preferred_model_reads_state_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            model_file = Path(tmp) / "lmstudio-model.txt"
            model_file.write_text("model-b", encoding="utf-8")
            with mock.patch.dict(
                raven_ai_fabric.os.environ,
                {"RAH_LMSTUDIO_MODEL": ""},
                clear=False,
            ), mock.patch.object(raven_ai_fabric, "LM_MODEL_FILE", model_file):
                self.assertEqual(raven_ai_fabric._lm_preferred_model(), "model-b")


if __name__ == "__main__":
    unittest.main()
