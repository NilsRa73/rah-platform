from __future__ import annotations

import gc
import hashlib
import json
import sys
import tempfile
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path

from chronicle import Chronicle
from investigator import Investigator


APP_DIR = Path(__file__).resolve().parent


def desktop_dir() -> Path:
    if sys.platform == "win32":
        try:
            import ctypes

            buf = ctypes.create_unicode_buffer(32768)
            # CSIDL_DESKTOPDIRECTORY = 0x10. Follows Windows/OneDrive Desktop redirection.
            if ctypes.windll.shell32.SHGetFolderPathW(None, 0x10, None, 0, buf) == 0 and buf.value:
                return Path(buf.value)
        except Exception:
            pass
    return Path.home() / "Desktop"


EVIDENCE_DIR = desktop_dir() / "RAH Daily Driver Evidence"
TOOL_SUMMARY = EVIDENCE_DIR / "OWNED_TOOL_REVIEW_SUMMARY.json"
MAX_REVIEW_BYTES = 50 * 1024 * 1024

SPECS = [
    {
        "id": "sherlock",
        "label": "Sherlock owned CSV export",
        "extensions": {".csv"},
        "passive_required": False,
    },
    {
        "id": "phoneinfoga",
        "label": "PhoneInfoga owned TXT/JSON export",
        "extensions": {".txt", ".json"},
        "passive_required": False,
    },
    {
        "id": "spiderfoot",
        "label": "SpiderFoot passive owned JSON/CSV export",
        "extensions": {".json", ".csv"},
        "passive_required": True,
    },
]


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        while True:
            chunk = f.read(1024 * 1024)
            if not chunk:
                break
            h.update(chunk)
    return h.hexdigest()


def choose_file(spec):
    import tkinter as tk
    from tkinter import filedialog

    root = tk.Tk()
    root.withdraw()
    patterns = " ".join(f"*{x}" for x in sorted(spec["extensions"]))
    selected = filedialog.askopenfilename(
        title=f"Select {spec['label']}",
        filetypes=[(spec["label"], patterns), ("All files", "*.*")],
    )
    root.destroy()
    return Path(selected) if selected else None


def inspect_export(path: Path, spec):
    if not path or not path.exists() or not path.is_file():
        raise ValueError("export file was not selected or does not exist")
    if path.suffix.lower() not in spec["extensions"]:
        allowed = ", ".join(sorted(spec["extensions"]))
        raise ValueError(f"expected one of: {allowed}")

    size = path.stat().st_size
    if size <= 0:
        raise ValueError("export file is empty")
    if size > MAX_REVIEW_BYTES:
        raise ValueError("export file is larger than the 50 MiB review limit")

    before = sha256_file(path)
    with tempfile.TemporaryDirectory(prefix="rah-owned-tool-review-", ignore_cleanup_errors=True) as tmp:
        chronicle = Chronicle(Path(tmp) / "chronicle.db")
        investigator = Investigator(chronicle)
        result = investigator.import_tool_export(path)
        del investigator
        del chronicle
        gc.collect()
    after = sha256_file(path)

    kinds = Counter(str(item.get("kind", "unknown")) for item in result.get("entities", []))
    return {
        "format": path.suffix.lower().lstrip("."),
        "sizeBytes": size,
        "parseOk": True,
        "sourceUnchanged": before == after,
        "importedFiles": len(result.get("files", [])),
        "entityCount": len(result.get("entities", [])),
        "relationCount": len(result.get("relations", [])),
        "warningCount": len(result.get("warnings", [])),
        "entityKinds": dict(sorted(kinds.items())),
    }


def ask_exact(prompt: str, expected: str) -> bool:
    return input(prompt).strip().upper() == expected.upper()


