import json
import os
import threading
import tkinter as tk
from pathlib import Path
from tkinter import filedialog, messagebox, scrolledtext, ttk

from bridge import LocalBridge
from chronicle import Chronicle
from council import RavenCouncil
from devices import DeviceRegistry
from insights import generate_insights
from investigator import Investigator
from mission import build_report, save_report
from project_registry import find_repo_root, load_projects
from raven_agents import build_agents
from stable_gate import StableGate


BG = "#000000"
PANEL = "#0B0B0B"
GOLD = "#FFD700"
MUTED = "#A98C26"
TEXT = "#F0E5B0"


class DailyDriver:
    def __init__(self, root, config, app_dir):
        self.root = root
        self.config = config
        self.app_dir = Path(app_dir)
        self.runtime = self.app_dir / "runtime"
        for name in ("data", "logs", "reports", "devices", "imports", "exports", "state"):
            (self.runtime / name).mkdir(parents=True, exist_ok=True)

        self.chronicle = Chronicle(self.runtime / "data" / "raven_chronicle.db")
        self.agents = build_agents(config)
        self.council = RavenCouncil(self.agents, self.chronicle)
        self.investigator = Investigator(self.chronicle, config.get("identity", {}))
        self.devices = DeviceRegistry(self.runtime / "devices" / "devices.json")
        self.gate = StableGate(
            self.runtime / "state" / "module_status.json",
            initial=config.get("component_status", {}),
        )
        for name, info in config.get("component_status", {}).items():
            self.gate.register(name, info.get("version", "1.0"), info.get("stage", "Candidate"), info.get("frozen", False))
            self.chronicle.upsert_project(
                name,
                info.get("version", "1.0"),
                info.get("stage", "Candidate"),
                info.get("frozen", False),
                score=60 if info.get("stage") == "Candidate" else 10,
            )

        load_projects(self.app_dir, self.chronicle)
        self.last_investigation = {"files": [], "entities": [], "relations": [], "warnings": []}
        self.last_council = None
        self.bridge = LocalBridge(self.system_status, port=int(config.get("bridge", {}).get("port", 18767)))
        self.bridge.start()

        self.root.title("RAH Raven Daily Driver v1.0")
        self.root.geometry("1500x900")
        self.root.configure(bg=BG)
        self.root.protocol("WM_DELETE_WINDOW", self.close)
        self.views = {}
        self.status_labels = {}
        self._build()

    def close(self):
        try:
            self.bridge.stop()
        finally:
            self.root.destroy()

    def system_status(self):
        return {
            "product": "RAH Raven Daily Driver",
            "version": "1.0",
            "agents": {a.agent_id: a.status() for a in self.agents},
            "components": self.gate.components(),
            "devices": self.devices.snapshot(),
        }

    def button(self, parent, text, command):
        b = tk.Button(
            parent,
            text=text,
            command=command,
            bg=PANEL,
            fg=GOLD,
            activebackground=GOLD,
            activeforeground=BG,
            relief="flat",
            bd=1,
            highlightthickness=1,
            highlightbackground=MUTED,
            padx=12,
            pady=7,
            font=("Segoe UI", 10, "bold"),
        )
        return b

    def _build(self):
        header = tk.Frame(self.root, bg=BG)
        header.pack(fill="x", padx=12, pady=10)
        tk.Label(header, text="[ RAH RAVEN ]", bg=BG, fg=GOLD, font=("Consolas", 16, "bold")).pack(side="left")
        tk.Label(header, text="  DAILY DRIVER v1.0 — CANDIDATE", bg=BG, fg=GOLD, font=("Segoe UI", 18, "bold")).pack(side="left")

        nav = tk.Frame(self.root, bg=BG)
        nav.pack(fill="x", padx=12, pady=(0, 8))
        for name in ("Council", "Investigator", "Chronicle", "Mission", "Insights", "Devices"):
            self.button(nav, name, lambda n=name: self.show(n)).pack(side="left", padx=(0, 7))
        self.button(nav, "Stable CC 2.3", self.open_stable_cc).pack(side="right")

        self.content = tk.Frame(self.root, bg=BG)
        self.content.pack(fill="both", expand=True, padx=12, pady=(0, 12))

        for name in ("Council", "Investigator", "Chronicle", "Mission", "Insights", "Devices"):
            frame = tk.Frame(self.content, bg=BG)
            self.views[name] = frame

        self._build_council()
        self._build_investigator()
        self._build_chronicle()
        self._build_mission()
        self._build_insights()
        self._build_devices()
        self.show("Insights")

    def show(self, name):
        for frame in self.views.values():
            frame.pack_forget()
        self.views[name].pack(fill="both", expand=True)
        if name == "Chronicle":
            self.refresh_chronicle()
        elif name == "Insights":
            self.refresh_insights()
        elif name == "Devices":
            self.refresh_devices()

    def open_stable_cc(self):
        repo = find_repo_root(self.app_dir)
        if not repo:
            return messagebox.showinfo("RAH", "Stable repo Command Center was not found beside this package.")
        path = repo / "RAH-COMMAND-CENTER-V2.3.html"
        if path.exists():
            os.startfile(str(path))

    def _build_council(self):
        f = self.views["Council"]
        status = tk.Frame(f, bg=BG)
        status.pack(fill="x", pady=(0, 8))
        for agent in self.agents:
            label = tk.Label(status, text="", bg=PANEL, fg=TEXT, padx=10, pady=6)
            label.pack(side="left", padx=(0, 6))
            self.status_labels[agent.agent_id] = label
        self.button(status, "Refresh AI status", self.refresh_agent_status).pack(side="right")
        self.refresh_agent_status()

        self.council_input = tk.Entry(f, bg=PANEL, fg=GOLD, insertbackground=GOLD, font=("Segoe UI", 12))
        self.council_input.pack(fill="x", ipady=8)
        actions = tk.Frame(f, bg=BG)
        actions.pack(fill="x", pady=8)
        self.button(actions, "Send to Council", self.send_council).pack(side="left", padx=(0, 6))
        self.button(actions, "Debate 2 rounds", self.debate_council).pack(side="left")
        self.council_output = scrolledtext.ScrolledText(f, bg=BG, fg=TEXT, insertbackground=GOLD, font=("Consolas", 10))
        self.council_output.pack(fill="both", expand=True)

    def refresh_agent_status(self):
        for agent in self.agents:
            st = agent.status()
            state = "ONLINE" if st.get("online") else "OFFLINE"
            self.status_labels[agent.agent_id].config(
                text=f"{agent.name}\n{agent.agent_type.upper()} • {state}\n{st.get('detail','')}"
            )

    def _local_context(self):
        return {
            "chronicle_recent": self.chronicle.decisions_last_days(7),
            "pending_accounts": self.chronicle.accounts(["Pending", "Lost"])[:20],
            "investigator": {
                "entities": len(self.last_investigation.get("entities", [])),
                "relations": len(self.last_investigation.get("relations", [])),
            },
        }

    def send_council(self):
        text = self.council_input.get().strip()
        if not text:
            return
        self.council_input.delete(0, "end")
        self.council_output.insert("end", f"\nYOU: {text}\n")
        def work():
            responses = self.council.send_all(text, self._local_context())
            self.root.after(0, lambda: self._render_responses(responses))
        threading.Thread(target=work, daemon=True).start()

    def debate_council(self):
        topic = self.council_input.get().strip() or "Review current RAH Daily Driver priorities"
        self.council_input.delete(0, "end")
        self.council_output.insert("end", f"\nCOUNCIL TOPIC: {topic}\n")
        def work():
            result = self.council.debate(topic, 2, self._local_context())
            self.last_council = result
            final = result["rounds"][-1]["responses"]
            self.root.after(0, lambda: self._render_responses(final))
        threading.Thread(target=work, daemon=True).start()

    def _render_responses(self, responses):
        for item in responses:
            self.council_output.insert("end", f"\n[{item['agent']}]\n{item['response']}\n")
        self.council_output.see("end")

    def _build_investigator(self):
        f = self.views["Investigator"]
        top = tk.Frame(f, bg=BG)
        top.pack(fill="x", pady=(0, 8))
        self.button(top, "Import Facebook / Archive ZIP", self.import_archive).pack(side="left", padx=(0, 6))
        self.button(top, "Import extracted folder", self.import_folder).pack(side="left", padx=(0, 6))
        self.button(top, "Import evidence file", self.import_file).pack(side="left", padx=(0, 6))
        self.button(top, "Import Sherlock/PhoneInfoga/SpiderFoot export", self.import_tool).pack(side="left")
        self.inv_summary = scrolledtext.ScrolledText(f, height=12, bg=PANEL, fg=TEXT, font=("Consolas", 10))
        self.inv_summary.pack(fill="x")
        tk.Label(f, text="Recovery Dashboard", bg=BG, fg=GOLD, font=("Segoe UI", 12, "bold")).pack(anchor="w", pady=(10, 5))
        self.recovery = ttk.Treeview(f, columns=("kind", "provider", "status", "confidence"), show="tree headings")
        self.recovery.heading("#0", text="Identifier")
        for col in ("kind", "provider", "status", "confidence"):
            self.recovery.heading(col, text=col.title())
        self.recovery.pack(fill="both", expand=True)
        action = tk.Frame(f, bg=BG)
        action.pack(fill="x", pady=6)
        for status in ("Recovered", "Pending", "Lost", "Not mine"):
            self.button(action, status, lambda s=status: self.set_recovery_status(s)).pack(side="left", padx=(0, 5))
        self.refresh_recovery()

    def import_archive(self):
        path = filedialog.askopenfilename(filetypes=[("ZIP archive", "*.zip")])
        if path:
            self._run_import(lambda: self.investigator.import_zip(path))

    def import_folder(self):
        path = filedialog.askdirectory(title="Choose extracted archive folder")
        if path:
            self._run_import(lambda: self.investigator.import_path(path))

    def import_file(self):
        path = filedialog.askopenfilename(filetypes=[("Evidence", "*.json *.html *.htm *.txt *.csv *.log *.xml"), ("All", "*.*")])
        if path:
            self._run_import(lambda: self.investigator.import_path(path))

    def import_tool(self):
        path = filedialog.askopenfilename(filetypes=[("Tool exports", "*.csv *.json *.txt *.log"), ("All", "*.*")])
        if path:
            self._run_import(lambda: self.investigator.import_tool_export(path))

    def _run_import(self, fn):
        try:
            self.last_investigation = fn()
        except Exception as exc:
            return messagebox.showerror("Investigator", str(exc))
        self.inv_summary.delete("1.0", "end")
        self.inv_summary.insert(
            "end",
            json.dumps(
                {
                    "files": len(self.last_investigation["files"]),
                    "entities": len(self.last_investigation["entities"]),
                    "relations": len(self.last_investigation["relations"]),
                    "warnings": self.last_investigation["warnings"],
                },
                ensure_ascii=False,
                indent=2,
            ),
        )
        self.refresh_recovery()

    def refresh_recovery(self):
        for item in self.recovery.get_children():
            self.recovery.delete(item)
        for acc in self.investigator.recovery_dashboard():
            self.recovery.insert(
                "",
                "end",
                text=acc["identifier"],
                values=(acc["kind"], acc["provider"], acc["status"], f"{acc['confidence']:.2f}"),
            )

    def set_recovery_status(self, status):
        selection = self.recovery.selection()
        if not selection:
            return
        identifier = self.recovery.item(selection[0], "text")
        self.chronicle.set_account_status(identifier, status)
        self.refresh_recovery()

    def _build_chronicle(self):
        f = self.views["Chronicle"]
        self.chronicle_query = tk.Entry(f, bg=PANEL, fg=GOLD, insertbackground=GOLD, font=("Segoe UI", 11))
        self.chronicle_query.pack(fill="x", ipady=7)
        actions = tk.Frame(f, bg=BG)
        actions.pack(fill="x", pady=7)
        self.button(actions, "Ask Chronicle", self.ask_chronicle).pack(side="left", padx=(0, 6))
        self.button(actions, "Remember decision", self.remember_decision).pack(side="left")
        self.chronicle_output = scrolledtext.ScrolledText(f, bg=BG, fg=TEXT, font=("Consolas", 10))
        self.chronicle_output.pack(fill="both", expand=True)

    def ask_chronicle(self):
        q = self.chronicle_query.get().strip()
        if not q:
            return
        result = self.chronicle.ask(q)
        self.chronicle_output.delete("1.0", "end")
        self.chronicle_output.insert("end", json.dumps(result, ensure_ascii=False, indent=2, default=str))

    def remember_decision(self):
        text = self.chronicle_query.get().strip()
        if text:
            self.chronicle.decision(text, module="Daily Driver")
            self.chronicle_query.delete(0, "end")
            self.refresh_chronicle()

    def refresh_chronicle(self):
        items = self.chronicle.search("", 30)
        self.chronicle_output.delete("1.0", "end")
        self.chronicle_output.insert("end", json.dumps(items, ensure_ascii=False, indent=2))

    def _build_mission(self):
        f = self.views["Mission"]
        self.button(f, "Generate Mission Report", self.generate_mission).pack(anchor="w", pady=(0, 8))
        self.mission_output = scrolledtext.ScrolledText(f, bg=BG, fg=TEXT, font=("Consolas", 10))
        self.mission_output.pack(fill="both", expand=True)

    def generate_mission(self):
        report = build_report(
            self.chronicle,
            self.agents,
            self.council.histories,
            self.devices.snapshot(),
            self.gate.components(),
        )
        path = save_report(report, self.runtime / "reports")
        self.mission_output.delete("1.0", "end")
        self.mission_output.insert("end", json.dumps(report, ensure_ascii=False, indent=2, default=str))
        self.chronicle.remember("mission_report", "Mission", path.name, str(path))
        messagebox.showinfo("Mission", f"Saved: {path}")

    def _build_insights(self):
        f = self.views["Insights"]
        self.insights_output = scrolledtext.ScrolledText(f, bg=BG, fg=TEXT, font=("Consolas", 10))
        self.insights_output.pack(fill="both", expand=True)

    def refresh_insights(self):
        data = {
            "system_status": self.system_status(),
            "projects": self.chronicle.projects(),
            "insights": generate_insights(
                self.chronicle,
                self.agents,
                self.devices.snapshot(),
                self.gate.components(),
            ),
        }
        self.insights_output.delete("1.0", "end")
        self.insights_output.insert("end", json.dumps(data, ensure_ascii=False, indent=2, default=str))

    def _build_devices(self):
        f = self.views["Devices"]
        self.button(f, "Refresh Devices", self.refresh_devices).pack(anchor="w", pady=(0, 8))
        self.devices_output = scrolledtext.ScrolledText(f, bg=BG, fg=TEXT, font=("Consolas", 10))
        self.devices_output.pack(fill="both", expand=True)

    def refresh_devices(self):
        data = self.devices.snapshot()
        self.devices_output.delete("1.0", "end")
        self.devices_output.insert("end", json.dumps(data, ensure_ascii=False, indent=2))


def run_command_center(config, app_dir):
    root = tk.Tk()
    DailyDriver(root, config, app_dir)
    root.mainloop()
