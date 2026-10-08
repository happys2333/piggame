"""Route unchanged image_gen PNGs into modular body and facial-glyph atlases."""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image
from build_pighub_rig import FACE_IDS, body_region, glyph_regions


ROOT = Path(__file__).resolve().parents[1]


def performance_asset_entries(copy_images: bool = False) -> list[dict]:
    config = json.loads((ROOT / "game/data/catalog/pig_performances.json").read_text())
    recipes = json.loads((ROOT / "docs/design/pig-performance-art-prompts.json").read_text())["records"]
    rig = json.loads((ROOT / "game/data/catalog/pig_visual_rig.json").read_text())
    entries = []
    for recipe in recipes:
        source = Path(recipe["source_file"])
        destination = ROOT / recipe["destination"]
        if recipe["tool"] != "built-in image_gen" or not source.is_file() or source.is_symlink() or destination.parent != ROOT / "game/assets/final/generated":
            raise ValueError("invalid performance image provenance/destination")
        image = Image.open(source)
        image.load()
        if image.format != "PNG" or "A" not in image.getbands():
            raise ValueError("performance sprites require generated PNG alpha")
        entry = {"path":"res://" + recipe["destination"], "sha256":hashlib.sha256(source.read_bytes()).hexdigest(), "dimensions":list(image.size), "source":"Built-in image_gen; commissioned prompt record pig-performance:" + recipe["id"], "license":"User-authorized AI-generated project art; final release ownership review remains pending."}
        if recipe["id"].startswith("body_"):
            sheet = int(recipe["id"].rsplit("_", 1)[1]) - 1
            entry["frames"] = {"performance_body:" + clip["id"]:[body_region(image, recipe, clip["row"], frame) for frame in range(4)] for clip in config["clips"] if clip["sheet"] == sheet}
            entry["frame_trims"] = {}
            for animation, mapping in rig["behaviors"].items():
                body_token = "performance_body:" + mapping["body_id"]
                if body_token in entry["frames"]:
                    token = "behavior:" + animation
                    entry["frames"][token] = entry["frames"][body_token]
            for token, frames in entry["frames"].items():
                trims = []
                for left, top, width, height in frames:
                    alpha = image.getchannel("A").crop((left, top, left + width, top + height))
                    bounds = alpha.point(lambda value: 255 if value >= 32 else 0).getbbox()
                    if bounds is None:
                        raise ValueError(f"empty pig keyframe: {token}")
                    trim_left, trim_top = max(0, bounds[0] - 1), max(0, bounds[1] - 1)
                    trim_right, trim_bottom = min(width, bounds[2] + 1), min(height, bounds[3] + 1)
                    trims.append([left + trim_left, top + trim_top, trim_right - trim_left, trim_bottom - trim_top])
                entry["frame_trims"][token] = trims
            entry["regions"] = {token:frames[0] for token, frames in entry["frames"].items()}
        else:
            entry["regions"] = {"performance_face:" + face_id + "_" + part:region for index, face_id in enumerate(FACE_IDS) for part, region in glyph_regions(image, index)[0].items()}
            for part in ("left", "right", "mouth"):
                entry["regions"]["performance_face:face_quake_" + part] = entry["regions"]["performance_face:face_shock_" + part]
        entry["covers"] = list(entry["regions"])
        entries.append(entry)
        image.close()
        if copy_images:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            if hashlib.sha256(destination.read_bytes()).hexdigest() != entry["sha256"]:
                raise ValueError("performance PNG changed while copying")
    return entries


def main() -> None:
    manifest_path = ROOT / "game/data/catalog/final_asset_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    entries = performance_asset_entries(True)
    manifest["entries"] = [entry for entry in manifest["entries"] if not any(token.startswith("performance_") for token in entry["covers"])] + entries
    manifest["note"] = "Commissioned image_gen visuals, including modular blank-face bodies and facial glyphs; audio, original-asset ownership and final release acceptance remain pending."
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    print("Copied 3 unchanged PNGs; 12 shared four-frame bodies, 36 behavior aliases, 8 black-eye faces plus legacy alias")


if __name__ == "__main__":
    main()
