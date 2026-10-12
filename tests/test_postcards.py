from __future__ import annotations

import copy
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
from pighub_postcard_assets import validate_postcards


class PostcardContentTests(unittest.TestCase):
    def setUp(self) -> None:
        self.cards = json.loads((ROOT / "game/data/catalog/postcards.json").read_text())
        self.manifest = json.loads((ROOT / "game/data/catalog/final_asset_manifest.json").read_text())

    def test_eight_original_postcards_have_exact_provenance(self) -> None:
        self.assertEqual(validate_postcards(self.cards, self.manifest), [])
        self.assertEqual([card["points"] for card in self.cards], [100, 300, 600, 1200, 2500, 5000, 9000, 15000])

    def test_threshold_types_and_order_are_checked(self) -> None:
        for value in (0, -1, 1.5, True, "100", 300):
            with self.subTest(value=value):
                altered = copy.deepcopy(self.cards)
                altered[0]["points"] = value
                self.assertTrue(validate_postcards(altered, self.manifest))

    def test_originals_cannot_be_omitted_or_renamed(self) -> None:
        altered = copy.deepcopy(self.cards)
        altered[0]["id"] = "postcard_other"
        self.assertTrue(validate_postcards(altered, self.manifest))
        self.assertTrue(validate_postcards(self.cards[:-1], self.manifest))

    def test_missing_localized_letter_is_rejected(self) -> None:
        altered = copy.deepcopy(self.cards)
        altered[0].pop("body_key")
        self.assertTrue(validate_postcards(altered, self.manifest))

    def test_source_flags_hash_dimensions_and_urls_are_checked(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            stage = Path(temporary)
            shutil.copytree(ROOT / "game/assets/final/pighub", stage / "game/assets/final/pighub")
            shutil.copytree(ROOT / "LICENSES/PigHub", stage / "LICENSES/PigHub")
            path = stage / "game/assets/final/pighub/source.json"
            original = json.loads(path.read_text())
            for field, value in (("ai_generated", True), ("release_approved", True), ("project_owner_authorized", False)):
                with self.subTest(field=field):
                    altered = copy.deepcopy(original)
                    altered[field] = value
                    path.write_text(json.dumps(altered))
                    self.assertTrue(validate_postcards(self.cards, self.manifest, stage))
            for field, value in (("sha256", "0" * 64), ("dimensions", [1, 1]), ("url", "https://example.com/other.jpg")):
                with self.subTest(field=field):
                    altered = copy.deepcopy(original)
                    altered["records"][0][field] = value
                    path.write_text(json.dumps(altered))
                    self.assertTrue(validate_postcards(self.cards, self.manifest, stage))


if __name__ == "__main__":
    unittest.main()
