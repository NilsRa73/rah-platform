#!/usr/bin/env python3
# RAH World Media v9.9 — SUPER MODE
# Gold Command Deck: TV + Radio + Webcams + World Live + Super Search + 12-screen mosaic.

from __future__ import annotations

import json
import math
import os
import random
import html
import queue
import re
import shutil
import subprocess
import threading
import time
import urllib.parse
import urllib.request
import webbrowser
from dataclasses import dataclass, asdict
from pathlib import Path
from tkinter import Tk, Toplevel, StringVar, BooleanVar, END, BOTH, LEFT, RIGHT, X, Y, VERTICAL, HORIZONTAL
from tkinter import ttk, messagebox, filedialog, simpledialog

APP_NAME = "RAH World Media"
VERSION = "9.9"
APP_DIR = Path(__file__).resolve().parent
WORLD_FILE = APP_DIR / "world_countries_simplified.json"
BASE_DIR = Path(os.environ.get("RAH_IPTV_HOME", r"C:\RAH\IPTV"))
CACHE_DIR = BASE_DIR / "cache"
STATE_FILE = BASE_DIR / "state_v99.json"
LEGACY_STATE_FILE = BASE_DIR / "state_v6.json"
TV_FAV_FILE = BASE_DIR / "favorites_tv.json"
RADIO_FAV_FILE = BASE_DIR / "favorites_radio.json"
WEBCAM_FAV_FILE = BASE_DIR / "favorites_webcams.json"
WEBCAM_FAV_ITEMS_FILE = BASE_DIR / "favorites_webcam_items.json"
FAVORITE_PLACES_FILE = BASE_DIR / "favorite_places.json"
WEBCAM_KEY_FILE = BASE_DIR / "windy_webcams_api_key.txt"
CUSTOM_FILE = BASE_DIR / "custom_channels.json"
TV_HISTORY_FILE = BASE_DIR / "history_tv.json"
RADIO_HISTORY_FILE = BASE_DIR / "history_radio.json"
WEBCAM_HISTORY_FILE = BASE_DIR / "history_webcams.json"
MEDIA_WALL_FILE = BASE_DIR / "media_wall_v99.html"
HEALTH_CACHE_FILE = BASE_DIR / "stream_health_v99.json"

TV_API = {
    "channels": "https://iptv-org.github.io/api/channels.json",
    "streams": "https://iptv-org.github.io/api/streams.json",
    "countries": "https://iptv-org.github.io/api/countries.json",
    "categories": "https://iptv-org.github.io/api/categories.json",
    "logos": "https://iptv-org.github.io/api/logos.json",
}
RADIO_APIS = [
    "https://de1.api.radio-browser.info",
    "https://de2.api.radio-browser.info",
    "https://nl1.api.radio-browser.info",
]
WEBCAM_API = "https://api.windy.com/webcams/api/v3"

GOLD = "#d7ad42"
GOLD2 = "#a9832e"
BG = "#0b0c0e"
PANEL = "#14161a"
PANEL2 = "#1d2025"
TEXT = "#f1ead8"
MUTED = "#a9a390"
ACCENT = "#f8d26a"
OCEAN = "#0e1520"
GRID = "#233042"

WEBCAM_THEME_MAP = {
    "ALL": (),
    "NORTHERN LIGHTS": ("aurora", "northern lights", "polar", "arctic"),
    "WEATHER": ("weather", "sky", "cloud", "storm", "snow", "rain"),
    "TRAFFIC": ("traffic", "road", "highway", "street", "intersection"),
    "BEACHES": ("beach", "coast", "sea", "ocean", "surf"),
    "HARBORS": ("harbor", "harbour", "port", "marina", "fjord"),
    "MOUNTAINS": ("mountain", "alps", "ski", "summit", "peak"),
    "CITY": ("city", "downtown", "square", "street", "urban"),
}


@dataclass
class TVChannel:
    id: str
    name: str
    country: str
    country_name: str
    categories: list[str]
    url: str
    quality: str
    labels: list[str]
    logo: str = ""
    website: str = ""
    source: str = "iptv-org"

    @property
    def category_text(self):
        return ", ".join(self.categories) if self.categories else "general"

    @property
    def label_text(self):
        return ", ".join(self.labels)


@dataclass
class RadioStation:
    uuid: str
    name: str
    country: str
    countrycode: str
    state: str
    language: str
    tags: str
    codec: str
    bitrate: int
    url: str
    homepage: str
    favicon: str
    votes: int
    clickcount: int


@dataclass
class Webcam:
    webcam_id: str
    title: str
    status: str
    country: str
    countrycode: str
    region: str
    city: str
    latitude: float
    longitude: float
    categories: list[str]
    image_url: str
    player_url: str
    detail_url: str
    is_live: bool


def ensure_dirs():
    BASE_DIR.mkdir(parents=True, exist_ok=True)
    CACHE_DIR.mkdir(parents=True, exist_ok=True)


def read_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return default


