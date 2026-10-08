#!/usr/bin/env python3
"""Reproduce legacy development-placeholder audio when explicitly requested."""

from __future__ import annotations

import argparse
import json
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AUDIO = ROOT / "game" / "assets" / "audio"
RATE = 22050
TAU = math.tau


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max(max(abs(value) for value in samples), 1.0)
    pcm = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, value / peak)) * 32767)) for value in samples)
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)


def add_tone(target: list[float], start: float, duration: float, frequency: float, volume: float, kind: str = "sine") -> None:
    begin = int(start * RATE)
    count = min(int(duration * RATE), len(target) - begin)
    for index in range(max(count, 0)):
        t = index / RATE
        attack = min(t / 0.015, 1.0)
        release = min((duration - t) / 0.08, 1.0)
        envelope = max(0.0, attack * release)
        phase = TAU * frequency * t
        if kind == "triangle":
            value = 2.0 / math.pi * math.asin(math.sin(phase))
        elif kind == "soft_square":
            value = math.tanh(math.sin(phase) * 1.8) * 0.75
        else:
            value = math.sin(phase)
        target[begin + index] += value * volume * envelope


def add_noise(target: list[float], start: float, duration: float, volume: float, seed: int) -> None:
    rng = random.Random(seed)
    begin = int(start * RATE)
    count = min(int(duration * RATE), len(target) - begin)
    previous = 0.0
    for index in range(max(count, 0)):
        t = index / max(duration * RATE, 1)
        raw = rng.uniform(-1.0, 1.0)
        previous = previous * 0.68 + raw * 0.32
        target[begin + index] += previous * volume * (1.0 - t) ** 2


def music(track: int, roots: list[int], melody: list[int]) -> list[float]:
    duration = 16.0
    result = [0.0] * int(duration * RATE)
    for bar in range(8):
        root = roots[bar % len(roots)]
        start = bar * 2.0
        for semitone in (0, 4 if track % 2 == 0 else 3, 7):
            frequency = 220.0 * 2 ** ((root + semitone - 57) / 12)
            add_tone(result, start, 1.95, frequency, 0.055, "sine")
        for step in range(4):
            note = melody[(bar * 4 + step + track) % len(melody)] + root
            frequency = 440.0 * 2 ** ((note - 69) / 12)
            add_tone(result, start + step * 0.5, 0.34, frequency, 0.13, "triangle")
        add_tone(result, start, 0.18, 82 + track * 5, 0.09, "sine")
        add_noise(result, start + 1.0, 0.09, 0.035, track * 100 + bar)
    fade = int(0.08 * RATE)
    for index in range(fade):
        factor = index / fade
        result[index] *= factor
        result[-index - 1] *= factor
    return result


def sfx_tone(frequencies: list[float], duration: float = 0.35, kind: str = "sine", volume: float = 0.5) -> list[float]:
    result = [0.0] * int(duration * RATE)
    segment = duration / len(frequencies)
    for index, frequency in enumerate(frequencies):
        add_tone(result, index * segment, segment * 0.96, frequency, volume, kind)
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--development-placeholders",
        action="store_true",
        help="explicitly reproduce non-final synthesized development placeholders",
    )
    args = parser.parse_args()
    if not args.development_placeholders:
        parser.error(
            "creative audio generation is frozen by the active project requirement; "
            "wait for user-supplied dedicated assets"
        )
    tracks = [
        ("room_morning", [60, 65, 67, 64], [0, 4, 7, 9, 7, 4, 2, 4]),
        ("room_afternoon", [57, 62, 64, 60], [7, 4, 2, 4, 9, 7, 4, 2]),
        ("room_evening", [53, 57, 60, 55], [0, 3, 7, 10, 7, 3, 2, 0]),
        ("room_rain", [55, 58, 62, 60], [0, 7, 5, 3, 2, 5, 7, 3]),
    ]
    manifest = {"development_placeholder": True, "music": [], "sfx": []}
    for index, (name, roots, melody) in enumerate(tracks):
        relative = f"music/{name}.wav"
        write_wav(AUDIO / relative, music(index, roots, melody))
        manifest["music"].append({"id": name, "path": f"res://game/assets/audio/{relative}"})

    definitions: dict[str, tuple[list[float], float, str, float]] = {
        "ui_click": ([620, 760], 0.12, "sine", 0.30), "pet_1": ([390, 520], 0.28, "sine", 0.36),
        "pet_2": ([430, 560], 0.28, "sine", 0.36), "pet_3": ([350, 490], 0.30, "sine", 0.36),
        "hum_1": ([220, 247, 220], 0.55, "sine", 0.25), "hum_2": ([196, 220, 262], 0.55, "sine", 0.25),
        "hum_3": ([247, 220, 196], 0.55, "sine", 0.25), "step_1": ([120], 0.09, "sine", 0.30),
        "step_2": ([135], 0.09, "sine", 0.30), "step_3": ([105], 0.09, "sine", 0.30),
        "snore_1": ([150, 120], 0.75, "sine", 0.23), "snore_2": ([135, 105], 0.82, "sine", 0.23),
        "bag_rustle": ([820, 640, 760], 0.30, "soft_square", 0.16), "bite": ([260, 180], 0.16, "triangle", 0.26),
        "sip": ([420, 510, 620], 0.33, "sine", 0.22), "fridge_open": ([180, 250], 0.42, "triangle", 0.28),
        "fridge_close": ([230, 130], 0.30, "triangle", 0.30), "treadmill": ([110, 125, 110], 0.32, "soft_square", 0.18),
        "yoga_roll": ([190, 170, 150], 0.48, "triangle", 0.22), "paint": ([540, 480], 0.22, "sine", 0.18),
        "water": ([700, 620, 540, 460], 0.72, "sine", 0.15), "radio_click": ([350, 680], 0.18, "soft_square", 0.22),
        "wind_chime": ([880, 1108, 1320], 1.20, "sine", 0.20), "camera": ([180, 880], 0.18, "soft_square", 0.28),
        "robot": ([160, 180, 200, 180], 0.64, "soft_square", 0.17), "soft_bump": ([95], 0.24, "sine", 0.34),
        "unlock": ([523, 659, 784], 0.48, "triangle", 0.30), "points": ([660, 880], 0.22, "triangle", 0.25),
        "level_up": ([392, 523, 659, 784], 0.80, "triangle", 0.30), "event": ([440, 554, 659], 0.58, "sine", 0.27),
    }
    for name, (frequencies, duration, kind, volume) in definitions.items():
        relative = f"sfx/{name}.wav"
        samples = sfx_tone(frequencies, duration, kind, volume)
        if name in {"bag_rustle", "paint", "water"}:
            add_noise(samples, 0.0, duration, 0.12, len(name))
        write_wav(AUDIO / relative, samples)
        manifest["sfx"].append({"id": name, "path": f"res://game/assets/audio/{relative}"})

    (AUDIO / "audio_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(manifest['music'])} music loops and {len(manifest['sfx'])} sound effects")


if __name__ == "__main__":
    main()
