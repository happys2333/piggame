"""Audit integrated feedback assets and policies using isolated Dummy output."""

from __future__ import annotations

import argparse
import array
from collections import Counter
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import uuid
import wave

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_godot_checks as checks
from validate_release_candidate import source_tree_sha256


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "game/assets/audio/audio_manifest.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dbfs(value: float) -> float | None:
    return round(20.0 * math.log10(value), 3) if value > 0.0 else None


def analyze_wav(path: Path) -> dict:
    with wave.open(str(path), "rb") as source:
        channels = source.getnchannels()
        rate = source.getframerate()
        frames = source.getnframes()
        if source.getsampwidth() != 2 or source.getcomptype() != "NONE":
            raise ValueError("WAV inspection currently expects uncompressed 16-bit PCM")
        samples = array.array("h", source.readframes(frames))
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples or len(samples) != frames * channels:
        raise ValueError("missing or truncated WAV samples")
    peak = max(abs(value) for value in samples) / 32768.0
    rms = math.sqrt(sum(value * value for value in samples) / len(samples)) / 32768.0
    dc = sum(samples) / len(samples) / 32768.0
    jumps = [abs(samples[-channels + channel] - samples[channel]) / 32768.0 for channel in range(channels)]
    return {"seconds":round(frames / rate, 6), "sample_rate":rate, "channels":channels, "bit_depth":16, "frames":frames, "peak_dbfs":dbfs(peak), "peak_linear":peak, "rms_dbfs":dbfs(rms), "dc_offset":dc, "clipped_samples":sum(abs(value) >= 32767 for value in samples), "first_last_sample_jump_dbfs":dbfs(max(jumps)), "sha256":sha256(path), "bytes":path.stat().st_size}


def inspect_inventory(root: Path = ROOT) -> dict:
    manifest_path = root / "game/assets/audio/audio_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    records = []
    errors = []
    identifiers = set()
    if manifest.get("playback_policy") != "player_feedback_only" or manifest.get("music") != []:
        errors.append("only player feedback is permitted")
    source = json.loads((root / "game/assets/audio/source.json").read_text())
    provenance = {entry["id"]:entry for entry in source["files"]}
    for kind, expected in (("music", 0), ("sfx", 13)):
        entries = manifest.get(kind, [])
        if len(entries) != expected:
            errors.append(f"{kind}: expected {expected} entries, found {len(entries)}")
        for entry in entries:
            identifier = entry["id"]
            path = (root / entry["path"].removeprefix("res://")).resolve()
            if identifier in identifiers:
                errors.append(f"duplicate id: {identifier}")
            identifiers.add(identifier)
            try:
                path.relative_to(root.resolve())
                record = {"id":identifier, "kind":kind, "path":entry["path"], **analyze_wav(path)}
                if record["clipped_samples"]:
                    errors.append(f"{identifier}: source has full-scale samples")
                if record["peak_linear"] == 0.0:
                    errors.append(f"{identifier}: source is entirely silent")
                if record["sample_rate"] != 44100 or record["channels"] != 1 or record["seconds"] > 3.0:
                    errors.append(f"{identifier}: expected short 44.1kHz mono feedback")
                origin = provenance.get(identifier, {})
                if origin.get("runtime_path") != entry["path"] or origin.get("prepared_sha256") != record["sha256"]:
                    errors.append(f"{identifier}: provenance path/hash mismatch")
                if origin.get("integration_approved") is not True or not origin.get("provenance", {}).get("prompt_seed_and_output_prefix_verified"):
                    errors.append(f"{identifier}: missing generation/integration evidence")
                records.append(record)
            except (OSError, ValueError, wave.Error) as error:
                errors.append(f"{identifier}: {error}")
    return {"development_placeholder":bool(manifest.get("development_placeholder", True)), "files":records, "technical_failures":errors, "bytes":sum(record["bytes"] for record in records), "listening_performed":False, "measured_loudness":"sample peak and unweighted RMS only; not LUFS or true peak", "manifest_sha256":sha256(manifest_path)}


def copy_preflight(root: Path = ROOT) -> dict:
    path = root / "docs/copy-review-2026-10-11/return-2026-10-11-zh-copyedit.json"
    if not path.is_file():
        return {"found":False, "applied_by_this_audit":False}
    data = json.loads(path.read_text())
    with (root / "game/data/localization/game.csv").open(newline="", encoding="utf-8-sig") as handle:
        rows = {row["keys"]:row for row in csv.DictReader(handle)}
    issues = []
    keys = set()
    for entry in data.get("changes", []):
        key = entry["key"]
        if key not in rows or key in keys:
            issues.append(key + ": unknown or duplicate key")
            continue
        keys.add(key)
        current = {locale:rows[key][locale] for locale in ("zh_CN", "zh_TW", "en")}
        current_hash = hashlib.sha256(json.dumps(current, ensure_ascii=False, sort_keys=True).encode()).hexdigest()
        if current_hash != entry.get("original_text_sha256"):
            issues.append(key + ": baseline text hash mismatch")
        for locale in current:
            proposed = entry.get(locale)
            if proposed is not None and Counter(re.findall(r"\{[^{}]+\}", proposed)) != Counter(re.findall(r"\{[^{}]+\}", current[locale])):
                issues.append(key + ": changed placeholders in " + locale)
    baseline_match = data.get("localization_csv_sha256") == sha256(root / "game/data/localization/game.csv")
    return {"found":True, "path":path.relative_to(root).as_posix(), "changes":len(data.get("changes", [])), "metadata_suggestions":len(data.get("metadata_changes", [])), "image_suggestions":len(data.get("image_caption_suggestions", [])), "baseline_csv_matches":baseline_match, "structural_issues":issues, "applied_by_this_audit":False, "note":"Copyediting suggestions are a separate handoff, not new music or sound effects."}


