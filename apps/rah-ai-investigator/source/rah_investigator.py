#!/usr/bin/env python3
"""RAH AI Investigator v1.0 RC2 local archive normalizer.

Reads only explicit local paths. It does not perform network requests, invoke
external OSINT tools, guess credentials, or modify the source archive.
"""
from __future__ import annotations

import argparse
import csv
import io
import json
import re
import sys
import tempfile
import zipfile
from datetime import datetime, timezone
from pathlib import Path, PurePosixPath
from typing import Iterable

VERSION = "1.0-RC2"
SCHEMA = "rah-investigator-case-v1"
SUPPORTED_SUFFIXES = {".txt", ".json", ".html", ".htm", ".csv", ".md", ".log"}
MAX_FILES = 500
MAX_MEMBER_BYTES = 8 * 1024 * 1024
MAX_TOTAL_BYTES = 64 * 1024 * 1024
MAX_TEXT_CHARS = 8 * 1024 * 1024

EMAIL_RE = re.compile(r"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b", re.I)
PHONE_RE = re.compile(r"(?<!\w)(?:\+?\d[\d .()\-]{6,}\d)(?!\w)")
URL_RE = re.compile(r"https?://[^\s\"'<>]+", re.I)
DATE_RE = re.compile(r"\b(?:19|20)\d{2}[-/.](?:0?[1-9]|1[0-2])[-/.](?:0?[1-9]|[12]\d|3[01])\b")


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def safe_archive_name(name: str) -> str:
    normalized = name.replace("\\", "/")
    p = PurePosixPath(normalized)
    if not normalized or p.is_absolute() or ".." in p.parts:
        raise ValueError(f"unsafe archive member path: {name!r}")
    return normalized


def decode_text(raw: bytes) -> str:
    if b"\x00" in raw[:4096]:
        raise ValueError("binary-looking file rejected")
    for encoding in ("utf-8-sig", "utf-8", "utf-16", "latin-1"):
        try:
            text = raw.decode(encoding)
            return text[:MAX_TEXT_CHARS]
        except UnicodeDecodeError:
            continue
    raise ValueError("unable to decode text")


def supported(name: str) -> bool:
    return Path(name).suffix.lower() in SUPPORTED_SUFFIXES


def iter_zip(path: Path) -> Iterable[tuple[str, bytes]]:
    total = 0
    with zipfile.ZipFile(path, "r") as zf:
        infos = zf.infolist()
        if len(infos) > MAX_FILES:
            raise ValueError(f"archive has too many members ({len(infos)} > {MAX_FILES})")
        if zf.testzip() is not None:
            raise ValueError("archive CRC validation failed")
        for info in infos:
            name = safe_archive_name(info.filename)
            if info.is_dir() or not supported(name):
                continue
            if info.file_size > MAX_MEMBER_BYTES:
                raise ValueError(f"archive member too large: {name}")
            total += info.file_size
            if total > MAX_TOTAL_BYTES:
                raise ValueError("archive supported-text payload exceeds safety limit")
            yield name, zf.read(info)


def iter_directory(path: Path) -> Iterable[tuple[str, bytes]]:
    files = sorted(p for p in path.rglob("*") if p.is_file() and p.suffix.lower() in SUPPORTED_SUFFIXES)
    if len(files) > MAX_FILES:
        raise ValueError(f"directory has too many supported files ({len(files)} > {MAX_FILES})")
    total = 0
    root = path.resolve()
    for p in files:
        resolved = p.resolve()
        try:
            rel = resolved.relative_to(root).as_posix()
        except ValueError as exc:
            raise ValueError(f"path escaped selected directory: {p}") from exc
        size = resolved.stat().st_size
        if size > MAX_MEMBER_BYTES:
            raise ValueError(f"file too large: {rel}")
        total += size
        if total > MAX_TOTAL_BYTES:
            raise ValueError("directory supported-text payload exceeds safety limit")
        yield rel, resolved.read_bytes()


def iter_input(path: Path) -> Iterable[tuple[str, bytes]]:
    if not path.exists():
        raise FileNotFoundError(path)
    if path.is_dir():
        yield from iter_directory(path)
        return
    if path.suffix.lower() == ".zip":
        yield from iter_zip(path)
        return
    if not supported(path.name):
        raise ValueError(f"unsupported input type: {path.suffix or '<none>'}")
    if path.stat().st_size > MAX_MEMBER_BYTES:
        raise ValueError("input file exceeds safety limit")
    yield path.name, path.read_bytes()


