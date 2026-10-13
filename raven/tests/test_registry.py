from __future__ import annotations

import importlib.util
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "raven" / "raven_registry.py"
SPEC = importlib.util.spec_from_file_location("raven_registry", MODULE_PATH)
assert SPEC and SPEC.loader
registry = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(registry)


class RegistryTests(unittest.TestCase):
    def test_registry_is_valid(self):
        data = registry.load_registry()
        self.assertEqual(registry.validate_registry(data), [])

    def test_top_ten_priorities_are_contiguous(self):
        data = registry.load_registry()
        priorities = [p["priority"] for p in data["projects"]]
        self.assertEqual(priorities, list(range(1, 11)))

    def test_health_checks_are_loopback_only(self):
        data = registry.load_registry()
        for project in data["projects"]:
            for check in project.get("checks", []):
                if check.get("type") == "http":
                    result = registry._probe_http(check["url"], timeout=0.01)
                    self.assertNotIn("blocked:", result["detail"])


if __name__ == "__main__":
    unittest.main()
