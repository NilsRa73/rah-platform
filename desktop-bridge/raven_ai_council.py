from __future__ import annotations

"""RAH Raven AI Council v1.

Collects independent text advice from configured AI providers, then synthesizes
one recommendation. Machine actions are never executed here; they remain behind
Raven's audited job allowlist.
"""

import concurrent.futures
from dataclasses import dataclass
from typing import Any

from flask import jsonify, request

from server_v17 import app
import raven_ai_fabric

COUNCIL_VERSION = "1.0.0"
ALLOWED_PROVIDERS = {"lmstudio", "anythingllm", "openai-compatible"}
DEFAULT_SYSTEM = (
    "You are one adviser in RAH Raven AI Council. Give a concise, concrete answer. "
    "State uncertainties. Do not claim to have executed machine actions."
)


@dataclass(frozen=True)
class CouncilReply:
    provider: str
    ok: bool
    text: str
    error: str = ""

    def as_dict(self) -> dict[str, Any]:
        return {"provider": self.provider, "ok": self.ok, "text": self.text, "error": self.error}


def _call_provider(provider: str, message: str, system: str, workspace: str, model: str) -> CouncilReply:
    try:
        if provider == "lmstudio":
            result = raven_ai_fabric._lm_chat(message, system, model)
        elif provider == "anythingllm":
            result = raven_ai_fabric._anything_chat(message, workspace)
        elif provider == "openai-compatible":
            result = raven_ai_fabric._openai_chat(message, system, model)
        else:
            raise ValueError("provider not allowlisted")
        return CouncilReply(provider, True, str(result.get("text") or "").strip())
    except Exception as exc:
        return CouncilReply(provider, False, "", str(exc)[:500])


def _ready_providers() -> list[str]:
    ready: list[str] = []
    for status in raven_ai_fabric.provider_statuses(start_if_needed=True):
        if status.id in ALLOWED_PROVIDERS and status.ready:
            ready.append(status.id)
    return ready


def run_council(
    message: str,
    *,
    system: str = "",
    workspace: str = "",
    model: str = "",
    providers: list[str] | None = None,
) -> dict[str, Any]:
    message = (message or "").strip()
    if not message:
        raise ValueError("message is required")

    selected = providers or _ready_providers()
    selected = [p for p in selected if p in ALLOWED_PROVIDERS]
    selected = list(dict.fromkeys(selected))[:3]
    if not selected:
        raise RuntimeError("No ready AI Council providers are available")

    system_prompt = (system or DEFAULT_SYSTEM).strip()
    replies: list[CouncilReply] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(selected)) as pool:
        futures = {
            pool.submit(_call_provider, p, message, system_prompt, workspace, model): p
            for p in selected
        }
        for future in concurrent.futures.as_completed(futures):
            replies.append(future.result())

    replies.sort(key=lambda item: selected.index(item.provider))
    successful = [r for r in replies if r.ok and r.text]
    if not successful:
        return {
            "ok": False,
            "version": COUNCIL_VERSION,
            "providers": selected,
            "replies": [r.as_dict() for r in replies],
            "consensus": "",
            "synthesizer": "none",
            "machine_actions_executed": False,
        }

    if len(successful) == 1:
        consensus = successful[0].text
        synthesizer = successful[0].provider
    else:
        evidence = "\n\n".join(f"[{r.provider}]\n{r.text}" for r in successful)
        synthesis_prompt = (
            "You are the RAH Raven Council synthesizer. Compare the independent adviser answers below. "
            "Produce one concise answer with: (1) shared conclusions, (2) disagreements/uncertainty, "
            "(3) recommended next step. Do not invent actions that were not executed.\n\n"
            f"ORIGINAL REQUEST:\n{message}\n\nADVISERS:\n{evidence}"
        )
        try:
            lm = raven_ai_fabric._lm_status(start_if_needed=False)
            if lm.ready:
                synth = raven_ai_fabric._lm_chat(synthesis_prompt, DEFAULT_SYSTEM, model)
                consensus = str(synth.get("text") or "").strip()
                synthesizer = "lmstudio"
            else:
                auto = raven_ai_fabric._auto_chat(synthesis_prompt, DEFAULT_SYSTEM, workspace, model)
                consensus = str(auto.get("text") or "").strip()
                synthesizer = str(auto.get("provider") or "auto")
        except Exception:
            consensus = evidence
            synthesizer = "fallback-concatenation"

    return {
        "ok": True,
        "version": COUNCIL_VERSION,
        "providers": selected,
        "replies": [r.as_dict() for r in replies],
        "consensus": consensus,
        "synthesizer": synthesizer,
        "machine_actions_executed": False,
        "machine_actions_route": "/ai/raven/job",
    }


@app.route("/ai/council", methods=["POST"])
def ai_council():
    payload = request.get_json(silent=True) or {}
    message = str(payload.get("message") or "").strip()
    if not message:
        return jsonify({"ok": False, "error": "message is required"}), 400

    raw_providers = payload.get("providers")
    providers = None
    if raw_providers is not None:
        if not isinstance(raw_providers, list) or any(str(p) not in ALLOWED_PROVIDERS for p in raw_providers):
            return jsonify({"ok": False, "error": "providers contains a non-allowlisted provider"}), 400
        providers = [str(p) for p in raw_providers]

    try:
        result = run_council(
            message,
            system=str(payload.get("system") or ""),
            workspace=str(payload.get("workspace") or ""),
            model=str(payload.get("model") or ""),
            providers=providers,
        )
        return jsonify(result), (200 if result.get("ok") else 503)
    except ValueError as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)[:500]}), 503
