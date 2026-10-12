from __future__ import annotations

import json
import hashlib
import re
from pathlib import Path
from urllib.parse import urlparse

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]


def postcard_asset_entries(root: Path = ROOT) -> list[dict]:
    provenance = json.loads((root / "game/assets/final/pighub/source.json").read_text())
    return [
        {
            "path": record["path"],
            "sha256": record["sha256"],
            "dimensions": record["dimensions"],
            "covers": ["postcard:" + record["id"]],
            "origin": "pighub_original",
            "source": "PigHub original " + record["format"] + ": " + record["url"],
            "license": "Project owner authorized use on 2026-10-05 and 2026-10-09; independent rights verification and final release approval remain pending. See LICENSES/PigHub/SOURCE.md.",
        }
        for record in provenance["records"]
    ]


def validate_postcards(cards: list[dict], manifest: dict, root: Path = ROOT) -> list[str]:
    errors: list[str] = []
    previous = 0
    for card in cards:
        points = card.get("points")
        if type(points) is not int or points <= previous:
            errors.append("postcard milestones must be positive, unique ascending integers")
        else:
            previous = points
        if not re.fullmatch(r"postcard_[a-z_]+", str(card.get("id", ""))):
            errors.append("postcard requires a permanent postcard_ ID")
        for field in ("name_key", "body_key"):
            if not isinstance(card.get(field), str) or not card[field].strip():
                errors.append(f"postcard missing localized {field}")
    try:
        provenance = json.loads((root / "game/assets/final/pighub/source.json").read_text())
        expected = postcard_asset_entries(root)
        records = provenance["records"]
    except (OSError, ValueError, KeyError, TypeError) as exc:
        return errors + [f"PigHub provenance cannot be read: {exc}"]
    flags = {"schema_version": 1, "source_page": "https://pighub.top/", "copied_unchanged": True,
             "ai_generated": False, "user_created_originals": False, "project_owner_authorized": True,
             "independent_rights_verified": False, "release_approved": False}
    if any(type(provenance.get(key)) is not type(value) or provenance.get(key) != value for key, value in flags.items()):
        errors.append("PigHub provenance must honestly distinguish authorized unchanged originals from generated/release-approved artwork")
    ids = [record.get("id") for record in records]
    if set(ids) != {card["id"] for card in cards} or len(ids) != len(set(ids)):
        errors.append("PigHub original IDs must cover each postcard exactly once")
    actual = [entry for entry in manifest.get("entries", []) if entry.get("origin") == "pighub_original"]
    if actual != expected:
        errors.append("PigHub postcard manifest must match original provenance exactly")
    for record in records:
        source = urlparse(record["url"])
        path = record["path"]
        if source.scheme != "https" or source.netloc != "pighub.top" or not source.path.startswith("/images/"):
            errors.append("PigHub original URL must come from the observed gallery")
        suffix = {"JPEG": ".jpg", "WEBP": ".webp"}.get(record.get("format"))
        if suffix is None or path != f"res://game/assets/final/pighub/{record['id']}{suffix}":
            errors.append("PigHub postcard path must match its permanent ID")
            continue
        disk = root / path.removeprefix("res://")
        try:
            if disk.is_symlink() or hashlib.sha256(disk.read_bytes()).hexdigest() != record["sha256"]:
                errors.append(f"PigHub original bytes changed: {path}")
            with Image.open(disk) as image:
                image.load()
                if image.format != record["format"] or list(image.size) != record["dimensions"]:
                    errors.append(f"PigHub original dimensions changed: {path}")
        except (OSError, ValueError) as exc:
            errors.append(f"PigHub original cannot be loaded: {path}: {exc}")
    if not (root / "LICENSES/PigHub/SOURCE.md").is_file():
        errors.append("PigHub source authorization record is missing")
    return errors
