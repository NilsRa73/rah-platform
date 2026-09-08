from __future__ import annotations

"""Structured read-only health snapshot for the local RAH Raven runtime.

This module deliberately performs diagnostics only. It never repairs, writes files,
changes configuration, or executes user-supplied commands. LM Studio is optional.
"""

import os
import pathlib
import platform
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from typing import Any

import mss

HEALTH_VERSION = "1.0.0"
RAVEN_IMAGE_NAME = "RAH-Raven-Vision.exe"


def _check(
    check_id: str,
    title: str,
    status: str,
    detail: str,
    *,
    required: bool = True,
    problem: str = "",
    fix: str = "",
    next_action: str = "",
) -> dict[str, Any]:
    return {
        "id": check_id,
        "title": title,
        "status": status,
        "detail": detail,
        "required": required,
        "problem": problem,
        "fix": fix,
        "next_action": next_action,
    }


def _asset_check(asset_id: str, title: str, path: pathlib.Path, marker: str) -> dict[str, Any]:
    if not path.is_file():
        return _check(
            asset_id,
            title,
            "RED",
            f"Mangler {path.name}",
            problem="Bundled Raven-asset mangler.",
            fix="Installer siste grønne Raven EXE-build.",
            next_action="Erstatt gammel Raven-build med siste release artifact.",
        )
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError as exc:
        return _check(
            asset_id,
            title,
            "RED",
            f"Kan ikke lese {path.name}: {exc}",
            problem="Raven-asset kan ikke leses.",
            fix="Installer siste Raven EXE på nytt.",
            next_action="Kjør Doctor igjen etter reinstallasjon.",
        )
    if marker not in text:
        return _check(
            asset_id,
            title,
            "RED",
            f"{path.name} finnes, men forventet marker mangler.",
            problem="Feil eller gammel Raven-asset.",
            fix="Installer siste grønne Raven EXE-build.",
            next_action="Kjør Doctor igjen.",
        )
    return _check(asset_id, title, "GREEN", f"{path.name} OK")


def _monitor_check() -> dict[str, Any]:
    try:
        with mss.mss() as sct:
            count = max(0, len(sct.monitors) - 1)
        if count > 0:
            return _check("monitors", "Monitorer", "GREEN", f"{count} monitor(er) oppdaget")
        return _check(
            "monitors",
            "Monitorer",
            "YELLOW",
            "Ingen monitorer rapportert i denne økten.",
            required=False,
            problem="Raven kan ikke bekrefte skjermfangst i denne økten.",
            fix="Kjør Raven i den interaktive Windows-brukerøkten.",
            next_action="Test LIVE 5s fysisk i ChatGPT.",
        )
    except Exception as exc:
        return _check(
            "monitors",
            "Monitorer",
            "YELLOW",
            f"Monitorprobe utilgjengelig: {str(exc)[:180]}",
            required=False,
            problem="Monitorprobe kunne ikke fullføres.",
            fix="Kontroller at Raven kjører i vanlig desktop-økt.",
            next_action="Test Raven Vision fra Command Wheel.",
        )


def _disk_check() -> dict[str, Any]:
    try:
        target = pathlib.Path(os.getenv("LOCALAPPDATA") or pathlib.Path.home()).resolve()
        usage = shutil.disk_usage(target)
        free_gb = round(usage.free / (1024 ** 3), 1)
        if free_gb < 5:
            return _check(
                "disk",
                "Lokal diskplass",
                "RED",
                f"Kun {free_gb} GB ledig på {target.drive or target}",
                problem="For lite diskplass for stabil Raven-drift og artifacts.",
                fix="Frigjør minst 10 GB.",
                next_action="Kjør Health Check på nytt.",
            )
        if free_gb < 15:
            return _check(
                "disk",
                "Lokal diskplass",
                "YELLOW",
                f"{free_gb} GB ledig",
                required=False,
                problem="Diskplassen begynner å bli lav.",
                fix="Frigjør plass før større builds eller modeller.",
                next_action="Sikt mot minst 15 GB ledig.",
            )
        return _check("disk", "Lokal diskplass", "GREEN", f"{free_gb} GB ledig")
    except Exception as exc:
        return _check("disk", "Lokal diskplass", "YELLOW", f"Kunne ikke lese diskplass: {exc}", required=False)


