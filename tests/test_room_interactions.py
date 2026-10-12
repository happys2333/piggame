from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import unittest


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from validate_content import validate_room_interactions


class RoomInteractionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.profiles = json.loads((ROOT / "game/data/catalog/room_interactions.json").read_text())
        self.behaviors = json.loads((ROOT / "game/data/catalog/behaviors.json").read_text())
        self.furniture = {item["id"] for item in json.loads((ROOT / "game/data/furniture/furniture.json").read_text())}
        self.bodies = set(json.loads((ROOT / "game/data/catalog/pig_visual_rig.json").read_text())["clips"])

    def validate(self, profiles: dict) -> list[str]:
        errors = []
        validate_room_interactions(profiles, self.behaviors, self.furniture, self.bodies, errors)
        return errors

    def test_all_required_furniture_has_a_valid_contact_profile(self) -> None:
        self.assertEqual(self.validate(self.profiles), [])

    def test_missing_contact_and_unknown_furniture_are_rejected(self) -> None:
        profiles = copy.deepcopy(self.profiles)
        profiles["furn_unknown"] = profiles.pop("furn_bed_basic")
        self.assertEqual(len(self.validate(profiles)), 2)

    def test_bad_geometry_and_unknown_pose_are_rejected(self) -> None:
        for field, value in (("contact", [1]), ("anchor", "mouth"), ("width", -1), ("pig_scale", 0), ("body_id", "missing"), ("motion", "stretch"), ("room_x", 4)):
            profiles = copy.deepcopy(self.profiles)
            profiles["furn_bed_basic"][field] = value
            self.assertTrue(self.validate(profiles), field)

    def test_tall_objects_use_standing_floor_contact_instead_of_floating(self) -> None:
        for furniture_id in ("furn_table_snack", "furn_fridge_pink", "furn_telescope"):
            profile = self.profiles[furniture_id]
            self.assertEqual(profile["anchor"], "ground")
            self.assertEqual(profile["contact"][1], 1.0)
            self.assertEqual(profile["body_id"], "body_base")

    def test_every_item_behavior_can_use_the_shared_desktop_stage(self) -> None:
        for behavior in self.behaviors:
            if behavior.get("required_furniture"):
                self.assertTrue(behavior["desktop_allowed"], behavior["id"])
                self.assertNotIn("room_x", self.profiles[behavior["required_furniture"]])


if __name__ == "__main__":
    unittest.main()
