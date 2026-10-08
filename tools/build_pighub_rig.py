"""Measure generated sprites without repainting their original PNG bytes."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
FACE_IDS = ["face_dot", "face_squint", "face_deadpan", "face_tears", "face_sly", "face_glare", "face_sleepy", "face_shock"]
MOUTH_HIDDEN_BODIES = {"body_prone", "body_flat", "body_corner", "body_crawl", "body_worker"}
BODY_GROUPS = {
    "body_prone": ["lie", "bed_nap", "window_nap"],
    "body_flat": ["sleep", "pillow_flop", "blanket_roll"],
    "body_head_hold": ["scratch", "alarm", "puzzle"],
    "body_kneel": ["sit", "read", "drink", "tea", "water_plant"],
    "body_corner": ["cookie_guard"],
    "body_arms": ["yoga", "paint", "ball", "drum", "radio"],
    "body_peek": ["stare", "look_mouse", "nightlight", "mirror_pose", "camera", "castle", "weather", "telescope", "wind_chime"],
    "body_crawl": ["sniff", "table_snack", "fridge"],
}
CATEGORY_FACES = {
    "happy": ["face_dot", "face_squint", "face_squint", "face_deadpan", "face_dot", "face_squint", "face_sly", "face_squint"],
    "sleepy": ["face_sleepy", "face_glare", "face_sleepy", "face_deadpan", "face_sleepy", "face_sleepy", "face_dot", "face_sleepy"],
    "hungry": ["face_dot", "face_sly", "face_shock", "face_tears", "face_glare", "face_dot", "face_sly", "face_squint"],
    "wronged": ["face_tears", "face_glare", "face_tears", "face_deadpan", "face_tears", "face_glare", "face_shock", "face_tears"],
    "proud": ["face_sly", "face_squint", "face_sly", "face_dot", "face_deadpan", "face_sly", "face_squint", "face_sly"],
    "shocked": ["face_shock", "face_dot", "face_shock", "face_tears", "face_glare", "face_shock", "face_deadpan", "face_shock"],
}


def components(image: Image.Image, predicate) -> list[list[tuple[int, int]]]:
    pixels = image.load()
    points = {(column, row) for row in range(image.height) for column in range(image.width) if predicate(pixels[column, row])}
    result = []
    while points:
        start = points.pop()
        pending, component = [start], [start]
        while pending:
            current_x, current_y = pending.pop()
            for neighbor in [(current_x - 1, current_y), (current_x + 1, current_y), (current_x, current_y - 1), (current_x, current_y + 1)]:
                if neighbor in points:
                    points.remove(neighbor)
                    pending.append(neighbor)
                    component.append(neighbor)
        if len(component) >= 12:
            result.append(component)
    return result


def center(points: list[tuple[int, int]]) -> tuple[float, float]:
    return tuple(sum(point[axis] for point in points) / len(points) for axis in (0, 1))


def bounds(points: list[tuple[int, int]]) -> list[int]:
    left, top = min(point[0] for point in points), min(point[1] for point in points)
    return [left, top, max(point[0] for point in points) - left + 1, max(point[1] for point in points) - top + 1]


def body_region(image: Image.Image, recipe: dict, row: int, frame: int) -> list[int]:
    edges = recipe.get("row_edges", [round(image.height * index / 6) for index in range(7)])
    left, right = round(image.width * frame / 4), round(image.width * (frame + 1) / 4)
    return [left, edges[row], right - left, edges[row + 1] - edges[row]]


def glyph_regions(image: Image.Image, index: int) -> tuple[dict, dict]:
    column, row = index % 4, index // 4
    left, top = round(image.width * column / 4), round(image.height * row / 2)
    right, bottom = round(image.width * (column + 1) / 4), round(image.height * (row + 1) / 2)
    cell = image.crop((left, top, right, bottom))
    groups = {part: [] for part in ("left", "right", "mouth")}
    dark = {part: [] for part in groups}
    for component in components(cell, lambda pixel: pixel[3] >= 32):
        location = center(component)
        part = "mouth" if 0.35 < location[0] / cell.width < 0.62 and location[1] > cell.height * 0.58 else "left" if location[0] < cell.width * 0.5 else "right"
        groups[part].extend(component)
    for component in components(cell, lambda pixel: pixel[3] >= 32 and max(pixel[:3]) < 80):
        location = center(component)
        part = "mouth" if 0.35 < location[0] / cell.width < 0.62 and location[1] > cell.height * 0.58 else "left" if location[0] < cell.width * 0.5 else "right"
        dark[part].append(component)
    regions, geometry = {}, {}
    for part, points in groups.items():
        if not points or not dark[part]:
            raise ValueError(f"missing black glyph: {FACE_IDS[index]}/{part}")
        region = bounds(points)
        root = center(max(dark[part], key=len))
        scale = 125 / cell.width
        regions[part] = [left + region[0], top + region[1], region[2], region[3]]
        geometry[part] = {"offset": [round((region[axis] - root[axis]) * scale, 4) for axis in (0, 1)], "size": [round(value * scale, 4) for value in region[2:]]}
    return regions, geometry


def build_rig() -> dict:
    config_path = ROOT / "game/data/catalog/pig_performances.json"
    config = json.loads(config_path.read_text())
    recipes = json.loads((ROOT / "docs/design/pig-performance-art-prompts.json").read_text())["records"]
    rig = {"schema_version": 1, "face_aliases": {"face_quake": "face_shock"}, "faces": {}, "clips": {}, "behaviors": {}, "expressions": {}, "category_faces": CATEGORY_FACES}
    for recipe in recipes:
        with Image.open(recipe["source_file"]) as image:
            if recipe["id"] == "faces":
                rig["faces"] = {face_id: glyph_regions(image, index)[1] for index, face_id in enumerate(FACE_IDS)}
                continue
            sheet = int(recipe["id"].rsplit("_", 1)[1]) - 1
            for clip in config["clips"]:
                if clip["sheet"] != sheet:
                    continue
                frames = []
                for frame in range(4):
                    left, top, width, height = body_region(image, recipe, clip["row"], frame)
                    cell = image.crop((left, top, left + width, top + height))
                    candidates = [component for component in components(cell, lambda pixel: pixel[3] >= 64 and max(pixel[:3]) < 80) if 8 <= len(component) < width * height * 0.018 and center(component)[0] < width * 0.55]
                    pair = sorted(sorted(candidates, key=len, reverse=True)[:2], key=lambda component: center(component)[0])
                    if len(pair) != 2:
                        raise ValueError(f"need exactly two visible nostrils: {clip['id']}/{frame}")
                    first, second = center(pair[0]), center(pair[1])
                    snout = [(first[0] + second[0]) * 128 / width, (first[1] + second[1]) * 128 / height]
                    pink_components = components(cell, lambda pixel: pixel[3] >= 64 and pixel[0] > 170 and pixel[1] < 135 and pixel[2] > 95)
                    nostril_center = ((first[0] + second[0]) * 0.5, (first[1] + second[1]) * 0.5)
                    nose_components = [component for component in pink_components if bounds(component)[0] <= nostril_center[0] <= bounds(component)[0] + bounds(component)[2] and bounds(component)[1] <= nostril_center[1] <= bounds(component)[1] + bounds(component)[3]]
                    if not nose_components:
                        raise ValueError(f"missing pink nose around the nostrils: {clip['id']}/{frame}")
                    nose = bounds(max(nose_components, key=len))
                    nose_width, nose_top, nose_bottom = nose[2] * 256 / width, nose[1] * 256 / height, (nose[1] + nose[3]) * 256 / height
                    scale = nose_width / 60
                    landmarks = {"left": [snout[0] - nose_width * 0.28, nose_top - nose_width * 0.32], "right": [snout[0] + nose_width * 0.63, nose_top - nose_width * 0.21], "mouth": [snout[0] + 1, nose_bottom + nose_width * 0.12]}
                    landmarks = {part: [round(value, 4) for value in point] for part, point in landmarks.items()}
                    pink_marks = [component for component in pink_components if center(component)[1] < (first[1] + second[1]) * 0.5 - 20 and center(component)[0] < width * 0.6]
                    head_top = min((bounds(component)[1] for component in pink_marks), default=(first[1] + second[1]) * 0.5 - 90) * 256 / height
                    frames.append({"snout": [round(value, 4) for value in snout], "head_top": round(head_top, 4), "scale": round(scale, 4), "landmarks": landmarks})
                clip["snouts"] = [frame["snout"] for frame in frames]
                rig["clips"][clip["id"]] = {"frames": frames, "integrated_outfit": clip.get("integrated_outfit", False), "mouth_visible": clip["id"] not in MOUTH_HIDDEN_BODIES}
    behaviors = json.loads((ROOT / "game/data/catalog/behaviors.json").read_text())
    for behavior in behaviors:
        animation = behavior["animation"]
        body_id = next((body for body, animations in BODY_GROUPS.items() if animation in animations), "body_base")
        category = "sleepy" if animation in {"sleep", "bed_nap", "window_nap", "lie", "pillow_flop", "blanket_roll"} else "hungry" if animation in {"fridge", "table_snack", "sniff", "cookie_guard", "drink", "tea"} else "proud" if animation in {"run", "yoga", "mirror_pose", "paint", "drum", "camera", "robot_ride"} else "wronged" if animation in {"alarm", "scratch"} else "shocked" if animation in {"telescope", "weather", "wind_chime", "puzzle", "castle"} else "happy"
        rig["behaviors"][animation] = {"body_id": body_id, "face_id": CATEGORY_FACES[category][0], "prop": behavior.get("required_furniture", ""), "frame_stride": 1 if animation in {"walk", "run", "drum", "scratch"} else 4 if category == "sleepy" else 2}
    for animation, face_id in {"walk": "face_squint", "stare": "face_deadpan", "look_mouse": "face_shock"}.items():
        rig["behaviors"][animation]["face_id"] = face_id
    expressions = json.loads((ROOT / "game/data/expressions/expressions.json").read_text())
    for category, face_ids in CATEGORY_FACES.items():
        for variant, expression in enumerate(item for item in expressions if item["category"] == category):
            rig["expressions"][expression["id"]] = face_ids[variant]
    rig["expressions"]["expr_happy_warm"] = "face_squint"
    rig["expressions"]["expr_hungry_sniff"] = "face_shock"
    config_path.write_text(json.dumps(config, ensure_ascii=False, indent=2) + "\n")
    (ROOT / "game/data/catalog/pig_visual_rig.json").write_text(json.dumps(rig, ensure_ascii=False, indent=2) + "\n")
    return rig


if __name__ == "__main__":
    build_rig()