def review_one(spec):
    print("\n" + "=" * 68)
    print(spec["label"])
    print("=" * 68)

    path = choose_file(spec)
    if not path:
        return {
            "tool": spec["id"],
            "status": "PENDING",
            "reason": "no file selected",
            "sourcePathPersisted": False,
            "sourceHashPersisted": False,
            "identifierValuesPersisted": False,
        }

    try:
        details = inspect_export(path, spec)
    except Exception as exc:
        return {
            "tool": spec["id"],
            "status": "FAIL",
            "reason": str(exc),
            "sourcePathPersisted": False,
            "sourceHashPersisted": False,
            "identifierValuesPersisted": False,
        }

    print(f"Format: {details['format']}")
    print(f"Size: {details['sizeBytes']} bytes")
    print(f"Entities: {details['entityCount']}")
    print(f"Relations: {details['relationCount']}")
    print(f"Warnings: {details['warningCount']}")
    print(f"Entity kinds: {json.dumps(details['entityKinds'], ensure_ascii=False)}")
    print(f"Source unchanged: {details['sourceUnchanged']}")
    print("\nReview the selected export yourself now.")
    print("No file path, file hash, or identifier value will be written to the evidence summary.")

    owned = ask_exact(
        "Type YES only if this is your own/authorized export and you are allowed to review it: ",
        "YES",
    )
    plausible = ask_exact(
        "Type YES only if the result looks plausible for the export you selected: ",
        "YES",
    )
    passive = True
    if spec["passive_required"]:
        passive = ask_exact(
            "Type PASSIVE only if this SpiderFoot export came from a passive-mode test: ",
            "PASSIVE",
        )

    passed = bool(details["parseOk"] and details["sourceUnchanged"] and owned and plausible and passive)
    return {
        "tool": spec["id"],
        "status": "PASS" if passed else "FAIL",
        "format": details["format"],
        "sizeBytes": details["sizeBytes"],
        "parseOk": details["parseOk"],
        "sourceUnchanged": details["sourceUnchanged"],
        "entityCount": details["entityCount"],
        "relationCount": details["relationCount"],
        "warningCount": details["warningCount"],
        "entityKinds": details["entityKinds"],
        "ownedAuthorizedConfirmed": owned,
        "plausibleResultConfirmed": plausible,
        "passiveModeConfirmed": passive if spec["passive_required"] else None,
        "sourcePathPersisted": False,
        "sourceHashPersisted": False,
        "identifierValuesPersisted": False,
    }


def write_summary(reviews):
    EVIDENCE_DIR.mkdir(parents=True, exist_ok=True)
    all_pass = all(x.get("status") == "PASS" for x in reviews)
    data = {
        "schemaVersion": 1,
        "product": "RAH Raven Daily Driver",
        "candidateVersion": "1.0.0",
        "review": "owned-tool-export-review",
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "stablePromotion": "BLOCKED",
        "automaticStablePromotion": False,
        "externalToolsAutoExecuted": False,
        "sourcePathsPersisted": False,
        "sourceHashesPersisted": False,
        "identifierValuesPersisted": False,
        "reviews": reviews,
        "allOwnedToolReviewsPass": all_pass,
        "nextAction": "canonical owned-machine acceptance combines this evidence with shortcut, LM Studio, and real archive evidence",
    }
    TOOL_SUMMARY.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    return data


def self_test():
    with tempfile.TemporaryDirectory(prefix="rah-owned-tool-selftest-", ignore_cleanup_errors=True) as tmp:
        tmp = Path(tmp)
        samples = [
            (
                SPECS[0],
                tmp / "sherlock.csv",
                "username,url_user,name,exists\nraven_test,https://github.com/raven_test,GitHub,true\n",
            ),
            (
                SPECS[1],
                tmp / "phoneinfoga.txt",
                "phone: +47 900 00 000\nsource: synthetic self-test\n",
            ),
            (
                SPECS[2],
                tmp / "spiderfoot.json",
                json.dumps({"source": "synthetic", "url": "https://example.invalid/profile"}),
            ),
        ]
        for spec, path, content in samples:
            path.write_text(content, encoding="utf-8")
            info = inspect_export(path, spec)
            assert info["parseOk"] is True
            assert info["sourceUnchanged"] is True
            assert info["importedFiles"] >= 1

    print("RAH Daily Driver owned-tool review self-test: PASS")
    print("External tools auto-executed: NO")
    print("Stable promotion: BLOCKED")
    return 0


def main():
    if "--self-test" in sys.argv:
        return self_test()

    print("RAH Raven Daily Driver 1.0 — OWNED-TOOL EXPORT REVIEW")
    print("This script never launches Sherlock, PhoneInfoga, or SpiderFoot.")
    print("It only reviews export files you explicitly select.")
    print("Stable promotion: BLOCKED")

    reviews = [review_one(spec) for spec in SPECS]
    summary = write_summary(reviews)

    print("\n" + "=" * 68)
    print("OWNED-TOOL REVIEW RESULT")
    print("=" * 68)
    for item in reviews:
        print(f"{item['tool']}: {item['status']}")
    print("All owned-tool reviews PASS:", summary["allOwnedToolReviewsPass"])
    print("Stable promotion: BLOCKED")
    print("Evidence:", TOOL_SUMMARY)

    try:
        import os

        os.startfile(EVIDENCE_DIR)
    except Exception:
        pass

    return 0 if summary["allOwnedToolReviewsPass"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