def _process_check() -> dict[str, Any]:
    if os.name != "nt":
        return _check("processes", "Raven-prosesser", "GREEN", "Windows-prosessjekk ikke relevant i denne testøkten", required=False)
    try:
        completed = subprocess.run(
            ["tasklist.exe", "/FI", f"IMAGENAME eq {RAVEN_IMAGE_NAME}", "/FO", "CSV", "/NH"],
            shell=False,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=5,
            check=False,
        )
        lines = [line.strip() for line in completed.stdout.splitlines() if line.strip() and not line.startswith("INFO:")]
        count = sum(1 for line in lines if RAVEN_IMAGE_NAME.casefold() in line.casefold())
        if count <= 1:
            return _check("processes", "Raven-prosesser", "GREEN", f"{count or 1} aktiv Raven-instans forventet", required=False)
        return _check(
            "processes",
            "Raven-prosesser",
            "YELLOW",
            f"{count} Raven-instans(er) funnet",
            required=False,
            problem="Flere Raven-versjoner kan konkurrere om port 18765 eller vise feil UI.",
            fix="Avslutt gamle Raven-instans(er) fra tray/Oppgavebehandling.",
            next_action="Start kun siste Raven EXE og kjør Health Check igjen.",
        )
    except Exception as exc:
        return _check("processes", "Raven-prosesser", "YELLOW", f"Prosessjekk feilet: {str(exc)[:160]}", required=False)


def _lm_studio_check() -> dict[str, Any]:
    request = urllib.request.Request("http://127.0.0.1:1234/v1/models", headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=0.8) as response:
            text = response.read(100_000).decode("utf-8", errors="replace")
        has_model = '"id"' in text
        if has_model:
            return _check("lm-studio", "LM Studio", "GREEN", "Valgfri lokal AI-server svarer og modell ser ut til å være lastet", required=False)
        return _check(
            "lm-studio",
            "LM Studio",
            "YELLOW",
            "Server svarer, men ingen lastet modell ble bekreftet",
            required=False,
            problem="Kun AI-analyseknappene påvirkes.",
            fix="Last en vision-modell hvis du vil bruke lokal bildeanalyse.",
            next_action="Vanlig Vision og LIVE 5s kan brukes uten LM Studio.",
        )
    except (urllib.error.URLError, TimeoutError, OSError):
        return _check(
            "lm-studio",
            "LM Studio",
            "YELLOW",
            "Ikke tilgjengelig — valgfritt",
            required=False,
            problem="Lokal AI-analyse er ikke tilgjengelig.",
            fix="Ingen fix nødvendig for skjermfangst, LIVE 5s eller Quick Check.",
            next_action="Start LM Studio senere hvis lokal bildeanalyse ønskes.",
        )


