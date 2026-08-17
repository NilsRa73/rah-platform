import argparse
import json
from pathlib import Path
from urllib.parse import urlparse

try:
    import requests
except ImportError:
    requests = None


APP_DIR = Path(__file__).resolve().parent
FIXED_PROMPT = (
    "RAH Raven owned-machine acceptance health check. "
    "Reply with a short non-empty acknowledgement and do not include personal data."
)


class AcceptanceError(RuntimeError):
    pass


def _require_requests():
    if requests is None:
        raise AcceptanceError("requests is not installed")


def _loopback_base_url(value):
    parsed = urlparse(str(value).rstrip("/"))
    if parsed.scheme not in {"http", "https"}:
        raise AcceptanceError("LM Studio base_url must use http or https")
    if (parsed.hostname or "").lower() not in {"127.0.0.1", "localhost", "::1"}:
        raise AcceptanceError("LM Studio acceptance is loopback-only")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        raise AcceptanceError("LM Studio base_url may not contain credentials, query, or fragment")
    if parsed.path not in {"", "/", "/v1", "/v1/"}:
        raise AcceptanceError("LM Studio base_url path must be /v1")
    return str(value).rstrip("/")


def _answer_text(data):
    try:
        value = data["choices"][0]["message"]["content"]
    except (KeyError, IndexError, TypeError) as exc:
        raise AcceptanceError("LM Studio returned an unexpected chat response") from exc
    text = str(value or "").strip()
    if not text:
        raise AcceptanceError("LM Studio returned an empty answer")
    return text


def run_lm_acceptance(config, http=None):
    _require_requests()
    http = http or requests
    agents = []
    for agent_id, raw in config.get("agents", {}).items():
        cfg = dict(raw or {})
        if cfg.get("adapter") == "lmstudio" and bool(cfg.get("enabled", True)):
            agents.append((agent_id, cfg))
    if len(agents) < 2:
        raise AcceptanceError("At least two enabled LM Studio Council roles are required")

    results = []
    for agent_id, cfg in agents:
        base_url = _loopback_base_url(cfg.get("base_url", "http://127.0.0.1:1234/v1"))
        model_response = http.get(f"{base_url}/models", timeout=3)
        model_response.raise_for_status()
        payload = model_response.json()
        models = [
            item.get("id")
            for item in payload.get("data", [])
            if isinstance(item, dict) and item.get("id")
        ]
        configured_model = str(cfg.get("model", "auto") or "auto")
        model = configured_model if configured_model != "auto" else (models[0] if models else "")
        if not model:
            raise AcceptanceError(f"No LM Studio model loaded for role {agent_id}")

        chat_payload = {
            "model": model,
            "messages": [
                {
                    "role": "system",
                    "content": str(
                        cfg.get(
                            "system_prompt",
                            "You are a RAH Raven Council agent. Be concise and evidence-aware.",
                        )
                    )[:4000],
                },
                {"role": "user", "content": FIXED_PROMPT},
            ],
            "temperature": 0.0,
            "max_tokens": 64,
        }
        response = http.post(
            f"{base_url}/chat/completions",
            json=chat_payload,
            timeout=min(int(cfg.get("timeout", 60)), 90),
        )
        response.raise_for_status()
        answer = _answer_text(response.json())
        results.append(
            {
                "agentId": agent_id,
                "name": str(cfg.get("name", agent_id))[:120],
                "role": str(cfg.get("role", "Council member"))[:160],
                "baseUrl": base_url,
                "model": model[:200],
                "status": "PASS",
                "responseChars": len(answer),
            }
        )

    return {
        "schemaVersion": 1,
        "product": "RAH Raven Daily Driver",
        "acceptance": "owned-machine-lm-studio",
        "status": "PASS",
        "fixedPrompt": True,
        "answerTextPersisted": False,
        "cloudRequestAllowed": False,
        "stablePromotion": "BLOCKED",
        "roles": results,
    }


def load_config(path=None):
    config_path = Path(path) if path else APP_DIR / "config.json"
    return json.loads(config_path.read_text(encoding="utf-8"))


def write_summary(data, output):
    target = Path(output)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return target


def main(argv=None):
    parser = argparse.ArgumentParser(description="RAH Raven owned-machine LM Studio acceptance")
    parser.add_argument("--config", help="Optional explicit Daily Driver config path")
    parser.add_argument(
        "--output",
        default=str(APP_DIR / "runtime" / "state" / "owned-machine-lm-acceptance.json"),
        help="Privacy-safe summary output path",
    )
    args = parser.parse_args(argv)
    try:
        data = run_lm_acceptance(load_config(args.config))
        target = write_summary(data, args.output)
        print("RAH Raven LM Studio owned-machine acceptance: PASS")
        for role in data["roles"]:
            print(
                f"- {role['agentId']}: PASS; model={role['model']}; "
                f"responseChars={role['responseChars']}"
            )
        print(f"Summary: {target}")
        print("Model answer text persisted: NO")
        print("Stable promotion: BLOCKED")
        return 0
    except Exception as exc:
        print(f"RAH Raven LM Studio owned-machine acceptance: FAIL: {exc}")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
