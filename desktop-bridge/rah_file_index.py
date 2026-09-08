from __future__ import annotations

"""Bounded read-only file metadata index for fixed RAH-owned roots.

No user-supplied path is accepted. The collector never opens file contents,
never follows symlinks, never scans outside the fixed RAH roots, and never writes.
"""

import os
import pathlib
import time
from typing import Any

INDEX_VERSION = "1.0.0"
MAX_ENTRIES = 300
MAX_DEPTH = 4


def fixed_roots() -> list[tuple[str, pathlib.Path]]:
    roots: list[tuple[str, pathlib.Path]] = []
    if os.name == "nt":
        roots.append(("C:\\RAH", pathlib.Path(r"C:\RAH")))
    localapp = os.getenv("LOCALAPPDATA")
    if localapp:
        roots.append(("RAH Raven LocalAppData", pathlib.Path(localapp) / "RAH Raven"))
    return roots


def _safe_stat(path: pathlib.Path):
    try:
        return path.stat(follow_symlinks=False)
    except (OSError, ValueError):
        return None


def _index_root(label: str, root: pathlib.Path, *, max_entries: int = MAX_ENTRIES, max_depth: int = MAX_DEPTH) -> dict[str, Any]:
    root = root.expanduser()
    exists = root.exists() and root.is_dir()
    result: dict[str, Any] = {
        "label": label,
        "root": str(root),
        "exists": bool(exists),
        "entries": [],
        "truncated": False,
        "max_entries": int(max_entries),
        "max_depth": int(max_depth),
        "contents_read": False,
        "symlinks_followed": False,
    }
    if not exists:
        return result

    queue: list[tuple[pathlib.Path, int]] = [(root, 0)]
    entries: list[dict[str, Any]] = []
    while queue and len(entries) < max_entries:
        current, depth = queue.pop(0)
        try:
            children = sorted(current.iterdir(), key=lambda p: p.name.casefold())
        except OSError:
            continue
        for child in children:
            if len(entries) >= max_entries:
                result["truncated"] = True
                break
            try:
                if child.is_symlink():
                    kind = "symlink"
                    size = None
                    modified = None
                else:
                    stat = _safe_stat(child)
                    if child.is_dir():
                        kind = "dir"
                    elif child.is_file():
                        kind = "file"
                    else:
                        kind = "other"
                    size = int(stat.st_size) if stat and kind == "file" else None
                    modified = int(stat.st_mtime) if stat else None
                relative = child.relative_to(root).as_posix()
            except (OSError, ValueError):
                continue

            entries.append(
                {
                    "path": relative[:500],
                    "kind": kind,
                    "size_bytes": size,
                    "modified_unix": modified,
                    "depth": depth + 1,
                }
            )
            if kind == "dir" and depth + 1 < max_depth:
                queue.append((child, depth + 1))

    if queue:
        result["truncated"] = True
    result["entries"] = entries
    result["count"] = len(entries)
    result["files"] = sum(1 for item in entries if item["kind"] == "file")
    result["directories"] = sum(1 for item in entries if item["kind"] == "dir")
    result["symlinks"] = sum(1 for item in entries if item["kind"] == "symlink")
    return result


def collect_index() -> dict[str, Any]:
    started = time.monotonic()
    roots = [_index_root(label, path) for label, path in fixed_roots()]
    total = sum(int(root.get("count") or 0) for root in roots)
    lines = [
        "RAH RAVEN - READ ONLY FILE INDEX",
        f"ROOTS       : {len(roots)} fixed RAH root(s)",
        f"ENTRIES     : {total} metadata entries",
        "CONTENTS    : NOT READ",
        "SYMLINKS    : NOT FOLLOWED",
        f"LIMIT       : max {MAX_ENTRIES} entries/root · depth {MAX_DEPTH}",
    ]
    for root in roots:
        lines.append(
            f"  {root['label']}: exists={root['exists']} | entries={root.get('count', 0)} | files={root.get('files', 0)} | dirs={root.get('directories', 0)} | truncated={root['truncated']}"
        )
        for item in root.get("entries", []):
            size = f" | {item['size_bytes']} B" if item.get("size_bytes") is not None else ""
            lines.append(f"    [{item['kind']}] {item['path']}{size}")
    lines.append("SAFETY      : READ ONLY | fixed RAH roots only | no file content | symlinks not followed | file writes OFF | arbitrary paths OFF")

    return {
        "ok": True,
        "file_index": {
            "version": INDEX_VERSION,
            "roots": roots,
            "total_entries": total,
            "contents_read": False,
            "symlinks_followed": False,
            "arbitrary_paths": False,
            "file_writes": False,
            "max_entries_per_root": MAX_ENTRIES,
            "max_depth": MAX_DEPTH,
        },
        "stdout": "\n".join(lines)[:24000],
        "stderr": "",
        "command": None,
        "cwd": None,
        "duration_ms": round((time.monotonic() - started) * 1000),
    }
