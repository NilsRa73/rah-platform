#!/usr/bin/env python3
"""Tiny localhost-only AI Fabric mock for RAH Agent Worker CI."""
from __future__ import annotations

import argparse
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
import uuid

JOBS: dict[str, dict] = {}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        return

    def send_json(self, code: int, obj) -> None:
        raw = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def read_json(self) -> dict:
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        value = json.loads(raw.decode("utf-8"))
        return value if isinstance(value, dict) else {}

    def do_GET(self):
        path = urlparse(self.path).path
        if path == "/ai/health":
            self.send_json(200, {"ok": True, "version": "mock", "ready_providers": ["mock"]})
            return
        if path.startswith("/agent/jobs/"):
            job_id = path.rsplit("/", 1)[-1]
            job = JOBS.get(job_id)
            if not job:
                self.send_json(404, {"ok": False, "error": "not found"})
                return
            self.send_json(200, {"ok": True, "job": job})
            return
        self.send_json(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        path = urlparse(self.path).path
        body = self.read_json()
        if path == "/ai/chat":
            message = str(body.get("message") or "")
            provider = str(body.get("provider") or "auto")
            self.send_json(
                200,
                {
                    "ok": True,
                    "provider": "mock-anythingllm" if provider == "anythingllm" else "mock-lmstudio",
                    "model": "mock-model",
                    "workspace": body.get("workspace"),
                    "text": "MOCK-ANSWER: " + message,
                },
            )
            return
        if path == "/agent/jobs":
            capability = str(body.get("capability") or "")
            if capability not in {
                "system-inventory",
                "test-council",
                "test-vision-core",
                "test-core-demo",
                "test-mission-engine",
                "test-bridge-security",
                "git-status",
                "project-files",
                "rah-file-index",
                "hovedpc-local-status",
            }:
                self.send_json(403, {"ok": False, "error": "capability denied"})
                return
            job_id = uuid.uuid4().hex[:16]
            job = {
                "id": job_id,
                "status": "succeeded",
                "capability": capability,
                "read_only": True,
                "result": {
                    "ok": True,
                    "stdout": f"mock-result:{capability}",
                    "stderr": "",
                    "files_modified": False,
                    "arbitrary_commands": False,
                },
            }
            JOBS[job_id] = job
            self.send_json(
                202,
                {
                    "ok": True,
                    "accepted": True,
                    "job": {"id": job_id, "status": "queued", "capability": capability},
                    "poll": f"/agent/jobs/{job_id}",
                    "arbitrary_commands": False,
                    "arguments_allowed": False,
                },
            )
            return
        self.send_json(404, {"ok": False, "error": "not found"})


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=18794)
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
