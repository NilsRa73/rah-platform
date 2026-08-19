from __future__ import annotations

import argparse
import json
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parent
MANIFEST = ROOT / "RAH-RAVEN-DAILY-DRIVER-VERSION.json"
PACKAGE = ROOT / "RAH-RAVEN-DAILY-DRIVER-PACKAGE.json"


class ReviewError(RuntimeError):
    pass


def load_json(path: Path):
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except Exception as exc:
        raise ReviewError(f"could not read JSON: {path}") from exc
    if not isinstance(data, dict):
        raise ReviewError(f"expected JSON object: {path}")
    return data


def require(condition: bool, message: str, checks: list[dict]):
    checks.append({"check": message, "status": "PASS" if condition else "FAIL"})
    if not condition:
        raise ReviewError(message)


def validate_repo_contract(checks: list[dict]):
    manifest = load_json(MANIFEST)
    package = load_json(PACKAGE)

    require(manifest.get("product") == "RAH Raven Daily Driver", "product must remain RAH Raven Daily Driver", checks)
    require(manifest.get("version") == "1.0.0", "version must remain 1.0.0", checks)
    require(manifest.get("stage") == "candidate", "stage must still be candidate before promotion review", checks)
    require(manifest.get("authority_delta") == "none", "authority_delta must remain none", checks)
    require(manifest.get("stable_command_center_reference") == "2.3.0", "Command Center Stable reference must remain 2.3.0", checks)
    require(manifest.get("stable_node_agent_reference") == "1.3.0", "Node Agent Stable reference must remain 1.3.0", checks)
    require(manifest.get("stable_chronicle_reference") == "1.7.1", "Chronicle Stable reference must remain 1.7.1", checks)

    gate = manifest.get("stable_gate") or {}
    require(gate.get("status") == "not_passed", "Stable gate must still be not_passed before separate promotion", checks)
    require(gate.get("requires_windows_runtime") is True, "Windows runtime acceptance must remain required", checks)
    require(gate.get("requires_lm_studio_live_test") is True, "LM Studio live acceptance must remain required", checks)
    require(gate.get("requires_real_facebook_archive_test") is True, "real Facebook/archive acceptance must remain required", checks)
    require(gate.get("requires_installer_shortcut_test") is True, "installer/shortcut acceptance must remain required", checks)
    require(gate.get("requires_owned_tool_export_review") is True, "owned tool-export review must remain required", checks)

    require(package.get("stage") == "candidate-package", "package must remain candidate-package", checks)
    require(package.get("packageFileCount") == 37, "immutable Candidate runtime package must remain 37 files", checks)
    require(len(package.get("packageFiles") or []) == 37, "Candidate package list must contain exactly 37 files", checks)
    policy = package.get("runtimePolicy") or {}
    require(policy.get("candidateOnly") is True, "Candidate package must remain candidate-only", checks)
    require(policy.get("stablePromotionIncluded") is False, "Candidate package must not include Stable promotion", checks)


def validate_owned_machine(data: dict, checks: list[dict]):
    require(data.get("schemaVersion") == 2, "owned-machine evidence schemaVersion must be 2", checks)
    require(data.get("product") == "RAH Raven Daily Driver", "owned-machine evidence product must match", checks)
    require(data.get("acceptance") == "owned-windows-machine", "acceptance type must be owned-windows-machine", checks)
    require(data.get("eligibleForStableReview") is True, "owned-machine evidence must be eligibleForStableReview=true", checks)
    require(data.get("stablePromotion") == "BLOCKED", "acceptance layer must still say stablePromotion=BLOCKED", checks)
    require(data.get("stablePromotionAutomated") is False, "acceptance layer must forbid automatic Stable promotion", checks)

    m = data.get("machineEvidence") or {}
    require(m.get("desktopShortcutContract") == "PASS", "desktop shortcut contract must PASS", checks)
    require(m.get("desktopShortcutInteractiveConfirmed") is True, "desktop shortcut interactive launch must be confirmed", checks)
    require(m.get("lmStudioRoleResponses") == "PASS", "LM Studio role responses must PASS", checks)
    require(m.get("lmStudioAnswerTextPersisted") is False, "LM answer text must not be persisted", checks)
    require(m.get("realOwnedArchiveRuntimeGate") == "PASS", "real owned archive runtime gate must PASS", checks)
    require(m.get("runtimeEvidenceEligibility") == "ELIGIBLE", "runtime evidence must be ELIGIBLE", checks)
    require(m.get("archivePathPersisted") is False, "archive path must not be persisted", checks)
    require(m.get("archiveContentsPersistedInAcceptanceSummary") is False, "archive contents must not be persisted in acceptance summary", checks)
    require(m.get("ownedToolEvidenceAvailable") is True, "owned-tool evidence must be available", checks)
    require(m.get("ownedToolExternalToolsAutoExecuted") is False, "owned-tool review must not auto-execute external tools", checks)
    require(m.get("ownedToolSourcePathsPersisted") is False, "owned-tool source paths must not be persisted", checks)
    require(m.get("ownedToolSourceHashesPersisted") is False, "owned-tool source hashes must not be persisted", checks)
    require(m.get("ownedToolIdentifierValuesPersisted") is False, "owned-tool identifier values must not be persisted", checks)

    ui = data.get("manualUiReview") or {}
    require(ui.get("ownedSherlock") is True, "Sherlock owned export review must PASS", checks)
    require(ui.get("ownedPhoneInfoga") is True, "PhoneInfoga owned export review must PASS", checks)
    require(ui.get("ownedSpiderFootPassive") is True, "SpiderFoot passive owned export review must PASS", checks)


