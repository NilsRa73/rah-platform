from __future__ import annotations

import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class CommandCenterRegistryIntegrationTests(unittest.TestCase):
    def test_registry_has_exact_top_ten(self):
        data = json.loads((ROOT / "raven" / "projects.json").read_text(encoding="utf-8"))
        projects = sorted(data["projects"], key=lambda p: p["priority"])
        self.assertEqual(len(projects), 10)
        self.assertEqual([p["priority"] for p in projects], list(range(1, 11)))
        self.assertEqual(projects[0]["id"], "raven-control-plane")

    def test_registry_bridge_loads_before_mission_engine(self):
        html = (ROOT / "index.html").read_text(encoding="utf-8")
        registry_pos = html.find('project-registry.js?v=1.0')
        mission_pos = html.find('mission-engine.js?v=1.5')
        self.assertGreaterEqual(registry_pos, 0)
        self.assertGreater(mission_pos, registry_pos)

    def test_continue_creates_registry_mission(self):
        script = (ROOT / "project-registry.js").read_text(encoding="utf-8")
        self.assertIn("function continueProject()", script)
        self.assertIn("state.activeMission = createRegistryMission(project)", script)
        self.assertIn("switchView(\"missions\")", script)

    def test_registry_mission_actions_are_allowed(self):
        script = (ROOT / "project-registry.js").read_text(encoding="utf-8")
        engine = (ROOT / "mission-engine.js").read_text(encoding="utf-8")
        actions = set(re.findall(r'action:\s*"([^"]+)"', script))
        allowed = set(re.findall(r'"([a-z0-9-]+)"', engine.split("const now =", 1)[0]))
        self.assertTrue(actions, "Expected registry mission actions")
        self.assertTrue(actions.issubset(allowed), f"Unknown actions: {sorted(actions - allowed)}")

    def test_registry_bridge_has_no_dynamic_code_execution(self):
        script = (ROOT / "project-registry.js").read_text(encoding="utf-8")
        self.assertNotIn("eval(", script)
        self.assertNotIn("new Function(", script)


if __name__ == "__main__":
    unittest.main()
