#!/usr/bin/env python3
"""RAH AI Tool Bridge

Connects an OpenAI-compatible local model (for example LM Studio) to RAH Local
Agent. The model decides when local facts/tools are required; the bridge invokes
the agent and feeds results back to the model.
"""
from __future__ import annotations

import json
import os
import urllib.request
from typing import Any

from rah_agent_client import call as agent_call, health as agent_health

LLM_BASE = os.environ.get("RAH_LLM_BASE", "http://127.0.0.1:1234/v1").rstrip("/")
LLM_MODEL = os.environ.get("RAH_LLM_MODEL", "").strip()
MAX_TOOL_STEPS = int(os.environ.get("RAH_MAX_TOOL_STEPS", "6"))

TOOLS = [
    "system.snapshot", "system.cpu", "system.memory", "system.gpu", "system.disks",
    "system.network", "system.displays", "fs.list", "fs.read_text", "fs.read_bytes",
    "fs.write_text", "fs.write_bytes", "fs.mkdir", "fs.copy", "fs.move", "fs.delete",
    "fs.search", "fs.hash", "process.list", "process.start", "process.stop",
    "service.list", "service.start", "service.stop", "shell.powershell", "shell.exec",
]

PLANNER = """You are the RAH Raven local tool router.
You have a trusted local Windows agent. Use it whenever the user's request depends on facts,
files, processes, services, hardware, disks, network state, or actions on this PC.
Do not ask the user to copy/paste a command if a RAH tool can obtain the information.

Available tools:
%s

Return ONLY one JSON object, no markdown:
1) To invoke a tool: {"action":"tool","tool":"system.cpu","args":{}}
2) If you already have enough information to answer: {"action":"answer","text":"..."}

Use Windows paths for filesystem operations. Keep tool arguments minimal. Prefer structured tools
over shell commands. Use shell.powershell/shell.exec only when no structured tool fits.
""" % "\n".join("- " + t for t in TOOLS)


def _request_json(url: str, payload: dict[str, Any] | None = None, timeout: int = 120) -> Any:
    data = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(url, data=data, headers={"Content-Type": "application/json"}, method="GET" if data is None else "POST")
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8"))


def discover_model() -> str:
    if LLM_MODEL:
        return LLM_MODEL
    data = _request_json(LLM_BASE + "/models", timeout=5)
    models = data.get("data") or []
    if not models:
        raise RuntimeError("No local model is loaded on the OpenAI-compatible server")
    return str(models[0]["id"])


def local_chat(messages: list[dict[str, Any]], temperature: float = 0.1) -> str:
    model = discover_model()
    data = _request_json(LLM_BASE + "/chat/completions", {"model": model, "messages": messages, "temperature": temperature, "stream": False})
    choices = data.get("choices") or []
    if not choices:
        raise RuntimeError("Local model returned no choices")
    return str((choices[0].get("message") or {}).get("content") or "").strip()


def _extract_json(text: str) -> dict[str, Any]:
    text = text.strip()
    if text.startswith("```"):
        lines = text.splitlines()[1:]
        if lines and lines[-1].strip().startswith("```"): lines = lines[:-1]
        text = "\n".join(lines).strip()
        if text.lower().startswith("json"): text = text[4:].lstrip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        a, b = text.find("{"), text.rfind("}")
        if a >= 0 and b > a: return json.loads(text[a:b+1])
        raise


def ask(user_text: str, history: list[dict[str, str]] | None = None) -> dict[str, Any]:
    if not agent_health():
        raise RuntimeError("RAH Local Agent is not running on 127.0.0.1:18779")
    transcript: list[dict[str, Any]] = [{"role": "system", "content": PLANNER}]
    if history: transcript.extend(history[-20:])
    transcript.append({"role": "user", "content": user_text})
    trace: list[dict[str, Any]] = []
    for _ in range(MAX_TOOL_STEPS):
        raw = local_chat(transcript); decision = _extract_json(raw); action = decision.get("action")
        if action == "answer": return {"answer": str(decision.get("text", "")), "trace": trace}
        if action != "tool": raise RuntimeError(f"Unknown planner action: {action!r}")
        tool = str(decision.get("tool", ""))
        if tool not in TOOLS: raise RuntimeError(f"Planner requested unavailable tool: {tool}")
        args = decision.get("args") or {}
        if not isinstance(args, dict): raise RuntimeError("Planner args must be an object")
        result = agent_call(tool, args); trace.append({"tool": tool, "args": args, "result": result})
        transcript.append({"role": "assistant", "content": json.dumps(decision, ensure_ascii=False)})
        transcript.append({"role": "user", "content": "RAH_TOOL_RESULT " + json.dumps({"tool": tool, "result": result}, ensure_ascii=False, default=str)})
    final = local_chat(transcript + [{"role": "user", "content": "Tool-step limit reached. Answer using the local results already collected. Return JSON action=answer."}])
    decision = _extract_json(final)
    return {"answer": str(decision.get("text", final)), "trace": trace}


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(description="Ask local Raven AI with automatic RAH PC tools"); ap.add_argument("question", nargs="+"); ns = ap.parse_args()
    result = ask(" ".join(ns.question)); print(result["answer"])
    if os.environ.get("RAH_SHOW_TOOL_TRACE") == "1": print(json.dumps(result["trace"], indent=2, ensure_ascii=False, default=str))
