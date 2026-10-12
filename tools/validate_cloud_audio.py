"""Validate candidate hashes and Godot imports without touching the production project."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import uuid

import process_cloud_audio as audio
import run_godot_checks as checks
from validate_release_candidate import source_tree_sha256


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidates", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    directory = arguments.candidates.resolve()
    arguments.output.mkdir(parents=True, exist_ok=True)
    source_hash = source_tree_sha256(ROOT)
    manifest = json.loads((directory / "manifest.json").read_text())
    plan = json.loads((ROOT / "docs/design/comfy-cloud-audio-plan.json").read_text())
    identifiers = {entry["id"] for entry in plan["music"] + plan["effects"]}
    entries = manifest["files"]
    if len(entries) != 20 or {entry["id"] for entry in entries} != identifiers:
        raise ValueError("incomplete candidate inventory")
    if manifest["final_audio_accepted"] or manifest["production_audio_enabled"]:
        raise ValueError("candidate acceptance or playback gate changed")
    for entry in entries:
        for path_key, hash_key in (("prepared_path", "prepared_sha256"), ("master_path", "master_sha256")):
            path = (directory / entry[path_key]).resolve()
            path.relative_to(directory)
            if audio.digest(path) != entry[hash_key]:
                raise ValueError("candidate bytes changed: " + entry["id"])
        if not entry["provenance"]["prompt_seed_and_output_prefix_verified"] or entry["subjective_review_passed"]:
            raise ValueError("candidate provenance or review status is inconsistent")
    name = checks.USER_DIR_PREFIX + uuid.uuid4().hex
    try:
        with tempfile.TemporaryDirectory(prefix="piggame-candidate-import-") as temporary:
            stage = Path(temporary)
            (stage / "candidates").mkdir()
            shutil.copytree(directory / "prepared", stage / "candidates/prepared")
            shutil.copy2(directory / "manifest.json", stage / "candidates/manifest.json")
            shutil.copy2(ROOT / "tests/generated_audio_probe.gd", stage / "probe.gd")
            (stage / "project.godot").write_text("config_version=5\n[application]\nconfig/name=\"Piggame candidate audio probe\"\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name=\"" + name + "\"\n[rendering]\nrenderer/rendering_method=\"gl_compatibility\"\n")
            environment = {**os.environ, "PIGGAME_EXPECTED_USER_DIR":name}
            common = [str(checks.DEFAULT_GODOT), "--headless", "--audio-driver", "Dummy", "--path", str(stage)]
            for label, flags in (("import", ["--editor", "--quit"]), ("probe", ["--script", "res://probe.gd"])):
                result = subprocess.run(common + flags, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
                (arguments.output / (label + ".log")).write_text(result.stdout)
                if checks.result_exit_code(result, label, None) or "ObjectDB instances leaked" in result.stdout or "resources still in use at exit" in result.stdout:
                    raise RuntimeError(result.stdout)
                if label == "probe" and not re.search(r"^CLOUD_AUDIO_PROBE: assertions=84 failures=0 candidates=20 physical_output=false$", result.stdout, re.MULTILINE):
                    raise ValueError("candidate probe did not produce the expected completion marker")
                print(result.stdout.strip())
    finally:
        checks.remove_isolated_user_data(Path.home() / "Library/Application Support", name)
    if source_tree_sha256(ROOT) != source_hash:
        raise ValueError("production sources changed during candidate validation")
    report = {"candidate_count":20, "godot_import_passed":True, "godot_assertions":84, "production_source_sha256":source_hash, "production_sources_changed":False, "physical_output_tested":False, "subjective_review_passed":False, "final_audio_accepted":False, "prepared_bytes":sum(entry["prepared_bytes"] for entry in entries)}
    (arguments.output / "validation.json").write_text(json.dumps(report, indent=2) + "\n")


if __name__ == "__main__":
    main()
