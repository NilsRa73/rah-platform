from __future__ import annotations

import base64
import hashlib
import io
import json
import os
import platform
import sys
import time
import urllib.error
import urllib.request
import urllib.parse
from typing import Any

from flask import Flask, Response, jsonify, request
from flask_cors import CORS
from PIL import Image
from pypdf import PdfReader
import mss

APP_VERSION = "1.6.0"
CASE_CENTER_VERSION = "1.6.0"
DIRECT_RUN_DISABLED = True
LOOPBACK_HOSTS = {"127.0.0.1", "localhost", "::1"}


def _normalize_loopback_host(value: str) -> str:
    host = str(value or "").strip().lower()
    if host == "[::1]":
        host = "::1"
    if host not in LOOPBACK_HOSTS:
        raise RuntimeError("RAH Desktop Bridge må bindes til en lokal loopback-adresse.")
    return host


def _normalize_loopback_base(value: str, label: str = "lokal tjeneste") -> str:
    raw = str(value or "").strip()
    try:
        parsed = urllib.parse.urlsplit(raw)
        host = (parsed.hostname or "").lower()
        port = parsed.port
    except ValueError as exc:
        raise RuntimeError(f"{label} har ugyldig lokal adresse.") from exc
    if parsed.scheme not in {"http", "https"} or host not in LOOPBACK_HOSTS:
        raise RuntimeError(f"{label} må bruke lokal loopback-adresse.")
    if parsed.username or parsed.password or parsed.query or parsed.fragment or parsed.path not in {"", "/"}:
        raise RuntimeError(f"{label} må bruke en ren lokal baseadresse uten credentials, query, fragment eller sti.")
    shown_host = f"[{host}]" if ":" in host else host
    shown_port = f":{port}" if port is not None else ""
    return f"{parsed.scheme}://{shown_host}{shown_port}"


HOST = _normalize_loopback_host(os.getenv("RAH_BRIDGE_HOST", "127.0.0.1"))
PORT = int(os.getenv("RAH_BRIDGE_PORT", "18765"))
MAX_WIDTH = int(os.getenv("RAH_BRIDGE_MAX_WIDTH", "2200"))
LM_BASE = _normalize_loopback_base(os.getenv("RAH_LM_BASE", "http://127.0.0.1:1234"), "LM Studio")
MAX_UPLOAD_BYTES = int(os.getenv("RAH_CASE_MAX_UPLOAD", str(25 * 1024 * 1024)))
MAX_EXTRACTED_CHARS = int(os.getenv("RAH_CASE_MAX_EXTRACTED_CHARS", "240000"))
MAX_ANALYSIS_CHARS = int(os.getenv("RAH_CASE_MAX_ANALYSIS_CHARS", "160000"))
MAX_DOCUMENTS = int(os.getenv("RAH_CASE_MAX_DOCUMENTS", "24"))

LOCAL_BROWSER_ORIGINS = {
    "null",
    f"http://127.0.0.1:{PORT}",
    f"http://localhost:{PORT}",
    f"http://[::1]:{PORT}",
}
CASE_PROTECTED_PREFIXES = ("/capture/", "/lm/", "/case")

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = MAX_UPLOAD_BYTES
CORS(app, resources={r"/*": {"origins": sorted(LOCAL_BROWSER_ORIGINS)}})


@app.before_request
def protect_case_center_local_apis():
    if not request.path.startswith(CASE_PROTECTED_PREFIXES):
        return None
    origin = (request.headers.get("Origin") or "").rstrip("/")
    if origin and origin not in LOCAL_BROWSER_ORIGINS:
        return jsonify({
            "ok": False,
            "error": "Dette lokale Case Center-endepunktet er ikke tilgjengelig fra fremmede nettsteder.",
        }), 403
    return None


def _active_window_rect() -> dict[str, int] | None:
    if sys.platform != "win32":
        return None
    import ctypes
    from ctypes import wintypes

    user32 = ctypes.windll.user32
    hwnd = user32.GetForegroundWindow()
    if not hwnd:
        return None
    rect = wintypes.RECT()
    if not user32.GetWindowRect(hwnd, ctypes.byref(rect)):
        return None
    width = rect.right - rect.left
    height = rect.bottom - rect.top
    if width < 2 or height < 2:
        return None
    return {
        "left": int(rect.left),
        "top": int(rect.top),
        "width": int(width),
        "height": int(height),
    }


