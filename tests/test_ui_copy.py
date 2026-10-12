from __future__ import annotations

import ast
import csv
import json
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[1]
RETIRED_COPY = {
    "PERFORMANCE_INTRO", "PERFORMANCE_TEMPORARY", "PERSONALITY_SETUP_INTRO",
    "PERSONALITY_RANDOM_DESCRIPTION", "RESIDENTS_INTRO", "CATALOG_FURNITURE_INTRO",
    "CATALOG_SNACKS_INTRO", "CATALOG_OUTFITS_INTRO", "TENDENCY_INTRO",
    "POSTCARD_INBOX_HINT", "FURNITURE_STAGE_HINT", "LIFE_PLAN_INTRO",
    "DESKTOP_BACKGROUND_SHIELD", "FOCUS_TIMER_INTRO", "ALBUM_MEMORY_HINT",
}


class UICopyTests(unittest.TestCase):
    def setUp(self) -> None:
        with (ROOT / "game/data/localization/game.csv").open(newline="") as handle:
            self.rows = {row["keys"]: row for row in csv.DictReader(handle)}

    def test_removed_explanations_cannot_be_regenerated_or_rendered(self) -> None:
        tree = ast.parse((ROOT / "tools/build_localization.py").read_text())
        ui = next(ast.literal_eval(statement.value) for statement in tree.body if isinstance(statement, ast.Assign) and any(isinstance(target, ast.Name) and target.id == "UI" for target in statement.targets))
        source = (ROOT / "game/scripts/ui/main_ui.gd").read_text()
        for key in RETIRED_COPY:
            with self.subTest(key=key):
                self.assertNotIn(key, ui)
                self.assertNotIn(key, self.rows)
                self.assertNotIn(key, source)

    def test_short_status_copy_remains_localized(self) -> None:
        for key in ("POSTCARD_REQUIREMENT", "POSTCARD_UNREAD", "POSTCARD_READ", "POSTCARD_SOURCE", "RESIDENTS_CAPACITY", "LIFE_PLAN_RATE", "SETTINGS_AUDIO_SILENT", "DESKTOP_BEHAVIOR_FREQUENCY"):
            with self.subTest(key=key):
                row = self.rows[key]
                self.assertLessEqual(len(row["zh_CN"]), 40)
                self.assertLessEqual(len(row["en"]), 80)
                placeholders = {locale: set(re.findall(r"\{([^{}]+)\}", row[locale])) for locale in ("zh_CN", "zh_TW", "en")}
                self.assertEqual(placeholders["zh_CN"], placeholders["zh_TW"])
                self.assertEqual(placeholders["zh_CN"], placeholders["en"])

    def test_legal_help_recovery_and_game_clues_are_preserved(self) -> None:
        for key in ("LEGAL_PRIVACY", "LEGAL_THIRD_PARTY", "DESKTOP_PRIVACY_BOUNDARY", "HELP_CORE", "HELP_DESKTOP", "HELP_ALBUM", "HELP_SAVING", "SAVE_RECOVERY_MESSAGE", "EXIT_SAVE_FAILED_MESSAGE", "TOAST_SAVE_FAILED", "ALBUM_HIDDEN_HINT", "UI_DESKTOP_LOCKED", "PERFORMANCE_WEAR_FIRST"):
            for locale in ("zh_CN", "zh_TW", "en"):
                self.assertTrue(self.rows[key][locale].strip())

    def test_item_descriptions_do_not_expose_development_instructions(self) -> None:
        for relative in ("game/data/furniture/furniture.json", "game/data/catalog/snacks.json", "game/data/catalog/outfits.json"):
            for item in json.loads((ROOT / relative).read_text()):
                row = self.rows[item["description_key"]]
                for phrase in ("对应锚点", "原创包装", "没有现实品牌", "养成效率", "不提高数值", "matching anchor", "original packaging", "numeric advantage", "progression speed"):
                    self.assertNotIn(phrase, " ".join(row[locale] for locale in ("zh_CN", "zh_TW", "en")))


if __name__ == "__main__":
    unittest.main()
