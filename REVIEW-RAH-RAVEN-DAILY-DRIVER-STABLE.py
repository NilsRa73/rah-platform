from __future__ import annotations

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / "RAH-RAVEN-DAILY-DRIVER-VERSION.json"
PACKAGE = ROOT / "RAH-RAVEN-DAILY-DRIVER-PACKAGE.json"


class ReviewError(RuntimeError):
    pass


def load_json(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        raise ReviewError(f"could not read JSON: {path}") from exc
    if not isinstance(data, dict):
        raise ReviewError(f"expected JSON object: {path}")
    return data


def require(condition: bool, message: str, checks: list[dict]) -> None:
    checks.append({"check": message, "status": "PASS" if condition else "FAIL"})
    if not condition:
        raise ReviewError(message)


def validate_stable_contract(checks: list[dict]) -> None:
    manifest = load_json(MANIFEST)
    package = load_json(PACKAGE)

    require(manifest.get("product") == "RAH Raven Daily Driver", "product is RAH Raven Daily Driver", checks)
    require(manifest.get("version") == "1.0.0", "version is 1.0.0", checks)
    require(manifest.get("stage") == "stable", "lifecycle is Stable", checks)
    require(manifest.get("authority_delta") == "none", "authority_delta remains none", checks)
    require(manifest.get("stable_command_center_reference") == "2.4.0", "Command Center reference is 2.4.0", checks)
    require(manifest.get("stable_command_center_package_generation_reference") == 9, "Command Center package generation is 9", checks)
    require(manifest.get("stable_node_agent_reference") == "1.4.0", "Node Agent reference is 1.4.0", checks)
    require(manifest.get("stable_chronicle_reference") == "1.7.1", "Chronicle reference is 1.7.1", checks)

    gate = manifest.get("stable_gate") or {}
    require(gate.get("status") == "passed", "Stable gate is passed", checks)
    require(gate.get("runtime_files_frozen") is True, "Stable runtime files are frozen", checks)

    boundary = manifest.get("security_boundary") or {}
    for key in (
        "shell",
        "generic_process_execution",
        "generic_file_api",
        "native_remote_control",
        "credential_attack_features",
        "cloud_agent_enabled_by_default",
        "cloud_response_storage",
        "runtime_evidence_validator_can_promote_stable",
        "runtime_acceptance_can_promote_stable",
    ):
        require(boundary.get(key) is False, f"{key} remains false", checks)

    require(package.get("stage") == "stable-package", "package lifecycle is stable-package", checks)
    require(package.get("packageFileCount") == 39, "Stable package contains exactly 39 files", checks)
    require(len(package.get("packageFiles") or []) == 39, "Stable package list contains exactly 39 paths", checks)
    policy = package.get("runtimePolicy") or {}
    require(policy.get("candidateOnly") is False, "Stable package is not Candidate-only", checks)
    require(policy.get("stablePromotionIncluded") is True, "Stable package records completed promotion", checks)


def verify(legacy_evidence_supplied: bool = False) -> dict:
    checks: list[dict] = []
    result = {
        "schemaVersion": 2,
        "product": "RAH Raven Daily Driver",
        "version": "1.0.0",
        "review": "legacy-stable-review-compatibility",
        "status": "BLOCKED",
        "alreadyStable": False,
        "eligibleForPromotionReview": False,
        "stablePromotionPerformed": False,
        "automaticPromotion": False,
        "repoFilesModified": False,
        "legacyEvidenceSupplied": legacy_evidence_supplied,
        "legacyEvidenceUsed": False,
        "checks": checks,
    }
    try:
        validate_stable_contract(checks)
        result["status"] = "ALREADY_STABLE"
        result["alreadyStable"] = True
        result["nextAction"] = (
            "Use START-HER-RAH-RAVEN-DAILY-DRIVER.cmd for the canonical "
            "Stable self-diagnosing install/repair/test/runtime-gate flow."
        )
    except ReviewError as exc:
        result["reason"] = str(exc)
        result["nextAction"] = "repair Stable contract drift; do not run a Candidate promotion path"
    return result


def self_test() -> int:
    result = verify(False)
    assert result["status"] == "ALREADY_STABLE"
    assert result["alreadyStable"] is True
    assert result["eligibleForPromotionReview"] is False
    assert result["stablePromotionPerformed"] is False
    assert result["automaticPromotion"] is False
    assert result["legacyEvidenceUsed"] is False
    print("RAH Daily Driver legacy Stable-review compatibility self-test: PASS")
    print("Lifecycle: ALREADY_STABLE")
    print("Automatic Stable promotion: NO")
    return 0


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(
        description="Legacy Daily Driver Stable-review compatibility verifier"
    )
    parser.add_argument("owned_machine", nargs="?", help="legacy evidence path; retained for CLI compatibility and not read")
    parser.add_argument("--tool-summary", help="legacy argument; retained for CLI compatibility and not read")
    parser.add_argument("--output", help="optional JSON result path")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()

    result = verify(bool(args.owned_machine or args.tool_summary))
    text = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        target = Path(args.output)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0 if result["status"] == "ALREADY_STABLE" else 2


if __name__ == "__main__":
    raise SystemExit(main())
