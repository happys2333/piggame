from __future__ import annotations

import hashlib
import json
import sys
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from build_pighub_rig import components


class PigHubRigTests(unittest.TestCase):
    def setUp(self) -> None:
        self.rig = json.loads((ROOT / "game/data/catalog/pig_visual_rig.json").read_text())
        self.manifest = json.loads((ROOT / "game/data/catalog/final_asset_manifest.json").read_text())

    def test_all_behavior_and_collection_ids_are_routed(self) -> None:
        behaviors = json.loads((ROOT / "game/data/catalog/behaviors.json").read_text())
        expressions = json.loads((ROOT / "game/data/expressions/expressions.json").read_text())
        self.assertEqual(set(self.rig["behaviors"]), {item["animation"] for item in behaviors})
        self.assertEqual(set(self.rig["expressions"]), {item["id"] for item in expressions})
        self.assertTrue(all(item["body_id"] in self.rig["clips"] for item in self.rig["behaviors"].values()))
        self.assertTrue(all(face in self.rig["faces"] for face in self.rig["expressions"].values()))
        personalities = json.loads((ROOT / "game/data/catalog/personalities.json").read_text())
        self.assertEqual(len({self.rig["expressions"][item["pet"]["expression_id"]] for item in personalities}), 5)

    def test_eight_black_eye_faces_and_safe_legacy_alias(self) -> None:
        self.assertEqual(len(self.rig["faces"]), 8)
        self.assertNotIn("face_quake", self.rig["faces"])
        self.assertEqual(self.rig["face_aliases"], {"face_quake": "face_shock"})
        entry = next(item for item in self.manifest["entries"] if "performance_face:face_dot_left" in item["covers"])
        with Image.open(ROOT / entry["path"].removeprefix("res://")) as image:
            pixels = image.load()
            self.assertFalse(any(pixels[column, row][3] >= 32 and min(pixels[column, row][:3]) > 200 for row in range(image.height) for column in range(image.width)))
        for part in ("left", "right", "mouth"):
            self.assertEqual(entry["regions"]["performance_face:face_quake_" + part], entry["regions"]["performance_face:face_shock_" + part])

    def test_each_frame_uses_the_same_visible_snout_for_face_and_input(self) -> None:
        config = json.loads((ROOT / "game/data/catalog/pig_performances.json").read_text())
        for clip in config["clips"]:
            frames = self.rig["clips"][clip["id"]]["frames"]
            self.assertEqual(len(frames), 4)
            self.assertEqual(clip["snouts"], [frame["snout"] for frame in frames])
            for frame in frames:
                self.assertLess(frame["landmarks"]["left"][1], frame["snout"][1])
                self.assertLess(frame["landmarks"]["right"][1], frame["snout"][1])
                self.assertGreater(frame["landmarks"]["mouth"][1], frame["snout"][1])
                self.assertLess(frame["landmarks"]["mouth"][1] - frame["snout"][1], 45)
                self.assertTrue(all(0 <= coordinate <= 256 for point in frame["landmarks"].values() for coordinate in point))

    def test_all_physical_frames_are_distinct_and_inside_the_sheet(self) -> None:
        for entry in self.manifest["entries"]:
            with Image.open(ROOT / entry["path"].removeprefix("res://")) as image:
                for token, frames in entry.get("frames", {}).items():
                    if not token.startswith("performance_body:"):
                        continue
                    hashes = []
                    for left, top, width, height in frames:
                        self.assertLessEqual(left + width, image.width)
                        self.assertLessEqual(top + height, image.height)
                        hashes.append(hashlib.sha256(image.crop((left, top, left + width, top + height)).tobytes()).hexdigest())
                    self.assertEqual(len(set(hashes)), 4, token)

    def test_resting_and_obstructed_poses_hide_the_mouth(self) -> None:
        hidden = {"body_prone", "body_flat", "body_kneel", "body_corner", "body_crawl", "body_worker", "body_peek", "body_head_hold", "body_ruler"}
        for body_id, clip in self.rig["clips"].items():
            with self.subTest(body=body_id):
                self.assertEqual(clip.get("mouth_visible", True), body_id not in hidden)

    def test_neutral_face_has_no_mouth_and_expressive_mouths_are_separate(self) -> None:
        for face_id, face in self.rig["faces"].items():
            self.assertEqual(face["mouth_visible"], face_id != "face_dot")
            self.assertIn("performance_face:" + face_id + "_mouth", {
                token for entry in self.manifest["entries"] for token in entry["covers"]
            })

    def test_stationary_pose_profiles_keep_original_frames_and_real_floor_pivots(self) -> None:
        for body_id in self.rig["clips"]:
            clip = self.rig["clips"][body_id]
            profile = clip["motion"]
            self.assertEqual(profile["mode"], "pose")
            self.assertEqual(profile["frame"], 0)
            self.assertEqual(profile["pivot"][0], 128.0)
            token = "performance_body:" + body_id
            entry = next(item for item in self.manifest["entries"] if token in item["covers"])
            self.assertEqual(len(entry["frames"][token]), 4)
            left, top, width, height = entry["frames"][token][profile["frame"]]
            with Image.open(ROOT / entry["path"].removeprefix("res://")) as image:
                alpha = image.getchannel("A").crop((left, top, left + width, top + height))
                silhouette = alpha.point(lambda value: 255 if value >= 64 else 0).getbbox()
            self.assertAlmostEqual(profile["pivot"][1], silhouette[3] * 256 / width, places=3)
            self.assertLessEqual(profile["breath_amount"], 0.02)
            frame = clip["frames"][0]
            self.assertLess(0, frame["head_top"])
            self.assertLess(frame["head_top"], frame["snout"][1])
            self.assertLess(frame["snout"][1] + 16, frame["ground"])
            self.assertLessEqual(frame["ground"], frame["canvas"][1])
            self.assertNotIn("mesh", frame)
            for frame_index, measured in enumerate(clip["frames"]):
                region = entry["frames"][token][frame_index]
                self.assertAlmostEqual(measured["canvas"][1] / measured["canvas"][0], region[3] / region[2], places=5)
        self.assertEqual(self.rig["clips"]["body_base"]["motion"]["exclude_animations"], ["walk", "run"])

    def test_head_hold_uses_only_the_corrected_four_frame_strip(self) -> None:
        token = "performance_body:body_head_hold"
        owners = [entry for entry in self.manifest["entries"] if token in entry["covers"]]
        self.assertEqual(len(owners), 1)
        entry = owners[0]
        self.assertEqual(entry["path"], "res://game/assets/final/generated/pighub_head_hold.png")
        self.assertEqual(set(entry["covers"]), {token, "behavior:scratch", "behavior:alarm", "behavior:puzzle"})
        for other in self.manifest["entries"]:
            if other is not entry:
                self.assertNotIn(token, other["covers"])
        with Image.open(ROOT / entry["path"].removeprefix("res://")) as image:
            for frame, (left, top, width, height) in enumerate(entry["frames"][token]):
                cell = image.crop((left, top, left + width, top + height))
                marks = components(cell, lambda pixel: pixel[3] >= 64 and max(pixel[:3]) < 80)
                self.assertEqual(len(marks), 2, f"frame {frame}: only two nostrils, no baked eyes or mouth")

    def test_visible_mouth_stays_centered_below_the_snout(self) -> None:
        mouth_centers = {}
        for face_id, geometry in self.rig["faces"].items():
            token = "performance_face:" + face_id + "_mouth"
            entry = next(item for item in self.manifest["entries"] if token in item["covers"])
            left, top, width, height = entry["regions"][token]
            with Image.open(ROOT / entry["path"].removeprefix("res://")) as source:
                glyph = source.crop((left, top, left + width, top + height))
                pixels = glyph.load()
                black_points = [
                    (column, row)
                    for row in range(height)
                    for column in range(width)
                    if pixels[column, row][3] >= 64 and max(pixels[column, row][:3]) < 80
                ]
            self.assertTrue(black_points, face_id)
            mouth = geometry["mouth"]
            mouth_centers[face_id] = [
                mouth["offset"][axis]
                + sum(point[axis] for point in black_points) / len(black_points)
                * mouth["size"][axis] / (width, height)[axis]
                for axis in (0, 1)
            ]
        for body_id, clip in self.rig["clips"].items():
            if not clip.get("mouth_visible", True):
                continue
            for frame_index, frame in enumerate(clip["frames"]):
                nose_width = frame["scale"] * 60
                for face_id, glyph_center in mouth_centers.items():
                    with self.subTest(body=body_id, frame=frame_index, face=face_id):
                        rendered_center = [
                            frame["landmarks"]["mouth"][axis] + glyph_center[axis] * frame["scale"] * self.rig["faces"][face_id]["mouth"].get("relative_scale", 1.0)
                            for axis in (0, 1)
                        ]
                        self.assertLessEqual(abs(rendered_center[0] - frame["snout"][0]), nose_width * 0.12)
                        self.assertGreater(rendered_center[1], frame["snout"][1] + nose_width * 0.25)

    def test_mouth_fits_the_lower_face_without_reaching_paws_or_clothing(self) -> None:
        for body_id, clip in self.rig["clips"].items():
            if not clip.get("mouth_visible", True):
                continue
            for frame_index, frame in enumerate(clip["frames"]):
                for face_id, face in self.rig["faces"].items():
                    if not face["mouth_visible"]:
                        continue
                    with self.subTest(body=body_id, frame=frame_index, face=face_id):
                        self.assertIn("mouth_area", frame)
                        mouth = face["mouth"]
                        scale = frame["scale"] * mouth.get("relative_scale", 1.0)
                        position = [frame["landmarks"]["mouth"][axis] + mouth["offset"][axis] * scale for axis in (0, 1)]
                        dimensions = [value * scale for value in mouth["size"]]
                        area = frame["mouth_area"]
                        for axis in (0, 1):
                            self.assertGreaterEqual(position[axis], area[axis])
                            self.assertLessEqual(position[axis] + dimensions[axis], area[axis] + area[axis + 2])
                        self.assertLessEqual(dimensions[0], frame["scale"] * 60 * 0.36)
                        self.assertLessEqual(dimensions[1], frame["scale"] * 60 * 0.24)

    def test_runtime_contains_only_manifest_pngs(self) -> None:
        active = {entry["path"].removeprefix("res://") for entry in self.manifest["entries"] if entry.get("origin") != "pighub_original"}
        actual = {path.relative_to(ROOT).as_posix() for path in (ROOT / "game/assets/final/generated").glob("*.png")}
        self.assertEqual(actual, active)
        recipes = json.loads((ROOT / "docs/design/generated-art-prompts.json").read_text())["records"]
        self.assertFalse(any(item["id"].startswith(("behavior_", "expressions_")) for item in recipes))

    def test_keyframe_boundaries_do_not_cut_opaque_art(self) -> None:
        for entry in self.manifest["entries"]:
            with Image.open(ROOT / entry["path"].removeprefix("res://")) as image:
                for token, frames in entry.get("frames", {}).items():
                    if not token.startswith("performance_body:"):
                        continue
                    for frame_index, (left, top, width, height) in enumerate(frames):
                        alpha = image.getchannel("A").crop((left, top, left + width, top + height))
                        borders = [
                            alpha.crop((0, 0, width, 1)),
                            alpha.crop((0, height - 1, width, height)),
                            alpha.crop((0, 0, 1, height)),
                            alpha.crop((width - 1, 0, width, height)),
                        ]
                        for border_index, border in enumerate(borders):
                            self.assertLess(border.getextrema()[1], 64, (token, frame_index, border_index))

    def test_economy_and_motion_policy_remain_outside_the_rig(self) -> None:
        forbidden = {"points", "familiarity", "satiety", "cooldown_seconds", "duration_seconds", "hunger_multiplier"}
        for item in [*self.rig["clips"].values(), *self.rig["behaviors"].values()]:
            self.assertFalse(set(item) & forbidden)
        self.assertEqual(self.rig["behaviors"]["sleep"]["frame_stride"], 4)
        self.assertEqual(self.rig["behaviors"]["walk"]["frame_stride"], 1)


if __name__ == "__main__":
    unittest.main()
