from __future__ import annotations

import base64
import io
import json
import os
import platform
import sys
import time
import urllib.error
import urllib.request
from typing import Any

from flask import Flask, Response, jsonify, request
from flask_cors import CORS
from PIL import Image
import mss

APP_VERSION = "1.5.0"
HOST = os.getenv("RAH_BRIDGE_HOST", "127.0.0.1")
PORT = int(os.getenv("RAH_BRIDGE_PORT", "18765"))
MAX_WIDTH = int(os.getenv("RAH_BRIDGE_MAX_WIDTH", "2200"))
LM_BASE = os.getenv("RAH_LM_BASE", "http://127.0.0.1:1234")

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})


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
    return {"left": int(rect.left), "top": int(rect.top), "width": int(width), "height": int(height)}


def _fallback_monitor(sct: mss.mss) -> dict[str, int]:
    monitor = sct.monitors[1] if len(sct.monitors) > 1 else sct.monitors[0]
    return {"left": int(monitor["left"]), "top": int(monitor["top"]), "width": int(monitor["width"]), "height": int(monitor["height"])}


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


def _lm_json(path: str, method: str = "GET", payload: dict[str, Any] | None = None) -> Any:
    body = None if payload is None else json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(f"{LM_BASE}{path}", data=body, method=method, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"LM Studio HTTP {exc.code}: {detail[:500]}") from exc
    except urllib.error.URLError as exc:
        raise RuntimeError(f"LM Studio er ikke tilgjengelig: {exc.reason}") from exc


@app.after_request
def add_headers(response):
    response.headers["Cache-Control"] = "no-store"
    response.headers["X-Content-Type-Options"] = "nosniff"
    return response


@app.get("/health")
def health():
    return jsonify({"ok": True, "name": "RAH Raven Desktop Bridge", "version": APP_VERSION, "platform": platform.platform(), "host": HOST, "port": PORT, "lm_base": LM_BASE})


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
        models = _lm_json("/v1/models").get("data", [])
        if not model and models:
            model = str(models[0].get("id") or "")
        if not model:
            raise RuntimeError("Ingen modell er lastet i LM Studio.")
        payload = {
            "model": model,
            "temperature": 0.1,
            "max_tokens": 1400,
            "messages": [
                {"role": "system", "content": "Du er RAH Raven Vision. Svar på norsk. Ikke gjett uleselig tekst."},
                {"role": "user", "content": [{"type": "text", "text": prompt}, {"type": "image_url", "image_url": {"url": image}}]},
            ],
        }
        result = _lm_json("/v1/chat/completions", method="POST", payload=payload)
        answer = result.get("choices", [{}])[0].get("message", {}).get("content", "")
        return jsonify({"ok": True, "answer": answer, "model": model})
    except Exception as exc:
        return jsonify({"ok": False, "error": str(exc)}), 502


LINK_HTML = r'''<!doctype html><html lang="no"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>RAH Link</title><style>:root{color-scheme:dark}body{margin:0;background:#060606;color:#f5f1e6;font:16px Segoe UI,Arial;padding:22px}main{max-width:1100px;margin:auto}.card{background:#111;border:1px solid #5f4816;border-radius:18px;padding:18px;margin:14px 0}h1,h2{color:#ffe28a}.row{display:flex;gap:10px;flex-wrap:wrap}button{background:#20190b;color:#ffe28a;border:1px solid #8d691b;border-radius:11px;padding:11px 14px;cursor:pointer}button.primary{background:linear-gradient(135deg,#ffe68d,#bd8619);color:#171005;font-weight:800}textarea{width:100%;min-height:90px;background:#080808;color:#fff;border:1px solid #4b3a16;border-radius:10px;padding:10px;box-sizing:border-box}img{max-width:100%;max-height:520px;border-radius:12px;border:1px solid #443717;display:none}pre{white-space:pre-wrap;line-height:1.45}.good{color:#72e6a8}.bad{color:#ff9898}</style></head><body><main><h1>🐦‍⬛ RAH Link v1.5</h1><p>Trykk hent-knappen, og bytt straks til vinduet du vil lese. Bildet tas etter 3 sekunder.</p><section class="card"><h2>Forbindelse</h2><div class="row"><button id="test">Test alt</button><button id="capture" class="primary">Hent aktivt vindu om 3 sekunder</button></div><p id="status">Ikke testet.</p></section><section class="card"><h2>Skjermbilde</h2><img id="preview" alt="Skjermbilde"></section><section class="card"><h2>Raven Vision</h2><textarea id="prompt">Les bare synlig tekst. Ikke gjett. Forklar kort hva som er på skjermen.</textarea><div class="row"><button id="analyze" class="primary">Analyser</button></div><pre id="answer">Svar vises her.</pre></section></main><script>let image='';const $=id=>document.getElementById(id);async function j(url,opt){const r=await fetch(url,opt);const d=await r.json();if(!r.ok||d.ok===false)throw new Error(d.error||r.statusText);return d}$('test').onclick=async()=>{try{const h=await j('/health');const m=await j('/lm/models');$('status').className='good';$('status').textContent=`Bridge v${h.version} klar. LM Studio: ${(m.data||[]).length} modell(er).`}catch(e){$('status').className='bad';$('status').textContent=e.message}};$('capture').onclick=async()=>{try{$('status').className='';$('status').textContent='Bytt til ønsket vindu nå... 3 sekunder.';const d=await j('/capture/after-delay?seconds=3');image=d.image;$('preview').src=image;$('preview').style.display='block';$('status').className='good';$('status').textContent='Skjermbildet er hentet. Gå tilbake til denne siden.'}catch(e){$('status').className='bad';$('status').textContent=e.message}};$('analyze').onclick=async()=>{if(!image){$('answer').textContent='Hent skjermbilde først.';return}try{$('answer').textContent='Analyserer lokalt...';const d=await j('/lm/analyze',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({image,prompt:$('prompt').value})});$('answer').textContent=d.answer||'Tomt svar.'}catch(e){$('answer').textContent='Feil: '+e.message}}</script></body></html>'''


@app.get("/link")
def link_portal():
    return Response(LINK_HTML, mimetype="text/html")


@app.get("/")
def root():
    return jsonify({"service": "RAH Raven Desktop Bridge", "health": "/health", "capture": "/capture/active-window", "delayed_capture": "/capture/after-delay?seconds=3", "lm_models": "/lm/models", "rah_link": "/link"})


if __name__ == "__main__":
    print(f"RAH Raven Desktop Bridge v{APP_VERSION}")
    print(f"Listening on http://{HOST}:{PORT}")
    app.run(host=HOST, port=PORT, debug=False, threaded=True)