def _fallback_monitor(sct: mss.mss) -> dict[str, int]:
    monitor = sct.monitors[1] if len(sct.monitors) > 1 else sct.monitors[0]
    return {
        "left": int(monitor["left"]),
        "top": int(monitor["top"]),
        "width": int(monitor["width"]),
        "height": int(monitor["height"]),
    }


def capture_active_window() -> tuple[str, dict[str, Any]]:
    with mss.mss() as sct:
        active_rect = _active_window_rect()
        rect = active_rect or _fallback_monitor(sct)
        shot = sct.grab(rect)
        image = Image.frombytes("RGB", shot.size, shot.rgb)
    if image.width > MAX_WIDTH:
        target_height = max(1, round(image.height * MAX_WIDTH / image.width))
        image = image.resize((MAX_WIDTH, target_height), Image.Resampling.LANCZOS)
    buffer = io.BytesIO()
    image.save(buffer, format="PNG", optimize=True)
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}", {
        "width": image.width,
        "height": image.height,
        "capture": "active-window" if active_rect else "primary-monitor",
    }


def _lm_json(
    path: str,
    method: str = "GET",
    payload: dict[str, Any] | None = None,
    timeout: int = 180,
) -> Any:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{LM_BASE}{path}",
        data=body,
        method=method,
        headers={"Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"LM Studio HTTP {exc.code}: {detail[:500]}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"LM Studio er ikke tilgjengelig: {exc.reason}") from exc


def _select_model(requested: str = "") -> str:
    if requested.strip():
        return requested.strip()
    models = _lm_json("/v1/models").get("data", [])
    if not models:
        raise RuntimeError("Ingen modell er lastet i LM Studio.")
    model = str(models[0].get("id") or "").strip()
    if not model:
        raise RuntimeError("LM Studio returnerte ingen gyldig modell-ID.")
    return model


