import argparse
import hashlib
import ipaddress
import json
import os
import platform
import sys
import zipfile
from datetime import datetime, timezone
from pathlib import Path
from tempfile import TemporaryDirectory


SCHEMA = "rah-raven-runtime-evidence-v1"
PRODUCT = "RAH Raven Daily Driver"
VERSION = "1.0.0"


def _json(path):
    try:
        return json.loads(Path(path).read_text(encoding="utf-8"))
    except Exception:
        return None


def _sha256(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _host_class(value):
    value = str(value or "").strip()
    if not value:
        return "unset"
    if value.casefold() == "localhost":
        return "loopback"
    try:
        addr = ipaddress.ip_address(value)
    except ValueError:
        return "hostname-configured"
    if addr.is_loopback:
        return "loopback"
    if addr.is_private:
        return "private"
    return "public"


def _safe_gate_detail(name, detail):
    detail = str(detail or "")
    if name == "Python 3":
        return detail[:80]
    if name in {"Chronicle persistence", "Investigator synthetic", "Frozen guard"}:
        return detail[:240]
    if name == "Real Facebook/archive import":
        if "files=" in detail:
            return detail[:240]
        return "archive gate pending or unavailable"
    if name == "LM Studio":
        return "local LM Studio status recorded"
    if name == "Daily Driver Bridge":
        return "loopback bridge status recorded"
    if name == "OpenAI cloud":
        return "optional cloud status recorded"
    if name == "Main PC device node":
        try:
            item = json.loads(detail)
            storage = item.get("storage") if isinstance(item.get("storage"), dict) else {}
            safe = {
                "id": item.get("id"),
                "kind": item.get("kind"),
                "online": bool(item.get("online")),
                "cpu": item.get("cpu"),
                "hostClass": _host_class(item.get("host")),
                "storage": {
                    "total_gb": storage.get("total_gb"),
                    "free_gb": storage.get("free_gb"),
                },
            }
            return safe
        except Exception:
            return "main PC status recorded"
    return ""


def sanitize_gate(raw):
    if not isinstance(raw, dict):
        return {
            "product": PRODUCT,
            "version": VERSION,
            "overall": "MISSING",
            "recommended_stage": "Candidate",
            "checks": [],
        }
    checks = []
    for item in raw.get("checks", []):
        if not isinstance(item, dict):
            continue
        name = str(item.get("name", ""))[:160]
        checks.append(
            {
                "name": name,
                "status": str(item.get("status", "UNKNOWN"))[:40],
                "required": bool(item.get("required", True)),
                "detail": _safe_gate_detail(name, item.get("detail", "")),
            }
        )
    return {
        "product": PRODUCT,
        "version": VERSION,
        "overall": str(raw.get("overall", "UNKNOWN"))[:40],
        "recommended_stage": str(raw.get("recommended_stage", "Candidate"))[:80],
        "checks": checks,
    }


def sanitize_module_status(raw):
    result = {"components": {}}
    if not isinstance(raw, dict):
        return result
    components = raw.get("components")
    if not isinstance(components, dict):
        return result
    for name, item in components.items():
        if not isinstance(item, dict):
            continue
        result["components"][str(name)[:160]] = {
            "version": str(item.get("version", ""))[:80],
            "stage": str(item.get("stage", ""))[:80],
            "frozen": bool(item.get("frozen", False)),
        }
    return result


def sanitize_devices(raw):
    if not isinstance(raw, dict):
        return {"devices": []}
    devices = []
    for item in raw.get("devices", []):
        if not isinstance(item, dict):
            continue
        devices.append(
            {
                "id": str(item.get("id", ""))[:120],
                "kind": str(item.get("kind", ""))[:120],
                "display": str(item.get("display", ""))[:120],
                "hostClass": _host_class(item.get("host")),
                "agents": [str(x)[:120] for x in item.get("agents", [])[:20]],
                "services": [str(x)[:120] for x in item.get("services", [])[:20]],
            }
        )
    return {"devices": devices}


def config_summary(raw):
    raw = raw if isinstance(raw, dict) else {}
    bridge = raw.get("bridge") if isinstance(raw.get("bridge"), dict) else {}
    agents = []
    for agent_id, item in (raw.get("agents") or {}).items():
        if not isinstance(item, dict):
            continue
        agents.append(
            {
                "id": str(agent_id)[:120],
                "adapter": str(item.get("adapter", ""))[:80],
                "type": str(item.get("type", ""))[:80],
                "enabled": bool(item.get("enabled", True)),
                "model": str(item.get("model", ""))[:160],
                "endpointClass": _host_class(
                    str(item.get("base_url", "")).split("://")[-1].split("/")[0].split(":")[0]
                ) if item.get("base_url") else "not-configured",
            }
        )
    return {
        "bridge": {
            "hostClass": _host_class(bridge.get("host")),
            "port": int(bridge.get("port", 0) or 0),
        },
        "agents": agents,
        "openaiApiKeyPresent": bool(os.environ.get("OPENAI_API_KEY", "").strip()),
    }


def environment_summary():
    return {
        "schema": SCHEMA,
        "product": PRODUCT,
        "version": VERSION,
        "createdUtc": datetime.now(timezone.utc).isoformat(),
        "os": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
        },
        "python": {
            "version": platform.python_version(),
            "executableName": Path(sys.executable).name,
        },
        "cpuCount": os.cpu_count(),
        "hostnameIncluded": False,
        "rawExternalAddressesIncluded": False,
    }


