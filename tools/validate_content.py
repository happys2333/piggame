#!/usr/bin/env python3
"""Validate permanent IDs, content budgets, references, reachability and i18n."""

from __future__ import annotations

import csv
import hashlib
import json
import os
import re
import sys
import wave
from collections import Counter
from pathlib import Path
from typing import Any
from validate_pig_performances import validate_performances

DEFAULT_ROOT = Path(__file__).resolve().parents[1]
ROOT = Path(os.environ.get("PIGGAME_VALIDATION_ROOT", str(DEFAULT_ROOT))).resolve()
DATA = ROOT / "game" / "data"
AUDIO = ROOT / "game" / "assets" / "audio"
PATHS = {
    "behaviors": DATA / "catalog" / "behaviors.json",
    "furniture": DATA / "furniture" / "furniture.json",
    "snacks": DATA / "catalog" / "snacks.json",
    "outfits": DATA / "catalog" / "outfits.json",
    "expressions": DATA / "expressions" / "expressions.json",
    "events": DATA / "events" / "events.json",
    "achievements": DATA / "catalog" / "achievements.json",
    "life_plans": DATA / "catalog" / "life_plans.json",
    "personalities": DATA / "catalog" / "personalities.json",
}
EXPECTED = {
    "behaviors": 36,
    "furniture": 32,
    "snacks": 10,
    "outfits": 12,
    "expressions": 48,
    "events": 24,
    "achievements": 24,
    "life_plans": 6,
    "personalities": 5,
}
AREA_UNLOCK_LEVELS = {"sleep": 1, "snack": 3, "activity": 4, "window": 6}
AREAS = set(AREA_UNLOCK_LEVELS)
SLOTS = {"large", "small", "wall"}
FURNITURE_CATEGORIES = {"functional", "atmosphere", "decoration"}
ROOM_EFFECTS = {"sleep_glow", "oven_warmth", "rainy_window", "breeze", "window_glow"}
TIME_RULES = {"any", "morning", "day", "evening", "night"}
EVENT_ANCHORS = {"center", *AREAS}
EVENT_CATEGORIES = {"food", "sleep", "sport", "hobby", "weather", "chapter"}
EVENT_STEP_FIELDS = {"animation", "duration", "camera_shake"}
EXPRESSION_CATEGORIES = {"happy", "sleepy", "hungry", "wronged", "proud", "shocked"}
INTERACTION_CONDITIONS = {"pet", "poke", "feed"}
ACHIEVEMENT_LIMITS = {
    "familiarity": 10,
    "expressions": 48,
    "events": 24,
    "furniture": 32,
    "outfits": 12,
}
FORBIDDEN_CONTENT_FIELDS = {
    "streak",
    "login_streak",
    "daily_login",
    "login_reward",
    "consecutive_login",
    "expires_at",
    "expiry",
    "expiry_unix",
    "start_at",
    "end_at",
    "limited_time",
    "missable",
    "premium_currency",
    "iap",
    "ad_reward",
    "rewarded_ad",
    "energy_cost",
    "lives_cost",
}
FORBIDDEN_RUNTIME_APIS = {
    "HTTPRequest": re.compile(r"\bHTTPRequest\b"),
    "HTTPClient": re.compile(r"\bHTTPClient\b"),
    "PacketPeerUDP": re.compile(r"\bPacketPeerUDP\b"),
    "StreamPeerTCP": re.compile(r"\bStreamPeerTCP\b"),
    "TCPServer": re.compile(r"\bTCPServer\b"),
    "WebSocketPeer": re.compile(r"\bWebSocketPeer\b"),
    "WebSocketMultiplayerPeer": re.compile(r"\bWebSocketMultiplayerPeer\b"),
    "WebRTCPeerConnection": re.compile(r"\bWebRTCPeerConnection\b"),
    "WebRTCMultiplayerPeer": re.compile(r"\bWebRTCMultiplayerPeer\b"),
    "WebRTCDataChannel": re.compile(r"\bWebRTCDataChannel\b"),
    "ENetMultiplayerPeer": re.compile(r"\bENetMultiplayerPeer\b"),
    "MultiplayerAPI": re.compile(r"\bMultiplayerAPI\b"),
    "UPNP": re.compile(r"\bUPNP\b"),
    "IP.resolve_hostname": re.compile(r"\bIP\s*\.\s*resolve_hostname(?:_addresses)?\s*\("),
    "OS.execute": re.compile(r"\bOS\s*\.\s*execute\s*\("),
    "OS.execute_with_pipe": re.compile(r"\bOS\s*\.\s*execute_with_pipe\s*\("),
    "OS.create_process": re.compile(r"\bOS\s*\.\s*create_process\s*\("),
    "@rpc": re.compile(r"@rpc\b"),
    "rpc_id": re.compile(r"\brpc_id\s*\("),
    ".rpc": re.compile(r"\.rpc\s*\("),
}
FORBIDDEN_MOUSE_POLLING_APIS = {
    "DisplayServer.mouse_get_position": re.compile(r"\bDisplayServer\s*\.\s*mouse_get_position\s*\("),
    "Viewport.get_mouse_position": re.compile(r"\bget_viewport\s*\(\s*\)\s*\.\s*get_mouse_position\s*\("),
    "CanvasItem.get_global_mouse_position": re.compile(r"\bget_global_mouse_position\s*\("),
    "Input.get_last_mouse_velocity": re.compile(r"\bInput\s*\.\s*get_last_mouse_velocity\s*\("),
    "Input.get_mouse_button_mask": re.compile(r"\bInput\s*\.\s*get_mouse_button_mask\s*\("),
}
DIRECT_SCENE_TREE_QUIT_PATTERN = re.compile(
    r"\bget_tree\s*\(\s*\)\s*\.\s*quit\s*\("
)
DIRECT_VISIBILITY_INVERSION_PATTERNS = (
    re.compile(
        r"(?P<target>(?:[$%])?[A-Za-z_][A-Za-z0-9_/$]*"
        r"(?:\.[A-Za-z_][A-Za-z0-9_]*)*)\s*\.\s*visible\s*=\s*"
        r"(?:not\s+|!\s*)(?P=target)\s*\.\s*visible\b"
    ),
    re.compile(r"(?<!\.)\bvisible\s*=\s*(?:not\s+|!\s*)visible\b"),
)
LOOPED_TWEEN_ASSIGNMENT_PATTERN = re.compile(
    r"\b(?:var\s+)?(?P<name>[A-Za-z_][A-Za-z0-9_]*)"
    r"(?:\s*:\s*Tween)?\s*(?::=|=)\s*create_tween\s*\(\s*\)"
    r"\s*\.\s*set_loops\s*\("
)
LOOPED_TWEEN_CALL_PATTERN = re.compile(
    r"\b(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*\.\s*set_loops\s*\("
)
PERIODIC_OPACITY_ASSIGNMENT_PATTERN = re.compile(
    r"(?:self_)?modulate(?:\s*\.\s*a)?\s*=\s*[^\n]*(?:\bsin|\bcos)\s*\("
)
EXTERNAL_INTEGRATION_SUFFIXES = {
    ".dll",
    ".dylib",
    ".exe",
    ".gdextension",
    ".gdnlib",
    ".so",
    ".wasm",
}
EXTERNAL_INTEGRATION_IGNORED_TOP_LEVEL = {
    ".git",
    ".godot",
    "build",
    "docs",
    "tests",
    "tools",
}
STORE_COPY_PATH = ROOT / "docs" / "release" / "steam-store-copy.md"
STORE_COPY_SECTIONS = ("## 商店短描述", "## 商店长描述", "## Demo 对外承诺")
STORE_COPY_LOCALES = ("### 简体中文", "### 繁體中文", "### English")
STORE_COPY_PROMISES = {
    "## 商店长描述": {
        "### 简体中文": (
            "32 件家具", "48 个表情", "24 段小剧场", "一次买断", "无广告", "无内购",
            "无签到", "不会永久错过", "普通小窗降级",
        ),
        "### 繁體中文": (
            "32 件傢俱", "48 個表情", "24 段小劇場", "一次買斷", "無廣告", "無內購",
            "無簽到", "不會永久錯過", "普通小窗降級",
        ),
        "### English": (
            "32 pieces of furniture", "48 expressions", "24 memories", "buy-to-play", "no ads",
            "no in-app purchases", "no streaks", "never permanently missed", "normal-window fallback",
        ),
    },
    "## Demo 对外承诺": {
        "### 简体中文": (
            "20–40 分钟", "1 个开放区域", "6 件家具", "8 个表情", "4 段小剧场",
            "底部与左侧", "不反复弹出购买提示",
        ),
        "### 繁體中文": (
            "20–40 分鐘", "1 個開放區域", "6 件傢俱", "8 個表情", "4 段小劇場",
            "底部與左側", "不反覆彈出購買提示",
        ),
        "### English": (
            "20–40 minute", "1 open room area", "6 pieces of furniture", "8 expressions", "4 memories",
            "bottom and left docking", "without repeated purchase prompts",
        ),
    },
}
NOTO_COMMIT = "f2a4f72bffe0212c72949a22698be235269bfab5"
NOTO_UPSTREAM_SHA256 = "1352019e5be1dff3308f3bc6c9fb2d35b3f8bed971ef43c5c2aa96e59b7481c3"
NOTO_ARCHIVED_SHA256 = "63163d0374eb36b54081cda18063664e47efcfc186137a5d5eb786edbfd82b3b"
NOTO_LICENSE_SHA256 = "5c2258478882d24fecd707c685e480c5ddd352ab4ab984bc8ee5919d04f42048"
NOTO_ARCHIVE_PATH = ROOT / "game" / "assets" / "upstream" / "noto" / "emoji_u1f416.svg"
NOTO_LICENSE_PATH = ROOT / "LICENSES" / "NotoEmoji" / "LICENSE.txt"
NOTO_SOURCE_RECORD_PATH = ROOT / "LICENSES" / "NotoEmoji" / "SOURCE.md"
NOTO_NOTICE_PATH = ROOT / "docs" / "release" / "third-party-notices.md"
PRIVACY_NOTICE_PATH = ROOT / "docs" / "release" / "privacy.md"


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_noto_archive(errors: list[str]) -> None:
    try:
        archive = NOTO_ARCHIVE_PATH.read_bytes()
    except OSError as exc:
        errors.append(f"{NOTO_ARCHIVE_PATH.relative_to(ROOT)}: unreadable Noto archive ({exc})")
    else:
        archived_digest = sha256_bytes(archive)
        if archived_digest != NOTO_ARCHIVED_SHA256:
            errors.append(
                f"Noto archived SVG SHA-256 mismatch: expected {NOTO_ARCHIVED_SHA256}, got {archived_digest}"
            )
        if not archive.endswith(b"\n") or sha256_bytes(archive[:-1]) != NOTO_UPSTREAM_SHA256:
            errors.append(
                "Noto archived SVG must differ from the pinned upstream bytes only by one final newline"
            )

    try:
        license_data = NOTO_LICENSE_PATH.read_bytes()
    except OSError as exc:
        errors.append(f"{NOTO_LICENSE_PATH.relative_to(ROOT)}: unreadable Apache license ({exc})")
    else:
        license_digest = sha256_bytes(license_data)
        if license_digest != NOTO_LICENSE_SHA256:
            errors.append(
                f"Noto Apache license SHA-256 mismatch: expected {NOTO_LICENSE_SHA256}, got {license_digest}"
            )

    source_markers = (
        "googlefonts/noto-emoji",
        "svg/emoji_u1f416.svg",
        NOTO_COMMIT,
        f"https://github.com/googlefonts/noto-emoji/blob/{NOTO_COMMIT}/svg/emoji_u1f416.svg",
        f"Upstream SHA-256: `{NOTO_UPSTREAM_SHA256}`",
        f"Archived SHA-256: `{NOTO_ARCHIVED_SHA256}`",
        "only archival-file byte difference",
        "do not imply endorsement by or affiliation with Google or Noto",
    )
    notice_markers = (
        "## 简体中文",
        "## 繁體中文",
        "## English",
        NOTO_COMMIT,
        "Apache License 2.0",
        "LICENSES/NotoEmoji/",
        "本项目不受 Google 赞助、认可，也不隶属于 Google",
        "本專案不受 Google 贊助、認可，也不隸屬於 Google",
        "not sponsored, endorsed by, or affiliated with Google",
        "legacy `assest/` directory",
    )
    privacy_markers = (
        "## 简体中文",
        "## 繁體中文",
        "## English",
        "不要求账号",
        "不要求帳號",
        "requires no account",
        "不会自动上传",
        "不會自動上傳",
        "never uploaded automatically",
        "两个安全备份",
        "兩份安全備份",
        "two safety backups",
        "正式版和 Demo 使用互相隔离的云路径",
        "正式版與 Demo 使用互相隔離的雲端路徑",
        "full game and Demo use isolated cloud paths",
    )
    for record_path, label, markers in (
        (NOTO_SOURCE_RECORD_PATH, "Noto source record", source_markers),
        (NOTO_NOTICE_PATH, "third-party notice", notice_markers),
        (PRIVACY_NOTICE_PATH, "privacy notice", privacy_markers),
    ):
        try:
            source = record_path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            errors.append(f"{record_path.relative_to(ROOT)}: unreadable {label} ({exc})")
            continue
        for marker in markers:
            if marker not in source:
                errors.append(f"{label} is missing required marker {marker!r}")