def _lm_chat(system: str, user: str, model: str = "", max_tokens: int = 2600) -> tuple[str, str]:
    selected = _select_model(model)
    payload = {
        "model": selected,
        "temperature": 0.1,
        "max_tokens": max_tokens,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    result = _lm_json("/v1/chat/completions", method="POST", payload=payload)
    answer = result.get("choices", [{}])[0].get("message", {}).get("content", "")
    if not str(answer).strip():
        raise RuntimeError("Den lokale modellen returnerte et tomt svar.")
    return str(answer), selected


def _extract_pdf(raw: bytes) -> tuple[str, dict[str, Any]]:
    reader = PdfReader(io.BytesIO(raw), strict=False)
    warnings: list[str] = []
    if reader.is_encrypted:
        try:
            result = reader.decrypt("")
        except Exception as exc:
            raise ValueError("PDF-en er passordbeskyttet og kan ikke åpnes uten passord.") from exc
        if result == 0:
            raise ValueError("PDF-en er passordbeskyttet og kan ikke åpnes uten passord.")

    parts: list[str] = []
    char_count = 0
    pages_read = 0
    truncated = False
    for index, page in enumerate(reader.pages, start=1):
        try:
            page_text = page.extract_text() or ""
        except Exception as exc:
            warnings.append(f"Side {index} kunne ikke leses: {exc}")
            page_text = ""
        marker = f"\n\n--- Side {index} ---\n"
        remaining = MAX_EXTRACTED_CHARS - char_count
        if remaining <= 0:
            truncated = True
            break
        block = marker + page_text
        if len(block) > remaining:
            block = block[:remaining]
            truncated = True
        parts.append(block)
        char_count += len(block)
        pages_read += 1
        if truncated:
            break

    text = "".join(parts).strip()
    if not text:
        warnings.append(
            "Ingen maskinlesbar tekst ble funnet. Dokumentet kan være skannet som bilder og trenger senere bildeanalyse/OCR."
        )
    return text, {
        "pages_total": len(reader.pages),
        "pages_read": pages_read,
        "truncated": truncated,
        "warnings": warnings,
    }


def _extract_uploaded_file(filename: str, mimetype: str, raw: bytes) -> tuple[str, dict[str, Any]]:
    lower = filename.lower()
    if lower.endswith(".pdf") or mimetype == "application/pdf":
        return _extract_pdf(raw)
    if lower.endswith((".txt", ".md", ".csv", ".json", ".log", ".html", ".htm")) or mimetype.startswith("text/"):
        text = raw.decode("utf-8", errors="replace")
        truncated = len(text) > MAX_EXTRACTED_CHARS
        return text[:MAX_EXTRACTED_CHARS], {
            "pages_total": None,
            "pages_read": None,
            "truncated": truncated,
            "warnings": [],
        }
    raise ValueError("Filtypen støttes ikke ennå. Bruk PDF, TXT, MD, CSV, JSON, LOG eller HTML.")


@app.after_request
def add_headers(response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


@app.errorhandler(413)
def too_large(_error):
    return jsonify({"ok": False, "error": "Filen er større enn den lokale grensen på 25 MB."}), 413


@app.get("/health")
def health():
    return jsonify(
        {
            "ok": True,
            "name": "RAH Raven Desktop Bridge",
            "version": APP_VERSION,
            "platform": platform.platform(),
            "host": HOST,
            "port": PORT,
            "lm_base": LM_BASE,
            "case_center": True,
            "case_center_version": CASE_CENTER_VERSION,
        }
    )


@app.get("/capture/active-window")
def active_window():
    try:
        image, metadata = capture_active_window()
        return jsonify({"ok": True, "image": image, "metadata": metadata})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.get("/capture/after-delay")
def capture_after_delay():
    try:
        seconds = max(1, min(10, int(request.args.get("seconds", "3"))))
        time.sleep(seconds)
        image, metadata = capture_active_window()
        metadata["delay_seconds"] = seconds
        return jsonify({"ok": True, "image": image, "metadata": metadata})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 500


@app.get("/lm/models")
def lm_models():
    try:
        return jsonify(_lm_json("/v1/models"))
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 502


@app.post("/lm/analyze")
def lm_analyze():
    data = request.get_json(silent=True) or {}
    image = str(data.get("image") or "")
    prompt = str(data.get("prompt") or "Les skjermbildet. Ikke gjett. Svar kort på norsk.")
    model = str(data.get("model") or "")
    if not image.startswith("data:image/"):
        return jsonify({"ok": False, "error": "Mangler gyldig bilde."}), 400
    try:
        selected = _select_model(model)
        payload = {
            "model": selected,
            "temperature": 0.1,
            "max_tokens": 1400,
            "messages": [
                {
                    "role": "system",
                    "content": "Du er RAH Raven Vision. Svar på norsk. Ikke gjett uleselig tekst.",
                },
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {"type": "image_url", "image_url": {"url": image}},
                    ],
                },
            ],
        }
        result = _lm_json("/v1/chat/completions", method="POST", payload=payload)
        answer = result.get("choices", [{}])[0].get("message", {}).get("content", "")
        return jsonify({"ok": True, "answer": answer, "model": selected})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 502


@app.post("/case/extract")
def case_extract():
    uploaded = request.files.get("file")
    if uploaded is None or not uploaded.filename:
        return jsonify({"ok": False, "error": "Ingen fil ble mottatt."}), 400
    try:
        raw = uploaded.read()
        if not raw:
            raise ValueError("Filen er tom.")
        if len(raw) > MAX_UPLOAD_BYTES:
            raise ValueError("Filen er større enn den lokale grensen på 25 MB.")
        text, metadata = _extract_uploaded_file(
            uploaded.filename,
            uploaded.mimetype or "application/octet-stream",
            raw,
        )
        return jsonify(
            {
                "ok": True,
                "name": uploaded.filename,
                "mimetype": uploaded.mimetype,
                "size": len(raw),
                "sha256": hashlib.sha256(raw).hexdigest(),
                "text": text,
                "characters": len(text),
                "metadata": metadata,
                "stored": False,
            }
        )
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 400


