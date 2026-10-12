from __future__ import annotations

from collections import Counter
import csv
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("copy_review", ROOT / "tools/export_copy_review.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class CopyReviewExportTests(unittest.TestCase):
    def test_snapshot_is_complete_lossless_and_read_only(self) -> None:
        original = (ROOT / "game/data/localization/game.csv").read_bytes()
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            manifest = MODULE.export_review(ROOT, output)
            with (ROOT / "game/data/localization/game.csv").open(newline="") as handle:
                current = {row["keys"]:row for row in csv.DictReader(handle)}
            entries = json.loads((output / "all-text.json").read_text())["entries"]
            self.assertEqual(len(entries), len(current))
            self.assertEqual({entry["key"] for entry in entries}, set(current))
            for entry in entries:
                for locale in MODULE.LOCALES:
                    self.assertEqual(entry["current"][locale], current[entry["key"]][locale])
                    self.assertIsNone(entry["proposed"][locale])
                    self.assertEqual(Counter(MODULE.placeholders(entry["current"][locale])), Counter(entry["variables"]))
            with (output / "all-text-editable.csv").open(encoding="utf-8-sig", newline="") as handle:
                editable = list(csv.DictReader(handle))
            self.assertEqual(len(editable), len(current))
            for entry in editable:
                for locale in MODULE.LOCALES:
                    self.assertEqual(entry[f"{locale}_current"], current[entry["key"]][locale])
                    self.assertEqual(entry[f"{locale}_optimized"], "")
            self.assertEqual((output / "originals/game.csv").read_bytes(), original)
            self.assertFalse(manifest["game_text_changed"])
            self.assertEqual(manifest["translations"], len(current) * 3)
            self.assertEqual(manifest["direct_reference_entries"] + manifest["unconfirmed_reference_entries"], len(current))
            chinese = (output / "zh-CN-only.md").read_text()
            self.assertEqual(chinese.count("\n### "), len(current))
            meanings = json.loads((output / "placeholder-guide.json").read_text())["variables"]
            self.assertEqual(set(meanings), set(manifest["placeholder_tokens"]))
            for relative, expected in manifest["output_files_sha256"].items():
                self.assertEqual(MODULE.digest(output / relative), expected)
        self.assertEqual((ROOT / "game/data/localization/game.csv").read_bytes(), original)

    def test_unknown_usage_is_not_claimed_retired_and_config_is_separate(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            MODULE.export_review(ROOT, output)
            entries = json.loads((output / "all-text.json").read_text())["entries"]
            without_refs = [entry for entry in entries if not entry["data_references"] and not entry["runtime_references"]]
            self.assertTrue(without_refs)
            self.assertTrue(all("不要擅自删除" in entry["reference_status"] for entry in without_refs))
            metadata = json.loads((output / "project-metadata.json").read_text())
            self.assertEqual({entry["review_id"] for entry in metadata}, {"PROJECT_CONFIG_NAME", "PROJECT_CONFIG_DESCRIPTION"})
            self.assertTrue(all(entry["not_a_localization_key"] for entry in metadata))

    def test_image_references_remain_original_and_not_csv_editable(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            MODULE.export_review(ROOT, output)
            images = json.loads((output / "embedded-image-text.json").read_text())
            self.assertEqual(len(images), 8)
            for entry in images:
                self.assertFalse(entry["editable_via_localization_csv"])
                self.assertEqual(MODULE.digest(output / entry["file"]), entry["sha256"])
            bold = next(entry for entry in images if entry["id"] == "postcard_bold")
            self.assertIn("笨笨的我", bold["observed_image_text"])
            self.assertIn("笨笨的猪", bold["original_gallery_title"])


if __name__ == "__main__":
    unittest.main()
