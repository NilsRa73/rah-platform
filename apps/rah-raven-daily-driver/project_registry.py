import json
from pathlib import Path


KNOWN_MANIFESTS = [
    ("Command Center", "RAH-COMMAND-CENTER-VERSION.json"),
    ("Chronicle Stable", "RAH-RAVEN-CHRONICLE-VERSION.json"),
    ("Insights", "RAH-RAVEN-INSIGHTS-VERSION.json"),
    ("Mission Control", "RAH-RAVEN-MISSION-CONTROL-VERSION.json"),
    ("Council Legacy", "RAH-RAVEN-COUNCIL-VERSION.json"),
    ("Node Agent", "RAH-RAVEN-AGENT-RUNNER-VERSION.json"),
]


def find_repo_root(app_dir):
    current = Path(app_dir).resolve()
    for parent in [current, *current.parents]:
        if (parent / "RAH-COMMAND-CENTER-VERSION.json").exists():
            return parent
    return None


def load_projects(app_dir, chronicle):
    root = find_repo_root(app_dir)
    found = []
    if root:
        for fallback_name, relative in KNOWN_MANIFESTS:
            path = root / relative
            if not path.exists():
                continue
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
            except Exception:
                continue
            name = data.get("product", fallback_name)
            stage = str(data.get("stage", "Prototype")).title()
            if stage.lower() == "stable":
                stage = "Stable"
            frozen = bool(data.get("stable_release_gate", {}).get("runtime_files_frozen", False))
            if frozen:
                stage = "Frozen"
            score = {"Prototype": 10, "Candidate": 50, "Runtime Test": 75, "Stable": 100, "Frozen": 100}.get(stage, 0)
            chronicle.upsert_project(
                name,
                str(data.get("version", "")),
                stage,
                frozen=frozen,
                score=score,
                metadata={"manifest": relative},
            )
            found.append({"name": name, "stage": stage, "version": data.get("version", ""), "manifest": relative})
    return found