@app.post("/case/analyze")
def case_analyze():
    data = request.get_json(silent=True) or {}
    raw_documents = data.get("documents") or []
    question = str(
        data.get("question")
        or "Bygg en kronologisk tidslinje og finn viktige mangler, motsetninger, ansvar og frister."
    ).strip()
    model = str(data.get("model") or "")

    if not isinstance(raw_documents, list) or not raw_documents:
        return jsonify({"ok": False, "error": "Legg inn minst ett dokument før analyse."}), 400
    if len(raw_documents) > MAX_DOCUMENTS:
        return jsonify({"ok": False, "error": f"Maksimalt {MAX_DOCUMENTS} dokumenter per analyse."}), 400

    documents: list[tuple[str, str]] = []
    used_chars = 0
    truncated_sources: list[str] = []
    for index, item in enumerate(raw_documents, start=1):
        if not isinstance(item, dict):
            continue
        name = str(item.get("name") or f"Dokument {index}").strip()[:180]
        text = str(item.get("text") or "").strip()
        if not text:
            continue
        remaining = MAX_ANALYSIS_CHARS - used_chars
        if remaining <= 0:
            truncated_sources.append(name)
            break
        if len(text) > remaining:
            text = text[:remaining]
            truncated_sources.append(name)
        documents.append((name, text))
        used_chars += len(text)

    if not documents:
        return jsonify({"ok": False, "error": "Ingen maskinlesbar tekst ble funnet i dokumentene."}), 400

    source_blocks = []
    for index, (name, text) in enumerate(documents, start=1):
        source_blocks.append(f"\n[K{index}] KILDE: {name}\n{text}\n[/K{index}]")

    system = """Du er RAH Raven CaseGuard, en lokal veileder for dokumentkontroll.
Svar på norsk. Arbeid bare ut fra kildene brukeren har levert.

Ufravikelige regler:
1. Ikke still diagnose, ikke avgjør juridisk skyld og ikke lov erstatning eller medhold.
2. Skill tydelig mellom dokumentert opplysning, brukerens egen forklaring, faglig tolkning, bestridt opplysning og det som ikke er funnet.
3. Skriv «ikke funnet i de undersøkte kildene» — aldri «det skjedde ikke» — når dokumentasjon mangler.
4. Bevar datoer, legemiddelnavn, beløp, roller og usikkerhet nøyaktig.
5. Ikke gjør en persons tro eller åndelige språk til sykdom uten at kilden uttrykkelig viser at dette er en faglig vurdering.
6. Ikke la rus, diagnose eller én konflikt overskygge bolig, fysisk helse, økonomi, ensomhet, funksjon eller perioder med bedring.
7. Hver viktig påstand skal få kildehenvisning som [K1], [K2] osv.
8. Marker mulig kommunikasjons- eller dokumentasjonssvikt som et kontrollpunkt, ikke som bevist forsømmelse.

Bruk disse overskriftene:
KORT SAMMENDRAG
KRONOLOGISK TIDSLINJE
DOKUMENTERT I KILDENE
BRUKERENS EGNE OPPLYSNINGER
FAGLIGE TOLKNINGER I KILDENE
MOTSETNINGER ELLER UKLARHETER
MANGLENDE DOKUMENTASJON / UFERDIGE LØSE TRÅDER
ANSVAR, FRISTER OG NESTE KONTROLL
SIKKERHETSNOTE
"""
    user = (
        f"Brukerens oppgave:\n{question}\n\n"
        f"Antall kilder: {len(documents)}. Samlet tekst brukt: {used_chars} tegn.\n"
        + "\n".join(source_blocks)
    )

    try:
        answer, selected = _lm_chat(system, user, model=model)
        return jsonify(
            {
                "ok": True,
                "answer": answer,
                "model": selected,
                "document_count": len(documents),
                "characters_used": used_chars,
                "sources": [name for name, _text in documents],
                "truncated_sources": truncated_sources,
                "stored": False,
                "human_review_required": True,
            }
        )
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 502


