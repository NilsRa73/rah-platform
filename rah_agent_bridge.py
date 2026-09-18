#!/usr/bin/env python3
"""RAH Agent Bridge v1 - localhost job bus for approved RAH agents.

The bridge moves structured JSON jobs through:
queued -> running -> completed/failed

It does not execute commands, scripts, or arbitrary filesystem operations.
"""
from __future__ import annotations

import argparse
import hmac
import json
import os
from pathlib import Path
import secrets
import shutil
import tempfile
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse
import uuid

VERSION = "1.0.0"
SCHEMA = "rah-agent-bridge"
MAX_BODY = 1024 * 1024
ALLOWED_KINDS = {
    "system.inventory",
    "code.review",
    "project.review",
    "text.task",
    "test.request",
    "agent.message",
}


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def atomic_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    raw = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    tmp.write_text(raw, encoding="utf-8")
    os.replace(tmp, path)


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def safe_job_id(value: str) -> bool:
    if not value or len(value) > 80:
        return False
    return all(c.isalnum() or c in "-_" for c in value)


class JobBus:
    def __init__(self, root: Path):
        self.root = root.resolve()
        self.lock = threading.Lock()
        self.dirs = {
            "queued": self.root / "inbox",
            "running": self.root / "working",
            "completed": self.root / "results",
            "failed": self.root / "failed",
            "archive": self.root / "archive",
            "logs": self.root / "logs",
        }
        for folder in self.dirs.values():
            folder.mkdir(parents=True, exist_ok=True)

    def _job_path(self, status: str, job_id: str) -> Path:
        if status not in self.dirs or status in {"archive", "logs"}:
            raise ValueError("invalid status")
        if not safe_job_id(job_id):
            raise ValueError("invalid job id")
        return self.dirs[status] / f"{job_id}.json"

    def counts(self) -> dict:
        out = {}
        for name in ("queued", "running", "completed", "failed"):
            out[name] = len(list(self.dirs[name].glob("*.json")))
        return out

    def enqueue(self, kind: str, source: str, payload) -> dict:
        kind = str(kind or "").strip()
        source = str(source or "unknown").strip()[:120]
        if kind not in ALLOWED_KINDS:
            raise ValueError(f"kind must be one of: {', '.join(sorted(ALLOWED_KINDS))}")
        job_id = "J-" + datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + uuid.uuid4().hex[:10]
        doc = {
            "schema": "rah-agent-job",
            "version": 1,
            "id": job_id,
            "kind": kind,
            "source": source,
            "createdAt": utc_now(),
            "status": "queued",
            "payload": payload,
            "history": [{"status": "queued", "at": utc_now(), "by": source}],
        }
        atomic_json(self._job_path("queued", job_id), doc)
        return doc

    def claim(self, worker: str) -> dict | None:
        worker = str(worker or "agent").strip()[:120]
        with self.lock:
            jobs = sorted(self.dirs["queued"].glob("*.json"), key=lambda p: p.stat().st_mtime)
            if not jobs:
                return None
            src = jobs[0]
            doc = load_json(src)
            job_id = str(doc.get("id", ""))
            if not safe_job_id(job_id):
                raise ValueError("queued file contains invalid id")
            doc["status"] = "running"
            doc["claimedBy"] = worker
            doc["startedAt"] = utc_now()
            doc.setdefault("history", []).append({"status": "running", "at": utc_now(), "by": worker})
            dst = self._job_path("running", job_id)
            atomic_json(dst, doc)
            src.unlink(missing_ok=True)
            return doc

    def finish(self, job_id: str, worker: str, ok: bool, value) -> dict:
        worker = str(worker or "agent").strip()[:120]
        with self.lock:
            src = self._job_path("running", job_id)
            if not src.exists():
                raise FileNotFoundError("running job not found")
            doc = load_json(src)
            status = "completed" if ok else "failed"
            doc["status"] = status
            doc["finishedAt"] = utc_now()
            if ok:
                doc["result"] = value
            else:
                doc["error"] = value
            doc.setdefault("history", []).append({"status": status, "at": utc_now(), "by": worker})
            dst = self._job_path(status, job_id)
            atomic_json(dst, doc)
            src.unlink(missing_ok=True)
            return doc

    def recent(self, status: str, limit: int = 20) -> list[dict]:
        if status not in ("queued", "running", "completed", "failed"):
            raise ValueError("invalid status")
        limit = max(1, min(int(limit), 100))
        paths = sorted(self.dirs[status].glob("*.json"), key=lambda p: p.stat().st_mtime, reverse=True)[:limit]
        rows = []
        for path in paths:
            try:
                doc = load_json(path)
                rows.append({
                    "id": doc.get("id"),
                    "kind": doc.get("kind"),
                    "source": doc.get("source"),
                    "status": doc.get("status"),
                    "createdAt": doc.get("createdAt"),
                    "claimedBy": doc.get("claimedBy"),
                    "finishedAt": doc.get("finishedAt"),
                })
            except Exception:
                rows.append({"id": path.stem, "status": "invalid"})
        return rows


class BridgeServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, address, handler, bus: JobBus, token: str):
        super().__init__(address, handler)
        self.bus = bus
        self.token = token


