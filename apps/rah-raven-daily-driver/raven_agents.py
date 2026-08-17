import os
import socket
from urllib.parse import urlparse

try:
    import requests
except ImportError:
    requests = None


class AgentError(RuntimeError):
    pass


def _require_requests():
    if requests is None:
        raise AgentError("requests is not installed")


def _loopback_url(base_url):
    parsed = urlparse(str(base_url))
    return (
        parsed.scheme in {"http", "https"}
        and (parsed.hostname or "").lower() in {"127.0.0.1", "localhost", "::1"}
    )


def _compact_history(history, limit=10):
    history = list(history or [])[-limit:]
    lines = []
    for item in history:
        who = item.get("from", "?")
        text = str(item.get("msg", ""))
        if len(text) > 1200:
            text = text[:1200] + "…"
        lines.append(f"{who}: {text}")
    return "\n".join(lines)


class BaseAdapter:
    adapter_name = "base"

    def __init__(self, config):
        self.config = dict(config)

    def status(self):
        return {"online": False, "detail": "not implemented"}

    def send(self, prompt, history=None, context=None):
        raise NotImplementedError


class LMStudioAdapter(BaseAdapter):
    adapter_name = "lmstudio"

    def __init__(self, config):
        super().__init__(config)
        self.base_url = str(config.get("base_url", "http://127.0.0.1:1234/v1")).rstrip("/")
        self.model = config.get("model", "auto")
        self.timeout = int(config.get("timeout", 60))
        if not _loopback_url(self.base_url):
            raise AgentError("LM Studio adapter requires a loopback base_url")

    def list_models(self):
        _require_requests()
        response = requests.get(f"{self.base_url}/models", timeout=3)
        response.raise_for_status()
        data = response.json()
        return [
            item.get("id")
            for item in data.get("data", [])
            if isinstance(item, dict) and item.get("id")
        ]

    def resolved_model(self):
        if self.model and self.model != "auto":
            return self.model
        models = self.list_models()
        if not models:
            raise AgentError("LM Studio server is online but no model is loaded")
        return models[0]

    def status(self):
        try:
            models = self.list_models()
            return {
                "online": True,
                "detail": f"{len(models)} model(s)",
                "models": models,
            }
        except Exception as exc:
            return {"online": False, "detail": str(exc), "models": []}

    def send(self, prompt, history=None, context=None):
        _require_requests()
        model = self.resolved_model()
        messages = [
            {
                "role": "system",
                "content": self.config.get(
                    "system_prompt",
                    "You are a RAH Raven Council agent. Be concise and evidence-aware.",
                ),
            }
        ]
        for item in list(history or [])[-10:]:
            role = "assistant" if item.get("from") == self.config.get("name") else "user"
            messages.append({"role": role, "content": str(item.get("msg", ""))[:4000]})
        context_text = ""
        if context:
            context_text = "\n\nLocal RAH context:\n" + str(context)[:6000]
        messages.append({"role": "user", "content": str(prompt) + context_text})
        payload = {
            "model": model,
            "messages": messages,
            "temperature": float(self.config.get("temperature", 0.3)),
            "max_tokens": int(self.config.get("max_tokens", 1200)),
        }
        response = requests.post(
            f"{self.base_url}/chat/completions",
            json=payload,
            timeout=self.timeout,
        )
        response.raise_for_status()
        data = response.json()
        return data["choices"][0]["message"]["content"]


class OpenAIAdapter(BaseAdapter):
    adapter_name = "openai"
    endpoint = "https://api.openai.com/v1/responses"

    def __init__(self, config):
        super().__init__(config)
        self.model = config.get("model", "gpt-5.6")
        self.api_key_env = config.get("api_key_env", "OPENAI_API_KEY")
        self.timeout = int(config.get("timeout", 90))

    def api_key(self):
        return os.environ.get(self.api_key_env, "").strip()

    def status(self):
        if not self.api_key():
            return {"online": False, "detail": f"{self.api_key_env} not set"}
        return {"online": True, "detail": f"key present; model={self.model}"}

    @staticmethod
    def _output_text(data):
        if isinstance(data.get("output_text"), str):
            return data["output_text"]
        texts = []
        for item in data.get("output", []):
            if not isinstance(item, dict):
                continue
            for content in item.get("content", []):
                if isinstance(content, dict):
                    text = content.get("text")
                    if isinstance(text, str):
                        texts.append(text)
        if texts:
            return "\n".join(texts)
        return str(data)

    def send(self, prompt, history=None, context=None):
        _require_requests()
        key = self.api_key()
        if not key:
            raise AgentError(f"{self.api_key_env} is not set")
        history_text = _compact_history(history)
        local_context = str(context or {})[:6000]
        input_text = (
            (f"Recent conversation:\n{history_text}\n\n" if history_text else "")
            + f"Current request:\n{prompt}"
            + (f"\n\nLocal RAH context:\n{local_context}" if local_context else "")
        )
        payload = {
            "model": self.model,
            "instructions": self.config.get(
                "system_prompt",
                "You are a RAH Raven Council cloud agent. Be concise, practical, and evidence-aware.",
            ),
            "input": input_text,
            "store": False,
        }
        response = requests.post(
            self.endpoint,
            headers={
                "Authorization": f"Bearer {key}",
                "Content-Type": "application/json",
            },
            json=payload,
            timeout=self.timeout,
        )
        response.raise_for_status()
        return self._output_text(response.json())


class SimulatedAdapter(BaseAdapter):
    adapter_name = "simulated"

    def status(self):
        return {"online": True, "detail": "simulated"}

    def send(self, prompt, history=None, context=None):
        return (
            f"[SIMULATED {self.config.get('name', 'Raven')}]\n"
            f"Role: {self.config.get('role', 'Council member')}\n"
            f"Request: {prompt}\n"
            f"Context modules: {', '.join(sorted((context or {}).keys())) or 'none'}"
        )


def build_adapter(config):
    adapter = str(config.get("adapter", "simulated")).lower()
    if adapter == "lmstudio":
        return LMStudioAdapter(config)
    if adapter == "openai":
        return OpenAIAdapter(config)
    return SimulatedAdapter(config)


class RavenAgent:
    def __init__(self, agent_id, config):
        self.agent_id = agent_id
        self.config = dict(config)
        self.name = self.config.get("name", agent_id)
        self.role = self.config.get("role", "Council member")
        self.agent_type = self.config.get("type", "local")
        self.enabled = bool(self.config.get("enabled", True))
        self.adapter = build_adapter(self.config)

    def status(self):
        if not self.enabled:
            return {"online": False, "detail": "disabled"}
        return self.adapter.status()

    def send(self, prompt, history=None, context=None):
        if not self.enabled:
            raise AgentError(f"{self.name} is disabled")
        return self.adapter.send(prompt, history=history, context=context)


def build_agents(config):
    result = []
    for agent_id, agent_config in config.get("agents", {}).items():
        result.append(RavenAgent(agent_id, agent_config))
    return result
