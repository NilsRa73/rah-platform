import hashlib
import importlib.util
import json
import tempfile
import unittest
import zipfile
from pathlib import Path


MODULE_PATH = Path(__file__).resolve().parents[1] / "evidence_validator.py"
spec = importlib.util.spec_from_file_location("rah_evidence_validator", MODULE_PATH)
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)


CRITICAL = [
    "Python 3",
    "requests",
    "Chronicle persistence",
    "Investigator synthetic",
    "Real Facebook/archive import",
    "LM Studio",
    "Frozen guard",
    "Main PC device node",
    "Daily Driver Bridge",
]
MAIN_COMMIT = "6" * 40


def _json_bytes(data):
    return json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8")


def _make_bundle(
    path,
    gate_overall="PASS",
    critical_status="PASS",
    bad_hash=False,
    unsafe=False,
    provenance_status="BOUND",
    provenance_ref="refs/heads/main",
):
    root = "RAH-Raven-Runtime-Evidence-20260817-120000Z"
    gate = {
        "product": "RAH Raven Daily Driver",
        "version": "1.0.0",
        "overall": gate_overall,
        "recommended_stage": "Runtime Test" if gate_overall == "PASS" else "Candidate",
        "checks": [
            {"name": name, "status": critical_status, "required": True, "detail": "safe"}
            for name in CRITICAL
        ],
    }
    provenance = {
        "schema": validator.PROVENANCE_SCHEMA,
        "status": provenance_status,
        "product": "RAH Raven Daily Driver",
        "version": "1.0.0",
        "repository": "NilsRa73/rah-platform",
        "commit": MAIN_COMMIT,
        "ref": provenance_ref,
        "builtUtc": "2026-08-17T13:35:00Z",
        "packageRoot": "RAH-Raven-Daily-Driver-v1.0-Candidate",
        "packageFileCount": 37,
        "buildSourceSha256": "a" * 64,
        "packageManifestSha256": "b" * 64,
        "binding": "local-package-build-source-and-manifest-v1",
        "reasons": [] if provenance_status == "BOUND" else ["not packaged"],
    }
    files = {
        "README.txt": b"privacy-safe evidence\n",
        "build-provenance.json": _json_bytes(provenance),
        "config-summary.json": _json_bytes({"bridge": {"hostClass": "loopback", "port": 18767}, "agents": []}),
        "devices-sanitized.json": _json_bytes({"devices": [{"id": "main-pc", "hostClass": "private"}]}),
        "environment.json": _json_bytes({
            "schema": validator.EVIDENCE_SCHEMA,
            "product": "RAH Raven Daily Driver",
            "hostnameIncluded": False,
            "rawExternalAddressesIncluded": False,
        }),
        "module-status-sanitized.json": _json_bytes({"components": {}}),
        "privacy.json": _json_bytes({
            "schema": validator.EVIDENCE_SCHEMA,
            "excluded": sorted(validator.REQUIRED_PRIVACY_EXCLUSIONS),
        }),
        "runtime-gate-sanitized.json": _json_bytes(gate),
    }
    manifest = {"schema": validator.EVIDENCE_SCHEMA, "files": []}
    for name in sorted(files):
        digest = hashlib.sha256(files[name]).hexdigest()
        if bad_hash and name == "environment.json":
            digest = "0" * 64
        manifest["files"].append({"name": name, "bytes": len(files[name]), "sha256": digest})
    files["manifest.json"] = _json_bytes(manifest)

    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name, data in files.items():
            zf.writestr(f"{root}/{name}", data)
        if unsafe:
            zf.writestr("../escape.txt", "forbidden")


class EvidenceValidatorTests(unittest.TestCase):
    def test_valid_pass_is_runtime_test_eligible_but_never_stable(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.zip"
            _make_bundle(path)
            report = validator.validate_evidence_bundle(path)
            self.assertEqual(report["evidenceIntegrity"], "PASS")
            self.assertEqual(report["buildProvenance"], "PASS")
            self.assertEqual(report["buildCommit"], MAIN_COMMIT)
            self.assertEqual(report["automatedRuntimeGate"], "PASS")
            self.assertEqual(report["runtimeTestEligibility"], "ELIGIBLE")
            self.assertEqual(report["stablePromotion"], "BLOCKED")
            self.assertTrue(report["manualStableChecksPending"])

    def test_pending_gate_stays_pending(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.zip"
            _make_bundle(path, gate_overall="PENDING_RUNTIME", critical_status="PENDING")
            report = validator.validate_evidence_bundle(path)
            self.assertEqual(report["evidenceIntegrity"], "PASS")
            self.assertEqual(report["buildProvenance"], "PASS")
            self.assertEqual(report["runtimeTestEligibility"], "PENDING")
            self.assertEqual(report["stablePromotion"], "BLOCKED")

    def test_manifest_hash_tamper_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.zip"
            _make_bundle(path, bad_hash=True)
            report = validator.validate_evidence_bundle(path)
            self.assertEqual(report["evidenceIntegrity"], "FAIL")
            self.assertEqual(report["runtimeTestEligibility"], "BLOCKED")
            self.assertTrue(any("SHA-256 mismatch" in x for x in report["reasons"]))

    def test_zip_path_traversal_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.zip"
            _make_bundle(path, unsafe=True)
            report = validator.validate_evidence_bundle(path)
            self.assertEqual(report["evidenceIntegrity"], "FAIL")
            self.assertEqual(report["runtimeTestEligibility"], "BLOCKED")
            self.assertTrue(any("Unsafe ZIP member path" in x or "closure drift" in x for x in report["reasons"]))

    def test_unbound_provenance_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.zip"
            _make_bundle(path, provenance_status="UNBOUND")
            report = validator.validate_evidence_bundle(path)
            self.assertEqual(report["evidenceIntegrity"], "FAIL")
            self.assertEqual(report["buildProvenance"], "FAIL")
            self.assertEqual(report["runtimeTestEligibility"], "BLOCKED")
            self.assertTrue(any("not bound" in x.lower() for x in report["reasons"]))

    def test_non_main_provenance_fails_closed(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "evidence.zip"
            _make_bundle(path, provenance_ref="refs/pull/167/merge")
            report = validator.validate_evidence_bundle(path)
            self.assertEqual(report["evidenceIntegrity"], "FAIL")
            self.assertEqual(report["runtimeTestEligibility"], "BLOCKED")
            self.assertTrue(any("main-branch" in x for x in report["reasons"]))


if __name__ == "__main__":
    unittest.main()
