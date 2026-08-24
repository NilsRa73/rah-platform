from __future__ import annotations

"""RAH Raven Download Manager v0.1.

Captures downloads that Raven Wheel explicitly marks as expected from ChatGPT.
It does not sweep or reorganize unrelated files in the user's Downloads folder.
Expected downloads are moved into a dated RAH Raven Vault and indexed locally.
"""

import hashlib
import json
import os
import pathlib
import re
import shutil
import subprocess
import threading
import time
import uuid
from datetime import datetime, timezone
from typing import Any

from flask import jsonify, request, send_file

from server_v17 import app

DOWNLOAD_MANAGER_VERSION = "0.1.0"
PROJECT_ROOT = pathlib.Path(__file__).resolve().parent.parent
DOWNLOADS_UI = PROJECT_ROOT / "RAH-RAVEN-DOWNLOADS.html"
STATE_LOCK = threading.RLock()
WATCHER_STOP = threading.Event()
WATCHER_THREAD: threading.Thread | None = None
POLL_SECONDS = 2.0
STABLE_SECONDS = 3.0
MAX_EXPECTATIONS = 100
MAX_INDEX_ITEMS = 5000
EXPECTED_TTL_SECONDS = 900

PARTIAL_SUFFIXES = {".part", ".crdownload", ".tmp", ".download"}
TRACKED_SUFFIXES = {
    ".pdf", ".zip", ".docx", ".xlsx", ".pptx", ".txt", ".md", ".json",
    ".csv", ".html", ".htm", ".py", ".bat", ".ps1", ".png", ".jpg",
    ".jpeg", ".webp", ".gif", ".user.js",
}


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def _default_downloads_dir() -> pathlib.Path:
    configured = os.getenv("RAH_DOWNLOADS_DIR", "").strip()
    if configured:
        return pathlib.Path(configured).expanduser().resolve()
    return pathlib.Path.home() / "Downloads"


def _default_vault_dir() -> pathlib.Path:
    configured = os.getenv("RAH_RAVEN_VAULT", "").strip()
    if configured:
        return pathlib.Path(configured).expanduser().resolve()
    return pathlib.Path.home() / "Documents" / "RAH-Raven-Vault"


def _default_state_dir() -> pathlib.Path:
    configured = os.getenv("RAH_DOWNLOAD_MANAGER_STATE", "").strip()
    if configured:
        return pathlib.Path(configured).expanduser().resolve()
    if os.name == "nt" and os.getenv("LOCALAPPDATA"):
        return pathlib.Path(os.environ["LOCALAPPDATA"]) / "RAH-Raven" / "DownloadManager"
    return pathlib.Path.home() / ".rah-raven" / "downloads"


DOWNLOADS_DIR = _default_downloads_dir()
VAULT_DIR = _default_vault_dir()
STATE_DIR = _default_state_dir()
STATE_FILE = STATE_DIR / "state.json"
INDEX_FILE = STATE_DIR / "index.jsonl"

DEFAULT_STATE: dict[str, Any] = {
    "automatic": True,
    "expectations": [],
    "started_at": None,
    "last_scan_at": None,
    "last_capture_at": None,
    "last_error": None,
}


def _ensure_storage() -> None:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    VAULT_DIR.mkdir(parents=True, exist_ok=True)
    if not STATE_FILE.exists():
        _write_json(STATE_FILE, DEFAULT_STATE)
    INDEX_FILE.touch(exist_ok=True)


def _read_json(path: pathlib.Path, fallback: dict[str, Any]) -> dict[str, Any]:
    try:
        raw = json.loads(path.read_text(encoding="utf-8"))
        return raw if isinstance(raw, dict) else dict(fallback)
    except (OSError, json.JSONDecodeError):
        return dict(fallback)


