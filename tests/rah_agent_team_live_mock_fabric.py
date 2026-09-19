#!/usr/bin/env python3
"""Local-only Raven/AI Fabric mock for RAH Agent Team LIVE TEST CI."""
from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import uuid

JOBS: dict[str, dict] = {}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        return

    def send_json(self, code: int, obj) -> None:
        raw = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def read_json(self) -> dict:
        n = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(n) if n else b"{}"
        obj = json.loads(raw.decode("utf-8"))
        return obj if isinstance(obj, dict) else {}

    def do_GET(self):
        if self.path == "/health":
            return self.send_json(200, {"ok": True, "ai_fabric": True})
        if self.path == "/agent/jobs/health":
            return self.send_json(200, {"ok": True, "ready": True, "elevated": True})
        if self.path == "/ai/health":
            return self.send_json(200, {"ok": True, "ready_providers": ["anythingllm"]})
        if self.path == "/ai/providers":
            return self.send_json(
                200,
                {
                    "ok": True,
                    "providers": [
                        {
                            "id": "anythingllm",
                            "online": True,
                            "ready": True,
                            "detail": "mock authenticated",
                        }
                    ],
                },
            )
        if self.path.startswith("/agent/jobs/"):
            job_id = self.path.rsplit("/", 1)[-1]
            job = JOBS.get(job_id)
            if not job:
                return self.send_json(404, {"ok": False, "error": "missing"})
            return self.send_json(200, {"ok": True, "job": job})
        return self.send_json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        body = self.read_json()
        if self.path == "/ai/chat":
            provider = str(body.get("provider") or "auto")
            if provider not in {"auto", "anythingllm", "lmstudio"}:
                return self.send_json(400, {"ok": False, "error": "bad provider"})
            return self.send_json(
                200,
                {
                    "ok": True,
                    "provider": "mock-anythingllm",
                    "handledBy": "mock-anythingllm",
                    "model": "mock-live-model",
                    "backend": "mock-anythingllm-backend",
                    "workspace": body.get("workspace"),
                    "text": "RAH LIVE AGENT OK",
                    "traceVersion": 1,
                    "attemptCount": 1,
                    "fallbackUsed": False,
                    "attempts": [
                        {
                            "provider": "mock-anythingllm",
                            "model": "mock-live-model",
                            "result": "PASS",
                            "quarantined": False,
                            "durationMs": 7,
                        }
                    ],
                },
            )
        if self.path == "/agent/jobs":
            capability = str(body.get("capability") or "")
            if capability != "system-inventory" or body.get("confirm") is not True:
                return self.send_json(403, {"ok": False, "error": "capability rejected"})
            job_id = "live-" + uuid.uuid4().hex[:12]
            JOBS[job_id] = {
                "id": job_id,
                "capability": capability,
                "status": "completed",
                "read_only": True,
                "result": {
                    "ok": True,
                    "hostname": "CI-LIVE-MOCK",
                    "files_modified": False,
                    "arbitrary_commands": False,
                },
            }
            return self.send_json(
                202,
                {
                    "ok": True,
                    "accepted": True,
                    "job": {"id": job_id, "status": "queued"},
                    "arbitrary_commands": False,
                    "arguments_allowed": False,
                },
            )
        return self.send_json(404, {"ok": False, "error": "not found"})


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=18802)
    args = ap.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    try:
        server.serve_forever(poll_interval=0.1)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
