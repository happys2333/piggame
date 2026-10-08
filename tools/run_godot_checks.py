#!/usr/bin/env python3
"""Run non-rendering Godot checks with strict output and save isolation."""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path


DEFAULT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
USER_DIR_PREFIX = "PiggameGodotChecks-"
GODOT_TIMEOUT_SECONDS = 300
STAGED_DIRECTORIES = ("game", "tests")
STAGED_FILES = ("project.godot", "export_presets.cfg")
DEMO_PROFILE_EXPORT_PRESET = "Windows x64 Demo"
DEMO_PROFILE_PACK_FILENAME = "demo-profile-audit.zip"
FATAL_GODOT_OUTPUT_MARKERS = (
    "ERROR:",
    "SCRIPT ERROR:",
    "Parse Error:",
    "Failed to load script",
    "Cannot load source code",
)
CORE_RULES_PASS_MARKER = "PASS: 7062 assertions"
FULL_PROGRESSION_PASS_MARKER = (
    "PASS-CONTRACT: progression first_furniture=567s levels=2:1223,3:1369,4:1550,5:1708 "
    "event_assisted_level10=32520s level10=38165s ending=36225s first_memory=75s "
    "events=24 shop=12016 points=8h:4265,12h:6356,20h:10510,30h:15795,48h:25234,72h:37976 "
    "cadence=35100s sessions=39 items=39/39 max_empty=0"
)
DEMO_PROGRESSION_PASS_MARKER = (
    "PASS-CONTRACT: demo completion=1800s level=5 points=54 events=4 furniture=2"
)
DEMO_PROFILE_PASS_MARKER = (
    "PASS-CONTRACT: demo profile feature=true areas=sleep furniture=6 expressions=8 events=4 "
    "docks=bottom,left save_root=piggy_did_nothing_today_demo assertions=75"
)
CHECKS = (
    ("headless import", ("--editor", "--quit"), None),
    ("headless startup", ("--quit-after", "5"), None),
    (
        "core rules",
        ("--script", "res://tests/test_runner.gd"),
        CORE_RULES_PASS_MARKER,
    ),
    (
        "full progression",
        ("--script", "res://tests/progression_audit.gd"),
        FULL_PROGRESSION_PASS_MARKER,
    ),
    (
        "demo progression",
        ("--script", "res://tests/demo_progression_audit.gd"),
        DEMO_PROGRESSION_PASS_MARKER,
    ),
)


def validate_user_dir_name(name: str) -> None:
    if not re.fullmatch(rf"{USER_DIR_PREFIX}[0-9a-f]{{32}}", name):
        raise ValueError(f"unsafe Godot check user directory name: {name!r}")


def custom_user_data_path(name: str, application_support: Path) -> Path:
    validate_user_dir_name(name)
    return application_support.resolve() / name


def stage_project(
    source_root: Path,
    staging_root: Path,
    user_dir_name: str,
) -> None:
    validate_user_dir_name(user_dir_name)
    source_root = source_root.resolve()
    staging_root.mkdir(parents=True, exist_ok=True)
    for relative in STAGED_FILES:
        source = source_root / relative
        if not source.is_file():
            raise FileNotFoundError(f"required Godot check source file is missing: {source}")
        shutil.copy2(source, staging_root / relative)
    for relative in STAGED_DIRECTORIES:
        source = source_root / relative
        if not source.is_dir():
            raise FileNotFoundError(f"required Godot check source directory is missing: {source}")
        shutil.copytree(source, staging_root / relative)
    (staging_root / "override.cfg").write_text(
        "[application]\n\n"
        "config/use_custom_user_dir=true\n"
        f'config/custom_user_dir_name="{user_dir_name}"\n',
        encoding="utf-8",
    )


def remove_isolated_user_data(application_support: Path, user_dir_name: str) -> None:
    target = custom_user_data_path(user_dir_name, application_support)
    expected_parent = application_support.resolve()
    if target.parent != expected_parent or not target.name.startswith(USER_DIR_PREFIX):
        raise ValueError(f"refusing to remove unexpected Godot check path: {target}")
    if target.is_dir():
        shutil.rmtree(target)
    elif target.exists():
        raise ValueError(f"refusing to remove non-directory Godot check path: {target}")