def _write_json(path: pathlib.Path, value: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(value, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def _load_state() -> dict[str, Any]:
    _ensure_storage()
    state = _read_json(STATE_FILE, DEFAULT_STATE)
    for key, value in DEFAULT_STATE.items():
        state.setdefault(key, value)
    expectations = state.get("expectations")
    state["expectations"] = expectations if isinstance(expectations, list) else []
    return state


def _save_state(state: dict[str, Any]) -> None:
    with STATE_LOCK:
        _write_json(STATE_FILE, state)


def _parse_iso(value: str | None) -> float:
    if not value:
        return 0.0
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).timestamp()
    except ValueError:
        return 0.0


def _clean_expectations(state: dict[str, Any]) -> None:
    now = time.time()
    cleaned = []
    for item in state.get("expectations", []):
        if not isinstance(item, dict):
            continue
        expires_at = _parse_iso(str(item.get("expires_at") or ""))
        if expires_at and expires_at < now:
            continue
        if item.get("status") in {"captured", "expired", "cancelled"}:
            continue
        cleaned.append(item)
    state["expectations"] = cleaned[-MAX_EXPECTATIONS:]


def _suffix_for_name(name: str) -> str:
    lower = name.lower()
    if lower.endswith(".user.js"):
        return ".user.js"
    return pathlib.Path(lower).suffix


def _normalize_extension(value: str | None) -> str:
    ext = str(value or "").strip().lower()
    if not ext:
        return ""
    if not ext.startswith("."):
        ext = "." + ext
    return ext if ext in TRACKED_SUFFIXES else ""


def _safe_name(value: str) -> str:
    value = re.sub(r"[<>:\"/\\|?*\x00-\x1f]", "_", value).strip().strip(".")
    value = re.sub(r"\s+", " ", value)
    return value[:180] or "RAH-file"


def _project_tag(filename: str, label: str = "") -> str:
    text = f"{filename} {label}".casefold()
    rules = [
        ("Raven Core", ("raven core", "council", "vision", "agent runner", "chronicle")),
        ("Raven Care", ("raven care", "fristvakt", "fastlege", "fatigue", "medical", "helse")),
        ("RAH Platform", ("rah ai studios", "command center", "mission control", "project brain", "raven wheel")),
        ("Eiendom", ("figani", "parcelle", "eiendom", "bygg", "regulering", "pg3")),
        ("Gaming", ("gammon", "chess", "light gun", "arcade", "spill")),
    ]
    for tag, needles in rules:
        if any(needle in text for needle in needles):
            return tag
    return "Inbox"


def _read_index(limit: int = 200) -> list[dict[str, Any]]:
    _ensure_storage()
    limit = max(1, min(MAX_INDEX_ITEMS, int(limit)))
    try:
        lines = INDEX_FILE.read_text(encoding="utf-8").splitlines()
    except OSError:
        return []
    out: list[dict[str, Any]] = []
    for line in reversed(lines[-limit:]):
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if isinstance(item, dict):
            out.append(item)
    return out


def _append_index(item: dict[str, Any]) -> None:
    _ensure_storage()
    line = json.dumps(item, ensure_ascii=False, separators=(",", ":"))
    with STATE_LOCK:
        with INDEX_FILE.open("a", encoding="utf-8") as handle:
            handle.write(line + "\n")


def _sha256_if_reasonable(path: pathlib.Path) -> str | None:
    try:
        if path.stat().st_size > 100 * 1024 * 1024:
            return None
        digest = hashlib.sha256()
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()
    except OSError:
        return None


def _candidate_files() -> list[pathlib.Path]:
    if not DOWNLOADS_DIR.exists():
        return []
    output: list[pathlib.Path] = []
    try:
        for path in DOWNLOADS_DIR.iterdir():
            if not path.is_file():
                continue
            suffix = _suffix_for_name(path.name)
            if suffix in PARTIAL_SUFFIXES or suffix not in TRACKED_SUFFIXES:
                continue
            output.append(path)
    except OSError:
        return []
    return sorted(output, key=lambda p: p.stat().st_mtime if p.exists() else 0.0)


def _matches_expectation(path: pathlib.Path, expectation: dict[str, Any]) -> bool:
    try:
        modified = path.stat().st_mtime
    except OSError:
        return False
    created_at = _parse_iso(str(expectation.get("created_at") or ""))
    if created_at and modified < created_at - 8:
        return False
    expected_name = str(expectation.get("filename") or "").strip().casefold()
    expected_ext = _normalize_extension(str(expectation.get("extension") or ""))
    actual_name = path.name.casefold()
    actual_ext = _suffix_for_name(path.name)
    if expected_name and actual_name == expected_name:
        return True
    if expected_name and pathlib.Path(actual_name).stem == pathlib.Path(expected_name).stem:
        return True
    if expected_ext and actual_ext == expected_ext:
        return True
    return not expected_name and not expected_ext


def _is_stable(path: pathlib.Path) -> bool:
    try:
        stat = path.stat()
    except OSError:
        return False
    return stat.st_size > 0 and (time.time() - stat.st_mtime) >= STABLE_SECONDS


def _unique_destination(directory: pathlib.Path, filename: str) -> pathlib.Path:
    directory.mkdir(parents=True, exist_ok=True)
    candidate = directory / _safe_name(filename)
    if not candidate.exists():
        return candidate
    stem = candidate.stem
    suffix = candidate.suffix
    stamp = datetime.now().strftime("%H%M%S")
    return directory / f"{stem}_{stamp}{suffix}"


def _capture(path: pathlib.Path, expectation: dict[str, Any]) -> dict[str, Any]:
    now = datetime.now()
    day_dir = VAULT_DIR / f"{now:%Y}" / f"{now:%m}" / f"{now:%d}"
    destination = _unique_destination(day_dir, path.name)
    original_name = path.name
    size = path.stat().st_size
    shutil.move(str(path), str(destination))
    record = {
        "id": uuid.uuid4().hex,
        "captured_at": _utc_now(),
        "source": str(expectation.get("source") or "chatgpt")[:60],
        "label": str(expectation.get("label") or "")[:180],
        "project": _project_tag(original_name, str(expectation.get("label") or "")),
        "original_name": original_name,
        "stored_name": destination.name,
        "relative_path": destination.relative_to(VAULT_DIR).as_posix(),
        "size": size,
        "sha256": _sha256_if_reasonable(destination),
        "expectation_id": expectation.get("id"),
    }
    _append_index(record)
    return record


def _scan_once() -> list[dict[str, Any]]:
    state = _load_state()
    _clean_expectations(state)
    state["last_scan_at"] = _utc_now()
    if not state.get("automatic", True):
        _save_state(state)
        return []

    expectations = list(state.get("expectations", []))
    if not expectations:
        _save_state(state)
        return []

    captured: list[dict[str, Any]] = []
    files = _candidate_files()
    for expectation in expectations:
        match = next((p for p in files if _is_stable(p) and _matches_expectation(p, expectation)), None)
        if match is None:
            continue
        try:
            record = _capture(match, expectation)
            captured.append(record)
            files = [p for p in files if p != match]
            expectation["status"] = "captured"
            expectation["captured_file_id"] = record["id"]
            expectation["captured_at"] = record["captured_at"]
            state["last_capture_at"] = record["captured_at"]
            state["last_error"] = None
        except Exception as exc:
            state["last_error"] = str(exc)

    state["expectations"] = [item for item in expectations if item.get("status") != "captured"]
    _save_state(state)
    return captured


def _watcher_loop() -> None:
    while not WATCHER_STOP.is_set():
        try:
            _scan_once()
        except Exception as exc:
            state = _load_state()
            state["last_error"] = str(exc)
            _save_state(state)
        WATCHER_STOP.wait(POLL_SECONDS)


def _ensure_watcher() -> None:
    global WATCHER_THREAD
    if WATCHER_THREAD and WATCHER_THREAD.is_alive():
        return
    WATCHER_STOP.clear()
    WATCHER_THREAD = threading.Thread(target=_watcher_loop, name="raven-download-manager", daemon=True)
    WATCHER_THREAD.start()


def _open_path(path: pathlib.Path) -> None:
    if os.name == "nt":
        os.startfile(str(path))  # type: ignore[attr-defined]
    elif sys.platform == "darwin":  # pragma: no cover
        subprocess.Popen(["open", str(path)])
    else:  # pragma: no cover
        subprocess.Popen(["xdg-open", str(path)])


@app.get("/downloads/status")
def download_status():
    state = _load_state()
    _clean_expectations(state)
    _save_state(state)
    return jsonify({
        "ok": True,
        "version": DOWNLOAD_MANAGER_VERSION,
        "automatic": bool(state.get("automatic", True)),
        "downloads_dir": str(DOWNLOADS_DIR),
        "vault_dir": str(VAULT_DIR),
        "watcher_alive": bool(WATCHER_THREAD and WATCHER_THREAD.is_alive()),
        "pending_expectations": len(state.get("expectations", [])),
        "last_scan_at": state.get("last_scan_at"),
        "last_capture_at": state.get("last_capture_at"),
        "last_error": state.get("last_error"),
        "mode": "chatgpt-expected-only",
    })


@app.post("/downloads/config")
def download_config():
    payload = request.get_json(silent=True) or {}
    state = _load_state()
    if "automatic" in payload:
        state["automatic"] = bool(payload.get("automatic"))
    _save_state(state)
    return jsonify({"ok": True, "automatic": state["automatic"]})


@app.post("/downloads/expect")
def download_expect():
    payload = request.get_json(silent=True) or {}
    filename = _safe_name(str(payload.get("filename") or "")) if payload.get("filename") else ""
    extension = _normalize_extension(str(payload.get("extension") or ""))
    if filename and not extension:
        extension = _suffix_for_name(filename)
        if extension not in TRACKED_SUFFIXES:
            extension = ""
    if not filename and not extension:
        return jsonify({"ok": False, "error": "Raven Wheel må sende filnavn eller støttet filtype."}), 400

    ttl = payload.get("ttl_seconds", EXPECTED_TTL_SECONDS)
    try:
        ttl_seconds = max(60, min(3600, int(ttl)))
    except (TypeError, ValueError):
        ttl_seconds = EXPECTED_TTL_SECONDS
    created = datetime.now(timezone.utc)
    expires = datetime.fromtimestamp(created.timestamp() + ttl_seconds, tz=timezone.utc)
    expectation = {
        "id": uuid.uuid4().hex,
        "created_at": created.isoformat(timespec="seconds"),
        "expires_at": expires.isoformat(timespec="seconds"),
        "source": str(payload.get("source") or "chatgpt")[:60],
        "filename": filename,
        "extension": extension,
        "label": str(payload.get("label") or "")[:180],
        "status": "pending",
    }
    state = _load_state()
    _clean_expectations(state)
    state["expectations"].append(expectation)
    state["expectations"] = state["expectations"][-MAX_EXPECTATIONS:]
    _save_state(state)
    return jsonify({"ok": True, "expectation": expectation})


@app.post("/downloads/scan")
def download_scan():
    payload = request.get_json(silent=True) or {}
    if payload.get("confirm") is not True:
        return jsonify({"ok": False, "error": "confirm=true kreves for manuell skanning."}), 400
    captured = _scan_once()
    return jsonify({"ok": True, "captured": captured, "count": len(captured)})


@app.get("/downloads/recent")
def download_recent():
    try:
        limit = int(request.args.get("limit", "20"))
    except ValueError:
        limit = 20
    items = _read_index(limit)
    return jsonify({"ok": True, "items": items, "count": len(items)})


@app.get("/downloads/search")
def download_search():
    query = str(request.args.get("q") or "").strip().casefold()
    if not query:
        return jsonify({"ok": True, "items": _read_index(50), "count": len(_read_index(50))})
    items = _read_index(MAX_INDEX_ITEMS)
    matches = []
    for item in items:
        haystack = " ".join(str(item.get(key) or "") for key in ("original_name", "stored_name", "project", "label", "captured_at")).casefold()
        if query in haystack:
            matches.append(item)
        if len(matches) >= 100:
            break
    return jsonify({"ok": True, "items": matches, "count": len(matches)})


@app.post("/downloads/open-vault")
def download_open_vault():
    payload = request.get_json(silent=True) or {}
    if payload.get("confirm") is not True:
        return jsonify({"ok": False, "error": "confirm=true kreves for å åpne Raven Vault."}), 400
    try:
        VAULT_DIR.mkdir(parents=True, exist_ok=True)
        _open_path(VAULT_DIR)
        return jsonify({"ok": True, "opened": str(VAULT_DIR)})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.post("/downloads/open-file")
def download_open_file():
    payload = request.get_json(silent=True) or {}
    if payload.get("confirm") is not True:
        return jsonify({"ok": False, "error": "confirm=true kreves for å åpne en fil."}), 400
    file_id = str(payload.get("id") or "").strip()
    item = next((row for row in _read_index(MAX_INDEX_ITEMS) if str(row.get("id")) == file_id), None)
    if item is None:
        return jsonify({"ok": False, "error": "Filen finnes ikke i Raven-indeksen."}), 404
    target = (VAULT_DIR / str(item.get("relative_path") or "")).resolve()
    try:
        target.relative_to(VAULT_DIR.resolve())
    except ValueError:
        return jsonify({"ok": False, "error": "Ugyldig filplassering."}), 403
    if not target.is_file():
        return jsonify({"ok": False, "error": "Den indekserte filen finnes ikke lenger."}), 404
    try:
        _open_path(target)
        return jsonify({"ok": True, "opened": item})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.get("/downloads/ui")
def download_ui():
    if not DOWNLOADS_UI.exists():
        return jsonify({"ok": False, "error": f"{DOWNLOADS_UI.name} mangler."}), 404
    return send_file(DOWNLOADS_UI, mimetype="text/html", conditional=False, max_age=0)


_ensure_storage()
_ensure_watcher()