def validate_runtime_result(result: subprocess.CompletedProcess[str], path: Path) -> dict:
    fatal_markers = (*checks.FATAL_GODOT_OUTPUT_MARKERS, "ObjectDB instances leaked", "resources still in use at exit")
    if any(marker in (result.stdout or "") for marker in fatal_markers):
        raise RuntimeError("Godot audio audit reported an engine error or leaked resources: " + result.stdout)
    runtime = json.loads(path.read_text())
    if not isinstance(runtime, dict) or runtime.get("completed") is not True:
        raise ValueError("Godot audio audit did not complete")
    assertions = runtime.get("assertions")
    failures = runtime.get("failures")
    streams = runtime.get("decoded_streams")
    observations = runtime.get("policy_observations")
    if type(assertions) is not int or assertions <= 0 or not isinstance(failures, list) or not all(isinstance(entry, str) for entry in failures) or len(failures) > assertions:
        raise ValueError("Godot audio audit has invalid assertion results")
    if not isinstance(streams, list) or len(streams) != 13 or not all(isinstance(entry, dict) for entry in streams):
        raise ValueError("Godot audio audit has incomplete stream results")
    if not isinstance(observations, list) or len(observations) != 32 or not all(isinstance(entry, dict) and type(entry.get("unsafe_autonomous_bus_eligibility")) is bool for entry in observations):
        raise ValueError("Godot audio audit has incomplete policy results")
    if runtime.get("driver") != "Dummy" or runtime.get("physical_output_tested") is not False or runtime.get("production_playback_enabled") is not True:
        raise ValueError("Godot audio audit did not preserve Dummy isolation")
    marker = f"AUDIO_AUDIT: assertions={assertions} failures={len(failures)} streams=13 feedback_only=true physical_output=false"
    if (result.stdout or "").splitlines().count(marker) != 1:
        raise ValueError("Godot audio audit completion marker is missing or inconsistent")
    expected_exit = 1 if failures else 0
    if result.returncode != expected_exit:
        raise ValueError("Godot audio audit exit code disagrees with assertion results")
    return {**runtime, "process_exit_code":result.returncode}


def run_runtime(output: Path) -> dict:
    name = checks.USER_DIR_PREFIX + uuid.uuid4().hex
    support = Path.home() / "Library/Application Support"
    environment = os.environ.copy()
    environment["PIGGAME_EXPECTED_USER_DIR"] = name
    environment["PIGGAME_AUDIO_AUDIT_DIR"] = str(output)
    environment["PIGGAME_AUDIO_DUMMY_ONLY"] = "1"
    runtime_path = output / "runtime.json"
    runtime_path.unlink(missing_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix="piggame-audio-audit-") as temporary:
            stage = Path(temporary) / "project"
            checks.stage_project(ROOT, stage, name)
            common = [str(checks.DEFAULT_GODOT), "--headless", "--audio-driver", "Dummy", "--path", str(stage)]
            for label, arguments in (("import", ["--editor", "--quit"]), ("runtime", ["res://tests/audio_audit.tscn"])):
                result = subprocess.run(common + arguments, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
                (output / (label + ".log")).write_text(result.stdout)
                print(label, result.returncode, flush=True)
                if label == "runtime":
                    return validate_runtime_result(result, runtime_path)
                if checks.result_exit_code(result, label, None):
                    raise RuntimeError(result.stdout)
    finally:
        checks.remove_isolated_user_data(support, name)
    raise RuntimeError("Godot audio audit runtime was not executed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    output = arguments.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    before = source_tree_sha256(ROOT)
    inventory = inspect_inventory()
    if inventory["technical_failures"]:
        (output / "inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")
        raise RuntimeError("WAV file audit failed: " + str(inventory["technical_failures"]))
    runtime = run_runtime(output)
    assert before == source_tree_sha256(ROOT), "game code or assets changed during audit"
    failures = inventory["technical_failures"] + runtime["failures"]
    worst_peak = max(record["peak_linear"] for record in inventory["files"]) * 3
    if worst_peak >= 1.0:
        failures.append("three-voice worst-case coherent mix has no headroom")
    report = {"inventory":inventory, "runtime":runtime,
              "technical_audit_passed":not failures, "final_audio_accepted":False,
              "game_sources_changed":False, "physical_output_tested":False,
              "worst_case_mix_peak_dbfs":dbfs(worst_peak),
              "production_source_sha256":before,
              "copy_return_preflight":copy_preflight(), "audit_exit_code":1 if failures else 0}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    lines = ["# SFX-only integration audit", "",
             f"{len(inventory['files'])} files; {runtime['assertions']} runtime assertions.",
             f"Worst-case coherent 3-voice peak: {dbfs(worst_peak)} dBFS at maximum volume.",
             "Dummy-only validation. Physical output, subjective listening and Windows verification remain pending.",
             "BGM and continuous ambience are excluded. Final asset approval remains blocked.", ""]
    lines.extend("- " + failure for failure in failures)
    (output / "report.md").write_text("\n".join(lines) + "\n")
    exit_code = 1 if failures else 0
    print(f"AUDIO: {len(inventory['files'])} files, {runtime['assertions']} assertions; feedback only, final readiness blocked", flush=True)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
