from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from validate_generated_visuals import validate_manifest
from build_generated_visuals import isolated_sprite_region
from PIL import Image, ImageDraw


class GeneratedVisualTests(unittest.TestCase):
    def setUp(self) -> None:
        self.manifest = json.loads((ROOT / "game/data/catalog/final_asset_manifest.json").read_text())

    def test_complete_visual_set(self) -> None:
        self.assertEqual(validate_manifest(self.manifest), [])

    def test_sprite_crop_excludes_neighboring_cell_fragments(self) -> None:
        image = Image.new("RGBA", (120, 120))
        drawing = ImageDraw.Draw(image)
        drawing.rectangle((20, 40, 100, 110), fill=(255, 120, 120, 255))
        drawing.rectangle((45, 0, 70, 3), fill=(255, 120, 120, 255))
        self.assertEqual(isolated_sprite_region(image, [0, 0, 120, 120]), [19, 39, 83, 73])

    def test_sprite_crop_keeps_separate_meaningful_details(self) -> None:
        image = Image.new("RGBA", (120, 120))
        drawing = ImageDraw.Draw(image)
        drawing.rectangle((20, 40, 100, 110), fill=(255, 120, 120, 255))
        drawing.rectangle((45, 10, 70, 20), fill=(255, 120, 120, 255))
        self.assertEqual(isolated_sprite_region(image, [0, 0, 120, 120]), [19, 9, 83, 103])

    def test_authorization_required(self) -> None:
        self.manifest["generation_authorized"] = False
        self.assertTrue(validate_manifest(self.manifest))

    def test_generated_output_not_user_original(self) -> None:
        self.manifest["provided_by_user"] = True
        self.assertTrue(validate_manifest(self.manifest))

    def test_image_hash_checked(self) -> None:
        self.manifest["entries"][0]["sha256"] = "0" * 64
        self.assertTrue(validate_manifest(self.manifest))

    def test_complete_unique_coverage_required(self) -> None:
        self.manifest["entries"].append(copy.deepcopy(self.manifest["entries"][0]))
        self.assertTrue(validate_manifest(self.manifest))

    def test_four_animation_frames_required(self) -> None:
        first_entry = next(entry for entry in self.manifest["entries"] if any(token.startswith("behavior:") for token in entry["covers"]))
        first_token = next(token for token in first_entry["covers"] if token.startswith("behavior:"))
        first_entry["frames"][first_token].pop()
        self.assertTrue(validate_manifest(self.manifest))

    def test_trim_stays_inside_its_frame(self) -> None:
        first_entry = next(entry for entry in self.manifest["entries"] if any(token.startswith("behavior:") for token in entry["covers"]))
        first_token = next(token for token in first_entry["covers"] if token.startswith("behavior:"))
        first_entry["frame_trims"][first_token][0] = [0, 0, 512, 512]
        self.assertTrue(validate_manifest(self.manifest))

    def test_each_frame_requires_a_trim(self) -> None:
        first_entry = next(entry for entry in self.manifest["entries"] if any(token.startswith("behavior:") for token in entry["covers"]))
        first_token = next(token for token in first_entry["covers"] if token.startswith("behavior:"))
        first_entry["frame_trims"][first_token].pop()
        self.assertTrue(validate_manifest(self.manifest))

    def test_original_postcard_cannot_claim_generation(self) -> None:
        postcard = next(entry for entry in self.manifest["entries"] if entry.get("origin") == "pighub_original")
        postcard["origin"] = "image_gen"
        self.assertTrue(validate_manifest(self.manifest))

    def test_original_postcard_source_and_hash_are_verified(self) -> None:
        for field, value in (("sha256", "0" * 64), ("source", "image_gen"), ("license", "public domain")):
            with self.subTest(field=field):
                altered = copy.deepcopy(self.manifest)
                postcard = next(entry for entry in altered["entries"] if entry.get("origin") == "pighub_original")
                postcard[field] = value
                self.assertTrue(validate_manifest(altered))


if __name__ == "__main__":
    unittest.main()
