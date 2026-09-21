#!/usr/bin/env python3
"""RAH Raven 2-PC Inventory Client v1.

Fixed-purpose client for Node Agent 1.4 Stable:
  GET /health auth-init -> HMAC proof -> GET /raven/status

No shell, no arbitrary path, no caller-controlled remote arguments, and no token persistence.
"""
from __future__ import annotations

import argparse
import base64
import hashlib
import hmac
import ipaddress
import json
import os
from pathlib import Path
import re
import sys
import tempfile
import threading
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any

VERSION = "1.0.0"
PORT = 18766
AUTH_INIT_HEADER = "X-RAH-Auth-Init"
AUTH_NONCE_HEADER = "X-RAH-Auth-Nonce"
AUTH_PROOF_HEADER = "X-RAH-Auth-Proof"
AUTH_CANONICAL_VERSION = "RAH-AUTH-V2"
RAVEN_STATUS_ROUTE = "/raven/status"
RAVEN_STATUS_PROTOCOL = "rah-node-raven-status-v1"
RAVEN_STATUS_CAPABILITY = "system-inventory"
RAVEN_STATUS_SOURCE = "local-raven-job-executor"
EMPTY_SHA256 = hashlib.sha256(b"").hexdigest()
SAFE_HOST = re.compile(r"^[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$")


class ContractError(RuntimeError):
    pass


def _b64url(raw: bytes) -> str:
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def _safe_host(value: str) -> str:
    host = str(value or "").strip()
    if not host or any(ch in host for ch in "/:@?#\\"):
        raise ValueError("Invalid node address.")
    try:
        ipaddress.ip_address(host)
        return host
    except ValueError:
        pass
    if len(host) > 253 or not SAFE_HOST.fullmatch(host):
        raise ValueError("Invalid node hostname.")
    return host


def build_canonical(session_id: str, nonce: str) -> str:
    session = str(session_id or "").strip()
    nonce = str(nonce or "").strip()
    if not re.fullmatch(r"[A-Za-z0-9_-]{20,64}", session):
        raise ContractError("Invalid Node session id.")
    if not re.fullmatch(r"[A-Za-z0-9_-]{24,64}", nonce):
        raise ContractError("Invalid Node auth nonce.")
    return "\n".join([
        AUTH_CANONICAL_VERSION,
        session,
        nonce,
        "GET",
        RAVEN_STATUS_ROUTE,
        EMPTY_SHA256,
        "",
        "",
        "",
        "",
        "",
    ])


def build_proof(token: str, canonical: str) -> str:
    token = str(token or "").strip()
    if len(token) < 24 or len(token) > 128:
        raise ValueError("Fresh Node token is missing or invalid.")
    digest = hmac.new(token.encode("utf-8"), canonical.encode("utf-8"), hashlib.sha256).digest()
    return _b64url(digest)