def _write_json(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def build_evidence_bundle(app_dir=None, output_dir=None):
    app = Path(app_dir or Path(__file__).resolve().parent)
    runtime = app / "runtime"
    state = runtime / "state"
    devices_dir = runtime / "devices"
    exports = Path(output_dir or runtime / "exports")
    exports.mkdir(parents=True, exist_ok=True)

    raw_gate_path = state / "runtime-gate.json"
    raw_gate = _json(raw_gate_path)
    gate = sanitize_gate(raw_gate)
    module_status = sanitize_module_status(_json(state / "module_status.json"))
    devices = sanitize_devices(_json(devices_dir / "devices.json"))
    config = config_summary(_json(app / "config.json"))
    env = environment_summary()

    stamp = datetime.now(timezone.utc).strftime("%Y%m%d-%H%M%SZ")
    base = f"RAH-Raven-Runtime-Evidence-{stamp}"
    zip_path = exports / f"{base}.zip"
    hash_path = exports / f"{base}.zip.sha256.txt"

    with TemporaryDirectory(prefix="rah-raven-evidence-") as tmp:
        root = Path(tmp) / base
        root.mkdir(parents=True, exist_ok=True)
        _write_json(root / "environment.json", env)
        _write_json(root / "runtime-gate-sanitized.json", gate)
        _write_json(root / "module-status-sanitized.json", module_status)
        _write_json(root / "devices-sanitized.json", devices)
        _write_json(root / "config-summary.json", config)

        raw_gate_hash = _sha256(raw_gate_path) if raw_gate_path.exists() else None
        privacy = {
            "schema": SCHEMA,
            "rawRuntimeGateSha256": raw_gate_hash,
            "included": [
                "sanitized runtime gate",
                "sanitized lifecycle status",
                "sanitized device registry",
                "sanitized AI/bridge configuration summary",
                "OS/Python/CPU metadata",
            ],
            "excluded": [
                "Chronicle database",
                "Facebook/archive source files",
                "runtime imports and exports other than this bundle",
                "chat or Council content",
                "API keys or token values",
                "raw device hostnames",
                "raw external IP addresses",
                "application logs",
            ],
        }
        _write_json(root / "privacy.json", privacy)

        readme = (
            "RAH Raven Daily Driver Runtime Evidence\n"
            "=======================================\n"
            "This bundle is designed for Runtime Test debugging.\n"
            "It intentionally excludes Chronicle DBs, personal archives, chat content, API keys, raw hostnames, raw external IPs and application logs.\n"
            f"Gate status: {gate.get('overall')}\n"
            f"Recommended stage: {gate.get('recommended_stage')}\n"
        )
        (root / "README.txt").write_text(readme, encoding="utf-8")

        manifest = {"schema": SCHEMA, "files": []}
        for path in sorted(root.iterdir(), key=lambda p: p.name.casefold()):
            if path.name == "manifest.json":
                continue
            manifest["files"].append(
                {"name": path.name, "bytes": path.stat().st_size, "sha256": _sha256(path)}
            )
        _write_json(root / "manifest.json", manifest)

        with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
            for path in sorted(root.iterdir(), key=lambda p: p.name.casefold()):
                zf.write(path, arcname=f"{base}/{path.name}")

    digest = _sha256(zip_path)
    hash_path.write_text(f"{digest}  {zip_path.name}\n", encoding="ascii")
    return {
        "zip": str(zip_path),
        "sha256File": str(hash_path),
        "sha256": digest,
        "gateStatus": gate.get("overall", "MISSING"),
        "recommendedStage": gate.get("recommended_stage", "Candidate"),
    }


def main():
    parser = argparse.ArgumentParser(description="Export a privacy-safe RAH Raven Runtime Evidence ZIP")
    parser.add_argument("--output-dir", help="Optional directory for the generated evidence ZIP")
    args = parser.parse_args()
    result = build_evidence_bundle(output_dir=args.output_dir)
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