def build_snapshot(
    *,
    app: Any,
    bridge_version: str,
    project_root: pathlib.Path,
    agent_runner: Any,
    assets: dict[str, tuple[pathlib.Path, str, str]],
) -> dict[str, Any]:
    routes = {rule.rule for rule in app.url_map.iter_rules()}
    checks: list[dict[str, Any]] = []

    checks.append(_check(
        "runtime",
        "Raven runtime",
        "GREEN" if sys.version_info >= (3, 10) else "RED",
        f"Python {platform.python_version()} · Bridge v{bridge_version} · {platform.system()} {platform.release()}",
        problem="Python/runtime er for gammel." if sys.version_info < (3, 10) else "",
        fix="Installer siste Raven one-file EXE." if sys.version_info < (3, 10) else "",
    ))

    required_routes = {
        "/health", "/capture/monitors", "/capture/monitor", "/capture/area",
        "/agent/capabilities", "/agent/run", "/doctor/ui", "/doctor/status",
    }
    missing_routes = sorted(required_routes - routes)
    checks.append(_check(
        "bridge",
        "Raven Bridge",
        "RED" if missing_routes else "GREEN",
        "port 18765 · kjerne-routes OK" if not missing_routes else "Mangler routes: " + ", ".join(missing_routes),
        problem="Canonical Bridge er ufullstendig." if missing_routes else "",
        fix="Installer siste grønne Raven-build." if missing_routes else "",
        next_action="Kjør Doctor igjen." if missing_routes else "",
    ))

    for asset_id, (path, marker, title) in assets.items():
        checks.append(_asset_check(asset_id, title, path, marker))

    chatgpt_path = assets.get("chatgpt-bridge", (project_root / "RAH-RAVEN-CHATGPT.user.js", "", ""))[0]
    try:
        chatgpt_text = chatgpt_path.read_text(encoding="utf-8", errors="replace") if chatgpt_path.is_file() else ""
    except OSError:
        chatgpt_text = ""
    live_supported = "@version      0.4.0" in chatgpt_text and "LIVE_INTERVAL_MS = 5000" in chatgpt_text
    checks.append(_check(
        "live5s",
        "Raven LIVE 5s",
        "GREEN" if live_supported else "RED",
        "Støtte installert · 5 s latest-frame buffer · ingen auto-send" if live_supported else "LIVE 5s-støtte mangler i ChatGPT Bridge-asset",
        problem="Gammel ChatGPT Bridge." if not live_supported else "",
        fix="Installer/oppdater ChatGPT Bridge fra Command Wheel." if not live_supported else "",
        next_action="Fysisk acceptance: skriv «se» i ChatGPT og bekreft at ferskt bilde følger meldingen.",
    ))

    caps = getattr(agent_runner, "CAPABILITIES", {})
    inventory_cap = caps.get("system-inventory") if isinstance(caps, dict) else None
    safety_ok = bool(
        inventory_cap
        and getattr(agent_runner, "AGENT_RUNNER_VERSION", None)
        and "/agent/run" in routes
    )
    checks.append(_check(
        "agent-runner",
        "Raven Agent Runner",
        "GREEN" if safety_ok else "RED",
        f"v{getattr(agent_runner, 'AGENT_RUNNER_VERSION', '?')} · read-only allowlist · system-inventory" if safety_ok else "Agent Runner-systeminventar mangler",
        problem="HOVED-PC Agent proof er ikke tilgjengelig." if not safety_ok else "",
        fix="Installer siste Raven-build." if not safety_ok else "",
        next_action="Kjør HOVED-PC Quick Check." if safety_ok else "Kjør Doctor igjen etter oppdatering.",
    ))

    handoff_routes = {"/agent/chatgpt/quick-check", "/agent/chatgpt/pending", "/agent/chatgpt/ack"}
    handoff_ok = handoff_routes.issubset(routes)
    checks.append(_check(
        "chatgpt-handoff",
        "Quick Check → ChatGPT",
        "GREEN" if handoff_ok else "RED",
        "Composer-draft-only · auto_send=false" if handoff_ok else "ChatGPT handoff-routes mangler",
        problem="Quick Check kan ikke leveres som lokalt ChatGPT-utkast." if not handoff_ok else "",
        fix="Installer siste Raven-build." if not handoff_ok else "",
        next_action="Fysisk acceptance: SEND TIL CHATGPT og kontroller utkastet." if handoff_ok else "Kjør Doctor igjen.",
    ))

    chronicle_ok = "/chronicle/status" in routes and "/chronicle/ui" in routes
    checks.append(_check(
        "chronicle-service",
        "Raven Chronicle",
        "GREEN" if chronicle_ok else "RED",
        "Service + UI routes OK" if chronicle_ok else "Chronicle routes mangler",
        problem="Raven historikk/status er ufullstendig." if not chronicle_ok else "",
        fix="Installer siste Raven-build." if not chronicle_ok else "",
    ))

    daily_ok = "/chronicle/brief-ui" in routes
    checks.append(_check(
        "daily-brief-service",
        "Raven Daily Brief",
        "GREEN" if daily_ok else "RED",
        "Daily Brief route OK" if daily_ok else "Daily Brief route mangler",
        problem="Daily Brief er ikke tilgjengelig." if not daily_ok else "",
        fix="Installer siste Raven-build." if not daily_ok else "",
    ))

    checks.extend([_monitor_check(), _disk_check(), _process_check(), _lm_studio_check()])

    red_required = [item for item in checks if item["required"] and item["status"] == "RED"]
    yellow = [item for item in checks if item["status"] == "YELLOW"]
    overall = "RED" if red_required else ("YELLOW" if yellow else "GREEN")
    counts = {state: sum(1 for item in checks if item["status"] == state) for state in ("GREEN", "YELLOW", "RED")}

    return {
        "ok": overall != "RED",
        "status": overall,
        "version": HEALTH_VERSION,
        "bridge_version": bridge_version,
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "hostname": platform.node() or os.environ.get("COMPUTERNAME") or "ukjent",
        "port": 18765,
        "checks": checks,
        "counts": counts,
        "read_only": True,
        "files_modified": False,
        "automatic_actions": False,
        "lm_studio_required": False,
        "physical_acceptance": {
            "live5s": "PENDING UNTIL CHATGPT RECEIVES A FRESH RAVEN IMAGE",
            "quick_check_to_chatgpt": "PENDING UNTIL THE REAL HOVED-PC DRAFT ARRIVES",
        },
    }
