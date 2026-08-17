import json
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP))

from evidence_bundle import build_evidence_bundle


MAIN_COMMIT = "6" * 40


class EvidenceBundleTests(unittest.TestCase):
    def _make_app(self, root, with_provenance=True):
        package = Path(root) / "RAH-Raven-Daily-Driver-v1.0-Candidate"
        app = package / "apps" / "rah-raven-daily-driver"
        (app / "runtime" / "state").mkdir(parents=True)
        (app / "runtime" / "devices").mkdir(parents=True)
        (app / "runtime" / "exports").mkdir(parents=True)
        (app / "config.json").write_text(
            json.dumps(
                {
                    "bridge": {"host": "127.0.0.1", "port": 18767},
                    "agents": {
                        "local": {
                            "adapter": "lmstudio",
                            "type": "local",
                            "enabled": True,
                            "base_url": "http://127.0.0.1:1234/v1",
                            "model": "auto",
                        }
                    },
                }
            ),
            encoding="utf-8",
        )
        (app / "runtime" / "devices" / "devices.json").write_text(
            json.dumps(
                {
                    "devices": [
                        {
                            "id": "main-pc",
                            "name": "SECRET-HOSTNAME",
                            "kind": "windows-main",
                            "host": "192.168.1.99",
                            "display": "local",
                            "agents": ["daily-driver"],
                            "services": ["command-center"],
                        }
                    ]
                }
            ),
            encoding="utf-8",
        )
        if with_provenance:
            (package / "BUILD-SOURCE.json").write_text(
                json.dumps(
                    {
                        "product": "RAH Raven Daily Driver",
                        "version": "1.0.0",
                        "stage": "candidate",
                        "repository": "NilsRa73/rah-platform",
                        "commit": MAIN_COMMIT,
                        "ref": "refs/heads/main",
                        "built_utc": "2026-08-17T13:35:00Z",
                    }
                ),
                encoding="utf-8",
            )
            (package / "RAH-RAVEN-DAILY-DRIVER-PACKAGE.json").write_text(
                json.dumps(
                    {
                        "schemaVersion": 1,
                        "product": "RAH Raven Daily Driver",
                        "version": "1.0.0",
                        "stage": "candidate-package",
                        "packageRoot": "RAH-Raven-Daily-Driver-v1.0-Candidate",
                        "packageFileCount": 37,
                        "packageFiles": [f"file-{i}" for i in range(37)],
                        "runtimePolicy": {
                            "candidateOnly": True,
                            "stablePromotionIncluded": False,
                        },
                    }
                ),
                encoding="utf-8",
            )
        return app

    def test_bundle_is_sanitized_checksummed_and_build_bound(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = self._make_app(tmp)
            gate = {
                "overall": "PENDING_RUNTIME",
                "recommended_stage": "Candidate",
                "checks": [
                    {
                        "name": "Real Facebook/archive import",
                        "status": "PENDING",
                        "required": True,
                        "detail": r"C:\Users\Alice\private-facebook.zip",
                    },
                    {
                        "name": "Main PC device node",
                        "status": "PASS",
                        "required": True,
                        "detail": json.dumps(
                            {
                                "id": "main-pc",
                                "name": "SECRET-HOSTNAME",
                                "kind": "windows-main",
                                "host": "192.168.1.99",
                                "online": True,
                                "cpu": 8,
                                "storage": {"total_gb": 100, "free_gb": 50},
                            }
                        ),
                    },
                ],
            }
            (app / "runtime" / "state" / "runtime-gate.json").write_text(
                json.dumps(gate), encoding="utf-8"
            )
            result = build_evidence_bundle(app_dir=app)
            zip_path = Path(result["zip"])
            self.assertTrue(zip_path.exists())
            self.assertTrue(Path(result["sha256File"]).exists())
            self.assertEqual(result["gateStatus"], "PENDING_RUNTIME")
            self.assertEqual(result["buildProvenance"], "BOUND")
            self.assertEqual(result["buildCommit"], MAIN_COMMIT)

            with zipfile.ZipFile(zip_path) as zf:
                names = zf.namelist()
                self.assertTrue(any(name.endswith("manifest.json") for name in names))
                self.assertTrue(any(name.endswith("privacy.json") for name in names))
                provenance_name = next(name for name in names if name.endswith("build-provenance.json"))
                provenance = json.loads(zf.read(provenance_name).decode("utf-8"))
                payload = b"\n".join(zf.read(name) for name in names)

            self.assertEqual(provenance["status"], "BOUND")
            self.assertEqual(provenance["commit"], MAIN_COMMIT)
            self.assertRegex(provenance["buildSourceSha256"], r"^[0-9a-f]{64}$")
            self.assertRegex(provenance["packageManifestSha256"], r"^[0-9a-f]{64}$")
            self.assertNotIn(b"SECRET-HOSTNAME", payload)
            self.assertNotIn(b"192.168.1.99", payload)
            self.assertNotIn(b"private-facebook.zip", payload)
            self.assertIn(b"private", payload)

    def test_missing_gate_still_exports_candidate_evidence(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = self._make_app(tmp)
            result = build_evidence_bundle(app_dir=app)
            self.assertEqual(result["gateStatus"], "MISSING")
            self.assertEqual(result["recommendedStage"], "Candidate")
            self.assertEqual(result["buildProvenance"], "BOUND")
            self.assertTrue(Path(result["zip"]).exists())

    def test_repo_checkout_without_build_source_is_unbound(self):
        with tempfile.TemporaryDirectory() as tmp:
            app = self._make_app(tmp, with_provenance=False)
            result = build_evidence_bundle(app_dir=app)
            self.assertEqual(result["buildProvenance"], "UNBOUND")
            with zipfile.ZipFile(result["zip"]) as zf:
                name = next(x for x in zf.namelist() if x.endswith("build-provenance.json"))
                provenance = json.loads(zf.read(name).decode("utf-8"))
            self.assertEqual(provenance["status"], "UNBOUND")
            self.assertTrue(provenance["reasons"])


if __name__ == "__main__":
    unittest.main()
