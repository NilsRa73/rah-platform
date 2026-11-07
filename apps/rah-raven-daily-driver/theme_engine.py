import json
from pathlib import Path
import tkinter as tk
from tkinter import ttk


THEMES = {
    "raven_gold": {
        "label": "Raven Gold",
        "profile": "command",
        "bg": "#000000",
        "panel": "#0B0B0B",
        "accent": "#FFD700",
        "accent2": "#A98C26",
        "text": "#F0E5B0",
        "input_bg": "#111111",
        "good": "#39E75F",
        "danger": "#FF5A5A",
        "button_scale": 1.0,
        "font_scale": 1.0,
    },
    "picasso": {
        "label": "Picasso",
        "profile": "art",
        "bg": "#090A12",
        "panel": "#161321",
        "accent": "#E8A629",
        "accent2": "#2556A8",
        "text": "#F4EBD8",
        "input_bg": "#101726",
        "good": "#36D47A",
        "danger": "#E85F4A",
        "button_scale": 1.05,
        "font_scale": 1.02,
    },
    "steam_game": {
        "label": "Steam / Game",
        "profile": "game",
        "bg": "#0E141B",
        "panel": "#172331",
        "accent": "#66C0F4",
        "accent2": "#2A475E",
        "text": "#D6E4F0",
        "input_bg": "#101820",
        "good": "#75C46B",
        "danger": "#E66A6A",
        "button_scale": 1.35,
        "font_scale": 1.18,
    },
    "facebook_investigator": {
        "label": "Facebook Investigator",
        "profile": "analysis",
        "bg": "#05080D",
        "panel": "#101722",
        "accent": "#4C8BF5",
        "accent2": "#213B65",
        "text": "#E8F0FE",
        "input_bg": "#0D1520",
        "good": "#36D47A",
        "danger": "#FF6B6B",
        "button_scale": 1.0,
        "font_scale": 1.0,
    },
    "egypt_horus": {
        "label": "Egypt / Horus",
        "profile": "command",
        "bg": "#050401",
        "panel": "#171006",
        "accent": "#D9A520",
        "accent2": "#7C4B16",
        "text": "#F5E2A9",
        "input_bg": "#100B05",
        "good": "#68D391",
        "danger": "#E76F51",
        "button_scale": 1.05,
        "font_scale": 1.03,
    },
    "cyber_neon": {
        "label": "Cyber Neon",
        "profile": "lab",
        "bg": "#03070B",
        "panel": "#07141A",
        "accent": "#2FF3E0",
        "accent2": "#6C4BF4",
        "text": "#D8FFF8",
        "input_bg": "#061015",
        "good": "#51F58B",
        "danger": "#FF5C8A",
        "button_scale": 1.0,
        "font_scale": 1.0,
    },
    "clean_windows": {
        "label": "Clean Windows",
        "profile": "work",
        "bg": "#F3F3F3",
        "panel": "#FFFFFF",
        "accent": "#0067C0",
        "accent2": "#D9D9D9",
        "text": "#1A1A1A",
        "input_bg": "#FFFFFF",
        "good": "#107C10",
        "danger": "#C42B1C",
        "button_scale": 1.0,
        "font_scale": 1.0,
    },
}


