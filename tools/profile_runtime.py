#!/usr/bin/env python3
"""Measure controlled render invalidations and catalogue-owned texture retention."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid

import run_godot_checks as checks
import validate_release_candidate as candidate


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    source_hash = candidate.source_tree_sha256(root)
    user_name = checks.USER_DIR_PREFIX + uuid.uuid4().hex
    try:
        with tempfile.TemporaryDirectory(prefix="piggame-runtime-profile-") as directory:
            staging = Path(directory) / "project"
            checks.stage_project(root, staging, user_name)
            imported = subprocess.run(
                checks.build_command(checks.DEFAULT_GODOT, staging, ("--editor", "--quit")),
                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300,
            )
            if checks.result_exit_code(imported, "profile import", None) != 0:
                raise RuntimeError(imported.stdout)
            environment = os.environ.copy()
            environment["PIGGAME_EXPECTED_USER_DIR"] = user_name
            completed = subprocess.run(
                [str(checks.DEFAULT_GODOT), "--audio-driver", "Dummy", "--path", str(staging),
                 "--script", "res://tests/runtime_profile.gd"],
                env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                text=True, timeout=120,
            )
            if checks.result_exit_code(completed, "runtime profile", None) != 0:
                raise RuntimeError(completed.stdout)
            records = [line.removeprefix("PROFILE=") for line in completed.stdout.splitlines() if line.startswith("PROFILE=")]
            if len(records) != 1:
                raise RuntimeError(completed.stdout)
            record = json.loads(records[0])
            record["source_tree_sha256"] = source_hash
            record["scope"] = "macOS controlled render/cache probe; not Windows CPU/FPS/working-set acceptance"
            print(json.dumps(record, indent=2, sort_keys=True))
    finally:
        checks.remove_isolated_user_data(Path.home() / "Library/Application Support", user_name)


if __name__ == "__main__":
    main()
