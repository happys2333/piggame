#!/usr/bin/env python3
"""Sequentially export and load Full/Demo packs and emit a candidate identity record."""

from __future__ import annotations

from datetime import date
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import uuid

import run_godot_checks as checks
import validate_release_candidate as candidate


ROOT = Path(__file__).resolve().parents[1]
PROFILES = (("full", "Windows x64"), ("demo", "Windows x64 Demo"))


def run(command: list[str], environment: dict[str, str] | None = None) -> str:
    print("COMMAND:", command, flush=True)
    completed = subprocess.run(
        command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        text=True, timeout=300, env=environment,
    )
    print(completed.stdout, flush=True)
    if checks.result_exit_code(completed, "validation candidate", None) != 0:
        raise RuntimeError("validation candidate command failed")
    return completed.stdout


def identity(path: Path) -> dict:
    return {"size_bytes": path.stat().st_size, "sha256": candidate.file_sha256(path)}


def main() -> None:
    source_hash = candidate.source_tree_sha256(ROOT)
    godot = str(checks.DEFAULT_GODOT)
    user_name = checks.USER_DIR_PREFIX + uuid.uuid4().hex
    support = Path.home() / "Library/Application Support"
    package_dir = ROOT / "build/validation/package"
    package_dir.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix="piggame-validation-candidate-") as directory:
            staging = Path(directory) / "project"
            checks.stage_project(ROOT, staging, user_name)
            (staging / "override.cfg").unlink()
            for relative in candidate.SOURCE_INPUT_FILES:
                destination = staging / relative
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT / relative, destination)
            shutil.copytree(ROOT / "LICENSES", staging / "LICENSES")
            if candidate.source_tree_sha256(staging) != source_hash:
                raise RuntimeError("staged export inputs differ from the source snapshot")
            common = [godot, "--headless", "--audio-driver", "Dummy", "--path", str(staging)]
            run(common + ["--editor", "--quit"])
            for profile, preset in PROFILES:
                run(common + ["--export-pack", preset, str(package_dir / (profile + ".zip"))])
            manifest = json.loads((ROOT / "docs/release/candidate-manifest.json").read_text())
            for item in manifest["artifacts"]:
                output = ROOT / item["path"]
                output.parent.mkdir(parents=True, exist_ok=True)
                run(common + ["--export-release", dict(PROFILES)[item["profile"]], str(output)])
            run([sys.executable, str(ROOT / "tools/validate_export_package.py"),
                 *(str(package_dir / (profile + ".zip")) for profile, _ in PROFILES)])
            for profile, _ in PROFILES:
                original = package_dir / (profile + ".zip")
                load_root = Path(directory) / ("load-" + profile)
                load_root.mkdir()
                local_pack = load_root / original.name
                shutil.copy2(original, local_pack)
                if candidate.file_sha256(local_pack) != candidate.file_sha256(original):
                    raise RuntimeError("pack copy changed bytes")
                (load_root / "override.cfg").write_text(
                    "[application]\n\nconfig/use_custom_user_dir=true\n"
                    f'config/custom_user_dir_name="{user_name}"\n', encoding="utf-8",
                )
                environment = os.environ.copy()
                environment["PIGGAME_EXPECTED_USER_DIR"] = user_name
                environment["PIGGAME_EXPECTED_APP_TYPE"] = "0" if profile == "full" else "1"
                output = run(
                    [godot, "--headless", "--audio-driver", "Dummy", "--path", str(load_root),
                     "--main-pack", str(local_pack), "--script", str(ROOT / "tests/export_pack_probe.gd")],
                    environment,
                )
                marker = f"PASS: exported pack startup app_type={environment['PIGGAME_EXPECTED_APP_TYPE']} visuals=218 frames=4 residents=2 cache<=8 silent=true protection=true timer=25/5 personalities=5 performances=9/9/6/2"
                if output.splitlines().count(marker) != 1:
                    raise RuntimeError("pack startup did not produce the complete success marker")
            if candidate.source_tree_sha256(ROOT) != source_hash:
                raise RuntimeError("source inputs changed during exports")
            manifest["generated_date"] = date.today().isoformat()
            manifest["source_tree_sha256"] = source_hash
            for item in manifest["artifacts"]:
                item.update(identity(ROOT / item["path"]))
            record = {"manifest": manifest, "packs": {profile: identity(package_dir / (profile + ".zip")) for profile, _ in PROFILES}}
            print("CANDIDATE_RECORD=" + json.dumps(record, sort_keys=True), flush=True)
    finally:
        checks.remove_isolated_user_data(support, user_name)
        print("CLEANUP:", user_name, "removed", flush=True)


if __name__ == "__main__":
    main()
