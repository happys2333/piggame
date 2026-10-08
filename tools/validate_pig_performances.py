"""Validate purely cosmetic pig performances, fixed IDs, references and rig anchors."""

from __future__ import annotations

import math
from typing import Any


COUNTS = {"faces":9, "clips":12, "poses":9, "states":6, "forms":2, "outfit_actions":12}
FIELDS = {
    "faces":{"id", "name_key"},
    "clips":{"id", "sheet", "row", "snouts", "integrated_outfit"},
    "poses":{"id", "name_key", "clip_id", "duration_seconds"},
    "forms":{"id", "name_key", "clip_id", "duration_seconds"},
    "states":{"id", "name_key", "line_key", "pose_ids", "form_id", "face_ids", "duration_seconds"},
    "outfit_actions":{"id", "outfit_id", "pose_id", "face_id", "chance", "duration_seconds"},
}


def finite_number(value: Any, minimum: float, maximum: float) -> bool:
    return type(value) in (int, float) and math.isfinite(value) and minimum <= value <= maximum


def validate_performances(config: Any, outfit_ids: set[str], errors: list[str]) -> None:
    if not isinstance(config, dict) or set(config) != {*COUNTS, "base", "settings"}:
        errors.append("pig performances need the six cosmetic catalogs, one base and settings")
        return
    indexes = {}
    seen = set()
    for kind, count in COUNTS.items():
        items = config.get(kind)
        if not isinstance(items, list) or len(items) != count or not all(isinstance(item, dict) for item in items):
            errors.append(f"pig performances {kind} requires {count} objects")
            return
        indexes[kind] = {item.get("id"):item for item in items if isinstance(item.get("id"), str)}
        for item in items:
            identifier = item.get("id")
            if not isinstance(identifier, str) or not identifier or identifier in seen:
                errors.append(f"invalid/duplicate permanent performance ID {identifier!r}")
            seen.add(str(identifier))
            if set(item) - FIELDS[kind]:
                errors.append(f"{identifier}: performance fields must remain cosmetic")
            if kind not in ("clips", "outfit_actions") and not isinstance(item.get("name_key"), str):
                errors.append(f"{identifier}: missing localized performance name")
            if kind in ("poses", "forms", "states", "outfit_actions") and not finite_number(item.get("duration_seconds"), 1, 120):
                errors.append(f"{identifier}: performance duration must be 1..120 seconds")
    expected_faces = {f"face_{name}" for name in ("dot", "squint", "deadpan", "tears", "quake", "sly", "glare", "sleepy", "shock")}
    expected_poses = {f"pose_{name}" for name in ("prone", "flat", "head_hold", "kneel", "corner", "arms", "upside", "peek", "crawl")}
    if set(indexes["faces"]) != expected_faces or set(indexes["poses"]) != expected_poses:
        errors.append("pig face/pose IDs must remain permanent")
    if set(indexes["states"]) != {f"meme_{name}" for name in ("silly", "worker", "slack", "rage", "wronged", "ruler")} or set(indexes["forms"]) != {"form_worker", "form_ruler"}:
        errors.append("pig state/form IDs must remain permanent")
    if set(indexes["clips"]) != {f"body_{name}" for name in ("base", "prone", "flat", "head_hold", "kneel", "corner", "arms", "upside", "peek", "crawl", "worker", "ruler")} or config.get("base") != "body_base":
        errors.append("pig performances require one shared base and permanent body clips")
    cells = set()
    for clip in config["clips"]:
        if type(clip.get("sheet")) is not int or clip["sheet"] not in (0, 1) or type(clip.get("row")) is not int or clip["row"] not in range(6):
            errors.append(f"{clip['id']}: invalid atlas cell")
        else:
            cells.add((clip["sheet"], clip["row"]))
        anchors = clip.get("snouts")
        if not isinstance(anchors, list) or len(anchors) != 4 or any(not isinstance(anchor, list) or len(anchor) != 2 or not all(finite_number(value, 0, 256) for value in anchor) for anchor in anchors):
            errors.append(f"{clip['id']}: four head anchors must stay in the 256-pixel canvas")
        if "integrated_outfit" in clip and type(clip["integrated_outfit"]) is not bool:
            errors.append(f"{clip['id']}: integrated outfit flag must be boolean")
    if len(cells) != 12:
        errors.append("pig clips must occupy twelve unique four-frame rows")
    for kind in ("poses", "forms"):
        for entry in config[kind]:
            if entry.get("clip_id") not in indexes["clips"]:
                errors.append(f"{entry['id']}: unknown performance clip")
    for state in config["states"]:
        faces = state.get("face_ids")
        poses = state.get("pose_ids", [])
        form = state.get("form_id", "")
        if not isinstance(faces, list) or not faces or any(face not in indexes["faces"] for face in faces):
            errors.append(f"{state['id']}: unknown/empty face sequence")
        if not isinstance(poses, list) or any(pose not in indexes["poses"] for pose in poses) or (form and form not in indexes["forms"]) or (not form and not poses):
            errors.append(f"{state['id']}: unknown/empty pose or form sequence")
        if not isinstance(state.get("line_key"), str) or not state["line_key"]:
            errors.append(f"{state['id']}: missing localized meme line")
    action_outfits = []
    for action in config["outfit_actions"]:
        action_outfits.append(action.get("outfit_id"))
        if action.get("outfit_id") not in outfit_ids or action.get("pose_id") not in indexes["poses"] or action.get("face_id") not in indexes["faces"] or not finite_number(action.get("chance"), 0.01, 1):
            errors.append(f"{action['id']}: invalid outfit combination/probability")
    if set(action_outfits) != outfit_ids or len(action_outfits) != len(set(action_outfits)):
        errors.append("every outfit must have one cosmetic action")
    if config.get("settings") != {"auto_interval_seconds":{"frequent":60, "normal":120, "rare":240}, "phase_seconds":8}:
        errors.append("performance pacing settings must retain low-interruption intervals")