LINK_HTML = r'''<!doctype html><html lang="no"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>RAH Link</title><style>:root{color-scheme:dark}body{margin:0;background:#060606;color:#f5f1e6;font:16px Segoe UI,Arial;padding:22px}main{max-width:1100px;margin:auto}.card{background:#111;border:1px solid #5f4816;border-radius:18px;padding:18px;margin:14px 0}h1,h2{color:#ffe28a}.row{display:flex;gap:10px;flex-wrap:wrap}button,a{background:#20190b;color:#ffe28a;border:1px solid #8d691b;border-radius:11px;padding:11px 14px;cursor:pointer;text-decoration:none}button.primary,a.primary{background:linear-gradient(135deg,#ffe68d,#bd8619);color:#171005;font-weight:800}textarea{width:100%;min-height:90px;background:#080808;color:#fff;border:1px solid #4b3a16;border-radius:10px;padding:10px;box-sizing:border-box}img{max-width:100%;max-height:520px;border-radius:12px;border:1px solid #443717;display:none}pre{white-space:pre-wrap;line-height:1.45}.good{color:#72e6a8}.bad{color:#ff9898}</style></head><body><main><h1>🐦‍⬛ RAH Link v1.6</h1><p>Trykk hent-knappen, og bytt straks til vinduet du vil lese. Bildet tas etter 3 sekunder.</p><section class="card"><h2>Forbindelse</h2><div class="row"><button id="test">Test alt</button><button id="capture" class="primary">Hent aktivt vindu om 3 sekunder</button><a href="/case">Åpne Case Center</a></div><p id="status">Ikke testet.</p></section><section class="card"><h2>Skjermbilde</h2><img id="preview" alt="Skjermbilde"></section><section class="card"><h2>Raven Vision</h2><textarea id="prompt">Les bare synlig tekst. Ikke gjett. Forklar kort hva som er på skjermen.</textarea><div class="row"><button id="analyze" class="primary">Analyser</button></div><pre id="answer">Svar vises her.</pre></section></main><script>let image='';const $=id=>document.getElementById(id);async function j(url,opt){const r=await fetch(url,opt);const d=await r.json();if(!r.ok||d.ok===false)throw new Error(d.error||r.statusText);return d}$('test').onclick=async()=>{try{const h=await j('/health');const m=await j('/lm/models');$('status').className='good';$('status').textContent=`Bridge v${h.version} klar. LM Studio: ${(m.data||[]).length} modell(er).`}catch(e){$('status').className='bad';$('status').textContent=e.message}};$('capture').onclick=async()=>{try{$('status').className='';$('status').textContent='Bytt til ønsket vindu nå... 3 sekunder.';const d=await j('/capture/after-delay?seconds=3');image=d.image;$('preview').src=image;$('preview').style.display='block';$('status').className='good';$('status').textContent='Skjermbildet er hentet. Gå tilbake til denne siden.'}catch(e){$('status').className='bad';$('status').textContent=e.message}};$('analyze').onclick=async()=>{if(!image){$('answer').textContent='Hent skjermbilde først.';return}try{$('answer').textContent='Analyserer lokalt...';const d=await j('/lm/analyze',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({image,prompt:$('prompt').value})});$('answer').textContent=d.answer||'Tomt svar.'}catch(e){$('answer').textContent='Feil: '+e.message}}</script></body></html>'''


