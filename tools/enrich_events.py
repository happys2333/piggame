#!/usr/bin/env python3
"""Normalize the event schema and add deterministic branch/condition metadata."""

from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / "game" / "data" / "events" / "events.json"

STATE_RANGES = {
    "food": {"satiety": [0, 90], "energy": [0, 100], "interest": [0, 100]},
    "sleep": {"satiety": [0, 100], "energy": [0, 82], "interest": [0, 100]},
    "sport": {"satiety": [0, 100], "energy": [25, 100], "interest": [20, 100]},
    "hobby": {"satiety": [0, 100], "energy": [15, 100], "interest": [20, 100]},
    "weather": {"satiety": [0, 100], "energy": [0, 100], "interest": [15, 100]},
    "chapter": {"satiety": [0, 100], "energy": [0, 100], "interest": [0, 100]},
}

SPECIAL_BRANCHES = {
    "event_balanced_treat": {
        "id": "hungry_science",
        "conditions": {"satiety_max": 55},
        "variant_index": 1,
        "reward_bonus": {"points": 2},
    },
    "event_alarm_victory": {
        "id": "very_sleepy",
        "conditions": {"energy_max": 35},
        "variant_index": 0,
        "reward_bonus": {"familiarity": 1},
    },
    "event_dream_meeting": {
        "id": "deep_dream",
        "conditions": {"energy_max": 40},
        "variant_index": 2,
        "reward_bonus": {"points": 2},
    },
    "event_radio_dance": {
        "id": "active_mood",
        "conditions": {"tendency": "active"},
        "variant_index": 1,
        "reward_bonus": {"points": 2},
    },
    "event_rainy_window": {
        "id": "warm_drink",
        "conditions": {"required_furniture": ["furn_kettle_round"]},
        "variant_index": 1,
        "reward_bonus": {"familiarity": 2},
    },
    "event_ordinary_day": {
        "id": "complete_album",
        "conditions": {"seen_events_min": 23},
        "variant_index": 0,
        "reward_bonus": {"points": 10},
    },
}

EVENT_ACHIEVEMENTS = {
    "event_move_in": ["ach_welcome_home"],
    "event_robot_knight": ["ach_robot_knight"],
    "event_ordinary_day": ["ach_events_24"],
}


def main() -> None:
    events = json.loads(PATH.read_text(encoding="utf-8"))
    for event in events:
        event_id = event["id"]
        variants = event["variants"]
        event["state_ranges"] = STATE_RANGES[event["category"]]
        branches = []
        special = SPECIAL_BRANCHES.get(event_id)
        default_variants = list(variants)
        if special:
            key = variants[special["variant_index"]]
            default_variants.remove(key)
            branches.append(
                {
                    "id": special["id"],
                    "conditions": special["conditions"],
                    "variant_keys": [key],
                    "reward_bonus": special["reward_bonus"],
                }
            )
        branches.append(
            {
                "id": "default",
                "conditions": {},
                "variant_keys": default_variants or list(variants),
                "reward_bonus": {},
            }
        )
        event["branches"] = branches
        event["photo_id"] = "photo_" + event_id.removeprefix("event_")
        event["rewards"]["achievements"] = EVENT_ACHIEVEMENTS.get(event_id, [])
    PATH.write_text(json.dumps(events, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Enriched {len(events)} events")


if __name__ == "__main__":
    main()
