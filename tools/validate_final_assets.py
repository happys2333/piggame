#!/usr/bin/env python3
"""Gate final release on complete user-supplied creative-asset coverage."""

from __future__ import annotations

import json
import hashlib
import sys
from collections import Counter
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "game" / "data"
MANIFEST = DATA / "catalog" / "final_asset_manifest.json"
FINAL_PREFIX = "res://game/assets/final/"
VISUAL_SUFFIXES = {".png", ".webp", ".svg", ".tres", ".res"}


def load(path: Path) -> Any:
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def expected_coverage() -> set[str]:
    furniture = load(DATA / "furniture" / "furniture.json")
    catalogs = {
        "furniture": furniture,
        "outfit": load(DATA / "catalog" / "outfits.json"),
        "snack": load(DATA / "catalog" / "snacks.json"),
        "expression": load(DATA / "expressions" / "expressions.json"),
        "event": load(DATA / "events" / "events.json"),
    }
    result = {
        f"{kind}:{item['id']}"
        for kind, items in catalogs.items()
        for item in items
    }
    result.update(
        f"room_effect:{item['room_effect']}"
        for item in furniture
        if item.get("room_effect")
    )
    result.update(
        f"behavior:{item['animation']}"
        for item in load(DATA / "catalog" / "behaviors.json")
    )
    performances = load(DATA / "catalog" / "pig_performances.json")
    result.update(f"performance_body:{item['id']}" for item in performances["clips"])
    result.update(f"performance_face:{item['id']}_{part}" for item in performances["faces"] for part in ("left", "right", "mouth"))
    result.update(f"room:{palette}" for palette in ("rose", "mint", "night"))
    result.add("ui:app_icon")
    result.update(f"ui:photo_frame_{frame}" for frame in ("plain", "berry", "star"))
    result.update(
        f"ui:status_{status}"
        for status in ("sleepy", "hungry", "bored", "energetic", "content")
    )
    audio = load(ROOT / "game" / "assets" / "audio" / "audio_manifest.json")
    result.update(f"audio:{item['id']}" for kind in ("music", "sfx") for item in audio[kind])
    return result


def main() -> int:
    errors: list[str] = []
    if not MANIFEST.exists():
        print(f"Final asset validation failed: missing {MANIFEST.relative_to(ROOT)}")
        return 1
    manifest = load(MANIFEST)
    if manifest.get("schema_version") != 1:
        errors.append("final asset manifest schema_version must be 1")
    if not manifest.get("ready"):
        errors.append("final asset manifest is intentionally not ready")
    if not manifest.get("provided_by_user"):
        errors.append("dedicated assets have not yet been marked as user-provided")
    entries = manifest.get("entries", [])
    if not isinstance(entries, list):
        errors.append("final asset manifest entries must be an array")
        entries = []
    covered: set[str] = set()
    cover_counts: Counter[str] = Counter()
    token_paths: dict[str, str] = {}
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            errors.append(f"entry {index} must be an object")
            continue
        resource_path = str(entry.get("path", ""))
        covers = entry.get("covers", [])
        regions = entry.get("regions", {})
        disk_path: Path | None = None
        if not resource_path.startswith(FINAL_PREFIX):
            errors.append(f"entry {index} must use the dedicated final-asset directory: {resource_path!r}")
        elif not resource_path.startswith("res://"):
            errors.append(f"entry {index} has invalid resource path {resource_path!r}")
        else:
            disk_path = ROOT / resource_path.removeprefix("res://")
        if disk_path is not None and not disk_path.exists():
            errors.append(f"entry {index} resource does not exist: {resource_path}")
        elif disk_path is not None and (not disk_path.is_file() or disk_path.stat().st_size <= 0):
            errors.append(f"entry {index} resource is not a non-empty file: {resource_path}")
        elif disk_path is not None:
            actual_hash = hashlib.sha256(disk_path.read_bytes()).hexdigest()
            declared_hash = str(entry.get("sha256", "")).lower()
            if declared_hash != actual_hash:
                errors.append(f"entry {index} has a missing or incorrect SHA-256 for {resource_path}")
        if not isinstance(covers, list) or not covers:
            errors.append(f"entry {index} must cover at least one permanent content token")
        else:
            for raw_token in covers:
                token = str(raw_token)
                covered.add(token)
                cover_counts[token] += 1
                token_paths[token] = resource_path
            visual_tokens = [str(token) for token in covers if not str(token).startswith("audio:")]
            if visual_tokens and disk_path is not None and disk_path.suffix.lower() not in VISUAL_SUFFIXES:
                errors.append(
                    f"entry {index} visual tokens require PNG, WebP, SVG, TRES or RES: {resource_path}"
                )
        if not isinstance(regions, dict):
            errors.append(f"entry {index} regions must be an object when provided")
        else:
            for token, region in regions.items():
                if not isinstance(covers, list) or token not in covers:
                    errors.append(f"entry {index} region {token!r} is not listed in covers")
                if (
                    not isinstance(region, list)
                    or len(region) != 4
                    or not all(isinstance(value, (int, float)) for value in region)
                    or region[0] < 0
                    or region[1] < 0
                    or region[2] <= 0
                    or region[3] <= 0
                ):
                    errors.append(f"entry {index} region {token!r} must be [x, y, width, height] with positive size")
        if not str(entry.get("source", "")).strip():
            errors.append(f"entry {index} is missing source provenance")
        if not str(entry.get("license", "")).strip():
            errors.append(f"entry {index} is missing license or ownership terms")
    expected = expected_coverage()
    missing = sorted(expected - covered)
    unknown = sorted(covered - expected)
    if missing:
        preview = ", ".join(missing[:12])
        errors.append(f"{len(missing)} required coverage tokens are missing ({preview}{'…' if len(missing) > 12 else ''})")
    if unknown:
        errors.append(f"unknown coverage tokens: {unknown}")
    duplicate_tokens = sorted(token for token, count in cover_counts.items() if count != 1)
    if duplicate_tokens:
        errors.append(f"coverage tokens must appear exactly once: {duplicate_tokens}")
    audio = load(ROOT / "game" / "assets" / "audio" / "audio_manifest.json")
    if audio.get("development_placeholder"):
        errors.append("audio manifest still identifies its resources as development placeholders")
    for kind in ("music", "sfx"):
        for item in audio.get(kind, []):
            token = f"audio:{item['id']}"
            if token in token_paths and token_paths[token] != str(item.get("path", "")):
                errors.append(
                    f"{token} final-asset path {token_paths[token]!r} does not match audio_manifest.json {item.get('path')!r}"
                )
    app_icon_path = token_paths.get("ui:app_icon", "")
    if app_icon_path:
        project_config = (ROOT / "project.godot").read_text(encoding="utf-8")
        export_presets = (ROOT / "export_presets.cfg").read_text(encoding="utf-8")
        if f'config/icon="{app_icon_path}"' not in project_config:
            errors.append("ui:app_icon final path is not active in project.godot")
        expected_export_reference = f'application/icon="{app_icon_path}"'
        if export_presets.count(expected_export_reference) != 2:
            errors.append("ui:app_icon final path must be active in both Windows export presets")
    if errors:
        print("Final asset validation failed (expected until dedicated assets are supplied):")
        for error in errors:
            print(f"- {error}")
        return 1
    print(f"Final asset validation passed: {len(expected)} permanent coverage tokens")
    return 0


if __name__ == "__main__":
    sys.exit(main())