CASE_HTML = r'''<!doctype html><html lang="no"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>RAH Raven Local Case Center</title><style>:root{color-scheme:dark;--gold:#e1bd5e;--gold2:#ffe18a;--bg:#07080b;--panel:#12151b;--line:#333944;--muted:#a4aab5;--good:#73e6aa;--bad:#ff9898}*{box-sizing:border-box}body{margin:0;min-height:100vh;background:radial-gradient(circle at 80% 0,#d8b75c22,transparent 30%),linear-gradient(135deg,#07080b,#0d1015);color:#f5f1e7;font:16px/1.5 Segoe UI,Arial,sans-serif;padding:22px}main{max-width:1120px;margin:auto}h1{color:var(--gold2);font-size:clamp(30px,5vw,54px);margin:0}h2{color:var(--gold2)}p{color:#c1c6cf}.card{background:#12151bf2;border:1px solid var(--line);border-radius:18px;padding:20px;margin:14px 0}.hero{border-color:#d8b75c66}.row{display:flex;gap:10px;flex-wrap:wrap;align-items:center}button,a.btn{border:1px solid #7d6428;background:#211a0b;color:#ffe59a;border-radius:11px;padding:11px 15px;text-decoration:none;cursor:pointer;font-weight:750}button.primary{background:linear-gradient(135deg,#ffe68d,#bd8619);color:#171005;border:0}button.danger{border-color:#74333a;background:#351b20;color:#ffc2c2}input[type=file]{display:none}textarea{width:100%;min-height:105px;background:#090b0f;color:#fff;border:1px solid #3b424e;border-radius:11px;padding:12px}pre{white-space:pre-wrap;background:#090b0f;border:1px solid #303641;border-radius:12px;padding:16px;min-height:150px;max-height:650px;overflow:auto}.file{display:grid;grid-template-columns:1fr auto;gap:12px;padding:13px;border:1px solid #303641;border-radius:12px;background:#171b22;margin:8px 0}.meta{color:var(--muted);font-size:12px}.good{color:var(--good)}.bad{color:var(--bad)}.notice{border-left:4px solid var(--gold);padding:12px;background:#19160d;border-radius:9px}.status{font-weight:800}.spinner{display:none}.busy .spinner{display:inline}.busy button{opacity:.65;pointer-events:none}@media(max-width:650px){body{padding:12px}.file{grid-template-columns:1fr}}</style></head><body><main><section class="card hero"><h1>🐦‍⬛ RAH Raven Local Case Center v1.6</h1><p>PDF og tekst behandles på din egen PC gjennom Desktop Bridge. Ingenting lagres av serveren, og ingenting sendes videre uten at du trykker.</p><div class="row"><a class="btn" href="/link">Raven Vision</a><button id="test">Test forbindelse</button><span id="connection" class="status">Ikke testet</span></div></section><section class="card"><h2>1. Legg inn dokumenter</h2><div class="row"><label class="btn primary" for="files">Velg PDF eller tekstfiler</label><input id="files" type="file" multiple accept=".pdf,.txt,.md,.csv,.json,.log,.html,.htm"><button id="clear" class="danger">Tøm arbeidslisten</button></div><p class="notice">Originalfilene endres ikke. Raven leser bare maskinlesbar tekst. Skannede PDF-er kan foreløpig kreve Raven Vision.</p><div id="fileList"><p class="meta">Ingen dokumenter lagt inn.</p></div></section><section class="card"><h2>2. Be Raven analysere</h2><textarea id="question">Bygg en kronologisk tidslinje. Skill mellom dokumentert faktum, mine egne opplysninger og behandlerens eller saksbehandlerens tolkning. Finn motsetninger, manglende oppfølging, ansvar, frister og løse tråder. Ikke konkluder med skyld.</textarea><div class="row" style="margin-top:10px"><button id="analyze" class="primary">Kjør lokal kildeanalyse</button><button id="download">Lagre analysen som tekst</button><span class="spinner">Raven arbeider…</span></div><p id="analysisStatus" class="meta">Menneskelig kontroll kreves før teksten brukes.</p><pre id="answer">Analysen vises her.</pre></section></main><script>'use strict';const docs=[];let lastAnswer='';const $=id=>document.getElementById(id);function esc(s){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}async function api(url,opt){const r=await fetch(url,opt);let d;try{d=await r.json()}catch{throw new Error('Ugyldig svar fra Desktop Bridge.')}if(!r.ok||d.ok===false)throw new Error(d.error||r.statusText);return d}function render(){const root=$('fileList');if(!docs.length){root.innerHTML='<p class="meta">Ingen dokumenter lagt inn.</p>';return}root.innerHTML=docs.map((d,i)=>`<div class="file"><div><strong>${esc(d.name)}</strong><div class="meta">${d.characters.toLocaleString('no-NO')} tegn${d.metadata.pages_total?` · ${d.metadata.pages_read}/${d.metadata.pages_total} sider`:''} · SHA-256 ${d.sha256.slice(0,12)}…${d.metadata.truncated?' · forkortet':''}</div>${(d.metadata.warnings||[]).map(w=>`<div class="bad meta">${esc(w)}</div>`).join('')}</div><button onclick="removeDoc(${i})">Fjern</button></div>`).join('')}window.removeDoc=i=>{docs.splice(i,1);render()};async function extract(files){document.body.classList.add('busy');$('analysisStatus').textContent='Leser filer lokalt…';try{for(const file of files){const form=new FormData();form.append('file',file);const d=await api('/case/extract',{method:'POST',body:form});docs.push(d);render()}$('analysisStatus').textContent=`${docs.length} dokument(er) klare. Ingenting er lagret av serveren.`}catch(e){$('analysisStatus').textContent='Feil: '+e.message;$('analysisStatus').className='bad'}finally{document.body.classList.remove('busy');$('files').value=''}}$('files').onchange=e=>extract([...e.target.files]);$('clear').onclick=()=>{docs.length=0;lastAnswer='';$('answer').textContent='Analysen vises her.';$('analysisStatus').textContent='Arbeidslisten er tømt.';render()};$('test').onclick=async()=>{try{const h=await api('/health');const m=await api('/lm/models');$('connection').className='status good';$('connection').textContent=`Bridge v${h.version} · ${(m.data||[]).length} lokal modell`}catch(e){$('connection').className='status bad';$('connection').textContent=e.message}};$('analyze').onclick=async()=>{if(!docs.length){$('analysisStatus').textContent='Legg inn minst ett dokument først.';return}document.body.classList.add('busy');$('answer').textContent='Raven bygger kildebasert oversikt…';$('analysisStatus').className='meta';try{const d=await api('/case/analyze',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({question:$('question').value,documents:docs.map(x=>({name:x.name,text:x.text}))})});lastAnswer=d.answer;$('answer').textContent=d.answer;$('analysisStatus').textContent=`Ferdig med ${d.document_count} kilder via ${d.model}. ${d.truncated_sources.length?'Noen kilder ble forkortet. ':''}Menneskelig kontroll kreves.`}catch(e){$('answer').textContent='Feil: '+e.message;$('analysisStatus').textContent='Analysen ble ikke fullført.'}finally{document.body.classList.remove('busy')}};$('download').onclick=()=>{if(!lastAnswer){$('analysisStatus').textContent='Kjør en analyse først.';return}const source=docs.map((d,i)=>`K${i+1}: ${d.name} · SHA-256 ${d.sha256}`).join('\n');const text=`RAH RAVEN CASE ANALYSE\nDato: ${new Date().toLocaleString('no-NO')}\n\nKILDER\n${source}\n\n${lastAnswer}\n\nIKKE FAGLIG GODKJENT: Må kontrolleres av menneske før bruk.`;const u=URL.createObjectURL(new Blob([text],{type:'text/plain;charset=utf-8'}));const a=document.createElement('a');a.href=u;a.download='RAH-Raven-Case-Analyse.txt';a.click();URL.revokeObjectURL(u)};render();</script></body></html>'''


@app.get("/link")
def link_portal():
    return Response(LINK_HTML, mimetype="text/html")


@app.get("/case")
def case_portal():
    return Response(CASE_HTML, mimetype="text/html")


@app.get("/")
def root():
    return jsonify(
        {
            "service": "RAH Raven Desktop Bridge",
            "health": "/health",
            "capture": "/capture/active-window",
            "delayed_capture": "/capture/after-delay?seconds=3",
            "lm_models": "/lm/models",
            "rah_link": "/link",
            "case_center": "/case",
            "case_extract": "/case/extract",
            "case_analyze": "/case/analyze",
        }
    )


if __name__ == "__main__":
    print(f"RAH Raven Desktop Bridge library v{APP_VERSION}")
    print("Direkte oppstart av server_v16.py er deaktivert av sikkerhetsgrunner.")
    print("Start desktop-bridge/raven_bridge.py via Raven one-click launcher i stedet.")
    raise SystemExit(2)
