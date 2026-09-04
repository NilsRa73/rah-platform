#!/usr/bin/env python3
"""Small client used by Raven/RAH UI to call the local RAH tool bus."""
from __future__ import annotations
import json, os, urllib.request, urllib.error
from pathlib import Path
from typing import Any

DEFAULT_URL = os.environ.get("RAH_AGENT_URL", "http://127.0.0.1:18779")
TOKEN_FILE = Path(os.environ.get("LOCALAPPDATA", str(Path.home()/"AppData"/"Local"))) / "RAH" / "LocalAgent" / "token.txt"


def _token() -> str:
    token = os.environ.get("RAH_AGENT_TOKEN")
    if token: return token.strip()
    return TOKEN_FILE.read_text(encoding="utf-8").strip()


def call(tool: str, args: dict[str, Any] | None = None, timeout: int = 120, base_url: str = DEFAULT_URL) -> Any:
    payload = json.dumps({"tool": tool, "args": args or {}}).encode("utf-8")
    req = urllib.request.Request(base_url.rstrip("/") + "/v1/tool", data=payload, method="POST", headers={"Content-Type":"application/json", "Authorization":"Bearer " + _token()})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r: data = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace"); raise RuntimeError(f"RAH Agent HTTP {e.code}: {body}") from e
    if not data.get("ok"): raise RuntimeError(data.get("error", "RAH Agent call failed"))
    return data.get("result")


def health(base_url: str = DEFAULT_URL) -> bool:
    try:
        with urllib.request.urlopen(base_url.rstrip("/") + "/health", timeout=2) as r: return bool(json.loads(r.read().decode("utf-8")).get("ok"))
    except Exception: return False


if __name__ == "__main__":
    import argparse
    ap = argparse.ArgumentParser(); ap.add_argument("tool"); ap.add_argument("args", nargs="?", default="{}", help="JSON object"); ns = ap.parse_args()
    print(json.dumps(call(ns.tool, json.loads(ns.args)), indent=2, ensure_ascii=False, default=str))
