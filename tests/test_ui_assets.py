from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path.home() / "Library/Caches/piggame/python"))
from fontTools.ttLib import TTFont


class InterfaceAssetTests(unittest.TestCase):
    def test_offline_sources_and_derivative_integrity(self) -> None:
        manifest = json.loads((ROOT / "game/assets/interface/source.json").read_text())
        self.assertTrue(manifest["offline_runtime"])
        self.assertFalse(manifest["ai_generated"])
        self.assertEqual(len(manifest["pinned_commits"]), 3)
        for record in manifest["records"]:
            path = ROOT / record["path"].removeprefix("res://")
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), record["sha256"], str(path))
            self.assertIn("raw.githubusercontent.com", record["source_url"])
        icons = list((ROOT / "game/assets/interface/lucide").glob("*.svg"))
        self.assertEqual(len(icons), 28)
        for icon in icons:
            text = icon.read_text()
            self.assertIn('stroke="#ffffff"', text)
            self.assertIn('viewBox="0 0 24 24"', text)
            self.assertNotIn("http://", text.replace("http://www.w3.org/2000/svg", ""))

    def test_fonts_cover_three_language_interface(self) -> None:
        with (ROOT / "game/data/localization/game.csv").open(newline="") as handle:
            required = {ord(character) for row in csv.DictReader(handle) for locale in ("zh_CN", "zh_TW", "en") for character in row[locale] if character.isalnum()}
        for filename, family in (("pig-ui-body.ttf", "Piggame UI Sans"), ("pig-ui-title.ttf", "Piggame UI Hand")):
            path = ROOT / "game/assets/interface/fonts" / filename
            with TTFont(path) as font:
                self.assertFalse(required.difference(font.getBestCmap()), filename)
                self.assertEqual(font["name"].getDebugName(1), family)
                self.assertIsNotNone(font["name"].getDebugName(0))
                self.assertNotIn("fvar", font)
            self.assertLess(path.stat().st_size, 4 * 1024 * 1024)


if __name__ == "__main__":
    unittest.main()