class Handler(BaseHTTPRequestHandler):
    server_version = "RAHAgentBridge/1.0"

    def log_message(self, fmt, *args):
        return

    def _send(self, code: int, obj) -> None:
        data = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _authorized(self) -> bool:
        expected = "Bearer " + self.server.token
        actual = self.headers.get("Authorization", "")
        return hmac.compare_digest(actual, expected)

    def _auth_or_401(self) -> bool:
        if self._authorized():
            return True
        self._send(401, {"ok": False, "error": "unauthorized"})
        return False

    def _read_json(self) -> dict:
        raw_len = self.headers.get("Content-Length", "0")
        try:
            length = int(raw_len)
        except ValueError as exc:
            raise ValueError("invalid Content-Length") from exc
        if length < 0 or length > MAX_BODY:
            raise ValueError("request body too large")
        raw = self.rfile.read(length) if length else b"{}"
        value = json.loads(raw.decode("utf-8"))
        if not isinstance(value, dict):
            raise ValueError("JSON object required")
        return value

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == "/health":
            self._send(200, {
                "ok": True,
                "schema": SCHEMA,
                "version": VERSION,
                "bind": self.server.server_address[0],
                "port": self.server.server_address[1],
                "counts": self.server.bus.counts(),
                "execCapability": False,
            })
            return
        if not self._auth_or_401():
            return
        if parsed.path == "/v1/jobs/status":
            self._send(200, {"ok": True, "counts": self.server.bus.counts()})
            return
        if parsed.path.startswith("/v1/jobs/recent/"):
            status = parsed.path.rsplit("/", 1)[-1]
            try:
                rows = self.server.bus.recent(status)
                self._send(200, {"ok": True, "status": status, "jobs": rows})
            except Exception as exc:
                self._send(400, {"ok": False, "error": str(exc)})
            return
        self._send(404, {"ok": False, "error": "not found"})

    def do_POST(self):
        if not self._auth_or_401():
            return
        parsed = urlparse(self.path)
        try:
            body = self._read_json()
            if parsed.path == "/v1/jobs/enqueue":
                doc = self.server.bus.enqueue(
                    body.get("kind", ""),
                    body.get("source", "unknown"),
                    body.get("payload"),
                )
                self._send(201, {"ok": True, "job": doc})
                return
            if parsed.path == "/v1/jobs/claim":
                doc = self.server.bus.claim(body.get("worker", "agent"))
                self._send(200, {"ok": True, "job": doc})
                return
            parts = [p for p in parsed.path.split("/") if p]
            if len(parts) == 4 and parts[0:2] == ["v1", "jobs"]:
                job_id, action = parts[2], parts[3]
                if action == "complete":
                    doc = self.server.bus.finish(job_id, body.get("worker", "agent"), True, body.get("result"))
                    self._send(200, {"ok": True, "job": doc})
                    return
                if action == "fail":
                    doc = self.server.bus.finish(job_id, body.get("worker", "agent"), False, body.get("error"))
                    self._send(200, {"ok": True, "job": doc})
                    return
            self._send(404, {"ok": False, "error": "not found"})
        except FileNotFoundError as exc:
            self._send(404, {"ok": False, "error": str(exc)})
        except (ValueError, json.JSONDecodeError) as exc:
            self._send(400, {"ok": False, "error": str(exc)})
        except Exception:
            self._send(500, {"ok": False, "error": "internal error"})


def load_or_create_token(path: Path) -> str:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        value = path.read_text(encoding="utf-8").strip()
        if len(value) >= 24:
            return value
    value = secrets.token_urlsafe(32)
    path.write_text(value + "\n", encoding="utf-8")
    return value


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="rah-agent-bridge-") as tmp:
        bus = JobBus(Path(tmp) / "bus")
        a = bus.enqueue("text.task", "selftest", {"text": "hello"})
        assert a["status"] == "queued"
        assert bus.counts()["queued"] == 1
        b = bus.claim("worker-selftest")
        assert b and b["id"] == a["id"] and b["status"] == "running"
        c = bus.finish(a["id"], "worker-selftest", True, {"answer": "ok"})
        assert c["status"] == "completed"
        assert bus.counts() == {"queued": 0, "running": 0, "completed": 1, "failed": 0}
        d = bus.enqueue("test.request", "selftest", {"n": 2})
        bus.claim("worker-selftest")
        e = bus.finish(d["id"], "worker-selftest", False, {"message": "synthetic"})
        assert e["status"] == "failed"
        assert bus.counts()["failed"] == 1
        token_path = Path(tmp) / "token.txt"
        token = load_or_create_token(token_path)
        assert len(token) >= 24 and token == load_or_create_token(token_path)
    print("PASS: RAH Agent Bridge v1 self-test")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", default=r"C:\RAH\AgentBridge")
    parser.add_argument("--bus-root", default=r"C:\RAH\AgentBus")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=18781)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0
    if args.host not in ("127.0.0.1", "::1", "localhost"):
        raise SystemExit("RAH Agent Bridge v1 only permits loopback binding.")
    if args.port < 1024 or args.port > 65535:
        raise SystemExit("Invalid port.")

    root = Path(args.root).resolve()
    bus = JobBus(Path(args.bus_root))
    token = load_or_create_token(root / "token.txt")
    state = {
        "schema": SCHEMA,
        "version": VERSION,
        "startedAt": utc_now(),
        "pid": os.getpid(),
        "bind": args.host,
        "port": args.port,
        "busRoot": str(bus.root),
        "execCapability": False,
    }
    atomic_json(root / "bridge-state.json", state)

    server = BridgeServer((args.host, args.port), Handler, bus, token)
    try:
        print(f"RAH Agent Bridge v{VERSION} listening on {args.host}:{args.port}")
        server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
