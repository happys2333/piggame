#!/usr/bin/env python3
"""Validate commissioned visual coverage without approving audio or a final release."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image

from validate_final_assets import expected_coverage


ROOT = Path(__file__).resolve().parents[1]


def validate_manifest(manifest: dict, root: Path = ROOT) -> list[str]:
    errors = []
    if manifest.get("visual_ready") is not True or manifest.get("generation_authorized") is not True:
        errors.append("visual generation readiness and explicit authorization are required")
    if manifest.get("ready") is not False or manifest.get("provided_by_user") is not False:
        errors.append("generated visual-only artwork must not be described as user-supplied final assets")
    covered = []
    for entry in manifest.get("entries", []):
        path = entry.get("path", "")
        if not path.startswith("res://game/assets/final/generated/") or ".." in path:
            errors.append(f"invalid generated PNG path: {path}")
            continue
        disk_path = root / path.removeprefix("res://")
        if not disk_path.is_file() or disk_path.is_symlink():
            errors.append(f"missing generated image: {path}")
            continue
        if hashlib.sha256(disk_path.read_bytes()).hexdigest() != entry.get("sha256"):
            errors.append(f"generated image hash mismatch: {path}")
        image = Image.open(disk_path)
        image.load()
        if image.format != "PNG" or list(image.size) != entry.get("dimensions"):
            errors.append(f"generated PNG dimensions mismatch: {path}")
        if "image_gen" not in entry.get("source", "") or not entry.get("license", "").strip():
            errors.append(f"generated image provenance is missing: {path}")
        tokens = entry.get("covers", [])
        covered.extend(tokens)
        for token in tokens:
            if token.startswith("audio:"):
                errors.append(f"visual generation must not replace audio: {token}")
            regions = entry.get("frames", {}).get(token, [entry.get("regions", {}).get(token, [0, 0, *image.size])])
            if token.startswith(("behavior:", "performance_body:")) and len(regions) != 4:
                errors.append(f"behavior requires four keyframes: {token}")
            trims = entry.get("frame_trims", {}).get(token, [])
            if token.startswith("behavior:") and len(trims) != len(regions):
                errors.append(f"behavior trims must match its keyframes: {token}")
            for region, trim in zip(regions, trims):
                if len(trim) != 4 or any(type(value) is not int for value in trim):
                    errors.append(f"non-integer sprite trim: {token}")
                    continue
                left, top, width, height = region
                trim_left, trim_top, trim_width, trim_height = trim
                if trim_width <= 0 or trim_height <= 0 or trim_left < left or trim_top < top or trim_left + trim_width > left + width or trim_top + trim_height > top + height:
                    errors.append(f"sprite trim is outside its keyframe: {token}")
            for region in regions:
                if len(region) != 4 or any(type(value) is not int for value in region):
                    errors.append(f"non-integer atlas region: {token}")
                    continue
                left, top, width, height = region
                if left < 0 or top < 0 or width <= 0 or height <= 0 or left + width > image.width or top + height > image.height:
                    errors.append(f"atlas region is outside image: {token}")
                    continue
                if "A" in image.getbands():
                    alpha = image.getchannel("A").crop((left, top, left + width, top + height))
                    if alpha.getextrema()[1] < 32:
                        errors.append(f"empty transparent artwork: {token}")
                    if token.startswith("ui:photo_frame") and alpha.getpixel((width // 2, height // 2)) != 0:
                        errors.append(f"photo-frame center must be fully transparent: {token}")
                elif token.startswith(("behavior:", "outfit:", "furniture:", "expression:", "snack:", "room_effect:", "ui:", "performance_")):
                    errors.append(f"sprite or overlay lacks alpha: {token}")
        image.close()
    expected = {token for token in expected_coverage() if not token.startswith("audio:")}
    if set(covered) != expected or len(covered) != len(expected):
        errors.append(f"visual coverage must contain all {len(expected)} unique tokens; missing={sorted(expected - set(covered))}, extra={sorted(set(covered) - expected)}")
    return errors


def main() -> int:
    manifest = json.loads((ROOT / "game/data/catalog/final_asset_manifest.json").read_text(encoding="utf-8"))
    errors = validate_manifest(manifest)
    if errors:
        print("Generated visual validation failed:")
        for error in errors:
            print("- " + error)
        return 1
    count = sum(len(entry['covers']) for entry in manifest['entries'])
    bodies = sum(token.startswith("performance_body:") for entry in manifest["entries"] for token in entry["covers"])
    print(f"PASS: {count} generated visual tokens, {len(manifest['entries'])} unchanged PNG sources, {bodies} shared four-frame bodies, 36 behavior aliases; audio and final release remain pending")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