def validate_tool_summary(data: dict, checks: list[dict]):
    require(data.get("product") == "RAH Raven Daily Driver", "tool-review product must match", checks)
    require(data.get("candidateVersion") == "1.0.0", "tool-review candidate version must be 1.0.0", checks)
    require(data.get("stablePromotion") == "BLOCKED", "tool-review must keep Stable blocked", checks)
    require(data.get("automaticStablePromotion") is False, "tool-review must forbid automatic promotion", checks)
    require(data.get("externalToolsAutoExecuted") is False, "tool-review must not auto-execute external tools", checks)
    require(data.get("sourcePathsPersisted") is False, "tool-review must not persist source paths", checks)
    require(data.get("sourceHashesPersisted") is False, "tool-review must not persist source hashes", checks)
    require(data.get("identifierValuesPersisted") is False, "tool-review must not persist identifier values", checks)
    require(data.get("allOwnedToolReviewsPass") is True, "all owned-tool reviews must PASS", checks)

    reviews = {str(x.get("tool")): x for x in data.get("reviews", []) if isinstance(x, dict)}
    for tool in ("sherlock", "phoneinfoga", "spiderfoot"):
        require(reviews.get(tool, {}).get("status") == "PASS", f"{tool} review must PASS", checks)
        require(reviews.get(tool, {}).get("sourceUnchanged") is True, f"{tool} source file must be unchanged by review", checks)
        require(reviews.get(tool, {}).get("ownedAuthorizedConfirmed") is True, f"{tool} ownership/authorization must be confirmed", checks)
        require(reviews.get(tool, {}).get("plausibleResultConfirmed") is True, f"{tool} parsed result plausibility must be confirmed", checks)
    require(reviews.get("spiderfoot", {}).get("passiveModeConfirmed") is True, "SpiderFoot passive mode must be explicitly confirmed", checks)


def review(owned_machine: Path, tool_summary: Path | None = None):
    checks: list[dict] = []
    result = {
        "schemaVersion": 1,
        "product": "RAH Raven Daily Driver",
        "version": "1.0.0",
        "review": "separate-stable-review-evidence-validator",
        "eligibleForPromotionReview": False,
        "stablePromotionPerformed": False,
        "repoFilesModified": False,
        "automaticPromotion": False,
        "checks": checks,
    }

    try:
        validate_repo_contract(checks)
        validate_owned_machine(load_json(owned_machine), checks)
        if tool_summary is not None:
            validate_tool_summary(load_json(tool_summary), checks)
        result["eligibleForPromotionReview"] = True
        result["status"] = "ELIGIBLE"
        result["nextAction"] = "separate human/repo Stable promotion review may proceed; this validator does not promote"
    except ReviewError as exc:
        result["status"] = "BLOCKED"
        result["reason"] = str(exc)
        result["nextAction"] = "fix or complete the failing evidence/check and rerun; do not promote"
    return result


def self_test():
    owned = {
        "schemaVersion": 2,
        "product": "RAH Raven Daily Driver",
        "acceptance": "owned-windows-machine",
        "eligibleForStableReview": True,
        "stablePromotion": "BLOCKED",
        "stablePromotionAutomated": False,
        "machineEvidence": {
            "desktopShortcutContract": "PASS",
            "desktopShortcutInteractiveConfirmed": True,
            "lmStudioRoleResponses": "PASS",
            "lmStudioAnswerTextPersisted": False,
            "realOwnedArchiveRuntimeGate": "PASS",
            "runtimeEvidenceEligibility": "ELIGIBLE",
            "archivePathPersisted": False,
            "archiveContentsPersistedInAcceptanceSummary": False,
            "ownedToolEvidenceAvailable": True,
            "ownedToolExternalToolsAutoExecuted": False,
            "ownedToolSourcePathsPersisted": False,
            "ownedToolSourceHashesPersisted": False,
            "ownedToolIdentifierValuesPersisted": False,
        },
        "manualUiReview": {
            "ownedSherlock": True,
            "ownedPhoneInfoga": True,
            "ownedSpiderFootPassive": True,
        },
    }
    with tempfile.TemporaryDirectory(prefix="rah-stable-review-selftest-") as tmp:
        path = Path(tmp) / "owned-machine-acceptance.json"
        path.write_text(json.dumps(owned), encoding="utf-8")
        good = review(path)
        assert good["status"] == "ELIGIBLE"
        owned["machineEvidence"]["lmStudioRoleResponses"] = "FAIL"
        path.write_text(json.dumps(owned), encoding="utf-8")
        bad = review(path)
        assert bad["status"] == "BLOCKED"
    print("RAH Daily Driver separate Stable-review validator self-test: PASS")
    print("Automatic Stable promotion: NO")
    return 0


def main(argv=None):
    parser = argparse.ArgumentParser(description="Validate Daily Driver owned-machine evidence for a separate Stable review")
    parser.add_argument("owned_machine", nargs="?", help="owned-machine-acceptance.json")
    parser.add_argument("--tool-summary", help="optional OWNED_TOOL_REVIEW_SUMMARY.json for cross-checking")
    parser.add_argument("--output", help="optional JSON result path")
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args(argv)

    if args.self_test:
        return self_test()
    if not args.owned_machine:
        parser.error("owned_machine evidence path is required unless --self-test is used")

    result = review(Path(args.owned_machine), Path(args.tool_summary) if args.tool_summary else None)
    text = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        target = Path(args.output)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text, encoding="utf-8")
    print(text, end="")
    return 0 if result["status"] == "ELIGIBLE" else 2


if __name__ == "__main__":
    raise SystemExit(main())
