from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import unittest

from PIL import Image


ROOT = Path(__file__).parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from validate_pig_outfits import validate_outfit_rig, validate_retired_outfits, RETIRED_REFUNDS
from build_generated_visuals import OUTFIT_CELLS, cell_region, isolated_sprite_region


class PigOutfitTests(unittest.TestCase):
    def setUp(self) -> None:
        self.rig = json.loads((ROOT / "game/data/catalog/pig_outfit_rig.json").read_text())
        self.clips = json.loads((ROOT / "game/data/catalog/pig_visual_rig.json").read_text())["clips"]
        self.outfits = json.loads((ROOT / "game/data/catalog/outfits.json").read_text())

    def test_every_shape_and_pose_has_an_anatomical_policy(self) -> None:
        self.assertEqual(validate_outfit_rig(self.rig, self.clips, self.outfits), [])

    def test_missing_or_invalid_attachments_are_rejected(self) -> None:
        for mutation in ("missing_shape", "missing_pose", "anchor", "width", "pivot", "rotation", "hidden", "integrated"):
            invalid = copy.deepcopy(self.rig)
            if mutation == "missing_shape":
                del invalid["shapes"]["beret"]
            elif mutation == "missing_pose":
                del invalid["poses"]["body_base"]
            elif mutation == "integrated":
                invalid["poses"]["body_worker"]["hidden_anchors"] = []
            elif mutation == "hidden":
                invalid["poses"]["body_base"]["hidden_anchors"] = ["mouth"]
            else:
                invalid["shapes"]["beret"][mutation] = {"anchor":"eyes", "width":False, "pivot":[0, 2], "rotation":float("nan")}[mutation]
            with self.subTest(mutation=mutation):
                self.assertTrue(validate_outfit_rig(invalid, self.clips, self.outfits))

    def test_only_head_and_face_accessories_are_active(self) -> None:
        self.assertEqual(len(self.outfits), 8)
        self.assertEqual({item["anchor"] for item in self.outfits}, {"head", "eyes"})
        self.assertFalse(set(RETIRED_REFUNDS).intersection(item["id"] for item in self.outfits))
        self.assertTrue(all(shape["anchor"] in {"head", "eyes"} for shape in self.rig["shapes"].values()))

    def test_retired_ids_and_original_prices_are_preserved_for_save_compatibility(self) -> None:
        retired = json.loads((ROOT / "game/data/catalog/retired_outfits.json").read_text())
        identifiers = {item["id"] for item in self.outfits}
        self.assertEqual(validate_retired_outfits(retired, identifiers), [])
        for invalid in (retired[:-1], retired + [retired[0]], [{"id":"unknown", "refund_points":260}], [{"id":item["id"], "refund_points":True} for item in retired]):
            self.assertTrue(validate_retired_outfits(invalid, identifiers))

    def test_body_attachment_rules_are_rejected(self) -> None:
        for anchor in ("neck", "body"):
            outfits = copy.deepcopy(self.outfits)
            rig = copy.deepcopy(self.rig)
            outfits[0]["anchor"] = anchor
            rig["shapes"]["beret"]["anchor"] = anchor
            self.assertTrue(validate_outfit_rig(rig, self.clips, outfits))

    def test_active_accessories_keep_their_original_atlas_cells(self) -> None:
        manifest = json.loads((ROOT / "game/data/catalog/final_asset_manifest.json").read_text())
        entry = next(item for item in manifest["entries"] if "outfit:outfit_berry_beret" in item["covers"])
        self.assertEqual(set(entry["covers"]), {"outfit:" + item["id"] for item in self.outfits})
        with Image.open(ROOT / entry["path"].removeprefix("res://")) as source:
            for identifier, index in OUTFIT_CELLS.items():
                self.assertEqual(entry["regions"]["outfit:" + identifier], isolated_sprite_region(source, cell_region(*source.size, 4, 4, index)))

    def test_glasses_keep_transparent_centers_for_black_pupils(self) -> None:
        manifest = json.loads((ROOT / "game/data/catalog/final_asset_manifest.json").read_text())
        for identifier in ("outfit_round_glasses", "outfit_star_glasses"):
            token = "outfit:" + identifier
            entry = next(item for item in manifest["entries"] if token in item["covers"])
            left, top, width, height = entry["regions"][token]
            with Image.open(ROOT / entry["path"].removeprefix("res://")) as image:
                alpha = image.getchannel("A")
                for horizontal in (0.27, 0.73):
                    center = (left + round(width * horizontal), top + round(height * 0.5))
                    sample = alpha.crop((center[0] - 3, center[1] - 3, center[0] + 4, center[1] + 4))
                    self.assertLess(sample.getextrema()[1], 32, identifier)

    def test_attachment_points_touch_the_actual_pig_silhouette_in_every_frame(self) -> None:
        manifest = json.loads((ROOT / "game/data/catalog/final_asset_manifest.json").read_text())
        for body_id, clip in self.clips.items():
            token = "performance_body:" + body_id
            entry = next(item for item in manifest["entries"] if token in item["covers"])
            with Image.open(ROOT / entry["path"].removeprefix("res://")) as source:
                for frame_index, frame in enumerate(clip["frames"]):
                    left, top, width, height = entry["frames"][token][frame_index]
                    alpha = source.getchannel("A").crop((left, top, left + width, top + height))
                    for shape_id, shape in self.rig["shapes"].items():
                        if shape["anchor"] in self.rig["poses"][body_id]["hidden_anchors"]:
                            continue
                        anchor = list(frame["snout"])
                        if shape["anchor"] == "head":
                            anchor[1] = frame["head_top"]
                        elif shape["anchor"] == "eyes":
                            anchor = [(frame["landmarks"]["left"][axis] + frame["landmarks"]["right"][axis]) / 2 for axis in (0, 1)]
                        anchor = [anchor[axis] + shape["offset"][axis] * frame["scale"] * 60 for axis in (0, 1)]
                        center = [round(anchor[axis] * (width, height)[axis] / frame["canvas"][axis]) for axis in (0, 1)]
                        contact = alpha.crop((max(0, center[0] - 2), max(0, center[1] - 2), min(width, center[0] + 3), min(height, center[1] + 3)))
                        with self.subTest(body=body_id, frame=frame_index, shape=shape_id):
                            self.assertGreaterEqual(contact.getextrema()[1], 64, "attachment floats outside the actual pig")


if __name__ == "__main__":
    unittest.main()