def validate_store_copy(errors: list[str]) -> None:
    try:
        source = STORE_COPY_PATH.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as exc:
        errors.append(f"{STORE_COPY_PATH.relative_to(ROOT)}: unreadable Steam store copy ({exc})")
        return

    for marker in ("完成度明确的 1.0 正式版", "不启用 Steam Early Access"):
        if marker not in source:
            errors.append(f"Steam store release policy is missing required marker {marker!r}")

    section_matches = list(re.finditer(r"^## .+$", source, re.MULTILINE))
    section_positions = {match.group(0): index for index, match in enumerate(section_matches)}
    for section_heading in STORE_COPY_SECTIONS:
        if sum(match.group(0) == section_heading for match in section_matches) != 1:
            errors.append(f"Steam store copy must contain exactly one {section_heading} section")
            continue
        section_index = section_positions[section_heading]
        start = section_matches[section_index].end()
        end = section_matches[section_index + 1].start() if section_index + 1 < len(section_matches) else len(source)
        section = source[start:end]
        locale_matches = list(re.finditer(r"^### .+$", section, re.MULTILINE))
        locale_positions = {match.group(0): index for index, match in enumerate(locale_matches)}
        for locale_heading in STORE_COPY_LOCALES:
            if sum(match.group(0) == locale_heading for match in locale_matches) != 1:
                errors.append(
                    f"Steam store {section_heading.removeprefix('## ')} must contain exactly one "
                    f"{locale_heading} subsection"
                )
                continue
            locale_index = locale_positions[locale_heading]
            body_start = locale_matches[locale_index].end()
            body_end = locale_matches[locale_index + 1].start() if locale_index + 1 < len(locale_matches) else len(section)
            body = section[body_start:body_end].strip()
            if len(body) < 80:
                errors.append(
                    f"Steam store {section_heading.removeprefix('## ')} {locale_heading.removeprefix('### ')} "
                    "copy is incomplete"
                )
            for marker in STORE_COPY_PROMISES.get(section_heading, {}).get(locale_heading, ()):
                if marker not in body:
                    errors.append(
                        f"Steam store {section_heading.removeprefix('## ')} "
                        f"{locale_heading.removeprefix('### ')} is missing promise marker {marker!r}"
                    )


