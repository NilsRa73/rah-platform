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
        self._tmp = tempfile.TemporaryDirectory()
        self._state_dir = Path(self._tmp.name)
        self._patchers = [
            mock.patch.object(raven_ai_fabric, "STATE_DIR", self._state_dir),
            mock.patch.object(raven_ai_fabric, "STATE_FILE", self._state_dir / "providers.json"),
            mock.patch.object(raven_ai_fabric, "LM_MODEL_FILE", self._state_dir / "lmstudio-model.txt"),
            mock.patch.object(raven_ai_fabric, "MODEL_HEALTH_FILE", self._state_dir / "model-health.json"),
        ]
        for patcher in self._patchers:
            patcher.start()

    def tearDown(self) -> None:
        for patcher in reversed(self._patchers):
            patcher.stop()
        self._tmp.cleanup()

    def test_routes_registered(self) -> None:
        routes = {rule.rule for rule in app.url_map.iter_rules()}
        self.assertIn("/ai/health", routes)
        self.assertIn("/ai/providers", routes)
        self.assertIn("/ai/model-health", routes)
        self.assertIn("/ai/self-test", routes)
        self.assertIn("/ai/chat", routes)
        self.assertIn("/ai/raven/job", routes)
        self.assertIn("/ai/plan", routes)

    def test_ai_health_excludes_raven_executor_from_ready_providers(self) -> None:
        providers = [
            raven_ai_fabric.ProviderStatus("raven", "jobs", True, True, "ready"),
            raven_ai_fabric.ProviderStatus("lmstudio", "local", True, False, "not ready"),
            raven_ai_fabric.ProviderStatus("anythingllm", "knowledge", False, False, "offline"),
            raven_ai_fabric.ProviderStatus("openai-compatible", "cloud", False, False, "off"),
        ]
        with mock.patch.object(raven_ai_fabric, "provider_statuses", return_value=providers):
            response = self.client.get("/ai/health")
        self.assertEqual(response.status_code, 503)
        payload = response.get_json()
        self.assertFalse(payload.get("ok"))
        self.assertEqual(payload.get("ready_providers"), [])

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
        self.assertEqual(result["attemptCount"], 2)
        self.assertTrue(result["fallbackUsed"])
        self.assertEqual(result["attempts"][0]["model"], "bad-model")
        self.assertEqual(result["attempts"][0]["result"], "FAILED")
        self.assertTrue(result["attempts"][0]["quarantined"])
        self.assertEqual(result["attempts"][1]["model"], "good-model")
        self.assertEqual(result["attempts"][1]["result"], "PASS")
        self.assertTrue(raven_ai_fabric._lm_is_quarantined("bad-model"))
        self.assertEqual(raven_ai_fabric._model_effective_state("good-model"), "HEALTHY")

    def test_lm_chat_empty_200_quarantines_and_falls_back(self) -> None:
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["empty-model", "good-model"]), \
             mock.patch.object(raven_ai_fabric, "_lm_loaded_models", return_value=["empty-model"]), \
             mock.patch.object(raven_ai_fabric, "_lm_preferred_model", return_value="empty-model"), \
             mock.patch.object(
                 raven_ai_fabric,
                 "_json_request",
                 side_effect=[
                     (200, {"choices": [{"message": {"content": ""}}]}),
                     (200, {"choices": [{"message": {"content": "works"}}]}),
                 ],
             ):
            result = raven_ai_fabric._lm_chat("hello")
        self.assertEqual(result["model"], "good-model")
        self.assertEqual(result["attemptCount"], 2)
        self.assertTrue(result["fallbackUsed"])
        self.assertEqual(result["attempts"][0]["result"], "FAILED")
        self.assertIn("uten gyldig tekstsvar", result["attempts"][0]["reason"])
        self.assertTrue(raven_ai_fabric._lm_is_quarantined("empty-model"))

    def test_lm_chat_exception_quarantines_and_falls_back(self) -> None:
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["crash-model", "good-model"]), \
             mock.patch.object(raven_ai_fabric, "_lm_loaded_models", return_value=["crash-model"]), \
             mock.patch.object(raven_ai_fabric, "_lm_preferred_model", return_value="crash-model"), \
             mock.patch.object(
                 raven_ai_fabric,
                 "_json_request",
                 side_effect=[
                     TimeoutError("engine timed out"),
                     (200, {"choices": [{"message": {"content": "works"}}]}),
                 ],
             ):
            result = raven_ai_fabric._lm_chat("hello")
        self.assertEqual(result["model"], "good-model")
        self.assertEqual(result["attemptCount"], 2)
        self.assertEqual(result["attempts"][0]["result"], "FAILED")
        self.assertIn("TimeoutError", result["attempts"][0]["reason"])
        self.assertTrue(raven_ai_fabric._lm_is_quarantined("crash-model"))

    def test_ai_self_test_selects_working_local_model(self) -> None:
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["bad", "good"]), \
             mock.patch.object(raven_ai_fabric, "_lm_is_quarantined", return_value=False), \
             mock.patch.object(
                 raven_ai_fabric,
                 "_lm_chat",
                 side_effect=[
                     raven_ai_fabric.ProviderRouteError(
                         "bad",
                         [{"provider": "lmstudio", "model": "bad", "result": "FAILED", "reason": "crash", "quarantined": True}],
                     ),
                     {
                         "provider": "lmstudio",
                         "model": "good",
                         "text": "RAH SELFTEST OK",
                         "attempts": [{"provider": "lmstudio", "model": "good", "result": "PASS", "durationMs": 5}],
                     },
                 ],
             ):
            response = self.client.post("/ai/self-test")
        self.assertEqual(response.status_code, 200)
        payload = response.get_json()
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["winner"]["provider"], "lmstudio")
        self.assertEqual(payload["winner"]["model"], "good")

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
             mock.patch.object(
                 raven_ai_fabric,
                 "_lm_chat",
                 side_effect=raven_ai_fabric.ProviderRouteError(
                     "model crashed",
                     [{"provider": "lmstudio", "model": "bad-model", "result": "FAILED", "quarantined": True}],
                 ),
             ), \
             mock.patch.object(
                 raven_ai_fabric,
                 "_anything_chat",
                 return_value={
                     "provider": "anythingllm",
                     "text": "fallback ok",
                     "attempts": [{"provider": "anythingllm", "result": "PASS", "quarantined": False}],
                 },
             ) as anything_call:
            result = raven_ai_fabric._auto_chat("Skriv en kort testsetning", "", "", "")
        self.assertEqual(result["provider"], "anythingllm")
        self.assertEqual(result["attemptCount"], 2)
        self.assertTrue(result["fallbackUsed"])
        self.assertEqual(result["attempts"][0]["provider"], "lmstudio")
        self.assertEqual(result["attempts"][1]["provider"], "anythingllm")
        anything_call.assert_called_once()

    def test_lm_status_quarantines_failed_loaded_model(self) -> None:
        raven_ai_fabric._lm_record_failure("bad-model", "engine crash", 100)
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
             mock.patch.object(
                 raven_ai_fabric,
                 "_anything_chat",
                 return_value={
                     "provider": "anythingllm",
                     "text": "ok",
                     "attempts": [{"provider": "anythingllm", "result": "PASS", "quarantined": False}],
                 },
             ) as call:
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
             mock.patch.object(
                 raven_ai_fabric,
                 "_lm_chat",
                 return_value={
                     "provider": "lmstudio",
                     "model": "model-x",
                     "text": "ok",
                     "attempts": [{"provider": "lmstudio", "model": "model-x", "result": "PASS", "quarantined": False}],
                 },
             ) as call:
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


    def test_lm_status_allows_unloaded_fallback_candidate(self) -> None:
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["model-a"]), \
             mock.patch.object(raven_ai_fabric, "_lm_loaded_models", return_value=[]):
            status = raven_ai_fabric._lm_status(start_if_needed=False)
        self.assertTrue(status.online)
        self.assertTrue(status.ready)
        self.assertEqual(status.model, "model-a")
        self.assertIn("load on demand", status.detail)

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


    def test_model_health_progressive_quarantine_and_retest_gate(self) -> None:
        first = raven_ai_fabric._lm_record_failure("model-a", "fail-1", 10)
        self.assertEqual(first["state"], "QUARANTINED")
        self.assertEqual(first["failCount"], 1)
        self.assertIsNotNone(first["retryAfter"])

        second = raven_ai_fabric._lm_record_failure("model-a", "fail-2", 20)
        self.assertEqual(second["state"], "QUARANTINED")
        self.assertEqual(second["failCount"], 2)

        third = raven_ai_fabric._lm_record_failure("model-a", "fail-3", 30)
        self.assertEqual(third["state"], "QUARANTINED")
        self.assertEqual(third["failCount"], 3)

        fourth = raven_ai_fabric._lm_record_failure("model-a", "fail-4", 40)
        self.assertEqual(fourth["state"], "RETEST_REQUIRED")
        self.assertEqual(fourth["failCount"], 4)
        self.assertIsNone(fourth["retryAfter"])
        self.assertTrue(raven_ai_fabric.MODEL_HEALTH_FILE.is_file())

    def test_model_success_resets_failure_counter(self) -> None:
        raven_ai_fabric._lm_record_failure("model-a", "bad", 10)
        healthy = raven_ai_fabric._lm_record_success("model-a", 44)
        self.assertEqual(healthy["state"], "HEALTHY")
        self.assertEqual(healthy["failCount"], 0)
        self.assertEqual(healthy["latencyMs"], 44)
        self.assertFalse(raven_ai_fabric._lm_is_quarantined("model-a"))

    def test_healthy_model_is_prioritized_over_unknown_preferred_model(self) -> None:
        raven_ai_fabric._lm_record_success("known-good", 50)
        with mock.patch.object(raven_ai_fabric, "_lm_models", return_value=["unknown-pinned", "known-good"]), \
             mock.patch.object(raven_ai_fabric, "_lm_loaded_models", return_value=["unknown-pinned", "known-good"]), \
             mock.patch.object(raven_ai_fabric, "_lm_preferred_model", return_value="unknown-pinned"):
            candidates = raven_ai_fabric._lm_model_candidates()
        self.assertEqual(candidates[0], "known-good")

    def test_model_health_endpoint_reports_effective_state(self) -> None:
        raven_ai_fabric._lm_record_success("known-good", 42)
        response = self.client.get("/ai/model-health")
        self.assertEqual(response.status_code, 200)
        payload = response.get_json()
        self.assertTrue(payload["ok"])
        self.assertEqual(payload["fabricVersion"], "1.3.1")
        self.assertEqual(payload["models"]["known-good"]["effectiveState"], "HEALTHY")

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