def usernames_from_urls(urls: Iterable[str]) -> set[str]:
    from urllib.parse import urlparse

    found: set[str] = set()
    for value in urls:
        try:
            parsed = urlparse(value)
            part = next((x for x in parsed.path.split("/") if x), "")
            part = part.lstrip("@").strip()
            if 1 <= len(part) <= 79 and re.fullmatch(r"[A-Za-z0-9._-]+", part):
                found.add(part)
        except Exception:
            continue
    return found


def empty_case() -> dict:
    return {
        "schema": SCHEMA,
        "version": VERSION,
        "created": utc_now(),
        "sources": [],
        "identifiers": {"emails": [], "phones": [], "urls": [], "usernames": []},
        "seeds": [],
        "accounts": [],
        "events": [],
        "normalizer": {
            "localOnly": True,
            "networkRequests": False,
            "externalToolExecution": False,
            "sourceMutation": False,
        },
    }


def normalize(path: Path) -> dict:
    case = empty_case()
    emails: set[str] = set()
    phones: set[str] = set()
    urls: set[str] = set()
    events: list[dict] = []

    for name, raw in iter_input(path):
        try:
            text = decode_text(raw)
        except ValueError as exc:
            case["sources"].append({"name": name, "size": len(raw), "status": "skipped", "reason": str(exc)})
            continue
        case["sources"].append({"name": name, "size": len(raw), "status": "read"})
        emails.update(x.lower() for x in EMAIL_RE.findall(text))
        phones.update(re.sub(r"\s+", " ", x).strip() for x in PHONE_RE.findall(text))
        urls.update(x.rstrip(")],.;") for x in URL_RE.findall(text))
        for date in DATE_RE.findall(text)[:80]:
            events.append({"date": date, "source": name, "kind": "date-observed"})

    case["identifiers"]["emails"] = sorted(emails)
    case["identifiers"]["phones"] = sorted(phones)
    case["identifiers"]["urls"] = sorted(urls)
    case["identifiers"]["usernames"] = sorted(usernames_from_urls(urls))
    case["events"] = sorted(events, key=lambda e: (e["date"], e["source"]))[:500]
    return case


def write_case(case: dict, out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(case, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def self_test() -> None:
    sample = """Account: https://example.com/Nils.Test\nMail: NILSRa73@example.com\nPhone: +47 900 00 000\nSeen 2026-08-17\n"""
    with tempfile.TemporaryDirectory(prefix="rah investigator ") as td:
        root = Path(td)
        (root / "sample.txt").write_text(sample, encoding="utf-8")
        case = normalize(root)
        assert case["schema"] == SCHEMA
        assert case["version"] == VERSION
        assert "nilsra73@example.com" in case["identifiers"]["emails"]
        assert "+47 900 00 000" in case["identifiers"]["phones"]
        assert "Nils.Test" in case["identifiers"]["usernames"]
        assert any(e["date"] == "2026-08-17" for e in case["events"])

        zip_path = root / "archive.zip"
        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("nested/data.txt", sample)
        zipped = normalize(zip_path)
        assert zipped["identifiers"]["emails"] == case["identifiers"]["emails"]

        bad = root / "bad.zip"
        with zipfile.ZipFile(bad, "w", zipfile.ZIP_DEFLATED) as zf:
            zf.writestr("../escape.txt", sample)
        try:
            normalize(bad)
        except ValueError as exc:
            assert "unsafe archive member path" in str(exc)
        else:
            raise AssertionError("path traversal archive was not rejected")

    print("RAH Investigator RC2 self-test PASS")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="RAH AI Investigator local archive normalizer")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("self-test", help="run local deterministic self-test")
    p_norm = sub.add_parser("normalize", help="normalize one explicit local file, directory, or ZIP")
    p_norm.add_argument("path", type=Path)
    p_norm.add_argument("--out", required=True, type=Path)
    args = parser.parse_args(argv)

    if args.command == "self-test":
        self_test()
        return 0
    case = normalize(args.path.expanduser())
    write_case(case, args.out.expanduser())
    print(f"Wrote {args.out}")
    print(
        "Identifiers: "
        f"emails={len(case['identifiers']['emails'])} "
        f"phones={len(case['identifiers']['phones'])} "
        f"usernames={len(case['identifiers']['usernames'])} "
        f"urls={len(case['identifiers']['urls'])}"
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, json.JSONDecodeError, csv.Error, zipfile.BadZipFile) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(2)