def load(path: Path) -> list[dict[str, Any]]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, list) or not all(isinstance(item, dict) for item in value):
        raise ValueError(f"{path} must contain an array of objects")
    return value


def collect_keys(value: Any, output: set[str]) -> None:
    if isinstance(value, dict):
        for key, item in value.items():
            if key.endswith("_key") and isinstance(item, str) and item:
                output.add(item)
            elif key == "variants" and isinstance(item, list):
                output.update(str(entry) for entry in item)
            else:
                collect_keys(item, output)
    elif isinstance(value, list):
        for item in value:
            collect_keys(item, output)


def find_forbidden_content_fields(value: Any, path: str, errors: list[str]) -> None:
    if isinstance(value, dict):
        for key, item in value.items():
            normalized = re.sub(r"(?<!^)(?=[A-Z])", "_", str(key).strip()).lower()
            normalized = re.sub(r"[-\s]+", "_", normalized)
            child_path = f"{path}.{key}" if path else str(key)
            if normalized in FORBIDDEN_CONTENT_FIELDS:
                errors.append(
                    f"{child_path}: forbidden product-boundary field {key!r}; "
                    "the game has no streaks, login rewards, missable events, ads, IAP, or paid energy"
                )
            find_forbidden_content_fields(item, child_path, errors)
    elif isinstance(value, list):
        for index, item in enumerate(value):
            find_forbidden_content_fields(item, f"{path}[{index}]", errors)


def validate_life_plans(plans: list[dict], indexes: dict[str, dict], errors: list[str]) -> None:
    animations = {item.get("animation") for item in indexes["behaviors"].values()}
    tags = {tag for item in indexes["behaviors"].values() for tag in item.get("tags", [])}
    known_ids = {item_id for catalog in indexes.values() for item_id in catalog}
    for plan in plans:
        label = str(plan.get("id", "?"))
        level = plan.get("min_level")
        if type(level) is not int or not 2 <= level <= 10:
            errors.append(f"{label}: life-plan min_level must be an integer from 2 to 10")
        if plan.get("animation") not in animations:
            errors.append(f"{label}: life-plan animation must reference an existing action")
        for field, allowed in (("behavior_tags", tags), ("inspiration_furniture", set(indexes["furniture"]))):
            values = plan.get(field)
            if not isinstance(values, list) or not values or any(not isinstance(value, str) or value not in allowed for value in values) or len(set(values)) != len(values):
                errors.append(f"{label}: {field} must contain unique known IDs or tags")
        entries = plan.get("entries")
        if not isinstance(entries, list) or len(entries) != 3:
            errors.append(f"{label}: life plans require three diary entries")
            continue
        previous_seconds = 0
        for entry in entries:
            if not isinstance(entry, dict):
                errors.append(f"{label}: diary entries must be objects")
                continue
            entry_id = entry.get("id")
            if not isinstance(entry_id, str) or not entry_id or entry_id in known_ids:
                errors.append(f"{label}: diary entry IDs must be permanent and globally unique")
            else:
                known_ids.add(entry_id)
            seconds = entry.get("seconds")
            if type(seconds) is not int or not previous_seconds < seconds <= 86400:
                errors.append(f"{label}: diary thresholds must strictly increase within one day")
            else:
                previous_seconds = seconds
            for field in ("title_key", "text_key"):
                if not isinstance(entry.get(field), str) or not entry[field]:
                    errors.append(f"{label}: diary entry is missing {field}")
        for field in ("name_key", "description_key"):
            if not isinstance(plan.get(field), str) or not plan[field]:
                errors.append(f"{label}: life plan is missing {field}")
    demo_plan = indexes["life_plans"].get("plan_pillow_notes", {})
    if not demo_plan or any(item not in {"furn_pillow_cloud", "furn_nightlight_moon", "furn_blanket_roll", "furn_bed_basic", "furn_bookshelf_low", "furn_clock_sleepy"} for item in demo_plan.get("inspiration_furniture", [])):
        errors.append("Demo life plan and its inspiration furniture must remain available")


def validate_personalities(profiles: list[dict], expressions: dict, errors: list[str]) -> None:
    expected = {"personality_lively", "personality_tsundere", "personality_lazy", "personality_shy", "personality_foodie"}
    if {item.get("id") for item in profiles} != expected or len(profiles) != len(expected):
        errors.append("personalities must keep five unique permanent IDs")
    for profile in profiles:
        if set(profile) != {"id", "name_key", "description_key", "pet", "poke"}:
            errors.append(f"{profile.get('id')}: personality fields must remain presentation-only")
        for key in ("name_key", "description_key"):
            if not isinstance(profile.get(key), str) or not profile[key]:
                errors.append(f"{profile.get('id')}: missing personality {key}")
        for kind in ("pet", "poke"):
            response = profile.get(kind)
            if not isinstance(response, dict) or set(response) != {"category", "expression_id", "toast_key"}:
                errors.append(f"{profile.get('id')}: invalid personality {kind} reaction fields")
                continue
            expression = expressions.get(response.get("expression_id"), {})
            if not expression or expression.get("category") != response.get("category"):
                errors.append(f"{profile.get('id')}: personality {kind} expression/category mismatch")
            if not isinstance(response.get("toast_key"), str) or not response["toast_key"]:
                errors.append(f"{profile.get('id')}: missing personality {kind} toast_key")


def validate_desktop_companion(config: Any, behaviors: list[dict], errors: list[str]) -> None:
    expected = {
        "work_seconds": 1500,
        "rest_seconds": 300,
        "explicit_feedback_milliseconds": 1200,
        "presentation_hold_seconds": {"frequent": 0, "normal": 45, "rare": 120},
        "work_animation": "read",
        "rest_animation": "yoga",
    }
    if not isinstance(config, dict) or config != expected:
        errors.append("desktop companion configuration must preserve the 25/5 timer and interruption limits")
        return
    for field in ("work_seconds", "rest_seconds", "explicit_feedback_milliseconds"):
        if type(config[field]) is not int:
            errors.append(f"desktop companion {field} must be an integer")
    if any(type(value) is not int for value in config["presentation_hold_seconds"].values()):
        errors.append("desktop companion frequency limits must be integers")
    animations = {item.get("animation") for item in behaviors}
    for field in ("work_animation", "rest_animation"):
        if config[field] not in animations:
            errors.append(f"desktop companion {field} references missing art")


