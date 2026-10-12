"""Validate anatomical accessory coverage without approving generated artwork."""

from __future__ import annotations

from typing import Any

from validate_pig_performances import finite_number


ANCHORS = {"head", "eyes"}
RETIRED_REFUNDS = {
    "outfit_cloud_scarf": 260, "outfit_rain_cape": 260,
    "outfit_bow_tie": 260, "outfit_hero_cape": 260,
}


def validate_retired_outfits(records: Any, active_ids: set[str]) -> list[str]:
    if not isinstance(records, list) or not all(isinstance(item, dict) and set(item) == {"id", "refund_points"} and isinstance(item["id"], str) and type(item["refund_points"]) is int for item in records):
        return ["retired outfits require permanent IDs and integer refunds only"]
    refunds = {item["id"]: item["refund_points"] for item in records}
    if len(refunds) != len(records) or refunds != RETIRED_REFUNDS or active_ids.intersection(refunds):
        return ["retired outfits must preserve the four original IDs and purchase-price refunds outside the active catalogue"]
    return []


def validate_outfit_rig(config: Any, clips: dict, outfits: list[dict]) -> list[str]:
    errors = []
    if not isinstance(config, dict) or config.get("schema_version") != 1:
        return ["outfit rig requires schema_version 1"]
    shapes, poses = config.get("shapes"), config.get("poses")
    if not isinstance(shapes, dict) or set(shapes) != {item["shape"] for item in outfits}:
        return ["outfit rig must cover every outfit shape exactly once"]
    if not isinstance(poses, dict) or set(poses) != set(clips):
        return ["outfit rig must cover every physical pose exactly once"]
    for outfit in outfits:
        shape = shapes[outfit["shape"]]
        if not isinstance(shape, dict) or shape.get("anchor") != outfit["anchor"] or outfit["anchor"] not in ANCHORS:
            errors.append(f"{outfit['id']}: anatomical anchor mismatch")
            continue
        for field, minimum, maximum in (("offset", -2.0, 2.0), ("pivot", 0.0, 1.0)):
            value = shape.get(field)
            if not isinstance(value, list) or len(value) != 2 or not all(finite_number(item, minimum, maximum) for item in value):
                errors.append(f"{outfit['id']}: invalid {field}")
        if not finite_number(shape.get("rotation"), -1.0, 1.0):
            errors.append(f"{outfit['id']}: invalid rigid rotation")
        field = "eye_spacing" if shape["anchor"] == "eyes" else "width"
        if not finite_number(shape.get(field), 0.1, 3.0):
            errors.append(f"{outfit['id']}: invalid proportional {field}")
    for body_id, pose in poses.items():
        hidden = pose.get("hidden_anchors") if isinstance(pose, dict) else None
        if not isinstance(hidden, list) or not all(isinstance(item, str) and item in ANCHORS for item in hidden) or len(hidden) != len(set(hidden)):
            errors.append(f"{body_id}: invalid anatomical occlusion policy")
        elif clips[body_id].get("integrated_outfit") and set(hidden) != ANCHORS:
            errors.append(f"{body_id}: integrated costume must suppress overlapping accessories")
    return errors
