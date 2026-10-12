from __future__ import annotations

import copy
import json
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from validate_pig_performances import validate_performances
from validate_generated_visuals import validate_manifest


class PigPerformanceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.config = json.loads((ROOT / "game/data/catalog/pig_performances.json").read_text())
        self.outfit_ids = {item["id"] for item in json.loads((ROOT / "game/data/catalog/outfits.json").read_text())}

    def errors(self) -> list[str]:
        errors = []
        validate_performances(self.config, self.outfit_ids, errors)
        return errors

    def test_complete_cosmetic_library(self) -> None:
        self.assertEqual(self.errors(), [])

    def test_rewards_and_needs_cannot_enter_performances(self) -> None:
        for field in ("points", "familiarity", "satiety", "hunger_multiplier"):
            with self.subTest(field=field):
                self.config["states"][0][field] = 99
                self.assertTrue(self.errors())
                del self.config["states"][0][field]

    def test_head_anchors_and_atlas_rows_are_checked(self) -> None:
        self.config["clips"][1]["snouts"][0][1] = -1
        self.assertTrue(self.errors())
        self.config["clips"][1]["snouts"][0][1] = 150
        self.config["clips"][1]["row"] = 0
        self.assertTrue(self.errors())

    def test_corrected_strip_has_only_one_row_and_requires_a_known_sheet(self) -> None:
        clip = next(item for item in self.config["clips"] if item["id"] == "body_head_hold")
        self.assertEqual((clip["sheet"], clip["row"]), (2, 0))
        clip["row"] = 1
        self.assertTrue(self.errors())
        clip["row"] = 0
        clip["sheet"] = 3
        self.assertTrue(self.errors())

    def test_state_references_and_finite_duration_are_checked(self) -> None:
        self.config["states"][0]["pose_ids"] = ["pose_missing"]
        self.assertTrue(self.errors())
        self.config["states"][0]["pose_ids"] = ["pose_flat"]
        self.config["states"][0]["duration_seconds"] = float("nan")
        self.assertTrue(self.errors())

    def test_pose_motion_is_cosmetic_and_bounded(self) -> None:
        clip = next(item for item in self.config["clips"] if item["id"] == "body_base")
        original = copy.deepcopy(clip["motion"])
        invalid = [("frame", 4), ("frame", True), ("period_seconds", 0.4), ("period_seconds", float("nan")), ("breath_amount", 0.1), ("sway_radians", 0.5), ("exclude_animations", ["idle"]), ("exclude_animations", [{"walk":True}]), ("points", 100)]
        for field, value in invalid:
            with self.subTest(field=field, value=value):
                clip["motion"] = {**original, field:value}
                self.assertTrue(self.errors())
        clip["motion"] = original
        self.assertEqual(self.errors(), [])

    def test_every_outfit_keeps_one_gated_action(self) -> None:
        self.config["outfit_actions"][0]["outfit_id"] = self.config["outfit_actions"][1]["outfit_id"]
        self.assertTrue(self.errors())

    def test_all_new_bodies_require_four_generated_frames(self) -> None:
        manifest = json.loads((ROOT / "game/data/catalog/final_asset_manifest.json").read_text())
        self.assertEqual(validate_manifest(manifest), [])
        changed = copy.deepcopy(manifest)
        entry = next(item for item in changed["entries"] if "performance_body:body_base" in item["covers"])
        entry["frames"]["performance_body:body_base"].pop()
        self.assertTrue(validate_manifest(changed))


if __name__ == "__main__":
    unittest.main()
