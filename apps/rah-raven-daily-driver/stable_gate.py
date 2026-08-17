import json
from pathlib import Path


STAGES = ["Prototype", "Candidate", "Runtime Test", "Stable", "Frozen"]


class StableGate:
    def __init__(self, path, initial=None):
        self.path = Path(path)
        self.path.parent.mkdir(parents=True, exist_ok=True)
        if self.path.exists():
            self.data = json.loads(self.path.read_text(encoding="utf-8"))
        else:
            self.data = {"components": dict(initial or {})}
            self.save()

    def save(self):
        self.path.write_text(json.dumps(self.data, ensure_ascii=False, indent=2), encoding="utf-8")

    def components(self):
        return self.data.setdefault("components", {})

    def register(self, name, version, stage="Prototype", frozen=False, notes=""):
        if stage not in STAGES:
            raise ValueError("invalid stage")
        if name not in self.components():
            self.components()[name] = {
                "version": version,
                "stage": stage,
                "frozen": bool(frozen or stage == "Frozen"),
                "notes": notes,
            }
            self.save()

    def transition(self, name, new_stage, reason="normal"):
        if new_stage not in STAGES:
            raise ValueError("invalid stage")
        item = self.components()[name]
        if item.get("frozen") and reason not in {"bugfix", "new_version"}:
            raise PermissionError("Frozen component: only bugfix or explicit new_version may change it")
        old_index = STAGES.index(item["stage"])
        new_index = STAGES.index(new_stage)
        if new_index < old_index and reason != "new_version":
            raise ValueError("stage regression requires new_version")
        if new_index > old_index + 1:
            raise ValueError("stage skipping is forbidden")
        item["stage"] = new_stage
        item["frozen"] = new_stage == "Frozen"
        self.save()
