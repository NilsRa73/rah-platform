import argparse
import hashlib
import json
import zipfile
from pathlib import Path, PurePosixPath


EVIDENCE_SCHEMA = "rah-raven-runtime-evidence-v1"
VALIDATION_SCHEMA = "rah-raven-runtime-evidence-validation-v1"
PRODUCT = "RAH Raven Daily Driver"

EXPECTED_FILES = {
    "README.txt",
    "config-summary.json",
    "devices-sanitized.json",
    "environment.json",
    "manifest.json",
    "module-status-sanitized.json",
    "privacy.json",
    "runtime-gate-sanitized.json",
}
MANIFESTED_FILES = EXPECTED_FILES - {"manifest.json"}
REQUIRED_PRIVACY_EXCLUSIONS = {
    "Chronicle database",
    "Facebook/archive source files",
    "chat or Council content",
    "API keys or token values",
    "raw device hostnames",
    "raw external IP addresses",
    "application logs",
}
CRITICAL_RUNTIME_CHECKS = {
    "Python 3",
    "requests",
    "Chronicle persistence",
    "Investigator synthetic",
    "Real Facebook/archive import",
    "LM Studio",
    "Frozen guard",
    "Main PC device node",
    "Daily Driver Bridge",
}
MANUAL_STABLE_CHECKS = [
    "Confirm the installed desktop shortcut launches Daily Driver on Windows 10/11.",
    "Confirm both local Council roles answer through a live LM Studio model.",
    "Confirm cloud-disabled mode makes no OpenAI request.",
    "Import real Sherlock, PhoneInfoga and passive SpiderFoot exports.",
    "Restart and verify SQLite recovery-state persistence.",
    "Restart and verify prior-decision recall.",
    "Generate and inspect a Mission Report.",
    "Refresh Devices and confirm expected main-PC metadata and simulated nodes.",
]


def _sha256_bytes(data):
    return hashlib.sha256(data).hexdigest()


