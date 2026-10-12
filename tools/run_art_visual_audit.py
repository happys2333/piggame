"""Capture real Godot artwork, animation, desktop and UI evidence in an isolated project."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

import run_godot_checks as checks
from validate_release_candidate import source_tree_sha256


ROOT = Path(__file__).resolve().parents[1]


def run(label: str, command: list[str], environment: dict[str, str], output: Path) -> None:
    try:
        result = subprocess.run(command, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
    except subprocess.TimeoutExpired as error:
        captured = error.stdout or ""
        if isinstance(captured, bytes):
            captured = captured.decode("utf-8", errors="replace")
        (output / (label + ".log")).write_text(captured + "\nFAIL: rendering audit timed out after 300 seconds\n")
        raise RuntimeError(label + " timed out; incomplete rendering is not accepted") from error
    (output / (label + ".log")).write_text(result.stdout)
    print(label, result.returncode, flush=True)
    if checks.result_exit_code(result, label, None):
        print(result.stdout, flush=True)
        raise RuntimeError(label + " failed")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--only", nargs="+", choices=("all", "art", "context", "continuity", "ui", "interaction", "mouth", "postcards", "copy", "menu", "outfits", "refinement"), default=["all"])
    arguments = parser.parse_args()
    output = arguments.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    name = checks.USER_DIR_PREFIX + uuid.uuid4().hex
    source_hash = source_tree_sha256(ROOT)
    script_hashes = {path.relative_to(ROOT).as_posix(): hashlib.sha256(path.read_bytes()).hexdigest() for path in (ROOT / "tests").glob("*.gd")}
    metadata = {"source_tree_sha256": source_hash, "test_scripts_sha256": script_hashes, "godot": str(checks.DEFAULT_GODOT), "real_rendering": True, "isolated_user_data": True, "complete": False, "validated_suites": []}
    (output / "source.json").write_text(json.dumps(metadata, indent=2) + "\n")
    support = Path.home() / "Library/Application Support"
    environment = os.environ.copy()
    environment["PIGGAME_EXPECTED_USER_DIR"] = name
    try:
        with tempfile.TemporaryDirectory(prefix="piggame-art-audit-") as temporary:
            stage = Path(temporary) / "project"
            checks.stage_project(ROOT, stage, name)
            common = [str(checks.DEFAULT_GODOT), "--audio-driver", "Dummy", "--path", str(stage)]
            run("import", common + ["--headless", "--editor", "--quit"], environment, output)
            for label, scene, variable in (
                ("refinement", "ui_refinement_audit", "PIGGAME_ART_AUDIT_DIR"),
                ("outfits", "pig_outfit_audit", "PIGGAME_ART_AUDIT_DIR"),
                ("menu", "desktop_context_audit", "PIGGAME_MENU_OUTPUT"),
                ("copy", "ui_copy_audit", "PIGGAME_ART_AUDIT_DIR"),
                ("postcards", "postcard_ui_audit", "PIGGAME_ART_AUDIT_DIR"),
                ("mouth", "pig_mouth_audit", "PIGGAME_ART_AUDIT_DIR"),
                ("interaction", "room_interaction_audit", "PIGGAME_ART_AUDIT_DIR"),
                ("art", "art_visual_audit", "PIGGAME_ART_AUDIT_DIR"),
                ("context", "art_context_audit", "PIGGAME_ART_AUDIT_DIR"),
                ("continuity", "pig_continuity_probe", "PIGGAME_MOTION_REVIEW_DIR"),
                ("ui", "pig_continuity_ui_probe", "PIGGAME_MOTION_REVIEW_DIR"),
            ):
                if "all" not in arguments.only and label not in arguments.only:
                    continue
                folder = output / label
                folder.mkdir(exist_ok=True)
                environment[variable] = str(folder)
                try:
                    run(label, common + [f"res://tests/{scene}.tscn"], environment, output)
                finally:
                    ui_output = stage / "build/validation/ui"
                    if ui_output.exists():
                        shutil.copytree(ui_output, output / "runtime-ui", dirs_exist_ok=True)
                    for screenshot in (support / name).glob("*.png"):
                        screenshot_folder = output / "user-screenshots"
                        screenshot_folder.mkdir(exist_ok=True)
                        shutil.copy2(screenshot, screenshot_folder / screenshot.name)
                if label == "outfits":
                    audit = json.loads((folder / "report.json").read_text())
                    inventory = audit["inventory"]
                    samples = len(inventory["bodies"]) * len(inventory["faces"]) * len(inventory["outfits"]) * 4 * 2
                    captures = len(inventory["bodies"]) * 8 * 2 + len(inventory["outfits"])
                    if audit["failures"] or audit["static_samples"] != samples or audit["runtime_samples"] != samples or len(audit["screenshots"]) != captures:
                        raise RuntimeError("incomplete joint accessory inventory")
                    if any(not (folder / filename).is_file() for filename in audit["screenshots"]):
                        raise RuntimeError("joint accessory capture is missing")
                if label == "art":
                    audit = json.loads((folder / "audit.json").read_text())
                    if audit["failures"] or len(audit["screenshots"]) < 30:
                        raise RuntimeError("incomplete visual inventory")
                if label == "menu":
                    audit = json.loads((folder / "report.json").read_text())
                    if audit["failures"] or len(audit["captures"]) != 45:
                        raise RuntimeError("incomplete desktop menu inventory")
                metadata["validated_suites"].append(label)
                (output / "source.json").write_text(json.dumps(metadata, indent=2) + "\n")
            ui_output = stage / "build/validation/ui"
            if ui_output.exists():
                shutil.copytree(ui_output, output / "runtime-ui", dirs_exist_ok=True)
            for screenshot in (support / name).glob("desktop-control-layout-*.png"):
                shutil.copy2(screenshot, output / "ui" / screenshot.name)
            if source_tree_sha256(ROOT) != source_hash:
                raise RuntimeError("source changed during the audit")
            if any(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() != expected for path, expected in script_hashes.items()):
                raise RuntimeError("test scripts changed during the audit")
            metadata["complete"] = True
            (output / "source.json").write_text(json.dumps(metadata, indent=2) + "\n")
    finally:
        checks.remove_isolated_user_data(support, name)


if __name__ == "__main__":
    main()
