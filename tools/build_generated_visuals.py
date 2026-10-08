#!/usr/bin/env python3
"""Copy commissioned image_gen output unchanged and assemble visual routing metadata."""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image

from validate_final_assets import expected_coverage
from build_pig_performances import performance_asset_entries
from build_pighub_rig import FACE_IDS


ROOT = Path(__file__).resolve().parents[1]
RECIPES = ROOT / "docs/design/generated-art-prompts.json"
OUTFIT_PLACEMENTS = [
    [28, 50, 142, 57], [40, 72, 124, 82], [48, 154, 137, 63],
    [28, 62, 139, 59], [24, 41, 158, 83], [115, 117, 139, 101],
    [27, 51, 148, 63], [26, 79, 139, 37], [68, 161, 74, 40],
    [26, 33, 146, 77], [40, 98, 112, 42], [124, 121, 129, 96],
]


def catalog_tokens(relative: str, kind: str, field: str = "id") -> list[str]:
    items = json.loads((ROOT / "game/data" / relative).read_text(encoding="utf-8"))
    return [f"{kind}:{item[field]}" for item in items]


def cell_region(width: int, height: int, columns: int, rows: int, index: int, inset: int = 0) -> list[int]:
    column = index % columns
    row = index // columns
    left = round(width * column / columns) + inset
    top = round(height * row / rows) + inset
    right = round(width * (column + 1) / columns) - inset
    bottom = round(height * (row + 1) / rows) - inset
    return [left, top, right - left, bottom - top]


def build_manifest(copy_images: bool = False) -> dict:
    recipes = json.loads(RECIPES.read_text(encoding="utf-8"))["records"]
    furniture_tokens = catalog_tokens("furniture/furniture.json", "furniture")
    expression_tokens = catalog_tokens("expressions/expressions.json", "expression")
    event_tokens = catalog_tokens("events/events.json", "event")
    outfit_tokens = catalog_tokens("catalog/outfits.json", "outfit")
    entries = []
    pending_copies = []
    for recipe in recipes:
        source = Path(recipe["source_file"])
        destination = ROOT / recipe["destination"]
        if recipe["tool"] != "built-in image_gen" or not source.is_file() or source.is_symlink():
            raise ValueError(f"invalid generated source: {source}")
        if destination.parent != ROOT / "game/assets/final/generated" or destination.suffix != ".png":
            raise ValueError(f"invalid generated destination: {destination}")
        image = Image.open(source)
        image.load()
        width, height = image.size
        identifier = recipe["id"]
        entry = {
            "path": "res://" + recipe["destination"],
            "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "dimensions": [width, height],
            "source": f"Built-in image_gen, commissioned by the user; prompt record {identifier}",
            "license": "AI-generated output for this user-authorized project; release ownership and legal review remain pending.",
        }
        if identifier.startswith("furniture_"):
            group = int(identifier.rsplit("_", 1)[1]) - 1
            tokens = furniture_tokens[group * 16 : (group + 1) * 16]
            entry["regions"] = {token: cell_region(width, height, 4, 4, index) for index, token in enumerate(tokens)}
        elif identifier == "pighub_expressions":
            rig = json.loads((ROOT / "game/data/catalog/pig_visual_rig.json").read_text())
            tokens = expression_tokens
            entry["regions"] = {token: cell_region(width, height, 4, 2, FACE_IDS.index(rig["expressions"][token.split(":", 1)[1]])) for token in tokens}
            status_faces = {"sleepy": "face_sleepy", "hungry": "face_dot", "bored": "face_glare", "energetic": "face_shock", "content": "face_squint"}
            for status, face_id in status_faces.items():
                token = "ui:status_" + status
                tokens.append(token)
                entry["regions"][token] = cell_region(width, height, 4, 2, FACE_IDS.index(face_id))
            entry["full_character"] = True
        elif identifier.startswith("events_"):
            group = int(identifier.rsplit("_", 1)[1]) - 1
            tokens = event_tokens[group * 6 : (group + 1) * 6]
            entry["regions"] = {token: cell_region(width, height, 2, 3, index, 2) for index, token in enumerate(tokens)}
        elif identifier.startswith("room_") and identifier != "room_effects":
            tokens = ["room:" + identifier.removeprefix("room_")]
        elif identifier == "room_effects":
            tokens = ["room_effect:" + effect for effect in ["sleep_glow", "oven_warmth", "rainy_window", "breeze", "window_glow"]]
            entry["regions"] = {token: cell_region(width, height, 2, 3, index, 3) for index, token in enumerate(tokens)}
        elif identifier == "snacks":
            tokens = catalog_tokens("catalog/snacks.json", "snack")
            entry["regions"] = {token: cell_region(width, height, 4, 4, index) for index, token in enumerate(tokens)}
        elif identifier == "outfits":
            tokens = outfit_tokens
            entry["regions"] = {}
            entry["placements"] = dict(zip(tokens, OUTFIT_PLACEMENTS, strict=True))
            for index, token in enumerate(tokens):
                left, top, cell_width, cell_height = cell_region(width, height, 4, 4, index)
                alpha = image.getchannel("A").crop((left, top, left + cell_width, top + cell_height))
                bounds = alpha.point(lambda value: 255 if value >= 32 else 0).getbbox()
                if bounds is None:
                    raise ValueError(f"empty outfit artwork: {token}")
                entry["regions"][token] = [left + bounds[0], top + bounds[1], bounds[2] - bounds[0], bounds[3] - bounds[1]]
        elif identifier == "photo_frames":
            tokens = ["ui:photo_frame_" + frame for frame in ["plain", "berry", "star"]]
            entry["regions"] = {token: cell_region(width, height, 1, 3, index) for index, token in enumerate(tokens)}
        elif identifier == "app_icon":
            tokens = ["ui:app_icon"]
        else:
            raise ValueError(f"unknown artwork recipe: {identifier}")
        entry["covers"] = tokens
        entries.append(entry)
        pending_copies.append((source, destination, entry["sha256"]))
        image.close()
    covered = [token for entry in entries for token in entry["covers"]]
    entries.extend(performance_asset_entries(copy_images))
    covered = [token for entry in entries for token in entry["covers"]]
    expected = {token for token in expected_coverage() if not token.startswith("audio:")}
    if set(covered) != expected or len(covered) != len(expected):
        raise ValueError(f"generated visual coverage mismatch: missing={expected - set(covered)}, extra={set(covered) - expected}")
    if copy_images:
        for source, destination, expected_hash in pending_copies:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            if hashlib.sha256(destination.read_bytes()).hexdigest() != expected_hash:
                raise ValueError(f"generated image copy changed bytes: {destination}")
    return {
        "schema_version": 1,
        "ready": False,
        "provided_by_user": False,
        "visual_ready": True,
        "generation_authorized": True,
        "note": "Commissioned image_gen visuals, including modular faces/poses/forms. Audio, release ownership and external acceptance remain pending; generated images are not user-supplied originals.",
        "entries": entries,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--copy", action="store_true", help="copy generated PNGs unchanged into the workspace")
    args = parser.parse_args()
    print(json.dumps(build_manifest(args.copy), ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