def _sha256_file(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def _safe_member(name):
    if not isinstance(name, str) or not name or "\\" in name:
        return False
    p = PurePosixPath(name)
    if p.is_absolute() or any(part in {"", ".", ".."} for part in p.parts):
        return False
    return True


def _load_json(zf, name):
    try:
        return json.loads(zf.read(name).decode("utf-8"))
    except Exception as exc:
        raise ValueError(f"Invalid JSON in {name}: {exc}") from exc


def validate_evidence_bundle(zip_path):
    evidence = Path(zip_path)
    reasons = []
    warnings = []
    result = {
        "schema": VALIDATION_SCHEMA,
        "product": PRODUCT,
        "evidenceFile": evidence.name,
        "evidenceZipSha256": None,
        "evidenceSchema": None,
        "evidenceIntegrity": "FAIL",
        "automatedRuntimeGate": "UNKNOWN",
        "runtimeTestEligibility": "BLOCKED",
        "stablePromotion": "BLOCKED",
        "reasons": reasons,
        "warnings": warnings,
        "criticalChecks": {},
        "manualStableChecksPending": list(MANUAL_STABLE_CHECKS),
    }

    if not evidence.is_file():
        reasons.append("Evidence ZIP does not exist.")
        return result

    result["evidenceZipSha256"] = _sha256_file(evidence)

    try:
        with zipfile.ZipFile(evidence, "r") as zf:
            members = [x.filename for x in zf.infolist() if not x.is_dir()]
            if not members:
                raise ValueError("Evidence ZIP is empty.")
            if len(members) != len(set(members)):
                raise ValueError("Duplicate ZIP members are forbidden.")
            bad = [name for name in members if not _safe_member(name)]
            if bad:
                raise ValueError(f"Unsafe ZIP member path: {bad[0]}")

            roots = {PurePosixPath(name).parts[0] for name in members}
            if len(roots) != 1:
                raise ValueError("Evidence ZIP must contain exactly one root directory.")
            root = next(iter(roots))
            rel_names = {str(PurePosixPath(name).relative_to(root)) for name in members}
            if rel_names != EXPECTED_FILES:
                missing = sorted(EXPECTED_FILES - rel_names)
                extra = sorted(rel_names - EXPECTED_FILES)
                raise ValueError(f"Evidence closure drift; missing={missing}, extra={extra}")

            full = {rel: f"{root}/{rel}" for rel in rel_names}
            env = _load_json(zf, full["environment.json"])
            gate = _load_json(zf, full["runtime-gate-sanitized.json"])
            privacy = _load_json(zf, full["privacy.json"])
            manifest = _load_json(zf, full["manifest.json"])
            _load_json(zf, full["module-status-sanitized.json"])
            _load_json(zf, full["devices-sanitized.json"])
            _load_json(zf, full["config-summary.json"])

            schemas = {env.get("schema"), privacy.get("schema"), manifest.get("schema")}
            if schemas != {EVIDENCE_SCHEMA}:
                raise ValueError(f"Evidence schema drift: {sorted(str(x) for x in schemas)}")
            result["evidenceSchema"] = EVIDENCE_SCHEMA

            manifest_items = manifest.get("files")
            if not isinstance(manifest_items, list):
                raise ValueError("Evidence manifest files list missing.")
            indexed = {}
            for item in manifest_items:
                if not isinstance(item, dict):
                    raise ValueError("Invalid evidence manifest entry.")
                name = item.get("name")
                if name in indexed:
                    raise ValueError(f"Duplicate manifest entry: {name}")
                indexed[name] = item
            if set(indexed) != MANIFESTED_FILES:
                raise ValueError("Evidence manifest closure does not match schema v1.")
            for name in sorted(MANIFESTED_FILES):
                data = zf.read(full[name])
                item = indexed[name]
                if int(item.get("bytes", -1)) != len(data):
                    raise ValueError(f"Byte-count mismatch: {name}")
                if str(item.get("sha256", "")).lower() != _sha256_bytes(data):
                    raise ValueError(f"SHA-256 mismatch: {name}")

            excluded = set(privacy.get("excluded") or [])
            missing_exclusions = sorted(REQUIRED_PRIVACY_EXCLUSIONS - excluded)
            if missing_exclusions:
                raise ValueError(f"Privacy exclusions missing: {missing_exclusions}")
            if env.get("hostnameIncluded") is not False:
                raise ValueError("Evidence claims hostname inclusion.")
            if env.get("rawExternalAddressesIncluded") is not False:
                raise ValueError("Evidence claims raw external address inclusion.")

            result["evidenceIntegrity"] = "PASS"
            gate_overall = str(gate.get("overall", "UNKNOWN"))
            result["automatedRuntimeGate"] = gate_overall
            checks = gate.get("checks") if isinstance(gate.get("checks"), list) else []
            check_map = {
                str(item.get("name")): str(item.get("status", "UNKNOWN"))
                for item in checks
                if isinstance(item, dict)
            }
            critical = {name: check_map.get(name, "MISSING") for name in sorted(CRITICAL_RUNTIME_CHECKS)}
            result["criticalChecks"] = critical

            failed = sorted(name for name, status in critical.items() if status == "FAIL")
            incomplete = sorted(name for name, status in critical.items() if status != "PASS")
            if gate_overall == "PASS" and not incomplete:
                result["runtimeTestEligibility"] = "ELIGIBLE"
                warnings.append("Automated runtime evidence is eligible for Runtime Test review; this is not Stable approval.")
            elif failed or gate_overall == "FAIL":
                result["runtimeTestEligibility"] = "BLOCKED"
                reasons.append(f"Runtime gate failed; critical failures={failed}")
            else:
                result["runtimeTestEligibility"] = "PENDING"
                reasons.append(f"Runtime evidence is incomplete; critical non-PASS checks={incomplete}")

            if gate.get("recommended_stage") not in {"Candidate", "Runtime Test"}:
                reasons.append("Unexpected runtime-gate recommended stage.")
                result["runtimeTestEligibility"] = "BLOCKED"

    except (OSError, zipfile.BadZipFile, ValueError, KeyError, TypeError) as exc:
        reasons.append(str(exc))
        result["evidenceIntegrity"] = "FAIL"
        result["runtimeTestEligibility"] = "BLOCKED"

    return result


def _default_output(evidence):
    p = Path(evidence)
    return p.with_name(p.stem + ".readiness.json")


def main():
    parser = argparse.ArgumentParser(description="Validate a RAH Raven Runtime Evidence ZIP")
    parser.add_argument("evidence", help="Path to RAH-Raven-Runtime-Evidence-*.zip")
    parser.add_argument("--output", help="Optional readiness JSON output path")
    args = parser.parse_args()

    report = validate_evidence_bundle(args.evidence)
    output = Path(args.output) if args.output else _default_output(args.evidence)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")

    print("=" * 72)
    print("RAH RAVEN — RUNTIME EVIDENCE VALIDATOR")
    print("=" * 72)
    print("EVIDENCE INTEGRITY:", report["evidenceIntegrity"])
    print("AUTOMATED RUNTIME GATE:", report["automatedRuntimeGate"])
    print("RUNTIME TEST ELIGIBILITY:", report["runtimeTestEligibility"])
    print("STABLE PROMOTION:", report["stablePromotion"])
    print("REPORT:", output)
    if report["reasons"]:
        print("REASONS:")
        for reason in report["reasons"]:
            print(" -", reason)

    if report["evidenceIntegrity"] != "PASS" or report["runtimeTestEligibility"] == "BLOCKED":
        return 1
    if report["runtimeTestEligibility"] != "ELIGIBLE":
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