def _json_get(url: str, headers: dict[str, str], timeout: float) -> tuple[int, Any]:
    req = urllib.request.Request(url, method="GET", headers={"Accept": "application/json", **headers})
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            raw = response.read(512 * 1024 + 1)
            if len(raw) > 512 * 1024:
                raise ContractError("Node response exceeded size limit.")
            return int(response.status), json.loads(raw.decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read(64 * 1024).decode("utf-8", errors="replace")
        try:
            payload = json.loads(raw)
        except json.JSONDecodeError:
            payload = {"error": raw[:1000]}
        return int(exc.code), payload


def _plain_dict(value: Any) -> dict[str, Any] | None:
    return value if isinstance(value, dict) else None


def sanitize_raven_status(payload: Any) -> dict[str, Any]:
    p = _plain_dict(payload)
    if not p or p.get("ok") is not True:
        raise ContractError("Raven status did not return ok=true.")
    if p.get("protocol") != RAVEN_STATUS_PROTOCOL:
        raise ContractError("Unexpected Raven status protocol.")
    if p.get("source") != RAVEN_STATUS_SOURCE or p.get("capability") != RAVEN_STATUS_CAPABILITY:
        raise ContractError("Unexpected Raven status source/capability.")
    if p.get("arbitraryCommands") is not False or p.get("argumentsAllowed") is not False or p.get("localOnlyHop") is not True:
        raise ContractError("Remote safety flags failed.")

    result = _plain_dict(p.get("result"))
    if not result or result.get("ok") is not True:
        raise ContractError("Inventory job failed.")
    if result.get("read_only") is not True or result.get("files_modified") is not False or result.get("arbitrary_commands") is not False:
        raise ContractError("Inventory result safety contract failed.")

    inv = _plain_dict(result.get("inventory"))
    if not inv:
        raise ContractError("Inventory payload missing.")
    os_info = _plain_dict(inv.get("os"))
    cpu = _plain_dict(inv.get("cpu"))
    bridge = _plain_dict(inv.get("raven_bridge"))
    safety = _plain_dict(inv.get("safety"))
    if not all((os_info, cpu, bridge, safety)):
        raise ContractError("Inventory payload is incomplete.")
    if safety.get("read_only") is not True or safety.get("arbitrary_commands") is not False or safety.get("file_writes") is not False or safety.get("automatic_execution") is not False:
        raise ContractError("Inventory safety block failed.")

    def text(value: Any, limit: int) -> str:
        return str(value or "").replace("\x00", "").replace("\r", " ").strip()[:limit]

    gpus = [text(x, 200) for x in (inv.get("gpus") or []) if isinstance(x, str)][:8]
    clean = {
        "schema": "rah-2pc-inventory-proof-v1",
        "clientVersion": VERSION,
        "status": "PASS",
        "protocol": RAVEN_STATUS_PROTOCOL,
        "capability": RAVEN_STATUS_CAPABILITY,
        "nodeJobId": text(p.get("nodeJobId"), 160),
        "inventory": {
            "hostname": text(inv.get("hostname"), 120),
            "os": {
                "system": text(os_info.get("system"), 80),
                "release": text(os_info.get("release"), 80),
                "architecture": text(os_info.get("architecture"), 80),
            },
            "cpu": {
                "name": text(cpu.get("name"), 200),
                "logical_cores": cpu.get("logical_cores") if isinstance(cpu.get("logical_cores"), int) else None,
            },
            "ram_gb": inv.get("ram_gb") if isinstance(inv.get("ram_gb"), (int, float)) else None,
            "gpus": gpus,
            "monitor_count": inv.get("monitor_count") if isinstance(inv.get("monitor_count"), int) else None,
            "raven_bridge": {
                "version": text(bridge.get("version"), 40),
                "port": bridge.get("port") if isinstance(bridge.get("port"), int) else None,
                "health_route": bridge.get("health_route") is True,
                "agent_route": bridge.get("agent_route") is True,
            },
        },
        "safety": {
            "readOnly": True,
            "arbitraryCommands": False,
            "callerArguments": False,
            "tokenPersisted": False,
            "localRavenHopOnly": True,
        },
        "stdout": text(result.get("stdout"), 12000),
    }
    return clean


def run_inventory(host: str, token: str, *, port: int = PORT, timeout: float = 8.0) -> dict[str, Any]:
    host = _safe_host(host)
    if port != PORT:
        raise ValueError(f"Remote port is fixed to {PORT}.")
    base = f"http://{host}:{port}"

    code, challenge = _json_get(base + "/health", {AUTH_INIT_HEADER: "1"}, timeout)
    if code != 200 or not isinstance(challenge, dict):
        raise RuntimeError(f"Auth challenge failed: HTTP {code}")
    session = challenge.get("sessionId")
    nonce = challenge.get("nonce")
    canonical = build_canonical(str(session or ""), str(nonce or ""))
    proof = build_proof(token, canonical)

    code, payload = _json_get(
        base + RAVEN_STATUS_ROUTE,
        {AUTH_NONCE_HEADER: str(nonce), AUTH_PROOF_HEADER: proof},
        max(timeout, 30.0),
    )
    if code != 200:
        raise RuntimeError(f"Raven status failed: HTTP {code}: {str(payload)[:600]}")
    clean = sanitize_raven_status(payload)
    clean["target"] = {"host": host, "port": PORT}
    return clean


class _SelfTestHandler(BaseHTTPRequestHandler):
    token = "Token_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
    session = "Session_ABCDEFGHIJKLMNOPQRSTUVWXYZ1234"
    nonce = "Nonce_ABCDEFGHIJKLMNOPQRSTUVWXYZ123456"
    inventory = {
        "hostname": "SELFTEST-NODE",
        "os": {"system": "Windows", "release": "11", "architecture": "AMD64"},
        "cpu": {"name": "Self Test CPU", "logical_cores": 8},
        "ram_gb": 16.0,
        "gpus": ["Self Test GPU"],
        "monitor_count": 2,
        "raven_bridge": {"version": "2.0.32", "port": 18765, "health_route": True, "agent_route": True},
        "safety": {"read_only": True, "arbitrary_commands": False, "file_writes": False, "automatic_execution": False},
    }

    def log_message(self, fmt, *args):
        return

    def _send(self, code: int, obj: Any):
        raw = json.dumps(obj).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path == "/health" and self.headers.get(AUTH_INIT_HEADER) == "1":
            return self._send(200, {"protocol": "rah-node-auth-v2", "status": "challenge", "sessionId": self.session, "nonce": self.nonce, "nonceTtlSeconds": 30})
        if self.path == RAVEN_STATUS_ROUTE:
            expected = build_proof(self.token, build_canonical(self.session, self.nonce))
            if self.headers.get(AUTH_NONCE_HEADER) != self.nonce or not hmac.compare_digest(self.headers.get(AUTH_PROOF_HEADER, ""), expected):
                return self._send(401, {"error": "auth_proof_invalid"})
            return self._send(200, {
                "ok": True,
                "protocol": RAVEN_STATUS_PROTOCOL,
                "source": RAVEN_STATUS_SOURCE,
                "capability": RAVEN_STATUS_CAPABILITY,
                "arbitraryCommands": False,
                "argumentsAllowed": False,
                "localOnlyHop": True,
                "nodeJobId": "selftest-job",
                "result": {
                    "ok": True,
                    "read_only": True,
                    "files_modified": False,
                    "arbitrary_commands": False,
                    "inventory": self.inventory,
                    "stdout": "selftest inventory ok",
                },
            })
        return self._send(404, {"error": "not_found"})


def self_test() -> None:
    server = ThreadingHTTPServer(("127.0.0.1", 0), _SelfTestHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        port = int(server.server_address[1])
        # Internal self-test permits a random loopback port; production is fixed to 18766.
        base = f"http://127.0.0.1:{port}"
        code, challenge = _json_get(base + "/health", {AUTH_INIT_HEADER: "1"}, 2)
        assert code == 200
        canonical = build_canonical(challenge["sessionId"], challenge["nonce"])
        proof = build_proof(_SelfTestHandler.token, canonical)
        code, payload = _json_get(base + RAVEN_STATUS_ROUTE, {AUTH_NONCE_HEADER: challenge["nonce"], AUTH_PROOF_HEADER: proof}, 2)
        assert code == 200
        clean = sanitize_raven_status(payload)
        assert clean["status"] == "PASS"
        assert clean["inventory"]["hostname"] == "SELFTEST-NODE"
        assert clean["safety"]["tokenPersisted"] is False
        assert "Token_" not in json.dumps(clean)
    finally:
        server.shutdown()
        server.server_close()
    print("PASS: RAH Raven 2-PC Inventory Client v1 self-test")


def default_out() -> Path:
    if os.name == "nt":
        return Path(r"C:\RAH\2PCProof\results\last-inventory.json")
    return Path(tempfile.gettempdir()) / "rah-2pc-last-inventory.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host")
    parser.add_argument("--port", type=int, default=PORT)
    parser.add_argument("--out", default=str(default_out()))
    parser.add_argument("--timeout", type=float, default=8.0)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    if args.self_test:
        self_test()
        return 0
    if not args.host:
        parser.error("--host is required")

    token = sys.stdin.readline().strip()
    if not token:
        print("FAIL: Fresh Node token must be provided on stdin.", file=sys.stderr)
        return 2

    try:
        result = run_inventory(args.host, token, port=args.port, timeout=args.timeout)
        out = Path(args.out)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print(json.dumps(result, ensure_ascii=False))
        return 0
    except Exception as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        return 3


if __name__ == "__main__":
    raise SystemExit(main())