def write_json(path: Path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(json.dumps(obj, ensure_ascii=False, indent=2), encoding="utf-8")
    tmp.replace(path)


def http_json(url: str, timeout=35):
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": f"RAH-World-TV-Radio/{VERSION}",
            "Accept": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", errors="replace"))


def radio_json(endpoint: str, params=None, timeout=35):
    query = ""
    if params:
        query = "?" + urllib.parse.urlencode(params)
    last = None
    for base in RADIO_APIS:
        try:
            return http_json(f"{base}/json/{endpoint.lstrip('/')}" + query, timeout=timeout)
        except Exception as e:
            last = e
    if last:
        raise last
    raise RuntimeError("No Radio Browser mirror available")


def push_history(path: Path, item: dict, key: str, limit=40):
    rows = read_json(path, [])
    value = str(item.get(key, ""))
    rows = [x for x in rows if str(x.get(key, "")) != value]
    item = dict(item)
    item["played_at"] = int(time.time())
    rows.insert(0, item)
    write_json(path, rows[:limit])


def windy_api_key():
    key = os.environ.get("WINDY_WEBCAMS_API_KEY", "").strip()
    if key:
        return key
    try:
        return WEBCAM_KEY_FILE.read_text(encoding="utf-8").strip()
    except Exception:
        return ""


def windy_json(url: str, timeout=35):
    key = windy_api_key()
    if not key:
        raise RuntimeError("WINDY_WEBCAMS_API_KEY is not configured")
    req = urllib.request.Request(
        url,
        headers={
            "User-Agent": f"RAH-World-Media/{VERSION}",
            "Accept": "application/json",
            "X-WINDY-API-KEY": key,
        },
    )
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", errors="replace"))


def fetch_tv_json(name: str, force=False, max_age_hours=8):
    ensure_dirs()
    p = CACHE_DIR / f"tv_{name}.json"
    if p.exists() and not force:
        age = time.time() - p.stat().st_mtime
        if age < max_age_hours * 3600:
            return read_json(p, [])
    data = http_json(TV_API[name])
    write_json(p, data)
    return data


def locate_vlc():
    candidates = [
        shutil.which("vlc"),
        os.path.expandvars(r"%PROGRAMFILES%\VideoLAN\VLC\vlc.exe"),
        os.path.expandvars(r"%PROGRAMFILES(X86)%\VideoLAN\VLC\vlc.exe"),
        str(Path.home() / "scoop" / "apps" / "vlc" / "current" / "vlc.exe"),
    ]
    for p in candidates:
        if p and Path(p).exists():
            return p
    return None


def play_url(url: str):
    vlc = locate_vlc()
    if not vlc:
        raise FileNotFoundError("VLC ble ikke funnet")
    subprocess.Popen([vlc, "--one-instance", "--playlist-enqueue", url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def normalize(s):
    return re.sub(r"\s+", " ", (s or "").strip()).casefold()


def parse_m3u(path: Path):
    text = path.read_text(encoding="utf-8", errors="ignore")
    out = []
    meta = None
    for raw in text.splitlines():
        line = raw.strip()
        if line.startswith("#EXTINF"):
            name = line.rsplit(",", 1)[-1].strip() or "Custom channel"
            group = ""
            m = re.search(r'group-title="([^"]*)"', line)
            if m:
                group = m.group(1)
            meta = (name, group)
        elif line and not line.startswith("#") and meta:
            name, group = meta
            out.append({
                "id": f"custom:{len(out)}:{name}",
                "name": name,
                "country": "CUSTOM",
                "country_name": "Custom M3U",
                "categories": [group] if group else ["custom"],
                "url": line,
                "quality": "",
                "labels": [],
                "logo": "",
                "website": "",
                "source": "custom",
            })
            meta = None
    return out


def blend(c1, c2, t):
    t = max(0.0, min(1.0, t))
    a = tuple(int(c1[i:i+2], 16) for i in (1, 3, 5))
    b = tuple(int(c2[i:i+2], 16) for i in (1, 3, 5))
    rgb = tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))
    return '#%02x%02x%02x' % rgb


def load_world_shapes():
    return read_json(WORLD_FILE, [])


class App:
    def __init__(self, root: Tk):
        self.root = root
        self.root.title(f"{APP_NAME} {VERSION}")
        self.root.geometry("1620x930")
        self.root.minsize(1150, 700)

        ensure_dirs()
        self.state = read_json(STATE_FILE, read_json(LEGACY_STATE_FILE, {}))
        self.tv_favorites = set(read_json(TV_FAV_FILE, []))
        self.radio_favorites = set(read_json(RADIO_FAV_FILE, []))
        self.webcam_favorites = set(read_json(WEBCAM_FAV_FILE, []))
        self.webcam_favorite_items = read_json(WEBCAM_FAV_ITEMS_FILE, [])
        self.favorite_places = read_json(FAVORITE_PLACES_FILE, [])
        self.tv_history = read_json(TV_HISTORY_FILE, [])
        self.radio_history = read_json(RADIO_HISTORY_FILE, [])
        self.webcam_history = read_json(WEBCAM_HISTORY_FILE, [])
        self.world_shapes = load_world_shapes()

        self.tv_channels = []
        self.tv_filtered = []
        self.radio_stations = []
        self.radio_filtered = []
        self.radio_countries = []
        self.radio_country_counts = {}
        self.webcams = []
        self.webcam_filtered = []
        self.webcam_country_counts = {}
        self.webcam_loading = False
        self.tv_counts_by_iso = {}
        self.tv_country_name_by_iso = {}
        self.msgq = queue.Queue()
        self.tv_loading = False
        self.radio_loading = False
        self.globe_preview_loading = False
        self.globe_preview_request = 0
        self.globe_selected_iso = None
        self.globe_selected_name = None
        self.globe_tv_preview_items = []
        self.globe_radio_preview_items = []
        self.globe_webcam_preview_items = []
        self.globe_layer_var = StringVar(value=self.state.get("globe_layer", "ALL"))
        self.auto_rotate_var = BooleanVar(value=bool(self.state.get("globe_auto_rotate", True)))
        self.world_live_var = BooleanVar(value=bool(self.state.get("world_live", False)))
        self.world_live_interval = int(self.state.get("world_live_interval", 18) or 18)
        self.world_live_next_ts = 0.0
        self.world_live_last_iso = None
        self.super_mode_var = BooleanVar(value=bool(self.state.get("super_mode", True)))
        self.super_scene_var = StringVar(value=self.state.get("super_scene", "WORLD"))
        self.stream_health_cache = read_json(HEALTH_CACHE_FILE, {})
        self.webcam_theme_var = StringVar(value=self.state.get("webcam_theme", "ALL"))
        self.country_jump_var = StringVar(value="")
        self.home_tv_var = StringVar(value="TV: loading…")
        self.home_radio_var = StringVar(value="Radio: loading…")
        self.home_webcam_var = StringVar(value="Webcams: connect key")
        self.home_network_var = StringVar(value="Network: ready")
        self.globe_hover_text = StringVar(value="Dra for å rotere globusen • Klikk et land")
        self.globe_selected_text = StringVar(value="No country selected")
        self.globe_selected_counts = StringVar(value="TV: 0 • Radio: 0 • Webcams: —")
        self.status_var = StringVar(value="Klar.")
        self.globe_lon0 = float(self.state.get("globe_lon0", 0.0))
        self.globe_lat0 = float(self.state.get("globe_lat0", 15.0))
        self.globe_zoom = float(self.state.get("globe_zoom", 1.0))
        self._drag_last = None
        self._skip_click = False

        self.setup_style()
        self.build_ui()
        self.root.after(120, self.poll_queue)
        self.root.after(500, self.auto_rotate_tick)
        self.root.after(900, self.world_live_tick)

        self.load_tv_async()
        self.load_radio_countries_async()
        self.load_radio_async(mode="top")
        self.redraw_globe()

    def setup_style(self):
        style = ttk.Style(self.root)
        try:
            style.theme_use("clam")
        except Exception:
            pass
        self.root.configure(bg=BG)
        style.configure(".", background=BG, foreground=TEXT, fieldbackground=PANEL2, font=("Segoe UI", 10))
        style.configure("TFrame", background=BG)
        style.configure("Panel.TFrame", background=PANEL)
        style.configure("TLabel", background=BG, foreground=TEXT)
        style.configure("Muted.TLabel", foreground=MUTED)
        style.configure("Title.TLabel", font=("Segoe UI Semibold", 21), foreground=GOLD)
        style.configure("Gold.TButton", background=GOLD2, foreground="#ffffff", padding=8)
        style.map("Gold.TButton", background=[("active", GOLD)])
        style.configure("TButton", background=PANEL2, foreground=TEXT, padding=7)
        style.map("TButton", background=[("active", "#2a2e35")])
        style.configure("TEntry", fieldbackground=PANEL2, foreground=TEXT, insertcolor=TEXT, padding=7)
        style.configure("TCombobox", fieldbackground=PANEL2, background=PANEL2, foreground=TEXT)
        style.configure("Treeview", background=PANEL, fieldbackground=PANEL, foreground=TEXT, rowheight=26, borderwidth=0)
        style.configure("Treeview.Heading", background=PANEL2, foreground=GOLD, relief="flat", font=("Segoe UI Semibold", 10))
        style.map("Treeview", background=[("selected", "#4a3c18")], foreground=[("selected", "#ffffff")])
        style.configure("TCheckbutton", background=BG, foreground=TEXT)
        style.configure("TNotebook", background=BG, borderwidth=0)
        style.configure("TNotebook.Tab", background=PANEL2, foreground=TEXT, padding=(18, 9))
        style.map("TNotebook.Tab", background=[("selected", GOLD2)], foreground=[("selected", "#ffffff")])

    def build_ui(self):
        top = ttk.Frame(self.root)
        top.pack(fill=X, padx=14, pady=(12, 8))
        ttk.Label(top, text="RAH WORLD MEDIA", style="Title.TLabel").pack(side=LEFT)
        ttk.Label(top, text="  SUPER MODE • Globe • TV • Radio • Webcams", style="Muted.TLabel").pack(side=LEFT, padx=10)
        ttk.Button(top, text="🌍 RADIO GARDEN", style="Gold.TButton", command=lambda: webbrowser.open("https://radio.garden/")).pack(side=RIGHT, padx=4)
        ttk.Checkbutton(top, text="⚡ SUPER MODE", variable=self.super_mode_var, command=self.on_super_mode_toggle).pack(side=RIGHT, padx=6)
        ttk.Button(top, text="⌘ SUPER SEARCH", command=self.super_search).pack(side=RIGHT, padx=4)
        ttk.Button(top, text="✨ MEDIA WALL", command=self.open_media_wall).pack(side=RIGHT, padx=4)
        ttk.Button(top, text="▦ TV MOSAIC", command=self.open_media_wall).pack(side=RIGHT, padx=4)
        ttk.Checkbutton(top, text="🌍 WORLD LIVE", variable=self.world_live_var, command=self.on_world_live_toggle).pack(side=RIGHT, padx=6)
        ttk.Button(top, text="🎲 SURPRISE", command=self.surprise_country).pack(side=RIGHT, padx=4)

        self.tabs = ttk.Notebook(self.root)
        self.tabs.pack(fill=BOTH, expand=True, padx=14, pady=(0, 8))
        self.home_tab = ttk.Frame(self.tabs)
        self.globe_tab = ttk.Frame(self.tabs)
        self.tv_tab = ttk.Frame(self.tabs)
        self.radio_tab = ttk.Frame(self.tabs)
        self.webcam_tab = ttk.Frame(self.tabs)
        self.tabs.add(self.home_tab, text="⌂ HOME")
        self.tabs.add(self.globe_tab, text="🌐 GLOBE")
        self.tabs.add(self.tv_tab, text="📺 WORLD TV")
        self.tabs.add(self.radio_tab, text="📻 WORLD RADIO")
        self.tabs.add(self.webcam_tab, text="📷 WEBCAMS")

        self.build_home_tab()
        self.build_globe_tab()
        self.build_tv_tab()
        self.build_radio_tab()
        self.build_webcam_tab()

        footer = ttk.Frame(self.root)
        footer.pack(fill=X, padx=14, pady=(0, 10))
        ttk.Label(footer, text="RAH World Media v9.9 SUPER MODE • public/legal streams • explicit heavy playback only • no DRM bypass", style="Muted.TLabel").pack(side=LEFT)
        ttk.Label(footer, textvariable=self.status_var, style="Muted.TLabel").pack(side=RIGHT)

    # ---------- Home / Command Deck ----------

    def build_home_tab(self):
        outer = ttk.Frame(self.home_tab)
        outer.pack(fill=BOTH, expand=True, padx=18, pady=18)
        ttk.Label(outer, text="RAH WORLD MEDIA", style="Title.TLabel").pack(anchor="w")
        ttk.Label(outer, text="SUPER MODE  •  WORLD LIVE  •  12-SCREEN MOSAIC  •  SUPER SEARCH", style="Muted.TLabel").pack(anchor="w", pady=(2, 16))

        stats = ttk.Frame(outer)
        stats.pack(fill=X)
        for var, caption in ((self.home_tv_var, "WORLD TV"), (self.home_radio_var, "WORLD RADIO"), (self.home_webcam_var, "WEBCAMS"), (self.home_network_var, "SYSTEM")):
            card = ttk.Frame(stats, style="Panel.TFrame", padding=12)
            card.pack(side=LEFT, fill=X, expand=True, padx=(0, 8))
            ttk.Label(card, text=caption, style="Muted.TLabel").pack(anchor="w")
            ttk.Label(card, textvariable=var, style="Title.TLabel").pack(anchor="w", pady=(4, 0))

        quick = ttk.Frame(outer)
        quick.pack(fill=X, pady=(18, 12))
        ttk.Button(quick, text="🌐 OPEN GLOBE", style="Gold.TButton", command=lambda: self.tabs.select(self.globe_tab)).pack(side=LEFT, padx=(0, 6))
        ttk.Button(quick, text="✨ OPEN MEDIA WALL", command=self.open_media_wall).pack(side=LEFT, padx=6)
        ttk.Button(quick, text="▦ TV MOSAIC 4/6/9/12", command=self.open_media_wall).pack(side=LEFT, padx=6)
        ttk.Button(quick, text="⌘ SUPER SEARCH", command=self.super_search).pack(side=LEFT, padx=6)
        ttk.Checkbutton(quick, text="🌍 WORLD LIVE", variable=self.world_live_var, command=self.on_world_live_toggle).pack(side=LEFT, padx=6)
        ttk.Button(quick, text="🎲 SURPRISE COUNTRY", command=self.surprise_country).pack(side=LEFT, padx=6)
        ttk.Button(quick, text="↻ REFRESH DATA", command=self.refresh_all).pack(side=LEFT, padx=6)
        ttk.Button(quick, text="📷 WINDY WEBCAMS", command=lambda: webbrowser.open("https://www.windy.com/webcams")).pack(side=RIGHT, padx=6)

        scenes = ttk.Frame(outer)
        scenes.pack(fill=X, pady=(0, 12))
        ttk.Label(scenes, text="SUPER SCENES", style="Muted.TLabel").pack(side=LEFT, padx=(0, 8))
        for scene in ("WORLD", "NEWS", "SPORTS", "MUSIC", "NORDICS", "CAMS", "RANDOM"):
            ttk.Button(scenes, text=scene, command=lambda x=scene: self.apply_super_scene(x)).pack(side=LEFT, padx=3)

        jump = ttk.Frame(outer)
        jump.pack(fill=X, pady=(0, 12))
        ttk.Label(jump, text="QUICK JUMP", style="Muted.TLabel").pack(side=LEFT, padx=(0, 8))
        vals = sorted(f"{(x.get('iso_a2') or '').upper()} — {x.get('name','')}" for x in self.world_shapes if x.get('iso_a2'))
        box = ttk.Combobox(jump, textvariable=self.country_jump_var, values=vals, state="readonly", width=42)
        box.pack(side=LEFT)
        box.bind("<<ComboboxSelected>>", lambda e: self.jump_to_country())
        ttk.Button(jump, text="GO", command=self.jump_to_country).pack(side=LEFT, padx=6)

        ttk.Label(outer, text="RECENT ACTIVITY", style="Muted.TLabel").pack(anchor="w", pady=(6, 4))
        recent_wrap = ttk.Frame(outer)
        recent_wrap.pack(fill=BOTH, expand=True)
        self.home_recent_tree = ttk.Treeview(recent_wrap, columns=("type","name","place"), show="headings", height=12)
        for col, title, width in (("type","TYPE",100),("name","NAME",420),("place","COUNTRY / LOCATION",260)):
            self.home_recent_tree.heading(col, text=title)
            self.home_recent_tree.column(col, width=width, stretch=True)
        ys = ttk.Scrollbar(recent_wrap, orient=VERTICAL, command=self.home_recent_tree.yview)
        self.home_recent_tree.configure(yscrollcommand=ys.set)
        self.home_recent_tree.pack(side=LEFT, fill=BOTH, expand=True)
        ys.pack(side=RIGHT, fill=Y)
        self.refresh_home()

    def refresh_home(self):
        if hasattr(self, "home_recent_tree"):
            self.home_recent_tree.delete(*self.home_recent_tree.get_children())
            rows=[]
            for x in self.tv_history[:12]: rows.append((x.get("played_at",0), "TV", x.get("name",""), x.get("country_name", x.get("country",""))))
            for x in self.radio_history[:12]: rows.append((x.get("played_at",0), "RADIO", x.get("name",""), x.get("country", x.get("countrycode",""))))
            for x in self.webcam_history[:12]: rows.append((x.get("played_at",0), "WEBCAM", x.get("title",""), ", ".join(v for v in [x.get("city",""),x.get("region",""),x.get("country","")] if v)))
            rows.sort(key=lambda r:r[0], reverse=True)
            for i,(_,typ,name,place) in enumerate(rows[:30]):
                self.home_recent_tree.insert("", END, iid=str(i), values=(typ,name,place))
        self.home_tv_var.set(f"{len(self.tv_channels):,} streams" if self.tv_channels else "loading…")
        if self.radio_country_counts:
            self.home_radio_var.set(f"{sum(int(x.get('count',0)) for x in self.radio_country_counts.values()):,} stations")
        else:
            self.home_radio_var.set("loading…")
        self.home_webcam_var.set("API connected" if windy_api_key() else "optional API key")
        self.home_network_var.set("VLC ready" if locate_vlc() else "VLC optional")

    def on_super_mode_toggle(self):
        enabled = bool(self.super_mode_var.get())
        if enabled:
            self.auto_rotate_var.set(True)
            self.world_live_interval = 12
            self.status_var.set("SUPER MODE ON • 2 hover previews • 12-screen/World Mix unlocked • World Live 12s")
        else:
            self.world_live_interval = 18
            self.status_var.set("SUPER MODE OFF • 1 hover preview • standard command deck")
        self.save_state()
        self.redraw_globe()

    def apply_super_scene(self, scene):
        scene=(scene or "WORLD").upper()
        self.super_scene_var.set(scene)
        self.save_state()
        if scene == "WORLD":
            self.world_live_var.set(True)
            self.on_world_live_toggle()
            self.tabs.select(self.globe_tab)
            return
        if scene == "RANDOM":
            self.surprise_country()
            return
        if scene == "NORDICS":
            candidates=[("NO","Norway"),("SE","Sweden"),("DK","Denmark"),("FI","Finland"),("IS","Iceland")]
            code,name=random.choice(candidates)
            self.country_jump_var.set(f"{code} — {name}")
            self.select_country(code,name)
            self.tabs.select(self.globe_tab)
            return
        if scene == "CAMS":
            self.webcam_theme_var.set("ALL")
            self.tabs.select(self.webcam_tab)
            self.status_var.set("SUPER SCENE • CAMS • choose country/theme; live catalog uses your optional Windy key")
            return
        # NEWS / SPORTS / MUSIC map to actual catalog categories when available.
        target=scene.title()
        values=list(self.tv_category_box['values']) if hasattr(self,'tv_category_box') else []
        match=next((v for v in values if target.lower() in str(v).lower()), None)
        self.tv_category_var.set(match or 'ALL')
        if not match:
            self.tv_search_var.set(scene.lower())
        else:
            self.tv_search_var.set('')
        self.apply_tv_filters()
        self.tabs.select(self.tv_tab)
        self.status_var.set(f"SUPER SCENE • {scene} • {len(self.tv_filtered)} matching TV streams")

    def super_search(self):
        q=simpledialog.askstring(APP_NAME + " — SUPER SEARCH", "Search loaded TV, radio and webcam catalogs.\nLeave blank to show favorites:")
        if q is None:
            return
        q=q.strip().lower()
        rows=[]
        def hit(text): return (not q) or q in text.lower()
        for ch in self.tv_channels:
            fav=self.tv_fav_key(ch) in self.tv_favorites
            text=' '.join([ch.name,ch.country_name,ch.category_text,ch.quality])
            if hit(text) and (q or fav): rows.append(('TV',ch.name,ch.country_name,ch))
        for st in self.radio_stations:
            fav=st.uuid in self.radio_favorites
            text=' '.join([st.name,st.country,st.state,st.language,st.tags])
            if hit(text) and (q or fav): rows.append(('RADIO',st.name,st.country,st))
        cams={c.webcam_id:c for c in self.favorite_webcam_objects()}
        for c in self.webcams: cams[c.webcam_id]=c
        for cam in cams.values():
            fav=cam.webcam_id in self.webcam_favorites
            text=' '.join([cam.title,cam.city,cam.region,cam.country,' '.join(cam.categories)])
            if hit(text) and (q or fav): rows.append(('WEBCAM',cam.title,', '.join(x for x in [cam.city,cam.country] if x),cam))
        rows=rows[:300]
        win=Toplevel(self.root); win.title("RAH SUPER SEARCH"); win.geometry("980x620"); win.configure(bg=BG)
        ttk.Label(win,text=f"SUPER SEARCH • {len(rows)} result(s) • double-click to open",style="Title.TLabel").pack(anchor='w',padx=14,pady=(14,8))
        tree=ttk.Treeview(win,columns=('type','name','place'),show='headings')
        for col,title,width in (('type','TYPE',90),('name','NAME',520),('place','COUNTRY / LOCATION',280)):
            tree.heading(col,text=title); tree.column(col,width=width,stretch=True)
        ys=ttk.Scrollbar(win,orient=VERTICAL,command=tree.yview); tree.configure(yscrollcommand=ys.set)
        tree.pack(side=LEFT,fill=BOTH,expand=True,padx=(14,0),pady=(0,14)); ys.pack(side=RIGHT,fill=Y,padx=(0,14),pady=(0,14))
        for i,(typ,name,place,obj) in enumerate(rows): tree.insert('',END,iid=str(i),values=(typ,name,place))
        def open_row(_e=None):
            sel=tree.selection()
            if not sel: return
            typ,name,place,obj=rows[int(sel[0])]
            try:
                if typ=='TV':
                    play_url(obj.url); push_history(TV_HISTORY_FILE,asdict(obj),'url'); self.tv_history=read_json(TV_HISTORY_FILE,[])
                elif typ=='RADIO':
                    play_url(obj.url); push_history(RADIO_HISTORY_FILE,asdict(obj),'url'); self.radio_history=read_json(RADIO_HISTORY_FILE,[])
                else:
                    link=obj.detail_url or obj.player_url
                    if link: webbrowser.open(link)
                    push_history(WEBCAM_HISTORY_FILE,asdict(obj),'webcam_id'); self.webcam_history=read_json(WEBCAM_HISTORY_FILE,[])
                self.refresh_home(); self.status_var.set(f"SUPER SEARCH • opened {typ}: {name}")
            except FileNotFoundError:
                self.offer_vlc()
        tree.bind('<Double-1>',open_row)

    def probe_selected_stream(self, kind):
        obj=self.selected_tv() if kind=='TV' else self.selected_radio()
        if not obj:
            messagebox.showinfo(APP_NAME, f'Velg en {kind.lower()}-stream først.')
            return
        url=obj.url; name=obj.name
        self.status_var.set(f"HEALTH TEST • {name} …")
        threading.Thread(target=self._probe_stream_worker,args=(kind,name,url),daemon=True).start()

    def _probe_stream_worker(self, kind, name, url):
        started=time.time(); status='UNKNOWN'; detail=''
        try:
            req=urllib.request.Request(url,headers={'User-Agent':'RAH-World-Media/9.9','Range':'bytes=0-1023','Accept':'*/*'})
            with urllib.request.urlopen(req,timeout=9) as r:
                code=getattr(r,'status',200); r.read(1)
                status='LIVE' if 200 <= int(code) < 400 else f'HTTP {code}'
                detail=str(r.headers.get('Content-Type','')).split(';')[0]
        except Exception as e:
            status='OFFLINE / BLOCKED'; detail=str(e)[:140]
        ms=int((time.time()-started)*1000)
        self.msgq.put(('health_result',(kind,name,url,status,detail,ms)))

    def refresh_all(self):
        self.status_var.set("Refreshing TV + radio catalogs …")
        self.load_tv_async(force=True)
        self.load_radio_countries_async()
        self.load_radio_async(mode="top")
        if self.globe_selected_iso and windy_api_key():
            self.load_webcams_async(self.globe_selected_iso, target="globe")

    def jump_to_country(self):
        value = self.country_jump_var.get().strip()
        code = value.split("—",1)[0].strip().upper() if value else ""
        if len(code) != 2:
            return
        name = next((x.get("name",code) for x in self.world_shapes if (x.get("iso_a2") or "").upper()==code), code)
        self.select_country(code, name)
        self.tabs.select(self.globe_tab)

    def surprise_country(self):
        pool=[]
        for shape in self.world_shapes:
            code=(shape.get("iso_a2") or "").upper()
            if code and (self.tv_counts_by_iso.get(code,0) or self.radio_country_counts.get(code,{}).get("count",0)):
                pool.append((code, shape.get("name") or code))
        if not pool:
            return
        code,name=random.choice(pool)
        self.country_jump_var.set(f"{code} — {name}")
        self.select_country(code,name)
        self.tabs.select(self.globe_tab)

    def country_centroid(self, iso):
        feat = next((x for x in self.world_shapes if (x.get("iso_a2") or "").upper() == iso.upper()), None)
        if not feat:
            return None
        pts=[]
        for poly in feat.get("polygons", []):
            if poly and poly[0]:
                pts.extend(poly[0][::max(1, len(poly[0])//80 or 1)])
        if not pts:
            return None
        # Circular longitude mean avoids the dateline problem for most countries.
        sx=sum(math.sin(math.radians(float(lon))) for lon,lat in pts)
        cx=sum(math.cos(math.radians(float(lon))) for lon,lat in pts)
        lon=math.degrees(math.atan2(sx,cx)) if sx or cx else float(pts[0][0])
        lat=sum(float(lat) for lon,lat in pts)/len(pts)
        return lon, max(-75.0, min(75.0, lat))

    def center_on_country(self, iso):
        c=self.country_centroid(iso)
        if c:
            self.globe_lon0, self.globe_lat0 = c
            self.globe_zoom = max(1.0, min(self.globe_zoom, 1.35))

    def on_world_live_toggle(self):
        if self.world_live_var.get():
            self.world_live_next_ts = 0.0
            self.tabs.select(self.globe_tab)
            self.status_var.set(f"WORLD LIVE ON • next country every {self.world_live_interval}s")
        else:
            self.status_var.set("WORLD LIVE paused")
        self.save_state()

    def world_live_pick(self):
        pool=[]; weights=[]
        for shape in self.world_shapes:
            code=(shape.get("iso_a2") or "").upper()
            if not code or code == self.world_live_last_iso:
                continue
            tvc=self.tv_counts_by_iso.get(code,0)
            rc=self.radio_country_counts.get(code,{}).get("count",0)
            if tvc or rc:
                pool.append((code, shape.get("name") or code))
                weights.append(max(1.0, math.log1p(tvc*4 + rc)))
        if not pool:
            return
        code,name=random.choices(pool, weights=weights, k=1)[0]
        self.world_live_last_iso=code
        self.center_on_country(code)
        # Do not spend Windy API quota while automatically hopping countries.
        self.select_country(code,name,load_webcams=False)
        self.status_var.set(f"WORLD LIVE • {name} ({code}) • next hop in {self.world_live_interval}s")

    def world_live_tick(self):
        try:
            if self.world_live_var.get() and time.time() >= self.world_live_next_ts and not self._drag_last:
                self.world_live_pick()
                self.world_live_next_ts = time.time() + max(10, self.world_live_interval)
        finally:
            self.root.after(900, self.world_live_tick)

    def auto_rotate_tick(self):
        try:
            if self.auto_rotate_var.get() and not self._drag_last and self.tabs.select() == str(self.globe_tab):
                self.globe_lon0 = ((self.globe_lon0 + 0.45 + 180) % 360) - 180
                self.redraw_globe()
        finally:
            self.root.after(240, self.auto_rotate_tick)

    # ---------- Globe ----------

    def build_globe_tab(self):
        wrap = ttk.Frame(self.globe_tab)
        wrap.pack(fill=BOTH, expand=True)
        wrap.columnconfigure(0, weight=3)
        wrap.columnconfigure(1, weight=2)
        wrap.rowconfigure(0, weight=1)

        left = ttk.Frame(wrap)
        left.grid(row=0, column=0, sticky='nsew', padx=(0, 10))
        left.rowconfigure(1, weight=1)
        left.columnconfigure(0, weight=1)

        toolbar = ttk.Frame(left)
        toolbar.grid(row=0, column=0, sticky='ew', pady=(6, 6))
        ttk.Label(toolbar, textvariable=self.globe_hover_text, style='Muted.TLabel').pack(side=LEFT)
        ttk.Button(toolbar, text='✨ Media Wall', command=self.open_media_wall).pack(side=RIGHT, padx=4)
        ttk.Checkbutton(toolbar, text='🌍 World Live', variable=self.world_live_var, command=self.on_world_live_toggle).pack(side=RIGHT, padx=4)
        ttk.Button(toolbar, text='🎲 Surprise', command=self.surprise_country).pack(side=RIGHT, padx=4)
        ttk.Checkbutton(toolbar, text='Auto rotate', variable=self.auto_rotate_var, command=self.save_state).pack(side=RIGHT, padx=6)
        ttk.Button(toolbar, text='⟲ Reset globe', command=self.reset_globe).pack(side=RIGHT, padx=4)
        ttk.Button(toolbar, text='＋ Zoom', command=lambda: self.zoom_globe(1.1)).pack(side=RIGHT, padx=4)
        ttk.Button(toolbar, text='－ Zoom', command=lambda: self.zoom_globe(0.9)).pack(side=RIGHT, padx=4)
        layer = ttk.Combobox(toolbar, textvariable=self.globe_layer_var, state='readonly', width=11, values=['ALL','TV','RADIO','WEBCAMS'])
        layer.pack(side=RIGHT, padx=8)
        layer.bind('<<ComboboxSelected>>', lambda e: (self.redraw_globe(), self.save_state()))

        self.globe_canvas = __import__('tkinter').Canvas(left, bg=BG, highlightthickness=0)
        self.globe_canvas.grid(row=1, column=0, sticky='nsew')
        self.globe_canvas.bind('<Configure>', lambda e: self.redraw_globe())
        self.globe_canvas.bind('<ButtonPress-1>', self.on_globe_press)
        self.globe_canvas.bind('<B1-Motion>', self.on_globe_drag)
        self.globe_canvas.bind('<ButtonRelease-1>', self.on_globe_release)
        self.globe_canvas.bind('<MouseWheel>', self.on_globe_wheel)
        self.globe_canvas.bind('<Button-4>', lambda e: self.zoom_globe(1.1))
        self.globe_canvas.bind('<Button-5>', lambda e: self.zoom_globe(0.9))

        right = ttk.Frame(wrap)
        right.grid(row=0, column=1, sticky='nsew')
        right.rowconfigure(4, weight=1)
        right.rowconfigure(6, weight=1)
        right.rowconfigure(8, weight=1)
        right.columnconfigure(0, weight=1)

        ttk.Label(right, text='Selected country', style='Muted.TLabel').grid(row=0, column=0, sticky='w', pady=(6, 2))
        ttk.Label(right, textvariable=self.globe_selected_text, style='Title.TLabel').grid(row=1, column=0, sticky='w')
        ttk.Label(right, textvariable=self.globe_selected_counts).grid(row=2, column=0, sticky='w', pady=(0, 8))

        btns = ttk.Frame(right)
        btns.grid(row=3, column=0, sticky='ew', pady=(0, 8))
        ttk.Button(btns, text='📺 Open TV for country', command=self.open_selected_country_tv).pack(side=LEFT, padx=(0, 6))
        ttk.Button(btns, text='📻 Open Radio for country', command=self.open_selected_country_radio).pack(side=LEFT, padx=(0, 6))
        ttk.Button(btns, text='📷 Webcams', command=self.open_selected_country_webcams).pack(side=LEFT)

        ttk.Label(right, text='TV streams in selected country', style='Muted.TLabel').grid(row=4, column=0, sticky='sw')
        tv_wrap = ttk.Frame(right)
        tv_wrap.grid(row=5, column=0, sticky='nsew', pady=(2, 8))
        tv_wrap.rowconfigure(0, weight=1)
        tv_wrap.columnconfigure(0, weight=1)
        self.globe_tv_tree = ttk.Treeview(tv_wrap, columns=('name','cat','q'), show='headings', height=8)
        self.globe_tv_tree.heading('name', text='Channel')
        self.globe_tv_tree.heading('cat', text='Category')
        self.globe_tv_tree.heading('q', text='Q')
        self.globe_tv_tree.column('name', width=210)
        self.globe_tv_tree.column('cat', width=140)
        self.globe_tv_tree.column('q', width=40, anchor='center')
        tvs = ttk.Scrollbar(tv_wrap, orient=VERTICAL, command=self.globe_tv_tree.yview)
        self.globe_tv_tree.configure(yscrollcommand=tvs.set)
        self.globe_tv_tree.grid(row=0, column=0, sticky='nsew')
        tvs.grid(row=0, column=1, sticky='ns')
        self.globe_tv_tree.bind('<Double-1>', lambda e: self.play_globe_tv_selected())

        ttk.Label(right, text='Radio stations in selected country', style='Muted.TLabel').grid(row=6, column=0, sticky='sw')
        radio_wrap = ttk.Frame(right)
        radio_wrap.grid(row=7, column=0, sticky='nsew', pady=(2, 6))
        radio_wrap.rowconfigure(0, weight=1)
        radio_wrap.columnconfigure(0, weight=1)
        self.globe_radio_tree = ttk.Treeview(radio_wrap, columns=('name','lang','bitrate'), show='headings', height=8)
        self.globe_radio_tree.heading('name', text='Station')
        self.globe_radio_tree.heading('lang', text='Language')
        self.globe_radio_tree.heading('bitrate', text='kbps')
        self.globe_radio_tree.column('name', width=210)
        self.globe_radio_tree.column('lang', width=120)
        self.globe_radio_tree.column('bitrate', width=60, anchor='center')
        rs = ttk.Scrollbar(radio_wrap, orient=VERTICAL, command=self.globe_radio_tree.yview)
        self.globe_radio_tree.configure(yscrollcommand=rs.set)
        self.globe_radio_tree.grid(row=0, column=0, sticky='nsew')
        rs.grid(row=0, column=1, sticky='ns')
        self.globe_radio_tree.bind('<Double-1>', lambda e: self.play_globe_radio_selected())

        ttk.Label(right, text='Webcams in selected country', style='Muted.TLabel').grid(row=8, column=0, sticky='sw')
        cam_wrap = ttk.Frame(right)
        cam_wrap.grid(row=9, column=0, sticky='nsew', pady=(2, 6))
        cam_wrap.rowconfigure(0, weight=1)
        cam_wrap.columnconfigure(0, weight=1)
        self.globe_webcam_tree = ttk.Treeview(cam_wrap, columns=('name','place','live'), show='headings', height=6)
        self.globe_webcam_tree.heading('name', text='Camera')
        self.globe_webcam_tree.heading('place', text='Location')
        self.globe_webcam_tree.heading('live', text='Live')
        self.globe_webcam_tree.column('name', width=210)
        self.globe_webcam_tree.column('place', width=150)
        self.globe_webcam_tree.column('live', width=55, anchor='center')
        cs = ttk.Scrollbar(cam_wrap, orient=VERTICAL, command=self.globe_webcam_tree.yview)
        self.globe_webcam_tree.configure(yscrollcommand=cs.set)
        self.globe_webcam_tree.grid(row=0, column=0, sticky='nsew')
        cs.grid(row=0, column=1, sticky='ns')
        self.globe_webcam_tree.bind('<Double-1>', lambda e: self.open_globe_webcam_selected())

    def reset_globe(self):
        self.globe_lon0 = 0.0
        self.globe_lat0 = 15.0
        self.globe_zoom = 1.0
        self.redraw_globe()
        self.save_state()

    def zoom_globe(self, factor):
        self.globe_zoom = max(0.7, min(2.2, self.globe_zoom * factor))
        self.redraw_globe()
        self.save_state()

    def on_globe_wheel(self, event):
        self.zoom_globe(1.1 if event.delta > 0 else 0.9)

    def on_globe_press(self, event):
        if self.world_live_var.get():
            self.world_live_var.set(False)
            self.status_var.set("WORLD LIVE paused by manual globe control")
            self.save_state()
        self._drag_last = (event.x, event.y)
        self._skip_click = False

    def on_globe_drag(self, event):
        if not self._drag_last:
            return
        x0, y0 = self._drag_last
        dx, dy = event.x - x0, event.y - y0
        if abs(dx) + abs(dy) > 2:
            self._skip_click = True
        self.globe_lon0 = (self.globe_lon0 - dx * 0.45) % 360
        if self.globe_lon0 > 180:
            self.globe_lon0 -= 360
        self.globe_lat0 = max(-85, min(85, self.globe_lat0 + dy * 0.35))
        self._drag_last = (event.x, event.y)
        self.redraw_globe()

    def on_globe_release(self, event):
        self._drag_last = None
        self.save_state()

    def project_point(self, lon, lat, lon0, lat0):
        lam = math.radians(lon)
        phi = math.radians(lat)
        lam0 = math.radians(lon0)
        phi0 = math.radians(lat0)
        cosc = math.sin(phi0) * math.sin(phi) + math.cos(phi0) * math.cos(phi) * math.cos(lam - lam0)
        if cosc < -0.08:
            return None
        x = math.cos(phi) * math.sin(lam - lam0)
        y = math.cos(phi0) * math.sin(phi) - math.sin(phi0) * math.cos(phi) * math.cos(lam - lam0)
        return x, y

    def webcam_theme_match(self, cam):
        theme=(self.webcam_theme_var.get() if hasattr(self,"webcam_theme_var") else "ALL").upper()
        words=WEBCAM_THEME_MAP.get(theme, ())
        if not words:
            return True
        hay=normalize(" ".join([cam.title,cam.city,cam.region,cam.country," ".join(cam.categories)]))
        return any(normalize(w) in hay for w in words)

    def favorite_webcam_objects(self):
        out=[]
        seen=set()
        for raw in self.webcam_favorite_items:
            try:
                cam=Webcam(**raw)
                if cam.webcam_id and cam.webcam_id not in seen:
                    seen.add(cam.webcam_id); out.append(cam)
            except Exception:
                pass
        return out

    def redraw_globe(self):
        c = self.globe_canvas
        if not c.winfo_exists():
            return
        w = max(c.winfo_width(), 400)
        h = max(c.winfo_height(), 300)
        c.delete('all')
        cx, cy = w / 2, h / 2
        r = min(w, h) * 0.42 * self.globe_zoom
        c.create_oval(cx-r, cy-r, cx+r, cy+r, fill=OCEAN, outline='#223040', width=2)
        self.draw_graticule(cx, cy, r)
        for feat in self.world_shapes:
            iso = (feat.get('iso_a2') or '').upper()
            name = feat.get('name') or iso
            tvc = self.tv_counts_by_iso.get(iso, 0)
            rc = self.radio_country_counts.get(iso, {}).get('count', 0)
            fill = self.country_fill_color(tvc, rc, iso == self.globe_selected_iso)
            outline = '#1b2026' if iso != self.globe_selected_iso else '#fff0bf'
            for poly in feat.get('polygons', []):
                for ring in poly[:1]:
                    pts = self.project_ring(ring, cx, cy, r)
                    if len(pts) >= 6:
                        item = c.create_polygon(pts, fill=fill, outline=outline, width=1, activeoutline=ACCENT, tags=('country', iso, name))
                        c.tag_bind(item, '<ButtonRelease-1>', lambda e, i=iso, n=name: self.on_country_click(e, i, n))
                        c.tag_bind(item, '<Enter>', lambda e, i=iso, n=name: self.on_country_hover(i, n))
        if self.globe_layer_var.get() in ('ALL', 'WEBCAMS'):
            for idx, cam in enumerate(self.globe_webcam_preview_items[:250]):
                if not self.webcam_theme_match(cam):
                    continue
                p = self.project_point(cam.longitude, cam.latitude, self.globe_lon0, self.globe_lat0)
                if p is None:
                    continue
                x, y = p
                px, py = cx + r * x, cy - r * y
                dot = c.create_oval(px-4, py-4, px+4, py+4, fill=ACCENT, outline=GOLD, width=1, tags=('webcam', str(idx)))
                c.tag_bind(dot, '<ButtonRelease-1>', lambda e, n=idx: self.select_globe_webcam(n))
            # Favorite webcams stay visible across countries as brighter glowing pins.
            for idx, cam in enumerate(self.favorite_webcam_objects()[:200]):
                if not self.webcam_theme_match(cam):
                    continue
                p=self.project_point(cam.longitude,cam.latitude,self.globe_lon0,self.globe_lat0)
                if p is None: continue
                x,y=p; px,py=cx+r*x,cy-r*y
                c.create_oval(px-8,py-8,px+8,py+8,outline='#f8d26a',width=1)
                dot=c.create_oval(px-4,py-4,px+4,py+4,fill='#fff0a6',outline=GOLD,width=2)
                c.tag_bind(dot,'<ButtonRelease-1>',lambda e,n=idx:self.select_favorite_webcam_pin(n))
            # Favorite city/place pins are diamonds and persist even when cameras are not loaded.
            for idx, place in enumerate(self.favorite_places[:200]):
                try:
                    p=self.project_point(float(place.get('longitude',0)),float(place.get('latitude',0)),self.globe_lon0,self.globe_lat0)
                except Exception:
                    p=None
                if p is None: continue
                x,y=p; px,py=cx+r*x,cy-r*y
                pin=c.create_polygon(px,py-7,px+7,py,px,py+7,px-7,py,fill=GOLD,outline='#fff0bf',width=1)
                c.tag_bind(pin,'<ButtonRelease-1>',lambda e,n=idx:self.select_favorite_place_pin(n))
        c.create_oval(cx-r, cy-r, cx+r, cy+r, outline='#41546a', width=1)
        c.create_text(cx, cy + r + 18, text='Drag • wheel zoom • gold dots=webcams • bright pins=favorites • diamonds=cities', fill=MUTED, font=('Segoe UI', 10))

    def draw_graticule(self, cx, cy, r):
        c = self.globe_canvas
        for lat in range(-60, 90, 30):
            pts=[]
            for lon in range(-180, 181, 6):
                p = self.project_point(lon, lat, self.globe_lon0, self.globe_lat0)
                if p:
                    x,y=p; pts.extend([cx+r*x, cy-r*y])
            if len(pts) >= 4:
                c.create_line(*pts, fill=GRID, smooth=True)
        for lon in range(-150, 181, 30):
            pts=[]
            for lat in range(-89, 90, 4):
                p = self.project_point(lon, lat, self.globe_lon0, self.globe_lat0)
                if p:
                    x,y=p; pts.extend([cx+r*x, cy-r*y])
            if len(pts) >= 4:
                c.create_line(*pts, fill=GRID, smooth=True)

    def project_ring(self, ring, cx, cy, r):
        pts=[]
        for lon, lat in ring:
            p = self.project_point(lon, lat, self.globe_lon0, self.globe_lat0)
            if p is not None:
                x, y = p
                pts.extend([cx + r * x, cy - r * y])
        return pts

    def country_fill_color(self, tv_count, radio_count, selected=False):
        total = tv_count + radio_count
        if total <= 0:
            base = '#20242a'
        else:
            strength = min(1.0, math.log1p(total) / math.log(400))
            base = blend('#3a2d13', GOLD, 0.35 + 0.65 * strength)
        return blend(base, '#fff0bf', 0.25) if selected else base

    def on_country_hover(self, iso, name):
        tvc = self.tv_counts_by_iso.get(iso, 0)
        rc = self.radio_country_counts.get(iso, {}).get('count', 0)
        wc = self.webcam_country_counts.get(iso, '—')
        self.globe_hover_text.set(f'{name} ({iso}) • TV {tvc} • Radio {rc} • Webcams {wc}')

    def select_country(self, iso, name, load_webcams=True):
        self.globe_selected_iso = iso
        self.globe_selected_name = name
        self.globe_selected_text.set(f'{name} ({iso})')
        tvc = self.tv_counts_by_iso.get(iso, 0)
        rc = self.radio_country_counts.get(iso, {}).get('count', 0)
        wc = self.webcam_country_counts.get(iso, '—')
        self.globe_selected_counts.set(f'TV: {tvc} stream(s) • Radio: {rc} station(s) • Webcams: {wc}')
        self.populate_globe_tv_preview(iso)
        self.populate_globe_radio_preview([], loading=True)
        self.populate_globe_webcam_preview([], loading=True if (windy_api_key() and load_webcams) else False, note=None if (windy_api_key() and load_webcams) else ('World Live: webcams on demand' if windy_api_key() else 'Add Windy API key'))
        self.load_globe_radio_preview_async(iso)
        if windy_api_key() and load_webcams:
            self.load_webcams_async(iso, target='globe')
        self.redraw_globe()

    def on_country_click(self, event, iso, name):
        if self._skip_click:
            return
        self.select_country(iso, name)

    def populate_globe_tv_preview(self, iso):
        items = [c for c in self.tv_channels if (c.country or '').upper() == iso]
        self.globe_tv_preview_items = items
        self.globe_tv_tree.delete(*self.globe_tv_tree.get_children())
        for idx, ch in enumerate(items[:500]):
            self.globe_tv_tree.insert('', END, iid=str(idx), values=(ch.name, ch.category_text[:40], ch.quality))

    def populate_globe_radio_preview(self, items, loading=False, note=None):
        self.globe_radio_preview_items = items
        self.globe_radio_tree.delete(*self.globe_radio_tree.get_children())
        if loading:
            self.globe_radio_tree.insert('', END, iid='0', values=('Loading…', '', ''))
            return
        if note:
            self.globe_radio_tree.insert('', END, iid='0', values=(note, '', ''))
            return
        for idx, st in enumerate(items[:500]):
            self.globe_radio_tree.insert('', END, iid=str(idx), values=(st.name, st.language[:20], st.bitrate))

    def play_globe_tv_selected(self):
        sel = self.globe_tv_tree.selection()
        if not sel:
            return
        ch = self.globe_tv_preview_items[int(sel[0])]
        try:
            play_url(ch.url)
            push_history(TV_HISTORY_FILE, asdict(ch), 'url')
            self.tv_history = read_json(TV_HISTORY_FILE, [])
            self.refresh_home()
            self.status_var.set(f'TV: {ch.name}')
        except FileNotFoundError:
            self.offer_vlc()

    def play_globe_radio_selected(self):
        sel = self.globe_radio_tree.selection()
        if not sel:
            return
        idx = sel[0]
        if not idx.isdigit():
            return
        st = self.globe_radio_preview_items[int(idx)]
        try:
            threading.Thread(target=self.radio_click_ping, args=(st.uuid,), daemon=True).start()
            play_url(st.url)
            push_history(RADIO_HISTORY_FILE, asdict(st), 'url')
            self.radio_history = read_json(RADIO_HISTORY_FILE, [])
            self.refresh_home()
            self.status_var.set(f'Radio: {st.name}')
        except FileNotFoundError:
            self.offer_vlc()

    def load_globe_radio_preview_async(self, iso):
        self.globe_preview_request += 1
        token = self.globe_preview_request
        threading.Thread(target=self._globe_radio_preview_worker, args=(iso, token), daemon=True).start()

    def _globe_radio_preview_worker(self, iso, token):
        try:
            params = {'countrycode': iso, 'hidebroken': 'true', 'order': 'votes', 'reverse': 'true', 'limit': '500'}
            raw = radio_json("stations/search", params)
            stations=[]; seen=set()
            for x in raw:
                station_url=(x.get('url_resolved') or x.get('url') or '').strip()
                uid=(x.get('stationuuid') or station_url).strip()
                if not station_url or not uid or uid in seen:
                    continue
                seen.add(uid)
                stations.append(RadioStation(
                    uuid=uid,
                    name=(x.get('name') or 'Unnamed').strip(),
                    country=(x.get('country') or '').strip(),
                    countrycode=(x.get('countrycode') or '').strip(),
                    state=(x.get('state') or '').strip(),
                    language=(x.get('language') or '').strip(),
                    tags=(x.get('tags') or '').strip(),
                    codec=(x.get('codec') or '').strip(),
                    bitrate=int(x.get('bitrate') or 0),
                    url=station_url,
                    homepage=(x.get('homepage') or '').strip(),
                    favicon=(x.get('favicon') or '').strip(),
                    votes=int(x.get('votes') or 0),
                    clickcount=int(x.get('clickcount') or 0),
                ))
            self.msgq.put(('globe_radio_preview', (token, iso, stations, None)))
        except Exception as e:
            self.msgq.put(('globe_radio_preview', (token, iso, [], str(e))))

    def populate_globe_webcam_preview(self, items, loading=False, note=None):
        self.globe_webcam_preview_items = list(items)
        self.globe_webcam_tree.delete(*self.globe_webcam_tree.get_children())
        if loading:
            self.globe_webcam_tree.insert('', END, iid='0', values=('Loading…', '', ''))
            return
        if note:
            self.globe_webcam_tree.insert('', END, iid='0', values=(note, '', ''))
            return
        for idx, cam in enumerate(items[:250]):
            place = ', '.join(x for x in [cam.city, cam.region] if x)
            self.globe_webcam_tree.insert('', END, iid=str(idx), values=(cam.title, place, 'LIVE' if cam.is_live else ''))

    def select_globe_webcam(self, idx):
        if idx < 0 or idx >= len(self.globe_webcam_preview_items):
            return
        cam = self.globe_webcam_preview_items[idx]
        self.globe_hover_text.set(f'📷 {cam.title} • {cam.city or cam.region or cam.country}')
        self.tabs.select(self.webcam_tab)
        self.webcams = list(self.globe_webcam_preview_items)
        self.webcam_country_var.set(cam.countrycode)
        self.populate_webcams(self.webcams)
        if str(idx) in self.webcam_tree.get_children():
            self.webcam_tree.selection_set(str(idx))
            self.webcam_tree.see(str(idx))

    def select_favorite_webcam_pin(self, idx):
        cams=self.favorite_webcam_objects()
        if idx < 0 or idx >= len(cams): return
        cam=cams[idx]
        self.globe_hover_text.set(f"★ {cam.title} • {cam.city or cam.region or cam.country}")
        self.tabs.select(self.webcam_tab)
        self.webcams=cams
        self.populate_webcams(cams)
        for i,x in enumerate(self.webcam_filtered):
            if x.webcam_id == cam.webcam_id and str(i) in self.webcam_tree.get_children():
                self.webcam_tree.selection_set(str(i)); self.webcam_tree.see(str(i)); break

    def select_favorite_place_pin(self, idx):
        if idx < 0 or idx >= len(self.favorite_places): return
        p=self.favorite_places[idx]
        code=str(p.get('countrycode') or '').upper()
        name=str(p.get('country') or p.get('city') or code)
        self.globe_hover_text.set(f"◆ {p.get('city') or p.get('region') or name} • favorite place")
        if len(code)==2:
            self.center_on_country(code)
            self.select_country(code,name,load_webcams=False)

    def open_globe_webcam_selected(self):
        sel = self.globe_webcam_tree.selection()
        if not sel or not sel[0].isdigit():
            return
        idx = int(sel[0])
        if idx >= len(self.globe_webcam_preview_items):
            return
        self.open_webcam(self.globe_webcam_preview_items[idx])

    def open_selected_country_tv(self):
        if not self.globe_selected_iso:
            return
        display = self.tv_country_name_by_iso.get(self.globe_selected_iso)
        if display and display in self.tv_country_box['values']:
            self.tv_country_var.set(display)
            self.apply_tv_filters()
        self.tabs.select(self.tv_tab)

    def open_selected_country_radio(self):
        if not self.globe_selected_iso:
            return
        prefix = f'{self.globe_selected_iso} — '
        for val in self.radio_country_box['values']:
            if isinstance(val, str) and val.startswith(prefix):
                self.radio_country_var.set(val)
                break
        self.tabs.select(self.radio_tab)
        self.load_radio_async(mode='country')

    def open_selected_country_webcams(self):
        if not self.globe_selected_iso:
            return
        self.webcam_country_var.set(self.globe_selected_iso)
        self.tabs.select(self.webcam_tab)
        if windy_api_key():
            self.load_webcams_async(self.globe_selected_iso, target='tab')
        else:
            self.populate_webcams([])
            self.status_var.set('Webcams: legg inn gratis Windy API key for live katalog')

    # ---------- TV ----------

    def build_tv_tab(self):
        self.tv_search_var = StringVar(value=self.state.get('tv_search', ''))
        self.tv_country_var = StringVar(value=self.state.get('tv_country', 'ALL'))
        self.tv_category_var = StringVar(value=self.state.get('tv_category', 'ALL'))
        self.tv_hide_geo_var = BooleanVar(value=bool(self.state.get('tv_hide_geo', False)))
        self.tv_hide_not247_var = BooleanVar(value=bool(self.state.get('tv_hide_not247', False)))
        self.tv_info_var = StringVar(value='Velg en kanal.')

        controls = ttk.Frame(self.tv_tab)
        controls.pack(fill=X, pady=8)
        self.tv_search = ttk.Entry(controls, textvariable=self.tv_search_var)
        self.tv_search.pack(side=LEFT, fill=X, expand=True, padx=(0, 8))
        self.tv_search.bind('<KeyRelease>', lambda e: self.apply_tv_filters())
        self.tv_country_box = ttk.Combobox(controls, textvariable=self.tv_country_var, state='readonly', width=27)
        self.tv_country_box.pack(side=LEFT, padx=4)
        self.tv_country_box.bind('<<ComboboxSelected>>', lambda e: self.apply_tv_filters())
        self.tv_category_box = ttk.Combobox(controls, textvariable=self.tv_category_var, state='readonly', width=23)
        self.tv_category_box.pack(side=LEFT, padx=4)
        self.tv_category_box.bind('<<ComboboxSelected>>', lambda e: self.apply_tv_filters())
        ttk.Checkbutton(controls, text='Skjul geo', variable=self.tv_hide_geo_var, command=self.apply_tv_filters).pack(side=LEFT, padx=6)
        ttk.Checkbutton(controls, text='Skjul ikke-24/7', variable=self.tv_hide_not247_var, command=self.apply_tv_filters).pack(side=LEFT, padx=6)
        ttk.Button(controls, text='↻ Oppdater', command=lambda: self.load_tv_async(force=True)).pack(side=RIGHT, padx=4)
        ttk.Button(controls, text='＋ M3U', command=self.import_m3u).pack(side=RIGHT, padx=4)

        columns = ('fav','name','country','category','quality','labels')
        wrap = ttk.Frame(self.tv_tab)
        wrap.pack(fill=BOTH, expand=True)
        self.tv_tree = ttk.Treeview(wrap, columns=columns, show='headings', selectmode='browse')
        heads = {'fav':'★','name':'Kanal','country':'Land','category':'Kategori','quality':'Kvalitet','labels':'Merking'}
        widths = {'fav':45,'name':350,'country':190,'category':220,'quality':85,'labels':220}
        for col in columns:
            self.tv_tree.heading(col, text=heads[col])
            self.tv_tree.column(col, width=widths[col], anchor='center' if col in ('fav','quality') else 'w', stretch=(col not in ('fav','quality')))
        ys = ttk.Scrollbar(wrap, orient=VERTICAL, command=self.tv_tree.yview)
        xs = ttk.Scrollbar(wrap, orient=HORIZONTAL, command=self.tv_tree.xview)
        self.tv_tree.configure(yscrollcommand=ys.set, xscrollcommand=xs.set)
        self.tv_tree.grid(row=0, column=0, sticky='nsew')
        ys.grid(row=0, column=1, sticky='ns')
        xs.grid(row=1, column=0, sticky='ew')
        wrap.rowconfigure(0, weight=1)
        wrap.columnconfigure(0, weight=1)
        self.tv_tree.bind('<Double-1>', lambda e: self.play_tv())
        self.tv_tree.bind('<<TreeviewSelect>>', lambda e: self.update_tv_info())

        actions = ttk.Frame(self.tv_tab)
        actions.pack(fill=X, pady=8)
        ttk.Button(actions, text='▶ PLAY TV', style='Gold.TButton', command=self.play_tv).pack(side=LEFT, padx=(0, 5))
        ttk.Button(actions, text='★ / ☆ Favoritt', command=self.toggle_tv_favorite).pack(side=LEFT, padx=4)
        ttk.Button(actions, text='★ Vis favoritter', command=self.show_tv_favorites).pack(side=LEFT, padx=4)
        ttk.Button(actions, text='🌐 Nettside', command=self.open_tv_website).pack(side=LEFT, padx=4)
        ttk.Button(actions, text='⧉ Kopier URL', command=self.copy_tv_url).pack(side=LEFT, padx=4)
        ttk.Button(actions, text='✨ Media Wall', command=self.open_media_wall).pack(side=LEFT, padx=4)
        ttk.Button(actions, text='◉ TEST STREAM', command=lambda: self.probe_selected_stream('TV')).pack(side=LEFT, padx=4)
        ttk.Label(actions, textvariable=self.tv_info_var, style='Muted.TLabel').pack(side=LEFT, padx=12)

    def load_tv_async(self, force=False):
        if self.tv_loading:
            return
        self.tv_loading = True
        self.status_var.set('Laster verdens-TV …')
        threading.Thread(target=self._tv_worker, args=(force,), daemon=True).start()

    def _tv_worker(self, force):
        try:
            countries = fetch_tv_json('countries', force)
            categories = fetch_tv_json('categories', force)
            channels = fetch_tv_json('channels', force)
            logos = fetch_tv_json('logos', force)
            streams = fetch_tv_json('streams', force)
            country_map = {x.get('code', ''): x.get('name', x.get('code', '')) for x in countries}
            category_map = {x.get('id', ''): x.get('name', x.get('id', '')) for x in categories}
            ch_map = {x.get('id'): x for x in channels if x.get('id') and not x.get('is_nsfw', False)}
            logo_exact={}; logo_main={}
            for lg in logos:
                cid=lg.get('channel'); url=(lg.get('url') or '').strip()
                if not cid or not url or not lg.get('in_use', True):
                    continue
                feed=lg.get('feed')
                if feed:
                    logo_exact.setdefault((cid,feed), url)
                else:
                    logo_main.setdefault(cid, url)
            result=[]; seen=set()
            counts={}; display_by_iso={}
            for s in streams:
                cid = s.get('channel')
                if not cid or cid not in ch_map:
                    continue
                c = ch_map[cid]
                url = (s.get('url') or '').strip()
                if not url or (cid, url) in seen:
                    continue
                seen.add((cid, url))
                cc = (c.get('country') or 'XX').upper()
                cats = c.get('categories') or []
                display_by_iso[cc] = country_map.get(cc, cc)
                counts[cc] = counts.get(cc, 0) + 1
                result.append(TVChannel(
                    id=cid,
                    name=(s.get('title') or c.get('name') or cid).strip(),
                    country=cc,
                    country_name=country_map.get(cc, cc),
                    categories=[category_map.get(x, x) for x in cats],
                    url=url,
                    quality=s.get('quality') or '',
                    labels=s.get('labels') or [],
                    logo=logo_exact.get((cid,s.get('feed'))) or logo_main.get(cid,'') or '',
                    website=c.get('website') or '',
                    source='iptv-org',
                ))
            for item in read_json(CUSTOM_FILE, []):
                try:
                    t = TVChannel(**item)
                    result.append(t)
                    cc = (t.country or '').upper()
                    if cc and cc != 'CUSTOM':
                        counts[cc] = counts.get(cc, 0) + 1
                        display_by_iso[cc] = t.country_name or cc
                except Exception:
                    pass
            result.sort(key=lambda x: (x.country_name.casefold(), x.name.casefold()))
            self.msgq.put(('tv_loaded', (result, counts, display_by_iso)))
        except Exception as e:
            self.msgq.put(('error', ('TV', str(e))))

    def apply_tv_filters(self):
        q = normalize(self.tv_search_var.get())
        country = self.tv_country_var.get()
        category = self.tv_category_var.get()
        hide_geo = self.tv_hide_geo_var.get()
        hide_not247 = self.tv_hide_not247_var.get()
        items=[]
        for ch in self.tv_channels:
            if country != 'ALL' and ch.country_name != country:
                continue
            if category != 'ALL' and category not in ch.categories:
                continue
            labels_norm = {normalize(x) for x in ch.labels}
            if hide_geo and 'geo-blocked' in labels_norm:
                continue
            if hide_not247 and 'not 24/7' in labels_norm:
                continue
            hay = ' '.join([ch.name, ch.country_name, ch.category_text, ch.quality, ch.label_text, ch.id])
            if q and q not in normalize(hay):
                continue
            items.append(ch)
        self.tv_filtered = items
        self.tv_tree.delete(*self.tv_tree.get_children())
        for idx, ch in enumerate(items):
            fav = '★' if self.tv_fav_key(ch) in self.tv_favorites else ''
            self.tv_tree.insert('', END, iid=str(idx), values=(fav, ch.name, ch.country_name, ch.category_text, ch.quality, ch.label_text))
        self.status_var.set(f'TV: {len(items):,} / {len(self.tv_channels):,} streams')
        self.save_state()

    @staticmethod
    def tv_fav_key(ch):
        return f'{ch.id}|{ch.url}'

    def selected_tv(self):
        sel = self.tv_tree.selection()
        if not sel:
            return None
        try:
            return self.tv_filtered[int(sel[0])]
        except Exception:
            return None

    def play_tv(self):
        ch = self.selected_tv()
        if not ch:
            messagebox.showinfo(APP_NAME, 'Velg en TV-kanal først.')
            return
        try:
            play_url(ch.url)
            push_history(TV_HISTORY_FILE, asdict(ch), 'url')
            self.tv_history = read_json(TV_HISTORY_FILE, [])
            self.refresh_home()
            self.status_var.set(f'TV: {ch.name}')
        except FileNotFoundError:
            self.offer_vlc()

    def toggle_tv_favorite(self):
        ch = self.selected_tv()
        if not ch:
            return
        key = self.tv_fav_key(ch)
        if key in self.tv_favorites:
            self.tv_favorites.remove(key)
        else:
            self.tv_favorites.add(key)
        write_json(TV_FAV_FILE, sorted(self.tv_favorites))
        self.apply_tv_filters()

    def show_tv_favorites(self):
        q = [c for c in self.tv_channels if self.tv_fav_key(c) in self.tv_favorites]
        self.tv_filtered = q
        self.tv_tree.delete(*self.tv_tree.get_children())
        for idx, c in enumerate(q):
            self.tv_tree.insert('', END, iid=str(idx), values=('★', c.name, c.country_name, c.category_text, c.quality, c.label_text))
        self.status_var.set(f'TV-favoritter: {len(q)}')

    def update_tv_info(self):
        ch = self.selected_tv()
        self.tv_info_var.set('Velg en kanal.' if not ch else f'{ch.country_name} • {ch.category_text}')

    def open_tv_website(self):
        ch = self.selected_tv()
        if ch and ch.website:
            webbrowser.open(ch.website)

    def copy_tv_url(self):
        ch = self.selected_tv()
        if ch:
            self.copy_clipboard(ch.url, 'TV-stream URL kopiert')

    def import_m3u(self):
        path = filedialog.askopenfilename(title='Importer M3U/M3U8', filetypes=[('M3U playlist', '*.m3u *.m3u8'), ('Alle filer', '*.*')])
        if not path:
            return
        try:
            items = parse_m3u(Path(path))
            if not items:
                raise ValueError('Ingen kanaler funnet.')
            existing = read_json(CUSTOM_FILE, [])
            urls = {x.get('url') for x in existing}
            added = 0
            for x in items:
                if x['url'] not in urls:
                    existing.append(x)
                    urls.add(x['url'])
                    added += 1
            write_json(CUSTOM_FILE, existing)
            messagebox.showinfo(APP_NAME, f'Importert {added} nye TV/radio-streams i Custom M3U.')
            self.load_tv_async()
        except Exception as e:
            messagebox.showerror(APP_NAME, f'M3U-import feilet:\n{e}')

    # ---------- Radio ----------

    def build_radio_tab(self):
        self.radio_search_var = StringVar(value='')
        self.radio_country_var = StringVar(value='WORLD TOP')
        self.radio_tag_var = StringVar(value='')
        self.radio_hide_broken_var = BooleanVar(value=True)
        self.radio_info_var = StringVar(value='Velg en radiostasjon.')
        controls = ttk.Frame(self.radio_tab)
        controls.pack(fill=X, pady=8)
        self.radio_search = ttk.Entry(controls, textvariable=self.radio_search_var)
        self.radio_search.pack(side=LEFT, fill=X, expand=True, padx=(0, 8))
        self.radio_search.bind('<Return>', lambda e: self.load_radio_async(mode='search'))
        self.radio_country_box = ttk.Combobox(controls, textvariable=self.radio_country_var, state='readonly', width=28)
        self.radio_country_box['values'] = ['WORLD TOP']
        self.radio_country_box.pack(side=LEFT, padx=4)
        self.radio_country_box.bind('<<ComboboxSelected>>', lambda e: self.load_radio_async(mode='country'))
        self.radio_tag = ttk.Entry(controls, textvariable=self.radio_tag_var, width=20)
        self.radio_tag.pack(side=LEFT, padx=4)
        self.radio_tag.bind('<Return>', lambda e: self.load_radio_async(mode='search'))
        ttk.Checkbutton(controls, text='Skjul døde', variable=self.radio_hide_broken_var).pack(side=LEFT, padx=6)
        ttk.Button(controls, text='🔎 Søk', command=lambda: self.load_radio_async(mode='search')).pack(side=RIGHT, padx=4)
        ttk.Button(controls, text='🔥 World Top', command=lambda: self.load_radio_async(mode='top')).pack(side=RIGHT, padx=4)
        ttk.Button(controls, text='🌍 Radio Garden', command=lambda: webbrowser.open('https://radio.garden/')).pack(side=RIGHT, padx=4)

        columns = ('fav','name','country','state','language','tags','codec','bitrate','votes')
        wrap = ttk.Frame(self.radio_tab)
        wrap.pack(fill=BOTH, expand=True)
        self.radio_tree = ttk.Treeview(wrap, columns=columns, show='headings', selectmode='browse')
        heads = {'fav':'★','name':'Stasjon','country':'Land','state':'Region','language':'Språk','tags':'Tags','codec':'Codec','bitrate':'kbps','votes':'Stemmer'}
        widths = {'fav':45,'name':310,'country':160,'state':150,'language':140,'tags':250,'codec':75,'bitrate':70,'votes':75}
        for col in columns:
            self.radio_tree.heading(col, text=heads[col])
            self.radio_tree.column(col, width=widths[col], anchor='center' if col in ('fav','codec','bitrate','votes') else 'w', stretch=(col not in ('fav','codec','bitrate','votes')))
        ys = ttk.Scrollbar(wrap, orient=VERTICAL, command=self.radio_tree.yview)
        xs = ttk.Scrollbar(wrap, orient=HORIZONTAL, command=self.radio_tree.xview)
        self.radio_tree.configure(yscrollcommand=ys.set, xscrollcommand=xs.set)
        self.radio_tree.grid(row=0, column=0, sticky='nsew')
        ys.grid(row=0, column=1, sticky='ns')
        xs.grid(row=1, column=0, sticky='ew')
        wrap.rowconfigure(0, weight=1)
        wrap.columnconfigure(0, weight=1)
        self.radio_tree.bind('<Double-1>', lambda e: self.play_radio())
        self.radio_tree.bind('<<TreeviewSelect>>', lambda e: self.update_radio_info())

        actions = ttk.Frame(self.radio_tab)
        actions.pack(fill=X, pady=8)
        ttk.Button(actions, text='▶ PLAY RADIO', style='Gold.TButton', command=self.play_radio).pack(side=LEFT, padx=(0, 5))
        ttk.Button(actions, text='★ / ☆ Favoritt', command=self.toggle_radio_favorite).pack(side=LEFT, padx=4)
        ttk.Button(actions, text='★ Vis favoritter', command=self.show_radio_favorites).pack(side=LEFT, padx=4)
        ttk.Button(actions, text='🌐 Stasjonsside', command=self.open_radio_homepage).pack(side=LEFT, padx=4)
        ttk.Button(actions, text='⧉ Kopier stream', command=self.copy_radio_url).pack(side=LEFT, padx=4)
        ttk.Button(actions, text='✨ Media Wall', command=self.open_media_wall).pack(side=LEFT, padx=4)
        ttk.Button(actions, text='◉ TEST STREAM', command=lambda: self.probe_selected_stream('RADIO')).pack(side=LEFT, padx=4)
        ttk.Label(actions, textvariable=self.radio_info_var, style='Muted.TLabel').pack(side=LEFT, padx=12)

    def load_radio_countries_async(self):
        threading.Thread(target=self._radio_countries_worker, daemon=True).start()

    def _radio_countries_worker(self):
        try:
            data = radio_json('countries', {'hidebroken':'true','order':'name'})
            self.msgq.put(('radio_countries', data))
        except Exception as e:
            self.msgq.put(('radio_note', f'Kunne ikke hente radioland: {e}'))

    def load_radio_async(self, mode='top'):
        if self.radio_loading:
            return
        self.radio_loading = True
        self.status_var.set('Laster verdensradio …')
        threading.Thread(target=self._radio_worker, args=(mode,), daemon=True).start()

    def _radio_worker(self, mode):
        try:
            hidebroken = 'true' if self.radio_hide_broken_var.get() else 'false'
            params = {'hidebroken': hidebroken, 'limit': '1000'}
            endpoint = 'stations'
            if mode == 'top':
                params.update({'order': 'votes', 'reverse': 'true', 'limit': '500'})
            elif mode == 'country':
                country = self.radio_country_var.get()
                if not country or country == 'WORLD TOP':
                    params.update({'order': 'votes', 'reverse': 'true', 'limit': '500'})
                else:
                    cc = country.split(' — ', 1)[0].strip()
                    params.update({'countrycode': cc, 'order': 'votes', 'reverse': 'true'})
                    endpoint = 'stations/search'
            else:
                name = self.radio_search_var.get().strip()
                tag = self.radio_tag_var.get().strip()
                if name:
                    params['name'] = name
                if tag:
                    params['tag'] = tag
                params.update({'order': 'votes', 'reverse': 'true'})
                endpoint = 'stations/search'
            raw = radio_json(endpoint, params)
            stations=[]; seen=set()
            for x in raw:
                station_url=(x.get('url_resolved') or x.get('url') or '').strip()
                uid=(x.get('stationuuid') or station_url).strip()
                if not station_url or not uid or uid in seen:
                    continue
                seen.add(uid)
                stations.append(RadioStation(
                    uuid=uid,
                    name=(x.get('name') or 'Unnamed').strip(),
                    country=(x.get('country') or '').strip(),
                    countrycode=(x.get('countrycode') or '').strip(),
                    state=(x.get('state') or '').strip(),
                    language=(x.get('language') or '').strip(),
                    tags=(x.get('tags') or '').strip(),
                    codec=(x.get('codec') or '').strip(),
                    bitrate=int(x.get('bitrate') or 0),
                    url=station_url,
                    homepage=(x.get('homepage') or '').strip(),
                    favicon=(x.get('favicon') or '').strip(),
                    votes=int(x.get('votes') or 0),
                    clickcount=int(x.get('clickcount') or 0),
                ))
            self.msgq.put(('radio_loaded', stations))
        except Exception as e:
            self.msgq.put(('error', ('Radio', str(e))))

    def populate_radio(self, items):
        self.radio_filtered = list(items)
        self.radio_tree.delete(*self.radio_tree.get_children())
        for idx, s in enumerate(items):
            fav = '★' if s.uuid in self.radio_favorites else ''
            tags = s.tags[:80] + ('…' if len(s.tags) > 80 else '')
            self.radio_tree.insert('', END, iid=str(idx), values=(fav, s.name, s.country, s.state, s.language, tags, s.codec, s.bitrate, s.votes))
        self.status_var.set(f'Radio: {len(items):,} stasjoner')

    def selected_radio(self):
        sel = self.radio_tree.selection()
        if not sel:
            return None
        try:
            return self.radio_filtered[int(sel[0])]
        except Exception:
            return None

    def play_radio(self):
        s = self.selected_radio()
        if not s:
            messagebox.showinfo(APP_NAME, 'Velg en radiostasjon først.')
            return
        try:
            threading.Thread(target=self.radio_click_ping, args=(s.uuid,), daemon=True).start()
            play_url(s.url)
            push_history(RADIO_HISTORY_FILE, asdict(s), 'url')
            self.radio_history = read_json(RADIO_HISTORY_FILE, [])
            self.refresh_home()
            self.status_var.set(f'Radio: {s.name}')
        except FileNotFoundError:
            self.offer_vlc()

    def radio_click_ping(self, uuid):
        try:
            radio_json(f'url/{urllib.parse.quote(uuid)}', timeout=8)
        except Exception:
            pass

    def toggle_radio_favorite(self):
        s = self.selected_radio()
        if not s:
            return
        if s.uuid in self.radio_favorites:
            self.radio_favorites.remove(s.uuid)
        else:
            self.radio_favorites.add(s.uuid)
        write_json(RADIO_FAV_FILE, sorted(self.radio_favorites))
        self.populate_radio(self.radio_filtered)

    def show_radio_favorites(self):
        q = [s for s in self.radio_stations if s.uuid in self.radio_favorites]
        self.populate_radio(q)
        self.status_var.set(f'Radio-favoritter i nåværende datasett: {len(q)}')

    def update_radio_info(self):
        s = self.selected_radio()
        if not s:
            self.radio_info_var.set('Velg en radiostasjon.')
            return
        parts = [x for x in [s.country, s.state, s.language, f'{s.codec} {s.bitrate}kbps'.strip()] if x]
        self.radio_info_var.set(' • '.join(parts))

    def open_radio_homepage(self):
        s = self.selected_radio()
        if s and s.homepage:
            webbrowser.open(s.homepage)

    def copy_radio_url(self):
        s = self.selected_radio()
        if s:
            self.copy_clipboard(s.url, 'Radio-stream URL kopiert')

    # ---------- Browser Media Wall ----------

    def open_media_wall(self):
        iso = self.globe_selected_iso or "NO"
        name = self.globe_selected_name or self.tv_country_name_by_iso.get(iso, iso)
        tv = [c for c in self.tv_channels if (c.country or "").upper() == iso][:72]
        radio = self.globe_radio_preview_items[:30] if self.globe_selected_iso == iso else []
        cams = self.globe_webcam_preview_items[:30] if self.globe_selected_iso == iso else []
        hls_all=[c for c in self.tv_channels if c.url and '.m3u8' in c.url.lower()]
        random.shuffle(hls_all)
        world_mix=hls_all[:60]
        data = {
            "country": {"code": iso, "name": name},
            "super_mode": bool(self.super_mode_var.get()),
            "scene": self.super_scene_var.get(),
            "tv": [asdict(x) for x in tv],
            "world_tv": [asdict(x) for x in world_mix],
            "radio": [asdict(x) for x in radio],
            "webcams": [asdict(x) for x in cams],
        }
        ensure_dirs()
        MEDIA_WALL_FILE.write_text(self.media_wall_html(data), encoding="utf-8")
        webbrowser.open(MEDIA_WALL_FILE.as_uri())
        self.status_var.set(f"Media Wall opened • {name} • {len(tv)} TV • {len(radio)} radio • {len(cams)} webcams")

    def media_wall_html(self, data):
        payload = json.dumps(data, ensure_ascii=False).replace("</", "<\\/")
        title = html.escape(data["country"]["name"])
        code = html.escape(data["country"]["code"])
        return f'''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RAH World Media — {title}</title>
<script src="https://cdn.jsdelivr.net/npm/hls.js@1/dist/hls.min.js"></script>
<style>
:root{{--bg:#07090c;--panel:#11151b;--gold:#d7ad42;--gold2:#f2d270;--text:#f3ead5;--muted:#a9a390}}
*{{box-sizing:border-box}} body{{margin:0;background:radial-gradient(circle at 20% 0,#1e190c 0,#07090c 38%);color:var(--text);font-family:Segoe UI,system-ui,sans-serif}}
header{{position:sticky;top:0;z-index:20;padding:18px 26px;background:rgba(7,9,12,.91);backdrop-filter:blur(18px);border-bottom:1px solid #2b2517;display:flex;gap:18px;align-items:center}}
.brand{{font-weight:800;letter-spacing:.18em;color:var(--gold2)}} .sub{{color:var(--muted);font-size:13px}} input{{margin-left:auto;width:min(420px,40vw);background:#11151b;color:white;border:1px solid #3c321c;border-radius:9px;padding:10px 13px}}
main{{padding:24px;max-width:1900px;margin:auto}} h2{{letter-spacing:.13em;font-size:13px;color:var(--gold);margin:26px 0 12px}}
.grid{{display:grid;grid-template-columns:repeat(auto-fill,minmax(245px,1fr));gap:13px}}
.card{{position:relative;min-height:155px;border:1px solid #2e2a20;background:linear-gradient(150deg,#15191f,#0c0f13);border-radius:12px;overflow:hidden;transition:.22s transform,.22s border-color,.22s box-shadow}}
.card:hover{{transform:translateY(-4px) scale(1.015);border-color:var(--gold);box-shadow:0 12px 40px #000b,0 0 0 1px #d7ad4233}}
.visual{{height:138px;display:flex;align-items:center;justify-content:center;background:#090c10;overflow:hidden;position:relative}}
.visual img{{width:100%;height:100%;object-fit:cover}} .visual img.logo{{object-fit:contain;padding:28px;background:radial-gradient(circle,#282213,#090c10 65%)}}
.visual video{{position:absolute;inset:0;width:100%;height:100%;object-fit:cover;background:#000;opacity:0;transition:opacity .28s}} .card.previewing video{{opacity:1}}
.meta{{padding:11px 12px 13px}} .name{{font-weight:650;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}} .small{{color:var(--muted);font-size:12px;margin-top:4px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}}
.badge{{position:absolute;top:9px;left:9px;background:#090b0ddd;border:1px solid #5b4a20;color:#f4d97f;padding:4px 7px;border-radius:5px;font:10px ui-monospace,monospace;letter-spacing:.12em;z-index:4}}
.play{{position:absolute;right:9px;top:9px;background:#d7ad42;color:#08090a;border:0;border-radius:6px;padding:5px 8px;font-weight:800;z-index:5;cursor:pointer}}
.empty{{padding:30px;border:1px dashed #3a321f;border-radius:12px;color:var(--muted)}}
.mosaicButtons{{display:flex;gap:5px;margin-left:auto}} .mosaicButtons button{{background:#17140c;border:1px solid #5b4a20;color:#f2d270;padding:8px 10px;border-radius:7px;cursor:pointer;font-weight:800}}
#mosaic{{display:none;position:fixed;inset:0;background:#030405f5;z-index:120;padding:54px 24px 24px}} #mosaic.open{{display:block}} #mosaicGrid{{height:100%;display:grid;gap:7px}} .mtile{{position:relative;min-height:0;background:#000;border:1px solid #493b1d;overflow:hidden}} .mtile video{{width:100%;height:100%;object-fit:cover;background:#000}} .mtile.dead{{border-color:#7d2f2f;opacity:.72}} .mtitle{{position:absolute;left:8px;bottom:7px;background:#000b;color:#f4d97f;padding:4px 7px;font:11px monospace}} #mosaicClose{{position:absolute;right:24px;top:15px;background:#d7ad42;border:0;padding:8px 13px;font-weight:900;cursor:pointer}}
#theater{{display:none;position:fixed;inset:0;background:#000e;z-index:99;align-items:center;justify-content:center;padding:5vw}} #theater.open{{display:flex}} #theater video{{width:min(1400px,92vw);max-height:82vh;background:black;border:1px solid #665322}} #close{{position:absolute;top:25px;right:28px;background:#d7ad42;border:0;padding:10px 14px;font-weight:800;cursor:pointer}}
@media(max-width:700px){{header{{flex-wrap:wrap}}input{{width:100%;margin-left:0}}main{{padding:14px}}.grid{{grid-template-columns:1fr 1fr}}.visual{{height:105px}}}}
</style></head><body>
<header><div><div class="brand">RAH WORLD MEDIA 9.9 • SUPER MODE</div><div class="sub">THE WORLD, LIVE. • {title} ({code})</div></div><div class="mosaicButtons"><button onclick="openMosaic(4)">▦ 4</button><button onclick="openMosaic(6)">▦ 6</button><button onclick="openMosaic(9)">▦ 9</button><button onclick="openMosaic(12)">▦ 12</button><button onclick="openMosaic(9,true)">🌍 WORLD MIX</button><button onclick="nextMosaic()">NEXT</button><button onclick="toggleFullscreen()">FULLSCREEN</button></div><input id="search" placeholder="SUPER SEARCH • channels, radio, webcams…"></header>
<main><section><h2>SUPER LIVE TV WALL • MOSAIC 4 / 6 / 9 / 12 • WORLD MIX</h2><div id="tv" class="grid"></div></section><section><h2>WORLD RADIO</h2><div id="radio" class="grid"></div></section><section><h2>WEBCAMS</h2><div id="cams" class="grid"></div></section></main>
<div id="mosaic"><button id="mosaicClose">CLOSE MOSAIC</button><div id="mosaicGrid"></div></div><div id="theater"><button id="close">CLOSE</button><video id="big" controls autoplay playsinline></video></div>
<script>const DATA={payload}; let active=[]; let bigHls=null; let mosaicHls=[]; let mosaicOffset=0; let mosaicCount=9; let mosaicWorld=false;
const esc=s=>String(s??'').replace(/[&<>\"']/g,m=>({{'&':'&amp;','<':'&lt;','>':'&gt;','\"':'&quot;',"'":'&#39;'}}[m]));
function placeholder(name,code){{return `<div style="font-weight:800;font-size:28px;color:#d7ad42;letter-spacing:.12em">${{esc((name||'RAH').slice(0,3).toUpperCase())}}</div><div style="position:absolute;bottom:10px;color:#8f876e;font:11px monospace">${{esc(code||'')}}</div>`}}
function stopPreview(card){{let v=card.querySelector('video');if(!v)return; if(v._hls){{v._hls.destroy();v._hls=null}} v.pause();v.removeAttribute('src');v.load();card.classList.remove('previewing');active=active.filter(x=>x!==card)}}
function startPreview(card,url){{if(!url||!url.includes('.m3u8'))return; while(active.length>=(DATA.super_mode?2:1))stopPreview(active.shift());let v=card.querySelector('video'); if(!v)return; try{{if(window.Hls&&Hls.isSupported()){{let h=new Hls({{enableWorker:true,lowLatencyMode:true,maxBufferLength:8}});v._hls=h;h.loadSource(url);h.attachMedia(v);h.on(Hls.Events.MANIFEST_PARSED,()=>v.play().catch(()=>{{}}));h.on(Hls.Events.ERROR,(_e,d)=>{{if(d&&d.fatal)stopPreview(card)}});}}else if(v.canPlayType('application/vnd.apple.mpegurl')){{v.src=url;v.play().catch(()=>{{}})}}else return; card.classList.add('previewing');active.push(card)}}catch(e){{stopPreview(card)}}}}
function openTheater(url){{let wrap=document.getElementById('theater'),v=document.getElementById('big'); if(bigHls){{bigHls.destroy();bigHls=null}} v.removeAttribute('src'); if(window.Hls&&Hls.isSupported()&&url.includes('.m3u8')){{bigHls=new Hls();bigHls.loadSource(url);bigHls.attachMedia(v)}}else v.src=url;wrap.classList.add('open');v.play().catch(()=>{{}})}}
function clearMosaic(){{mosaicHls.forEach(h=>{{try{{h.destroy()}}catch(e){{}}}});mosaicHls=[];let g=document.getElementById('mosaicGrid');g.innerHTML=''}}
function stopMosaic(){{clearMosaic();document.getElementById('mosaic').classList.remove('open')}}
function openMosaic(n,world=false){{if((n>9||world)&&!DATA.super_mode){{alert('Enable SUPER MODE in the Python command deck for 12-screen and WORLD MIX.');return}}clearMosaic();mosaicCount=n||mosaicCount;mosaicWorld=!!world;let src=(mosaicWorld?DATA.world_tv:DATA.tv).filter(x=>x.url&&x.url.toLowerCase().includes('.m3u8'));if(!src.length){{alert('No browser-compatible HLS streams in this set. VLC playback may still work.');return}}if(mosaicOffset>=src.length)mosaicOffset=0;let rows=src.slice(mosaicOffset,mosaicOffset+mosaicCount);if(rows.length<mosaicCount)rows=rows.concat(src.slice(0,mosaicCount-rows.length));let g=document.getElementById('mosaicGrid');let cols=mosaicCount<=4?2:(mosaicCount<=9?3:4);g.style.gridTemplateColumns=`repeat(${{cols}},1fr)`;g.style.gridTemplateRows=`repeat(${{Math.ceil(rows.length/cols)}},1fr)`;rows.forEach((x,i)=>{{let d=document.createElement('div');d.className='mtile';d.innerHTML=`<video muted playsinline autoplay></video><div class="mtitle">${{esc(x.name)}} • ${{esc(x.country_name)}}</div>`;g.appendChild(d);let v=d.querySelector('video');if(window.Hls&&Hls.isSupported()){{let h=new Hls({{enableWorker:true,maxBufferLength:4,maxMaxBufferLength:8}});mosaicHls.push(h);h.loadSource(x.url);h.attachMedia(v);h.on(Hls.Events.MANIFEST_PARSED,()=>v.play().catch(()=>{{}}));h.on(Hls.Events.ERROR,(_e,dta)=>{{if(dta&&dta.fatal){{try{{h.destroy()}}catch(e){{}};d.classList.add('dead')}}}})}}else if(v.canPlayType('application/vnd.apple.mpegurl')){{v.src=x.url;v.play().catch(()=>{{}})}}d.onclick=()=>{{g.querySelectorAll('video').forEach(z=>z.muted=true);v.muted=false;v.volume=.55}}}});document.getElementById('mosaic').classList.add('open')}}
function nextMosaic(){{mosaicOffset+=mosaicCount;openMosaic(mosaicCount,mosaicWorld)}}
function toggleFullscreen(){{let e=document.getElementById('mosaic');if(!document.fullscreenElement)e.requestFullscreen?.();else document.exitFullscreen?.()}}
document.getElementById('mosaicClose').onclick=stopMosaic;
document.getElementById('close').onclick=()=>{{document.getElementById('theater').classList.remove('open');let v=document.getElementById('big');v.pause();if(bigHls){{bigHls.destroy();bigHls=null}}}};
function tvCard(x){{let d=document.createElement('article');d.className='card item';d.dataset.search=(x.name+' '+x.country_name+' '+(x.categories||[]).join(' ')).toLowerCase();d.innerHTML=`<span class="badge">LIVE • ${{esc(x.quality||'TV')}}</span><button class="play">PLAY</button><div class="visual">${{x.logo?`<img class="logo" src="${{esc(x.logo)}}" onerror="this.remove()">`:placeholder(x.name,x.country)}}<video muted playsinline></video></div><div class="meta"><div class="name">${{esc(x.name)}}</div><div class="small">${{esc(x.country_name)}} • ${{esc((x.categories||['general'])[0])}}</div></div>`;let t;d.onmouseenter=()=>t=setTimeout(()=>startPreview(d,x.url),450);d.onmouseleave=()=>{{clearTimeout(t);stopPreview(d)}};d.querySelector('.play').onclick=e=>{{e.stopPropagation();openTheater(x.url)}};return d}}
function radioCard(x){{let d=document.createElement('article');d.className='card item';d.dataset.search=(x.name+' '+x.country+' '+x.tags).toLowerCase();d.innerHTML=`<span class="badge">RADIO • ${{esc(x.bitrate||'')}} kbps</span><button class="play">LISTEN</button><div class="visual">${{x.favicon?`<img class="logo" src="${{esc(x.favicon)}}" onerror="this.remove()">`:placeholder(x.name,x.countrycode)}}</div><div class="meta"><div class="name">${{esc(x.name)}}</div><div class="small">${{esc(x.country)}} • ${{esc(x.language||x.tags||'')}}</div></div>`;d.querySelector('.play').onclick=e=>{{e.stopPropagation();new Audio(x.url).play().catch(()=>window.open(x.url,'_blank'))}};return d}}
function camCard(x){{let d=document.createElement('article');d.className='card item';d.dataset.search=(x.title+' '+x.city+' '+x.region+' '+x.country+' '+(x.categories||[]).join(' ')).toLowerCase();let link=x.detail_url||x.player_url||'#';d.innerHTML=`<span class="badge">${{x.is_live?'LIVE CAM':'WEBCAM'}}</span><button class="play">OPEN</button><a class="visual" href="${{esc(link)}}" target="_blank" rel="noopener">${{x.image_url?`<img src="${{esc(x.image_url)}}">`:placeholder(x.title,x.countrycode)}}</a><div class="meta"><div class="name">${{esc(x.title)}}</div><div class="small">${{esc([x.city,x.region,x.country].filter(Boolean).join(' • '))}}</div><div class="small">Webcams provided by Windy.com</div></div>`;d.querySelector('.play').onclick=e=>{{e.stopPropagation();window.open(link,'_blank')}};return d}}
function fill(id,rows,fn,msg){{let el=document.getElementById(id);if(!rows.length){{el.innerHTML=`<div class="empty">${{msg}}</div>`;return}}rows.forEach(x=>el.appendChild(fn(x)))}}
fill('tv',DATA.tv,tvCard,'No TV streams loaded for this country.');fill('radio',DATA.radio,radioCard,'Select the country on the Python globe first to load radio previews.');fill('cams',DATA.webcams,camCard,'Add a Windy Webcams API key in the Python app to load webcam previews.');
document.getElementById('search').oninput=e=>{{let q=e.target.value.toLowerCase();document.querySelectorAll('.item').forEach(x=>x.style.display=!q||x.dataset.search.includes(q)?'':'none')}};
</script></body></html>'''

    # ---------- Webcams ----------

    def build_webcam_tab(self):
        self.webcam_country_var = StringVar(value='NO')
        self.webcam_search_var = StringVar(value='')
        self.webcam_info_var = StringVar(value='Windy Webcams API v3 • themed channels + favorite city pins')
        controls = ttk.Frame(self.webcam_tab)
        controls.pack(fill=X, pady=8)

        ttk.Label(controls, text='Country code:').pack(side=LEFT, padx=(0, 4))
        self.webcam_country_box = ttk.Combobox(controls, textvariable=self.webcam_country_var, width=8)
        self.webcam_country_box.pack(side=LEFT, padx=4)
        self.webcam_country_box.bind('<Return>', lambda e: self.load_webcams_async(self.webcam_country_var.get(), target='tab'))
        self.webcam_country_box.bind('<<ComboboxSelected>>', lambda e: self.load_webcams_async(self.webcam_country_var.get(), target='tab'))

        ttk.Entry(controls, textvariable=self.webcam_search_var).pack(side=LEFT, fill=X, expand=True, padx=8)
        ttk.Button(controls, text='🔎 Filter', command=self.apply_webcam_filter).pack(side=LEFT, padx=4)
        ttk.Button(controls, text='↻ Load country', command=lambda: self.load_webcams_async(self.webcam_country_var.get(), target='tab')).pack(side=LEFT, padx=4)
        ttk.Button(controls, text='🔑 Windy API key', command=self.set_windy_key).pack(side=RIGHT, padx=4)
        ttk.Label(controls, text='CHANNEL', style='Muted.TLabel').pack(side=LEFT, padx=(12,4))
        theme=ttk.Combobox(controls, textvariable=self.webcam_theme_var, state='readonly', width=18, values=list(WEBCAM_THEME_MAP))
        theme.pack(side=LEFT, padx=4)
        theme.bind('<<ComboboxSelected>>', lambda e: (self.apply_webcam_filter(), self.redraw_globe(), self.save_state()))
        ttk.Button(controls, text='🌍 Windy Webcams', command=lambda: webbrowser.open('https://www.windy.com/webcams')).pack(side=RIGHT, padx=4)

        columns=('fav','name','country','place','categories','live')
        wrap=ttk.Frame(self.webcam_tab)
        wrap.pack(fill=BOTH, expand=True)
        self.webcam_tree=ttk.Treeview(wrap, columns=columns, show='headings', selectmode='browse')
        heads={'fav':'★','name':'Webcam','country':'Land','place':'By / region','categories':'Kategori','live':'Live'}
        widths={'fav':45,'name':360,'country':120,'place':240,'categories':260,'live':65}
        for col in columns:
            self.webcam_tree.heading(col,text=heads[col])
            self.webcam_tree.column(col,width=widths[col],anchor='center' if col in ('fav','live') else 'w',stretch=(col not in ('fav','live')))
        ys=ttk.Scrollbar(wrap,orient=VERTICAL,command=self.webcam_tree.yview)
        xs=ttk.Scrollbar(wrap,orient=HORIZONTAL,command=self.webcam_tree.xview)
        self.webcam_tree.configure(yscrollcommand=ys.set,xscrollcommand=xs.set)
        self.webcam_tree.grid(row=0,column=0,sticky='nsew')
        ys.grid(row=0,column=1,sticky='ns')
        xs.grid(row=1,column=0,sticky='ew')
        wrap.rowconfigure(0,weight=1)
        wrap.columnconfigure(0,weight=1)
        self.webcam_tree.bind('<Double-1>',lambda e:self.open_selected_webcam())
        self.webcam_tree.bind('<<TreeviewSelect>>',lambda e:self.update_webcam_info())

        actions=ttk.Frame(self.webcam_tab)
        actions.pack(fill=X,pady=8)
        ttk.Button(actions,text='▶ OPEN CAMERA',style='Gold.TButton',command=self.open_selected_webcam).pack(side=LEFT,padx=(0,5))
        ttk.Button(actions,text='★ / ☆ Favoritt',command=self.toggle_webcam_favorite).pack(side=LEFT,padx=4)
        ttk.Button(actions,text='★ Vis favoritter',command=self.show_webcam_favorites).pack(side=LEFT,padx=4)
        ttk.Button(actions,text='◆ Pin city',command=self.toggle_webcam_place_pin).pack(side=LEFT,padx=4)
        ttk.Button(actions,text='🌐 Source',command=self.open_webcam_source).pack(side=LEFT,padx=4)
        ttk.Label(actions,textvariable=self.webcam_info_var,style='Muted.TLabel').pack(side=LEFT,padx=12)

        country_codes=sorted({(f.get('iso_a2') or '').upper() for f in self.world_shapes if f.get('iso_a2')})
        self.webcam_country_box['values']=country_codes
        if not windy_api_key():
            self.status_var.set('Webcams ready • add Windy API key to activate worldwide camera catalog')

    def set_windy_key(self):
        current = 'configured' if windy_api_key() else 'not configured'
        key = simpledialog.askstring(APP_NAME, f'Windy Webcams API key ({current})\n\nKey is stored only on this PC under C:\\RAH\\IPTV.', show='*')
        if key is None:
            return
        key=key.strip()
        if not key:
            try:
                WEBCAM_KEY_FILE.unlink(missing_ok=True)
            except Exception:
                pass
            self.status_var.set('Windy webcam API key cleared')
            return
        ensure_dirs()
        WEBCAM_KEY_FILE.write_text(key,encoding='utf-8')
        self.status_var.set('Windy webcam API key saved locally')
        if self.globe_selected_iso:
            self.load_webcams_async(self.globe_selected_iso,target='globe')

    def load_webcams_async(self, country_code, target='tab'):
        code=(country_code or '').split()[0].strip().upper()
        if len(code)!=2:
            return
        if not windy_api_key():
            if target=='globe':
                self.populate_globe_webcam_preview([], note='Add Windy API key')
            else:
                self.populate_webcams([])
            return
        if self.webcam_loading and target=='tab':
            return
        if target=='tab':
            self.webcam_loading=True
        self.status_var.set(f'Laster webcams for {code} …')
        threading.Thread(target=self._webcam_worker,args=(code,target),daemon=True).start()

    def _webcam_worker(self, code, target):
        try:
            params=urllib.parse.urlencode({
                'countries':code,
                'include':'categories,images,location,player,urls',
                'lang':'en',
                'limit':'50',
                'sortKey':'popularity',
                'sortDirection':'desc',
            })
            raw=windy_json(f'{WEBCAM_API}/webcams?{params}')
            rows=raw.get('webcams',[]) if isinstance(raw,dict) else []
            cams=[]
            for x in rows:
                loc=x.get('location') or {}
                cats=x.get('categories') or []
                images=(x.get('images') or {}).get('current') or {}
                image_url=''
                if isinstance(images,dict):
                    for k in ('full','large','medium','preview','small','icon'):
                        v=images.get(k)
                        if isinstance(v,str) and v:
                            image_url=v; break
                player=x.get('player') or {}
                player_url=''
                is_live=False
                if isinstance(player,dict):
                    live=player.get('live')
                    if isinstance(live,str) and live:
                        player_url=live; is_live=True
                    elif isinstance(live,dict):
                        player_url=str(live.get('embed') or live.get('link') or '')
                        is_live=bool(live.get('available',player_url))
                    if not player_url:
                        for k in ('day','month','year','lifetime'):
                            v=player.get(k)
                            if isinstance(v,str) and v:
                                player_url=v; break
                urls=x.get('urls') or {}
                detail_url=str(urls.get('detail') or '') if isinstance(urls,dict) else ''
                cam=Webcam(
                    webcam_id=str(x.get('webcamId') or x.get('id') or ''),
                    title=str(x.get('title') or 'Webcam'),
                    status=str(x.get('status') or ''),
                    country=str(loc.get('country') or ''),
                    countrycode=str(loc.get('country_code') or code).upper(),
                    region=str(loc.get('region') or ''),
                    city=str(loc.get('city') or ''),
                    latitude=float(loc.get('latitude') or 0.0),
                    longitude=float(loc.get('longitude') or 0.0),
                    categories=[str(c.get('name') or c.get('id') or '') for c in cats if isinstance(c,dict)],
                    image_url=image_url,
                    player_url=player_url,
                    detail_url=detail_url,
                    is_live=is_live,
                )
                if cam.webcam_id:
                    cams.append(cam)
            self.msgq.put(('webcams_loaded',(code,target,cams,None)))
        except Exception as e:
            self.msgq.put(('webcams_loaded',(code,target,[],str(e))))

    def populate_webcams(self, items):
        self.webcams=list(items)
        self.apply_webcam_filter()

    def apply_webcam_filter(self):
        q=normalize(self.webcam_search_var.get()) if hasattr(self,'webcam_search_var') else ''
        items=[]
        for cam in self.webcams:
            hay=' '.join([cam.title,cam.country,cam.countrycode,cam.city,cam.region,' '.join(cam.categories)])
            if q and q not in normalize(hay):
                continue
            if not self.webcam_theme_match(cam):
                continue
            items.append(cam)
        self.webcam_filtered=items
        if not hasattr(self,'webcam_tree'):
            return
        self.webcam_tree.delete(*self.webcam_tree.get_children())
        for idx,cam in enumerate(items):
            fav='★' if cam.webcam_id in self.webcam_favorites else ''
            place=', '.join(x for x in [cam.city,cam.region] if x)
            self.webcam_tree.insert('',END,iid=str(idx),values=(fav,cam.title,cam.country or cam.countrycode,place,', '.join(cam.categories[:3]),'LIVE' if cam.is_live else ''))
        self.status_var.set(f'Webcams: {len(items)} • Webcams provided by Windy.com')

    def selected_webcam(self):
        sel=self.webcam_tree.selection()
        if not sel:
            return None
        try:
            return self.webcam_filtered[int(sel[0])]
        except Exception:
            return None

    def open_webcam(self, cam):
        url=cam.player_url or cam.detail_url
        if not url:
            messagebox.showinfo(APP_NAME,'Denne webcam-en har ingen spillerlenke.')
            return
        webbrowser.open(url)
        push_history(WEBCAM_HISTORY_FILE, asdict(cam), 'webcam_id')
        self.webcam_history = read_json(WEBCAM_HISTORY_FILE, [])
        self.refresh_home()
        self.status_var.set(f'Webcam: {cam.title} • provided by Windy.com')

    def open_selected_webcam(self):
        cam=self.selected_webcam()
        if cam:
            self.open_webcam(cam)

    def toggle_webcam_favorite(self):
        cam=self.selected_webcam()
        if not cam:
            return
        if cam.webcam_id in self.webcam_favorites:
            self.webcam_favorites.remove(cam.webcam_id)
            self.webcam_favorite_items=[x for x in self.webcam_favorite_items if str(x.get('webcam_id','')) != cam.webcam_id]
        else:
            self.webcam_favorites.add(cam.webcam_id)
            self.webcam_favorite_items=[x for x in self.webcam_favorite_items if str(x.get('webcam_id','')) != cam.webcam_id]
            self.webcam_favorite_items.insert(0,asdict(cam))
        write_json(WEBCAM_FAV_FILE,sorted(self.webcam_favorites))
        write_json(WEBCAM_FAV_ITEMS_FILE,self.webcam_favorite_items[:200])
        self.apply_webcam_filter()
        self.redraw_globe()

    def toggle_webcam_place_pin(self):
        cam=self.selected_webcam()
        if not cam:
            return
        key=f"{cam.countrycode}|{cam.city or cam.region}|{round(cam.latitude,3)}|{round(cam.longitude,3)}"
        def pkey(p):
            return f"{str(p.get('countrycode','')).upper()}|{p.get('city') or p.get('region','')}|{round(float(p.get('latitude',0)),3)}|{round(float(p.get('longitude',0)),3)}"
        existing=next((i for i,p in enumerate(self.favorite_places) if pkey(p)==key),None)
        if existing is not None:
            self.favorite_places.pop(existing)
            self.status_var.set(f"Unpinned {cam.city or cam.region or cam.country}")
        else:
            self.favorite_places.insert(0,{
                'city':cam.city,'region':cam.region,'country':cam.country,'countrycode':cam.countrycode,
                'latitude':cam.latitude,'longitude':cam.longitude,'source_webcam_id':cam.webcam_id
            })
            self.status_var.set(f"Pinned {cam.city or cam.region or cam.country} on globe")
        write_json(FAVORITE_PLACES_FILE,self.favorite_places[:200])
        self.redraw_globe()

    def show_webcam_favorites(self):
        q=self.favorite_webcam_objects()
        self.webcam_filtered=q
        self.webcam_tree.delete(*self.webcam_tree.get_children())
        for idx,cam in enumerate(q):
            place=', '.join(x for x in [cam.city,cam.region] if x)
            self.webcam_tree.insert('',END,iid=str(idx),values=('★',cam.title,cam.country or cam.countrycode,place,', '.join(cam.categories[:3]),'LIVE' if cam.is_live else ''))
        self.status_var.set(f'Webcam-favoritter: {len(q)}')

    def open_webcam_source(self):
        cam=self.selected_webcam()
        if cam and cam.detail_url:
            webbrowser.open(cam.detail_url)

    def update_webcam_info(self):
        cam=self.selected_webcam()
        if cam:
            place=', '.join(x for x in [cam.city,cam.region,cam.country] if x)
            self.webcam_info_var.set(f'{place} • {"LIVE" if cam.is_live else "timelapse/still"} • Webcams provided by Windy.com')

    # ---------- shared ----------

    def offer_vlc(self):
        if messagebox.askyesno(APP_NAME, 'VLC ble ikke funnet.\n\nVil du åpne VLC sin nedlastingsside?'):
            webbrowser.open('https://www.videolan.org/vlc/')

    def copy_clipboard(self, text, status):
        self.root.clipboard_clear()
        self.root.clipboard_append(text)
        self.status_var.set(status)

    def save_state(self):
        write_json(STATE_FILE, {
            'tv_search': self.tv_search_var.get(),
            'tv_country': self.tv_country_var.get(),
            'tv_category': self.tv_category_var.get(),
            'tv_hide_geo': self.tv_hide_geo_var.get(),
            'tv_hide_not247': self.tv_hide_not247_var.get(),
            'globe_lon0': self.globe_lon0,
            'globe_lat0': self.globe_lat0,
            'globe_zoom': self.globe_zoom,
            'globe_layer': self.globe_layer_var.get(),
            'globe_auto_rotate': self.auto_rotate_var.get(),
            'world_live': self.world_live_var.get(),
            'world_live_interval': self.world_live_interval,
            'super_mode': self.super_mode_var.get(),
            'super_scene': self.super_scene_var.get(),
            'webcam_theme': self.webcam_theme_var.get(),
        })

    def poll_queue(self):
        try:
            while True:
                kind, payload = self.msgq.get_nowait()
                if kind == 'tv_loaded':
                    self.tv_channels, self.tv_counts_by_iso, self.tv_country_name_by_iso = payload
                    self.tv_loading = False
                    country_names = sorted({c.country_name for c in self.tv_channels if c.country_name})
                    category_names = sorted({cat for c in self.tv_channels for cat in c.categories if cat})
                    self.tv_country_box['values'] = ['ALL'] + country_names + ['Custom M3U']
                    self.tv_category_box['values'] = ['ALL'] + category_names
                    if self.tv_country_var.get() not in self.tv_country_box['values']:
                        self.tv_country_var.set('ALL')
                    if self.tv_category_var.get() not in self.tv_category_box['values']:
                        self.tv_category_var.set('ALL')
                    self.apply_tv_filters()
                    self.redraw_globe()
                    if self.globe_selected_iso:
                        self.populate_globe_tv_preview(self.globe_selected_iso)
                    self.refresh_home()
                elif kind == 'health_result':
                    media_kind,name,url,status,detail,ms=payload
                    self.stream_health_cache[url]={'status':status,'detail':detail,'latency_ms':ms,'checked_at':int(time.time())}
                    write_json(HEALTH_CACHE_FILE,self.stream_health_cache)
                    self.status_var.set(f"{media_kind} HEALTH • {status} • {ms} ms • {name} • {detail}")
                elif kind == 'radio_countries':
                    self.radio_countries = payload
                    vals=['WORLD TOP']
                    counts={}
                    for x in payload:
                        cc=(x.get('iso_3166_1') or '').strip().upper()
                        name=(x.get('name') or '').strip()
                        count=int(x.get('stationcount') or 0)
                        if cc and name:
                            vals.append(f'{cc} — {name} ({count})')
                            counts[cc]={'name': name, 'count': count}
                    self.radio_country_counts = counts
                    self.radio_country_box['values'] = vals
                    self.redraw_globe()
                    self.refresh_home()
                elif kind == 'radio_loaded':
                    self.radio_loading = False
                    self.radio_stations = payload
                    self.populate_radio(payload)
                elif kind == 'radio_note':
                    self.status_var.set(payload)
                elif kind == 'globe_radio_preview':
                    token, iso, stations, err = payload
                    if token != self.globe_preview_request or iso != self.globe_selected_iso:
                        continue
                    if err:
                        self.populate_globe_radio_preview([], loading=False, note='Radio preview failed')
                    else:
                        self.populate_globe_radio_preview(stations)
                elif kind == 'webcams_loaded':
                    code, target, cams, err = payload
                    if target == 'tab':
                        self.webcam_loading = False
                    if err:
                        if target == 'globe':
                            self.populate_globe_webcam_preview([], note='Webcam API unavailable')
                        else:
                            self.populate_webcams([])
                        self.status_var.set(f'Webcams: {err}')
                    else:
                        self.webcam_country_counts[code] = len(cams)
                        if target == 'globe':
                            if code == self.globe_selected_iso:
                                self.populate_globe_webcam_preview(cams)
                                tvc=self.tv_counts_by_iso.get(code,0)
                                rc=self.radio_country_counts.get(code,{}).get('count',0)
                                self.globe_selected_counts.set(f'TV: {tvc} stream(s) • Radio: {rc} station(s) • Webcams: {len(cams)}')
                                self.redraw_globe()
                        else:
                            self.populate_webcams(cams)
                        self.refresh_home()
                elif kind == 'error':
                    section, err = payload
                    if section == 'TV':
                        self.tv_loading = False
                    else:
                        self.radio_loading = False
                    self.status_var.set(f'{section}: feil')
                    messagebox.showerror(APP_NAME, f'{section} kunne ikke lastes:\n\n{err}\n\nSjekk internett/VPN og prøv igjen.')
        except queue.Empty:
            pass
        self.root.after(120, self.poll_queue)


def main():
    ensure_dirs()
    root = Tk()
    App(root)
    root.mainloop()


if __name__ == '__main__':
    main()
