import sys
import tempfile
import unittest
from pathlib import Path

APP = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(APP))

from theme_engine import THEMES, ThemeEngine, contrast_ratio


class ThemeEngineSmoke(unittest.TestCase):
    def test_all_expected_themes_exist(self):
        expected = {
            "raven_gold",
            "picasso",
            "steam_game",
            "facebook_investigator",
            "egypt_horus",
            "cyber_neon",
            "clean_windows",
        }
        self.assertTrue(expected <= set(THEMES))

    def test_theme_persistence(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "theme.json"
            engine = ThemeEngine(path)
            engine.set_theme("picasso")
            loaded = ThemeEngine(path)
            self.assertEqual(loaded.current_name, "picasso")

    def test_theme_audit(self):
        with tempfile.TemporaryDirectory() as tmp:
            engine = ThemeEngine(Path(tmp) / "theme.json")
            audit = engine.audit("steam_game")
            self.assertEqual(audit["profile"], "game")
            self.assertIn("contrast", audit)
            self.assertGreater(contrast_ratio("#FFFFFF", "#000000"), 20)


if __name__ == "__main__":
    unittest.main()