def main() -> int:
    errors: list[str] = []
    catalogs = {name: load(path) for name, path in PATHS.items()}
    validate_noto_archive(errors)
    validate_store_copy(errors)
    indexes = {name: {item.get("id"): item for item in items} for name, items in catalogs.items()}
    event_ids = set(indexes["events"])
    furniture_ids = set(indexes["furniture"])
    validate_life_plans(catalogs["life_plans"], indexes, errors)
    validate_personalities(catalogs["personalities"], indexes["expressions"], errors)
    performance_config = json.loads((DATA / "catalog" / "pig_performances.json").read_text(encoding="utf-8"))
    validate_performances(performance_config, set(indexes["outfits"]), errors)
    companion_config = DATA / "catalog" / "desktop_companion.json"
    try:
        validate_desktop_companion(json.loads(companion_config.read_text(encoding="utf-8")), catalogs["behaviors"], errors)
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"desktop companion configuration cannot be read: {exc}")

    content_json_paths = set(DATA.rglob("*.json"))
    content_json_paths.add(AUDIO / "audio_manifest.json")
    for content_path in sorted(content_json_paths):
        if not content_path.exists():
            continue
        try:
            value = json.loads(content_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            errors.append(f"{content_path.relative_to(ROOT)}: unreadable content JSON ({exc})")
            continue
        find_forbidden_content_fields(value, str(content_path.relative_to(ROOT)), errors)

    for name, count in EXPECTED.items():
        if len(catalogs[name]) != count:
            errors.append(f"{name}: expected {count}, got {len(catalogs[name])}")

    ids = [str(item.get("id", "")) for items in catalogs.values() for item in items]
    for item_id, count in Counter(ids).items():
        if not item_id:
            errors.append("empty permanent content ID")
        elif count != 1:
            errors.append(f"duplicate permanent content ID: {item_id}")

    functional = 0
    decoration_reactions = 0
    room_effects: list[str] = []
    for item in catalogs["furniture"]:
        item_id = str(item.get("id", ""))
        area = str(item.get("area", ""))
        slot = str(item.get("slot", ""))
        category = str(item.get("category", ""))
        if area not in AREAS:
            errors.append(f"{item_id}: invalid furniture area {area!r}")
        if slot not in SLOTS:
            errors.append(f"{item_id}: invalid furniture slot {slot!r}")
        if category not in FURNITURE_CATEGORIES:
            errors.append(f"{item_id}: invalid furniture category {category!r}")
        room_effect = str(item.get("room_effect", ""))
        reaction_key = str(item.get("reaction_key", ""))
        if category == "atmosphere" and room_effect not in ROOM_EFFECTS:
            errors.append(f"{item_id}: atmosphere furniture must define a supported room_effect")
        elif category != "atmosphere" and room_effect:
            errors.append(f"{item_id}: only atmosphere furniture may define room_effect")
        if room_effect:
            room_effects.append(room_effect)
        if reaction_key:
            if category != "decoration":
                errors.append(f"{item_id}: only decoration furniture may define reaction_key")
            else:
                decoration_reactions += 1
        if not isinstance(item.get("price"), int) or int(item.get("price", -1)) < 0:
            errors.append(f"{item_id}: furniture price must be a non-negative integer")
        else:
            price = int(item["price"])
            if category == "functional" and item_id != "furn_bed_basic" and not 100 <= price <= 320:
                errors.append(f"{item_id}: functional furniture price must remain within 100–320 points")
            if category == "decoration" and not 60 <= price <= 180:
                errors.append(f"{item_id}: decoration furniture price must remain within 60–180 points")
            if category == "atmosphere" and not 60 <= price <= 240:
                errors.append(f"{item_id}: atmosphere furniture price must remain within 60–240 points")
        if not isinstance(item.get("min_level"), int) or not 1 <= int(item.get("min_level", 0)) <= 10:
            errors.append(f"{item_id}: furniture min_level must be 1–10")
        elif area in AREA_UNLOCK_LEVELS and int(item["min_level"]) < AREA_UNLOCK_LEVELS[area]:
            errors.append(
                f"{item_id}: furniture cannot unlock before its {area} area at "
                f"familiarity level {AREA_UNLOCK_LEVELS[area]}"
            )
        behavior_id = item.get("behavior_id", "")
        if behavior_id:
            functional += 1
            if behavior_id not in indexes["behaviors"]:
                errors.append(f"{item['id']}: missing behavior {behavior_id}")
            else:
                required = str(indexes["behaviors"][behavior_id].get("required_furniture", ""))
                if required != item_id:
                    errors.append(f"{item_id}: behavior {behavior_id} must require the same furniture ID")
    if functional < 16:
        errors.append(f"functional furniture: expected at least 16, got {functional}")
    if decoration_reactions < 1:
        errors.append("at least one decoration furniture item must provide a short reaction")
    if Counter(room_effects) != Counter({effect: 1 for effect in ROOM_EFFECTS}):
        errors.append(
            "atmosphere furniture must route each permanent room effect exactly once: "
            f"{dict(Counter(room_effects))}"
        )
    if {str(item.get("area", "")) for item in catalogs["furniture"]} != AREAS:
        errors.append("furniture catalog must cover exactly the four launch room areas")

    behavior_animation_ids = {str(item.get("animation", "")) for item in catalogs["behaviors"]}
    for behavior in catalogs["behaviors"]:
        behavior_id = str(behavior.get("id", ""))
        if str(behavior.get("time", "")) not in TIME_RULES:
            errors.append(f"{behavior_id}: invalid behavior time rule")
        if not isinstance(behavior.get("desktop_allowed"), bool):
            errors.append(f"{behavior_id}: desktop_allowed must be boolean")
        if not isinstance(behavior.get("tags"), list) or not behavior.get("tags"):
            errors.append(f"{behavior_id}: behavior tags must be a non-empty array")
        if not isinstance(behavior.get("duration_seconds"), (int, float)) or float(behavior.get("duration_seconds", 0)) <= 0:
            errors.append(f"{behavior_id}: behavior duration must be positive")
        points_min = behavior.get("points_min")
        points_max = behavior.get("points_max")
        if not isinstance(points_min, int) or not isinstance(points_max, int) or not 2 <= points_min <= points_max <= 5:
            errors.append(f"{behavior_id}: ordinary behavior reward must remain within 2–5 points")
        required = str(behavior.get("required_furniture", ""))
        if required and required not in furniture_ids:
            errors.append(f"{behavior_id}: missing required furniture {required}")

    focus_behaviors = [
        behavior
        for behavior in catalogs["behaviors"]
        if behavior.get("desktop_allowed") is True
        and behavior.get("time") == "any"
        and not str(behavior.get("required_furniture", ""))
        and isinstance(behavior.get("tags"), list)
        and "quiet" in behavior["tags"]
    ]
    if len(focus_behaviors) < 2:
        errors.append(
            "desktop focus mode must retain at least two always-available quiet behaviors"
        )
    if not any("sleep" in behavior["tags"] for behavior in focus_behaviors):
        errors.append(
            "desktop focus mode must retain at least one always-available sleep behavior"
        )

    for snack in catalogs["snacks"]:
        snack_id = str(snack.get("id", ""))
        if not isinstance(snack.get("price"), int) or not 10 <= int(snack.get("price", 0)) <= 25:
            errors.append(f"{snack_id}: snack price must remain within 10–25 points")
        if not isinstance(snack.get("min_level"), int) or not 1 <= int(snack.get("min_level", 0)) <= 10:
            errors.append(f"{snack_id}: snack min_level must be 1–10")

    for outfit in catalogs["outfits"]:
        outfit_id = str(outfit.get("id", ""))
        if not isinstance(outfit.get("price"), int) or not 120 <= int(outfit.get("price", 0)) <= 260:
            errors.append(f"{outfit_id}: outfit price must remain within 120–260 points")
        if not str(outfit.get("anchor", "")) or not str(outfit.get("shape", "")):
            errors.append(f"{outfit_id}: outfit must define an anchor and replaceable shape")

    expression_rewards: list[str] = []
    photo_ids: list[str] = []
    variant_keys: list[str] = []
    camera_shake_steps = 0
    for event in catalogs["events"]:
        event_id = str(event.get("id", ""))
        if not str(event.get("title_key", "")) or not str(event.get("summary_key", "")):
            errors.append(f"{event_id}: event must define title_key and summary_key")
        if str(event.get("category", "")) not in EVENT_CATEGORIES:
            errors.append(f"{event_id}: invalid event category")
        if str(event.get("anchor", "")) not in EVENT_ANCHORS:
            errors.append(f"{event_id}: invalid event anchor")
        if str(event.get("time", "")) not in TIME_RULES:
            errors.append(f"{event_id}: invalid event time rule")
        if not isinstance(event.get("chapter"), int) or not 1 <= int(event.get("chapter", 0)) <= 5:
            errors.append(f"{event_id}: event chapter must be 1–5")
        if not isinstance(event.get("min_level"), int) or not 1 <= int(event.get("min_level", 0)) <= 10:
            errors.append(f"{event_id}: event min_level must be 1–10")
        if not isinstance(event.get("weight"), (int, float)) or float(event.get("weight", 0)) <= 0:
            errors.append(f"{event_id}: event weight must be positive")
        if not isinstance(event.get("unseen_multiplier"), (int, float)) or float(event.get("unseen_multiplier", 0)) < 1:
            errors.append(f"{event_id}: unseen_multiplier must be at least 1")
        if not isinstance(event.get("cooldown_seconds"), int) or int(event.get("cooldown_seconds", -1)) < 0:
            errors.append(f"{event_id}: cooldown_seconds must be a non-negative integer")
        if not isinstance(event.get("desktop_allowed"), bool):
            errors.append(f"{event_id}: desktop_allowed must be boolean")
        props = event.get("props", [])
        if (
            not isinstance(props, list)
            or not props
            or any(not isinstance(prop, str) or not prop for prop in props)
            or len(props) != len(set(props))
        ):
            errors.append(f"{event_id}: event must declare at least one replaceable prop")
        variants = event.get("variants", [])
        if (
            not isinstance(variants, list)
            or not variants
            or any(not isinstance(variant, str) or not variant for variant in variants)
            or len(variants) != len(set(variants))
        ):
            errors.append(f"{event_id}: event must declare localized variants")
        else:
            variant_keys.extend(variants)
        steps = event.get("steps", [])
        duration = 0.0
        if not isinstance(steps, list) or not steps:
            errors.append(f"{event_id}: event must declare animation steps")
        else:
            for step_index, step in enumerate(steps):
                if isinstance(step, dict):
                    unknown_step_fields = sorted(set(step) - EVENT_STEP_FIELDS)
                    if unknown_step_fields:
                        errors.append(
                            f"{event_id}: step {step_index} contains unsupported fields "
                            f"{unknown_step_fields}; allowed fields are {sorted(EVENT_STEP_FIELDS)}"
                        )
                if not isinstance(step, dict) or not str(step.get("animation", "")):
                    errors.append(f"{event_id}: step {step_index} is missing an animation ID")
                elif str(step.get("animation", "")) not in behavior_animation_ids:
                    errors.append(
                        f"{event_id}: step {step_index} references animation outside the shared vocabulary"
                    )
                step_duration = step.get("duration") if isinstance(step, dict) else None
                if not isinstance(step_duration, (int, float)) or float(step_duration) <= 0:
                    errors.append(f"{event_id}: step {step_index} duration must be positive")
                else:
                    duration += float(step_duration)
                camera_shake = step.get("camera_shake", False) if isinstance(step, dict) else False
                if not isinstance(camera_shake, bool):
                    errors.append(f"{event_id}: step {step_index} camera_shake must be boolean")
                elif camera_shake:
                    camera_shake_steps += 1
        rewards = event.get("rewards", {})
        reward_points = rewards.get("points") if isinstance(rewards, dict) else None
        if not isinstance(reward_points, int) or not 25 <= reward_points <= 40:
            errors.append(f"{event_id}: first-watch event reward must remain within 25–40 points")
        required_furniture = event.get("required_furniture", [])
        if not isinstance(required_furniture, list):
            errors.append(f"{event_id}: required_furniture must be an array")
            required_furniture = []
        for item_id in required_furniture:
            if not isinstance(item_id, str) or item_id not in furniture_ids:
                errors.append(f"{event['id']}: missing furniture {item_id}")
        prerequisite_events = event.get("prerequisite_events", [])
        if not isinstance(prerequisite_events, list):
            errors.append(f"{event_id}: prerequisite_events must be an array")
            prerequisite_events = []
        for prerequisite in prerequisite_events:
            if not isinstance(prerequisite, str) or prerequisite not in event_ids:
                errors.append(f"{event['id']}: missing prerequisite {prerequisite}")
        reward_expressions = rewards.get("expressions", []) if isinstance(rewards, dict) else []
        if not isinstance(reward_expressions, list):
            errors.append(f"{event_id}: reward expressions must be an array")
            reward_expressions = []
        for expression_id in reward_expressions:
            if isinstance(expression_id, str):
                expression_rewards.append(expression_id)
            if not isinstance(expression_id, str) or expression_id not in indexes["expressions"]:
                errors.append(f"{event['id']}: missing expression {expression_id}")
        reward_achievements = rewards.get("achievements", []) if isinstance(rewards, dict) else []
        if not isinstance(reward_achievements, list):
            errors.append(f"{event_id}: reward achievements must be an array")
            reward_achievements = []
        for achievement_id in reward_achievements:
            if not isinstance(achievement_id, str) or achievement_id not in indexes["achievements"]:
                errors.append(f"{event['id']}: missing achievement {achievement_id}")
        photo_id_value = event.get("photo_id", "")
        photo_id = photo_id_value if isinstance(photo_id_value, str) else ""
        photo_ids.append(photo_id)
        if not photo_id:
            errors.append(f"{event['id']}: missing photo_id")
        ranges = event.get("state_ranges", {})
        for state_name in ("satiety", "energy", "interest"):
            limits = ranges.get(state_name, []) if isinstance(ranges, dict) else []
            if (
                not isinstance(limits, list)
                or len(limits) != 2
                or any(not isinstance(limit, (int, float)) for limit in limits)
                or not (0 <= limits[0] <= limits[1] <= 100)
            ):
                errors.append(f"{event['id']}: invalid {state_name} state range")
        branches = event.get("branches", [])
        branch_ids: set[str] = set()
        if not isinstance(branches, list) or not branches:
            errors.append(f"{event['id']}: missing branches")
        else:
            for branch_index, branch in enumerate(branches):
                if not isinstance(branch, dict):
                    errors.append(f"{event_id}: branch {branch_index} must be an object")
                    continue
                branch_id = str(branch.get("id", ""))
                if not branch_id or branch_id in branch_ids:
                    errors.append(f"{event['id']}: empty or duplicate branch id {branch_id!r}")
                branch_ids.add(branch_id)
                branch_variants = branch.get("variant_keys", [])
                if (
                    not isinstance(branch_variants, list)
                    or not branch_variants
                    or any(not isinstance(variant, str) or not variant for variant in branch_variants)
                    or not set(branch_variants).issubset(set(variants if isinstance(variants, list) else []))
                ):
                    errors.append(f"{event['id']}/{branch_id}: invalid branch variants")
            if "default" not in branch_ids:
                errors.append(f"{event['id']}: missing default branch")
        if not 10 <= duration <= 25:
            errors.append(f"{event['id']}: duration {duration:g}s is outside 10–25s")
        if event.get("localization_complete") is not True:
            errors.append(f"{event['id']}: localization completeness flag is false")

    if camera_shake_steps == 0:
        errors.append("event content must include at least one data-driven camera-shake step")

    if len(photo_ids) != len(set(photo_ids)):
        errors.append("event photo IDs must be unique")

    animation_ids = set(behavior_animation_ids)
    for event in catalogs["events"]:
        steps = event.get("steps", [])
        if isinstance(steps, list):
            animation_ids.update(
                str(step.get("animation", ""))
                for step in steps
                if isinstance(step, dict)
            )
    if not 30 <= len(animation_ids) <= 36 or "" in animation_ids:
        errors.append(f"animation vocabulary must contain 30–36 non-empty entries, got {len(animation_ids)}")

    for expression in catalogs["expressions"]:
        expression_id = str(expression.get("id", ""))
        if str(expression.get("category", "")) not in EXPRESSION_CATEGORIES:
            errors.append(f"{expression_id}: invalid expression category")
        event_id = str(expression.get("associated_event", ""))
        if event_id not in event_ids:
            errors.append(f"{expression['id']}: missing associated event {event_id}")
        condition = expression.get("condition", {})
        if not isinstance(condition, dict) or not condition.get("type") or not condition.get("id"):
            errors.append(f"{expression['id']}: invalid unlock condition")
        elif condition.get("type") == "event" and str(condition.get("id", "")) not in event_ids:
            errors.append(f"{expression_id}: event unlock condition references missing content")
        elif condition.get("type") == "interaction" and str(condition.get("id", "")) not in INTERACTION_CONDITIONS:
            errors.append(f"{expression_id}: unsupported interaction unlock condition {condition.get('id')!r}")
        elif condition.get("type") not in {"event", "interaction"}:
            errors.append(f"{expression_id}: unsupported unlock condition type {condition.get('type')!r}")

    if Counter(expression_rewards) != Counter(indexes["expressions"].keys()):
        missing = set(indexes["expressions"]) - set(expression_rewards)
        duplicate = [key for key, count in Counter(expression_rewards).items() if count > 1]
        errors.append(f"expression reward coverage mismatch; missing={sorted(missing)}, duplicate={duplicate}")

    for achievement in catalogs["achievements"]:
        achievement_id = str(achievement.get("id", ""))
        if not isinstance(achievement.get("hidden"), bool):
            errors.append(f"{achievement_id}: hidden achievement flag must be boolean")
        condition = achievement.get("condition", {})
        if not isinstance(condition, dict):
            errors.append(f"{achievement_id}: achievement condition must be an object")
            continue
        kind = str(condition.get("type", ""))
        if kind in ACHIEVEMENT_LIMITS:
            count = condition.get("count")
            if not isinstance(count, int) or not 1 <= count <= ACHIEVEMENT_LIMITS[kind]:
                errors.append(f"{achievement_id}: unreachable {kind} achievement target {count!r}")
        elif kind == "event_id":
            if str(condition.get("id", "")) not in event_ids:
                errors.append(f"{achievement_id}: achievement references a missing event")
        elif kind == "expression_id":
            if str(condition.get("id", "")) not in indexes["expressions"]:
                errors.append(f"{achievement_id}: achievement references a missing expression")
        elif kind == "points":
            if not isinstance(condition.get("count"), int) or int(condition.get("count", 0)) <= 0:
                errors.append(f"{achievement_id}: points achievement target must be positive")
        else:
            errors.append(f"{achievement_id}: unsupported achievement condition type {kind!r}")

    categories = Counter(item.get("category") for item in catalogs["expressions"])
    if categories != Counter({name: 8 for name in ("happy", "sleepy", "hungry", "wronged", "proud", "shocked")}):
        errors.append(f"expression categories must each contain 8 entries: {dict(categories)}")

    event_categories = Counter(item.get("category") for item in catalogs["events"])
    expected_events = Counter({"food": 6, "sleep": 5, "sport": 4, "hobby": 4, "weather": 3, "chapter": 2})
    if event_categories != expected_events:
        errors.append(f"event category budget mismatch: {dict(event_categories)}")

    level_eight_combinations = []
    for event in catalogs["events"]:
        required_furniture = event.get("required_furniture")
        if not isinstance(required_furniture, list):
            continue
        distinct_furniture = {str(furniture_id) for furniture_id in required_furniture}
        includes_level_eight_furniture = any(
            indexes["furniture"].get(furniture_id, {}).get("min_level") == 8
            for furniture_id in distinct_furniture
        )
        if event.get("min_level") == 8 and len(distinct_furniture) >= 2 and includes_level_eight_furniture:
            level_eight_combinations.append(str(event.get("id", "")))
    if not level_eight_combinations:
        errors.append(
            "familiarity level 8 must unlock at least one multi-furniture combination event"
        )

    variant_count = len(variant_keys)
    if variant_count != 60 or len(set(variant_keys)) != 60:
        errors.append(
            f"event variants must contain 60 unique localization keys, "
            f"got {variant_count} entries/{len(set(variant_keys))} unique"
        )

    reachable: set[str] = set()
    while True:
        added = {
            item["id"]
            for item in catalogs["events"]
            if item["id"] not in reachable
            and set(item.get("prerequisite_events", [])).issubset(reachable)
        }
        if not added:
            break
        reachable.update(added)
    if reachable != event_ids:
        errors.append(f"unreachable events: {sorted(event_ids - reachable)}")

    locale_path = DATA / "localization" / "game.csv"
    content_keys: set[str] = set()
    collect_keys(list(catalogs.values()), content_keys)
    collect_keys(performance_config, content_keys)
    content_keys.update(f"PERFORMANCE_{kind.upper()}" for kind in ("faces", "poses", "outfit_actions", "states", "forms"))
    content_keys.update(f"DESKTOP_FREQUENCY_{value}" for value in ("FREQUENT", "NORMAL", "RARE", "OFF"))
    content_keys.update(f"FOCUS_PHASE_{value}" for value in ("IDLE", "WORK", "REST_READY", "REST", "FINISHED"))
    if locale_path.exists():
        with locale_path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.DictReader(handle))
        locale_key_counts = Counter(row.get("keys", "") for row in rows)
        locale_keys = set(locale_key_counts)
        if "" in locale_keys:
            errors.append("game.csv contains an empty localization key")
        duplicate_locale_keys = sorted(key for key, count in locale_key_counts.items() if key and count > 1)
        if duplicate_locale_keys:
            errors.append(f"duplicate localization keys: {duplicate_locale_keys}")
        missing_keys = sorted(content_keys - locale_keys)
        if missing_keys:
            errors.append(f"missing localization keys: {missing_keys}")
        for line, row in enumerate(rows, 2):
            for locale in ("zh_CN", "zh_TW", "en"):
                if not row.get(locale, "").strip():
                    errors.append(f"game.csv:{line}: empty {locale} value for {row.get('keys')}")
            localized_text = " ".join(str(row.get(locale, "")) for locale in ("zh_CN", "zh_TW", "en"))
            if "雪碧" in localized_text or "巧乐兹" in localized_text or re.search(r"\bSprite\b", localized_text, re.IGNORECASE):
                errors.append(f"game.csv:{line}: player-facing text contains a prohibited real-world brand")
        locale_rows = {str(row.get("keys", "")): row for row in rows}
        legal_privacy = locale_rows.get("LEGAL_PRIVACY", {})
        privacy_scope_markers = {
            "zh_CN": ("养成主档", "两份安全备份", "游戏自动生成的生活相册照片", "手动截图", "互相隔离的云路径"),
            "zh_TW": ("養成主檔", "兩份安全備份", "遊戲自動生成的生活相簿照片", "手動截圖", "互相隔離的雲路徑"),
            "en": ("main progression save", "two safety backups", "game-generated life-album photos", "manual screenshots", "isolated cloud paths"),
        }
        for locale, markers in privacy_scope_markers.items():
            localized_privacy = str(legal_privacy.get(locale, ""))
            for marker in markers:
                if marker not in localized_privacy:
                    errors.append(
                        f"LEGAL_PRIVACY {locale} is missing required privacy scope marker {marker!r}"
                    )
        ui_prefixes = (
            "UI_", "SETTINGS_", "HELP_", "LEGAL_", "CATALOG_", "TENDENCY_", "ALBUM_", "EVENT_",
            "AREA_", "STATUS_", "NAME_", "TUTORIAL_", "OFFLINE_", "DIARY_", "DESKTOP_", "TOAST_",
            "ROOM_", "FURNITURE_", "ENDING_", "EXIT_", "PHOTO_FRAME_", "DEMO_", "PERFORMANCE_",
        )
        script_keys: set[str] = set()
        for script_path in (ROOT / "game" / "scripts").rglob("*.gd"):
            source = script_path.read_text(encoding="utf-8")
            for literal in re.findall(r'"([A-Z][A-Z0-9_]{2,})"', source):
                if literal.startswith(ui_prefixes):
                    script_keys.add(literal)
        script_keys.update(
            {
                *(f"AREA_{area.upper()}" for area in AREAS),
                *(f"CATALOG_{kind}_INTRO" for kind in ("FURNITURE", "SNACKS", "OUTFITS")),
                *(f"ROOM_PALETTE_{palette}" for palette in ("ROSE", "MINT", "NIGHT")),
                *(f"PHOTO_FRAME_{frame}" for frame in ("PLAIN", "BERRY", "STAR")),
            }
        )
        missing_script_keys = sorted(script_keys - locale_keys)
        if missing_script_keys:
            errors.append(f"missing UI localization keys: {missing_script_keys}")
    else:
        errors.append("missing game/data/localization/game.csv")

    audio_manifest_path = AUDIO / "audio_manifest.json"
    music_count = 0
    sfx_count = 0
    if audio_manifest_path.exists():
        with audio_manifest_path.open(encoding="utf-8") as handle:
            audio_manifest = json.load(handle)
        development_placeholder = audio_manifest.get("development_placeholder")
        if not isinstance(development_placeholder, bool):
            errors.append("audio manifest must explicitly declare development_placeholder")
            development_placeholder = True
        seen_audio_ids: set[str] = set()
        for kind, expected_count in (("music", 4), ("sfx", 30)):
            entries = audio_manifest.get(kind, [])
            if not isinstance(entries, list):
                errors.append(f"audio manifest {kind} must be an array")
                continue
            if len(entries) != expected_count:
                errors.append(f"audio {kind}: expected {expected_count}, got {len(entries)}")
            for entry in entries:
                audio_id = str(entry.get("id", ""))
                resource_path = str(entry.get("path", ""))
                if not audio_id or audio_id in seen_audio_ids:
                    errors.append(f"audio {kind}: empty or duplicate id {audio_id!r}")
                seen_audio_ids.add(audio_id)
                if not resource_path.startswith("res://"):
                    errors.append(f"audio {audio_id}: invalid resource path {resource_path!r}")
                    continue
                disk_path = ROOT / resource_path.removeprefix("res://")
                if not disk_path.exists():
                    errors.append(f"audio {audio_id}: missing file {resource_path}")
                    continue
                if development_placeholder:
                    try:
                        with wave.open(str(disk_path), "rb") as source:
                            if source.getnchannels() != 1 or source.getsampwidth() != 2:
                                errors.append(f"placeholder audio {audio_id}: expected mono 16-bit WAV")
                            if source.getframerate() != 22050 or source.getnframes() <= 0:
                                errors.append(f"placeholder audio {audio_id}: invalid sample rate or empty data")
                    except (wave.Error, EOFError) as exc:
                        errors.append(f"placeholder audio {audio_id}: unreadable WAV ({exc})")
                elif disk_path.suffix.lower() not in {".ogg", ".wav"}:
                    errors.append(f"dedicated audio {audio_id}: expected an OGG or WAV resource")
                elif disk_path.stat().st_size <= 0:
                    errors.append(f"dedicated audio {audio_id}: resource is empty")
        music_count = len(audio_manifest.get("music", []))
        sfx_count = len(audio_manifest.get("sfx", []))
    else:
        errors.append("missing game/assets/audio/audio_manifest.json")

    final_asset_manifest_path = DATA / "catalog" / "final_asset_manifest.json"
    if final_asset_manifest_path.exists():
        with final_asset_manifest_path.open(encoding="utf-8") as handle:
            final_asset_manifest = json.load(handle)
        if final_asset_manifest.get("schema_version") != 1:
            errors.append("final asset manifest schema_version must be 1")
        if not isinstance(final_asset_manifest.get("ready"), bool):
            errors.append("final asset manifest ready must be boolean")
        if not isinstance(final_asset_manifest.get("provided_by_user"), bool):
            errors.append("final asset manifest provided_by_user must be boolean")
        if not isinstance(final_asset_manifest.get("entries"), list):
            errors.append("final asset manifest entries must be an array")
    else:
        errors.append("missing game/data/catalog/final_asset_manifest.json")

    script_sources = list((ROOT / "game" / "scripts").rglob("*.gd"))
    for script_path in script_sources:
        source = script_path.read_text(encoding="utf-8")
        if script_path.name == "pig_state.gd":
            default_name = re.search(
                r'^\s*var\s+name\s*:\s*String\s*=\s*"([^\"]*)"',
                source,
                re.MULTILINE,
            )
            if default_name and default_name.group(1):
                errors.append(
                    f"{script_path.relative_to(ROOT)} hardcodes the default pig name; "
                    "keep unnamed state empty and use NAME_DEFAULT for display"
                )
        for api_name, pattern in FORBIDDEN_RUNTIME_APIS.items():
            if pattern.search(source):
                errors.append(
                    f"{script_path.relative_to(ROOT)} uses forbidden online/multiplayer API {api_name}; "
                    "the launch game must remain single-player and offline-first"
                )
        for api_name, pattern in FORBIDDEN_MOUSE_POLLING_APIS.items():
            if pattern.search(source):
                errors.append(
                    f"{script_path.relative_to(ROOT)} uses forbidden mouse polling API {api_name}; "
                    "pointer interaction must remain event-driven so unfocused background play does not poll the mouse"
                )
        for pattern in DIRECT_VISIBILITY_INVERSION_PATTERNS:
            inversion = pattern.search(source)
            if inversion:
                errors.append(
                    f"{script_path.relative_to(ROOT)} uses direct visibility inversion near "
                    f"{inversion.group(0)!r}; visibility must follow explicit state"
                )
                break
        looped_tweens = {
            match.group("name")
            for pattern in (LOOPED_TWEEN_ASSIGNMENT_PATTERN, LOOPED_TWEEN_CALL_PATTERN)
            for match in pattern.finditer(source)
        }
        for tween_name in sorted(looped_tweens):
            opacity_tween_pattern = re.compile(
                rf"\b{re.escape(tween_name)}\s*\.\s*tween_property\s*\("
                r"\s*[^,\n]+,\s*[\"'](?:self_)?modulate:a[\"']"
            )
            if opacity_tween_pattern.search(source):
                errors.append(
                    f"{script_path.relative_to(ROOT)} uses looped opacity tween {tween_name!r}; "
                    "periodic opacity oscillation is prohibited"
                )
        periodic_opacity = PERIODIC_OPACITY_ASSIGNMENT_PATTERN.search(source)
        if periodic_opacity:
            errors.append(
                f"{script_path.relative_to(ROOT)} drives opacity with a periodic function near "
                f"{periodic_opacity.group(0)!r}; periodic opacity oscillation is prohibited"
            )
        if "res://assest/" in source:
            errors.append(
                f"{script_path.relative_to(ROOT)} references undocumented legacy assest/ resources"
            )
    for scene_path in (ROOT / "game" / "scenes").rglob("*.tscn"):
        if "res://assest/" in scene_path.read_text(encoding="utf-8"):
            errors.append(
                f"{scene_path.relative_to(ROOT)} references undocumented legacy assest/ resources"
            )

    for integration_path in sorted(path for path in ROOT.rglob("*") if path.is_file()):
        relative = integration_path.relative_to(ROOT)
        if relative.parts[0] in EXTERNAL_INTEGRATION_IGNORED_TOP_LEVEL:
            continue
        if (
            "addons" in relative.parts
            or integration_path.suffix.lower() in EXTERNAL_INTEGRATION_SUFFIXES
        ):
            errors.append(
                f"{relative}: unreviewed external integration file; addons and native code "
                "require a pinned version, license, hashes, and explicit boundary review"
            )

    ui_sources = list((ROOT / "game" / "scripts" / "ui").rglob("*.gd"))
    ui_sources.extend((ROOT / "game" / "scripts" / "desktop").rglob("*.gd"))
    direct_session_assignment_pattern = re.compile(
        r"GameSession\.[A-Za-z_][A-Za-z0-9_]*"
        r"(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]\n]+\])*\s*"
        r"(?:\+=|-=|\*=|/=|%=|&=|\|=|\^=|=(?!=))"
    )
    internal_module_access_pattern = re.compile(
        r"GameSession\.(?:save_service|event_director|simulation)\b"
    )
    pig_state_mutation_pattern = re.compile(
        r"GameSession\.pig_state\."
        r"(?:normalize|add_familiarity|add_points|spend_points|record_daily_interaction|unlock|load_dict)\s*\("
    )
    pig_state_collection_mutation_pattern = re.compile(
        r"GameSession\.pig_state(?:\.[A-Za-z_][A-Za-z0-9_]*|\[[^\]\n]+\])+\."
        r"(?:append|append_array|assign|clear|erase|insert|merge|pop_at|pop_back|pop_front|push_back|push_front|resize|reverse|set|shuffle|sort|sort_custom)\s*\("
    )
    session_signal_emit_pattern = re.compile(
        r"GameSession\.[A-Za-z_][A-Za-z0-9_]*\.emit\s*\("
    )
    player_facing_literal_patterns = (
        re.compile(r"\.(?:text|tooltip_text|placeholder_text)\s*=\s*\"([^\"]*)\""),
        re.compile(r"\.(?:add_item|add_check_item)\(\s*\"([^\"]*)\""),
    )
    for script_path in ui_sources:
        source = script_path.read_text(encoding="utf-8")
        has_custom_gui_input = "func _gui_input" in source or ".gui_input.connect" in source
        if has_custom_gui_input and "InputEventMouseButton" in source and "InputEventScreenTouch" not in source:
            errors.append(
                f"{script_path.relative_to(ROOT)} defines mouse-only custom GUI input; "
                "handle InputEventScreenTouch through the same player command path"
            )
        if has_custom_gui_input and "InputEventMouseMotion" in source and "InputEventScreenDrag" not in source:
            errors.append(
                f"{script_path.relative_to(ROOT)} defines mouse-only custom drag input; "
                "handle InputEventScreenDrag through the same placement path"
            )
        direct_assignment = direct_session_assignment_pattern.search(source)
        if direct_assignment:
            errors.append(
                f"{script_path.relative_to(ROOT)} assigns GameSession state directly near "
                f"{direct_assignment.group(0)!r}; call a GameSession command"
            )
        internal_access = internal_module_access_pattern.search(source)
        if internal_access:
            errors.append(
                f"{script_path.relative_to(ROOT)} bypasses the GameSession facade near "
                f"{internal_access.group(0)!r}"
            )
        for pattern in (pig_state_mutation_pattern, pig_state_collection_mutation_pattern):
            mutation = pattern.search(source)
            if mutation:
                errors.append(
                    f"{script_path.relative_to(ROOT)} mutates PigState directly near "
                    f"{mutation.group(0)!r}; call a GameSession command"
                )
        signal_emit = session_signal_emit_pattern.search(source)
        if signal_emit:
            errors.append(
                f"{script_path.relative_to(ROOT)} emits a GameSession signal directly near "
                f"{signal_emit.group(0)!r}; call a GameSession command"
            )
        direct_quit = DIRECT_SCENE_TREE_QUIT_PATTERN.search(source)
        if direct_quit:
            errors.append(
                f"{script_path.relative_to(ROOT)} exits the SceneTree directly near "
                f"{direct_quit.group(0)!r}; call GameSession.request_exit so progression "
                "and machine settings checkpoint first"
            )
        for pattern in player_facing_literal_patterns:
            for match in pattern.finditer(source):
                literal = match.group(1)
                if re.search(r"[A-Za-z\u3400-\u9fff]", literal):
                    errors.append(
                        f"{script_path.relative_to(ROOT)} hardcodes player-facing copy {literal!r}; "
                        "use a localization key"
                    )

    scene_facing_literal_pattern = re.compile(
        r'^\s*(?:text|tooltip_text|placeholder_text)\s*=\s*"([^\"]*)"',
        re.MULTILINE,
    )
    for scene_path in (ROOT / "game" / "scenes").rglob("*.tscn"):
        source = scene_path.read_text(encoding="utf-8")
        for match in scene_facing_literal_pattern.finditer(source):
            literal = match.group(1)
            if re.search(r"[A-Za-z\u3400-\u9fff]", literal):
                errors.append(
                    f"{scene_path.relative_to(ROOT)} hardcodes player-facing copy {literal!r}; "
                    "use a localization key"
                )

    if errors:
        print("Content validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    print(
        "Content validation passed: "
        f"{len(catalogs['behaviors'])} behaviors, "
        f"{len(catalogs['furniture'])} furniture, "
        f"{len(catalogs['snacks'])} snacks, "
        f"{len(catalogs['outfits'])} outfits, "
        f"{len(catalogs['expressions'])} expressions, "
        f"{len(catalogs['events'])} events/{variant_count} variants, "
        f"{len(catalogs['achievements'])} achievements, "
        f"{len(catalogs['life_plans'])} life plans/18 diary entries, "
        f"{music_count} music loops/{sfx_count} sound effects."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