def build_command(godot: Path, project_root: Path, arguments: tuple[str, ...]) -> list[str]:
    return [
        str(godot),
        "--headless",
        "--audio-driver",
        "Dummy",
        "--path",
        str(project_root),
        *arguments,
    ]


def build_pack_command(godot: Path, pack_path: Path, script_path: Path) -> list[str]:
    return [
        str(godot),
        "--headless",
        "--audio-driver",
        "Dummy",
        "--main-pack",
        str(pack_path),
        "--script",
        str(script_path),
    ]


def result_exit_code(
    completed: subprocess.CompletedProcess[str],
    label: str,
    required_pass_marker: str | None,
) -> int:
    output = completed.stdout or ""
    if completed.returncode != 0:
        return completed.returncode
    if any(marker in output for marker in FATAL_GODOT_OUTPUT_MARKERS):
        print(
            f"Godot check {label!r} reported a fatal error despite a zero exit status.",
            file=sys.stderr,
        )
        return 1
    if required_pass_marker is not None:
        marker_count = output.splitlines().count(required_pass_marker)
        if marker_count != 1:
            print(
                f"Godot check {label!r} expected exactly one PASS marker "
                f"{required_pass_marker!r}; got {marker_count}.",
                file=sys.stderr,
            )
            return 1
    return 0


def run_check(
    godot: Path,
    project_root: Path,
    label: str,
    arguments: tuple[str, ...],
    required_pass_marker: str | None,
) -> int:
    return run_command(
        build_command(godot, project_root, arguments),
        label,
        required_pass_marker,
    )


def run_command(
    command: list[str],
    label: str,
    required_pass_marker: str | None,
) -> int:
    print(f"[{label}]")
    completed = subprocess.run(
        command,
        check=False,
        timeout=GODOT_TIMEOUT_SECONDS,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    if completed.stdout:
        print(completed.stdout, end="" if completed.stdout.endswith("\n") else "\n")
    return result_exit_code(completed, label, required_pass_marker)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run isolated headless Godot import, startup, rules, progression, and Demo profile checks."
    )
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    return parser.parse_args()


def main() -> int:
    arguments = parse_args()
    source_root = arguments.root.resolve()
    godot = arguments.godot.resolve()
    if sys.platform != "darwin":
        print("Godot check runner currently supports the macOS development host only.", file=sys.stderr)
        return 2
    if not godot.is_file():
        print(f"Godot executable does not exist: {godot}", file=sys.stderr)
        return 2
    user_dir_name = USER_DIR_PREFIX + uuid.uuid4().hex
    application_support = Path.home() / "Library" / "Application Support"
    exit_code = 2
    cleanup_failed = False
    try:
        with tempfile.TemporaryDirectory(prefix="piggame-godot-checks-") as directory:
            staging_root = Path(directory) / "project"
            stage_project(source_root, staging_root, user_dir_name)
            exit_code = 0
            for label, check_arguments, required_pass_marker in CHECKS:
                exit_code = run_check(
                    godot,
                    staging_root,
                    label,
                    check_arguments,
                    required_pass_marker,
                )
                if exit_code != 0:
                    break
            if exit_code == 0:
                demo_pack = Path(directory) / DEMO_PROFILE_PACK_FILENAME
                exit_code = run_check(
                    godot,
                    staging_root,
                    "demo profile export",
                    ("--export-pack", DEMO_PROFILE_EXPORT_PRESET, str(demo_pack)),
                    None,
                )
                if exit_code == 0:
                    exit_code = run_command(
                        build_pack_command(
                            godot,
                            demo_pack,
                            staging_root / "tests" / "demo_profile_audit.gd",
                        ),
                        "demo profile",
                        DEMO_PROFILE_PASS_MARKER,
                    )
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"Godot check runner failed: {error}", file=sys.stderr)
    finally:
        try:
            remove_isolated_user_data(application_support, user_dir_name)
        except (OSError, ValueError) as error:
            print(f"Godot check cleanup failed: {error}", file=sys.stderr)
            cleanup_failed = True
    return 2 if cleanup_failed else exit_code


if __name__ == "__main__":
    sys.exit(main())