def _hex_to_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def _luminance(rgb):
    def channel(value):
        value = value / 255.0
        return value / 12.92 if value <= 0.03928 else ((value + 0.055) / 1.055) ** 2.4

    r, g, b = (channel(v) for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast_ratio(a, b):
    la = _luminance(_hex_to_rgb(a))
    lb = _luminance(_hex_to_rgb(b))
    lighter, darker = max(la, lb), min(la, lb)
    return (lighter + 0.05) / (darker + 0.05)


class ThemeEngine:
    def __init__(self, state_path, default="raven_gold"):
        self.state_path = Path(state_path)
        self.state_path.parent.mkdir(parents=True, exist_ok=True)
        self.current_name = self._load(default)
        self.style = None

    def _load(self, default):
        if self.state_path.exists():
            try:
                data = json.loads(self.state_path.read_text(encoding="utf-8"))
                name = data.get("theme")
                if name in THEMES:
                    return name
            except Exception:
                pass
        return default if default in THEMES else "raven_gold"

    def save(self):
        self.state_path.write_text(
            json.dumps({"theme": self.current_name}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def names(self):
        return list(THEMES)

    def labels(self):
        return {name: data["label"] for name, data in THEMES.items()}

    def palette(self, name=None):
        return THEMES[name or self.current_name]

    def set_theme(self, name):
        if name not in THEMES:
            raise KeyError(name)
        self.current_name = name
        self.save()

    def name_from_label(self, label):
        for name, data in THEMES.items():
            if data["label"] == label:
                return name
        raise KeyError(label)

    def apply(self, root):
        palette = self.palette()
        root.configure(bg=palette["bg"])
        self._configure_ttk(palette)
        self._apply_widget(root, palette)

    def _configure_ttk(self, palette):
        if self.style is None:
            self.style = ttk.Style()
        self.style.configure(
            "RAH.Treeview",
            background=palette["panel"],
            fieldbackground=palette["panel"],
            foreground=palette["text"],
            rowheight=max(24, int(24 * palette["font_scale"])),
            borderwidth=0,
        )
        self.style.configure(
            "RAH.Treeview.Heading",
            background=palette["panel"],
            foreground=palette["accent"],
            relief="flat",
        )
        self.style.map(
            "RAH.Treeview",
            background=[("selected", palette["accent2"])],
            foreground=[("selected", palette["text"])],
        )
        self.style.configure(
            "RAH.TCombobox",
            fieldbackground=palette["panel"],
            background=palette["panel"],
            foreground=palette["text"],
            arrowcolor=palette["accent"],
        )

    def _scaled_font(self, widget, scale):
        try:
            font = widget.cget("font")
            if isinstance(font, (tuple, list)) and len(font) >= 2 and isinstance(font[1], int):
                return (font[0], max(8, int(font[1] * scale)), *font[2:])
        except Exception:
            pass
        return None

    def _apply_widget(self, widget, palette):
        try:
            role = getattr(widget, "_rah_theme_role", None)
            if role is None:
                if isinstance(widget, tk.Frame):
                    role = "panel" if str(widget.cget("bg")).upper() == "#0B0B0B" else "background"
                elif isinstance(widget, tk.Label):
                    fg = str(widget.cget("fg")).upper()
                    role = "accent" if fg == "#FFD700" else ("muted" if fg == "#A98C26" else "text")
                elif isinstance(widget, tk.Text):
                    role = "panel" if str(widget.cget("bg")).upper() == "#0B0B0B" else "background"
                else:
                    role = "default"
                try:
                    setattr(widget, "_rah_theme_role", role)
                except Exception:
                    pass

            if isinstance(widget, tk.Frame):
                widget.configure(bg=palette["panel"] if role == "panel" else palette["bg"])
            elif isinstance(widget, tk.Button):
                widget.configure(
                    bg=palette["panel"],
                    fg=palette["accent"],
                    activebackground=palette["accent"],
                    activeforeground=palette["bg"],
                    highlightbackground=palette["accent2"],
                    highlightcolor=palette["accent"],
                    padx=max(8, int(12 * palette["button_scale"])),
                    pady=max(5, int(7 * palette["button_scale"])),
                )
            elif isinstance(widget, tk.Label):
                fg = (
                    palette["accent"]
                    if role == "accent"
                    else (palette["accent2"] if role == "muted" else palette["text"])
                )
                widget.configure(bg=palette["bg"], fg=fg)
            elif isinstance(widget, tk.Entry):
                widget.configure(
                    bg=palette["input_bg"],
                    fg=palette["text"],
                    insertbackground=palette["accent"],
                    selectbackground=palette["accent2"],
                    selectforeground=palette["text"],
                )
            elif isinstance(widget, tk.Text):
                widget.configure(
                    bg=palette["panel"] if role == "panel" else palette["bg"],
                    fg=palette["text"],
                    insertbackground=palette["accent"],
                    selectbackground=palette["accent2"],
                    selectforeground=palette["text"],
                )
        except tk.TclError:
            pass

        if isinstance(widget, ttk.Treeview):
            try:
                widget.configure(style="RAH.Treeview")
            except tk.TclError:
                pass
        elif isinstance(widget, ttk.Combobox):
            try:
                widget.configure(style="RAH.TCombobox")
            except tk.TclError:
                pass

        scaled = self._scaled_font(widget, palette["font_scale"])
        if scaled is not None:
            try:
                widget.configure(font=scaled)
            except tk.TclError:
                pass

        for child in widget.winfo_children():
            self._apply_widget(child, palette)

    def audit(self, name=None):
        palette = self.palette(name)
        text_ratio = contrast_ratio(palette["text"], palette["bg"])
        accent_ratio = contrast_ratio(palette["accent"], palette["bg"])
        text_pass = text_ratio >= 4.5
        accent_pass = accent_ratio >= 3.0
        profile = palette["profile"]
        recommendations = []

        if not text_pass:
            recommendations.append(
                "Increase body-text contrast before using this theme for long reading sessions."
            )
        if not accent_pass:
            recommendations.append(
                "Accent contrast is weak; use it for decoration rather than critical text."
            )
        if profile == "game":
            recommendations.append(
                "Controller/sofa profile: larger hit targets and typography are enabled."
            )
        elif profile == "analysis":
            recommendations.append(
                "Analysis profile: reserve accent color for identity/recovery state and primary actions."
            )
        elif profile == "art":
            recommendations.append(
                "Art profile: best for presentation/show mode; switch to Raven Gold or Clean Windows for dense work."
            )
        else:
            recommendations.append("Suitable as a general Daily Driver workspace profile.")

        return {
            "theme": self.current_name if name is None else name,
            "label": palette["label"],
            "profile": profile,
            "contrast": {
                "body_text_on_background": round(text_ratio, 2),
                "accent_on_background": round(accent_ratio, 2),
                "body_text_wcag_aa": text_pass,
                "accent_ui_contrast": accent_pass,
            },
            "recommendations": recommendations,
        }
