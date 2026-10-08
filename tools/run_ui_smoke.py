#!/usr/bin/env python3
"""Run the real-render Godot UI smoke test in an isolated temporary project."""

from __future__ import annotations

import argparse
from datetime import datetime, timezone
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path
from typing import Any


DEFAULT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_GODOT = Path("/Applications/Godot.app/Contents/MacOS/Godot")
DEFAULT_EVIDENCE_ROOT = Path.home() / "Library/Caches/piggame/ui-evidence"
USER_DIR_PREFIX = "PiggameUISmoke-"
GODOT_TIMEOUT_SECONDS = 300
STAGED_DIRECTORIES = ("game", "tests")
STAGED_FILES = ("project.godot",)
INPUT_EXCLUDED_DIRECTORIES = {".godot", "__pycache__"}
INPUT_EXCLUDED_SUFFIXES = {".import", ".pyc", ".pyo"}
VALIDATION_OUTPUT_SUFFIXES = {".png"}
EXPECTED_UI_SMOKE_ASSERTIONS = 4157
EXPECTED_GENERATED_ART_ASSERTIONS = 772
VALIDATION_STABILITY_SECONDS = 90.0
VALIDATION_STABILITY_POLL_SECONDS = 1.0
VALIDATION_RECONCILIATION_TIMEOUT_SECONDS = 300.0
UI_SMOKE_PASS_PATTERN = re.compile(r"(?m)^PASS: ([0-9]+) UI smoke assertions$")
UI_SMOKE_PRIVATE_ENTRY_CALL_PATTERN = re.compile(
    r'\.call\("_(open_album|open_settings|open_legal|open_help|open_tendency|menu_action|finish)"'
)
UI_SMOKE_PUBLIC_ENTRY_CALL_PATTERN = re.compile(r"\.(open_album|play_next_pending_memory)\s*\(")
UI_SMOKE_EVENT_ENTRY_CALL_PATTERN = re.compile(r'\.call\("_play_event"|\._play_event\s*\(')
GDSCRIPT_FUNCTION_PATTERN = re.compile(r"^func\s+([A-Za-z0-9_]+)\s*\(")
ALLOWED_PRIVATE_EVENT_FIXTURE_CALLS = {"_test_event_branch_handoff": 1}
VALIDATION_CONFLICT_COPY_PATTERN = re.compile(r"^(?P<name>.+) [2-9][0-9]*$")
EXPECTED_VALIDATION_OUTPUT_COUNTS = {
    ".": 63,
    "atmosphere": 5,
    "behaviors": 36,
    "events": 24,
    "expressions": 1,
    "furniture": 32,
    "outfits": 13,
    "performances": 19,
}
FATAL_GODOT_OUTPUT_MARKERS = (
    "ERROR:",
    "SCRIPT ERROR:",
    "Parse Error:",
    "Failed to load script",
    "Cannot load source code",
)


def godot_output_has_fatal_error(output: str) -> bool:
    return any(marker in output for marker in FATAL_GODOT_OUTPUT_MARKERS)


def run_godot(command: list[str]) -> subprocess.CompletedProcess[str]:
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
    return completed


def godot_exit_code(completed: subprocess.CompletedProcess[str]) -> int:
    if completed.returncode != 0:
        return completed.returncode
    if godot_output_has_fatal_error(completed.stdout or ""):
        print(
            "UI smoke runner detected a fatal Godot script error despite a zero exit status.",
            file=sys.stderr,
        )
        return 1
    return 0


def ui_smoke_exit_code(completed: subprocess.CompletedProcess[str]) -> int:
    exit_code = godot_exit_code(completed)
    if exit_code != 0:
        return exit_code
    assertion_counts = UI_SMOKE_PASS_PATTERN.findall(completed.stdout or "")
    expected = str(EXPECTED_UI_SMOKE_ASSERTIONS)
    if assertion_counts != [expected]:
        print(
            "UI smoke runner expected exactly one "
            f"'PASS: {expected} UI smoke assertions' marker; got {assertion_counts}.",
            file=sys.stderr,
        )
        return 1
    return 0


def generated_art_exit_code(completed: subprocess.CompletedProcess[str]) -> int:
    exit_code = godot_exit_code(completed)
    if exit_code != 0:
        return exit_code
    counts = re.findall(r"(?m)^PASS: ([0-9]+) generated art regression assertions$", completed.stdout or "")
    if counts != [str(EXPECTED_GENERATED_ART_ASSERTIONS)]:
        print(f"Generated art runner expected exactly one complete PASS marker; got {counts}.", file=sys.stderr)
        return 1
    return 0


def validate_user_dir_name(name: str) -> None:
    if not re.fullmatch(rf"{USER_DIR_PREFIX}[0-9a-f]{{32}}", name):
        raise ValueError(f"unsafe UI smoke user directory name: {name!r}")


def custom_user_data_path(name: str, application_support: Path) -> Path:
    validate_user_dir_name(name)
    return application_support.resolve() / name


def validate_ui_smoke_player_entry_paths(source_root: Path) -> None:
    smoke_source = source_root.resolve() / "tests" / "ui_smoke.gd"
    if not smoke_source.is_file():
        raise FileNotFoundError(f"required UI smoke source file is missing: {smoke_source}")
    contents = smoke_source.read_text(encoding="utf-8")
    violations = set(UI_SMOKE_PRIVATE_ENTRY_CALL_PATTERN.findall(contents))
    violations.update(UI_SMOKE_PUBLIC_ENTRY_CALL_PATTERN.findall(contents))
    current_function = "<top-level>"
    allowed_event_calls: dict[str, int] = {}
    for line_number, line in enumerate(contents.splitlines(), start=1):
        function_match = GDSCRIPT_FUNCTION_PATTERN.match(line)
        if function_match:
            current_function = function_match.group(1)
        if not UI_SMOKE_EVENT_ENTRY_CALL_PATTERN.search(line):
            continue
        allowed_count = ALLOWED_PRIVATE_EVENT_FIXTURE_CALLS.get(current_function, 0)
        observed_count = allowed_event_calls.get(current_function, 0) + 1
        allowed_event_calls[current_function] = observed_count
        if observed_count > allowed_count:
            violations.add(f"_play_event in {current_function} at line {line_number}")
    sorted_violations = sorted(violations)
    if sorted_violations:
        raise ValueError(
            "UI smoke must trigger player-facing entries through real Button.pressed signals; "
            f"entry bypasses remain: {', '.join(sorted_violations)}"
        )


def stage_project(source_root: Path, staging_root: Path, user_dir_name: str) -> None:
    validate_user_dir_name(user_dir_name)
    source_root = source_root.resolve()
    validate_ui_smoke_player_entry_paths(source_root)
    staging_root.mkdir(parents=True, exist_ok=True)
    for relative in STAGED_FILES:
        source = source_root / relative
        if not source.is_file():
            raise FileNotFoundError(f"required UI smoke source file is missing: {source}")
        shutil.copy2(source, staging_root / relative)
    for relative in STAGED_DIRECTORIES:
        source = source_root / relative
        if not source.is_dir():
            raise FileNotFoundError(f"required UI smoke source directory is missing: {source}")
        shutil.copytree(source, staging_root / relative)
    (staging_root / "override.cfg").write_text(
        "[application]\n\n"
        "config/use_custom_user_dir=true\n"
        f'config/custom_user_dir_name="{user_dir_name}"\n',
        encoding="utf-8",
    )


def file_identity(path: Path, relative: str) -> dict[str, str | int]:
    digest = hashlib.sha256()
    size_bytes = 0
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
            size_bytes += len(chunk)
    return {"path": relative, "size_bytes": size_bytes, "sha256": digest.hexdigest()}


def staged_input_identity(staging_root: Path) -> dict[str, Any]:
    paths = [staging_root / relative for relative in STAGED_FILES]
    for relative in STAGED_DIRECTORIES:
        paths.extend(
            path for path in (staging_root / relative).rglob("*")
            if path.is_file()
            and not INPUT_EXCLUDED_DIRECTORIES.intersection(path.relative_to(staging_root).parts)
            and path.suffix.lower() not in INPUT_EXCLUDED_SUFFIXES
        )
    identities = [
        file_identity(path, path.relative_to(staging_root).as_posix())
        for path in sorted(paths)
    ]
    encoded = json.dumps(identities, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {
        "scope": [*STAGED_FILES, *(f"{relative}/**" for relative in STAGED_DIRECTORIES)],
        "excluded_directories": sorted(INPUT_EXCLUDED_DIRECTORIES),
        "excluded_suffixes": sorted(INPUT_EXCLUDED_SUFFIXES),
        "tree_sha256": hashlib.sha256(encoded).hexdigest(),
        "file_count": len(identities),
        "files": identities,
    }


def capture_validation_provenance(staging_root: Path, godot: Path) -> dict[str, Any]:
    runner = Path(__file__).resolve()
    return {
        "captured_at_utc": datetime.now(timezone.utc).isoformat(),
        "source_inputs": staged_input_identity(staging_root),
        "user_data_override": file_identity(staging_root / "override.cfg", "override.cfg"),
        "runner": file_identity(runner, str(runner)),
        "engine": file_identity(godot, str(godot)),
    }


def write_verified_evidence(path: Path, contents: bytes) -> dict[str, str | int]:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(contents)
    identity = file_identity(path, path.name)
    if identity["sha256"] != hashlib.sha256(contents).hexdigest():
        raise ValueError(f"UI evidence copy identity mismatch: {path}")
    return identity


def persist_validation_evidence(
    staging_root: Path,
    evidence_root: Path,
    completed: subprocess.CompletedProcess[str],
    provenance: dict[str, Any],
    imported: subprocess.CompletedProcess[str],
) -> Path:
    if ui_smoke_exit_code(completed) != 0 or godot_exit_code(imported) != 0:
        raise ValueError("cannot preserve failed UI rendering as verified evidence")
    if (
        staged_input_identity(staging_root) != provenance["source_inputs"]
        or file_identity(staging_root / "override.cfg", "override.cfg") != provenance["user_data_override"]
    ):
        raise ValueError("UI smoke staged input identity changed after provenance capture")
    staged_output = staging_root / "build/validation/ui"
    outputs = sorted(
        path for path in staged_output.rglob("*")
        if path.is_file() and path.suffix.lower() in VALIDATION_OUTPUT_SUFFIXES
    )
    validate_expected_validation_outputs(staged_output, outputs)
    evidence_root = evidence_root.resolve()
    evidence_root.mkdir(parents=True, exist_ok=True)
    destination = Path(tempfile.mkdtemp(prefix="ui-smoke-", dir=evidence_root))
    try:
        identities: list[dict[str, str | int]] = []
        for source in outputs:
            relative = source.relative_to(staged_output)
            target = destination / "png" / relative
            identity = write_verified_evidence(target, source.read_bytes())
            identity["path"] = relative.as_posix()
            identities.append(identity)
        runtime_identity = {
            **write_verified_evidence(destination / "runtime.log", (completed.stdout or "").encode("utf-8")),
            "command": completed.args,
        }
        import_identity = {
            **write_verified_evidence(destination / "import.log", (imported.stdout or "").encode("utf-8")),
            "command": imported.args,
        }
        engine_banner = next(
            (line for line in (completed.stdout or "").splitlines() if line.startswith("Godot Engine v")),
            "unreported",
        )
        write_verified_evidence(
            destination / "identity.json",
            json.dumps({
                "schema_version": 1,
                "stage": "verified-ui-rendering",
                "created_at_utc": datetime.now(timezone.utc).isoformat(),
                "provenance": provenance,
                "engine_banner": engine_banner,
                "assertions": EXPECTED_UI_SMOKE_ASSERTIONS,
                "png_count": len(identities),
                "runtime": runtime_identity,
                "import": import_identity,
                "files": identities,
            }, indent=2).encode("utf-8") + b"\n",
        )
    except BaseException:
        shutil.rmtree(destination)
        raise
    return destination


def copy_validation_outputs(staging_root: Path, source_root: Path) -> list[Path]:
    staged_output = staging_root / "build" / "validation" / "ui"
    target_output = source_root / "build" / "validation" / "ui"
    if target_output.exists():
        if not target_output.is_dir():
            raise ValueError(f"UI validation output path is not a directory: {target_output}")
    target_output.mkdir(parents=True, exist_ok=True)
    sources = (
        sorted(
            path
            for path in staged_output.rglob("*")
            if path.is_file() and path.suffix.lower() in VALIDATION_OUTPUT_SUFFIXES
        )
        if staged_output.is_dir()
        else []
    )
    expected_relatives = {source.relative_to(staged_output) for source in sources}
    for target in sorted(path for path in target_output.rglob("*") if path.is_file()):
        if target.relative_to(target_output) not in expected_relatives:
            target.unlink()
    directories = sorted(
        (path for path in target_output.rglob("*") if path.is_dir()),
        key=lambda path: len(path.parts),
        reverse=True,
    )
    for directory in directories:
        try:
            directory.rmdir()
        except OSError:
            pass
    copied: list[Path] = []
    for source in sources:
        relative = source.relative_to(staged_output)
        target = target_output / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        copied.append(target)
    removed = remove_validation_conflict_copies(target_output, copied)
    if removed:
        print(f"Removed {removed} UI validation conflict copies during synchronization.")
    return copied


def validate_validation_output_inventory(target_output: Path, expected: list[Path]) -> None:
    expected_files = set(expected)
    actual_files = (
        {path for path in target_output.rglob("*") if path.is_file()}
        if target_output.is_dir()
        else set()
    )
    if actual_files == expected_files:
        return
    missing = sorted(
        path.relative_to(target_output).as_posix()
        for path in expected_files - actual_files
    )
    unexpected = sorted(
        path.relative_to(target_output).as_posix()
        for path in actual_files - expected_files
    )
    details: list[str] = []
    if missing:
        details.append(f"missing: {', '.join(missing)}")
    if unexpected:
        details.append(f"unexpected: {', '.join(unexpected)}")
    raise ValueError(f"UI validation output inventory mismatch ({'; '.join(details)})")


def remove_validation_conflict_copies(target_output: Path, expected: list[Path]) -> int:
    expected_files = set(expected)
    actual_files = (
        {path for path in target_output.rglob("*") if path.is_file()}
        if target_output.is_dir()
        else set()
    )
    missing = expected_files - actual_files
    unexpected = actual_files - expected_files
    conflicts: list[Path] = []
    if not missing and unexpected:
        for path in unexpected:
            match = VALIDATION_CONFLICT_COPY_PATTERN.fullmatch(path.stem)
            canonical = path.with_name(f"{match.group('name')}{path.suffix}") if match else None
            if path.suffix.lower() != ".png" or canonical not in expected_files:
                break
            conflicts.append(path)
        else:
            for path in conflicts:
                path.unlink(missing_ok=True)
            return len(conflicts)
    validate_validation_output_inventory(target_output, expected)
    return 0


def wait_for_stable_validation_output_inventory(
    target_output: Path,
    expected: list[Path],
    stability_seconds: float = VALIDATION_STABILITY_SECONDS,
    poll_seconds: float = VALIDATION_STABILITY_POLL_SECONDS,
    timeout_seconds: float = VALIDATION_RECONCILIATION_TIMEOUT_SECONDS,
) -> None:
    if stability_seconds < 0.0:
        raise ValueError("UI validation stability duration cannot be negative")
    if poll_seconds <= 0.0:
        raise ValueError("UI validation stability poll interval must be positive")
    if timeout_seconds < stability_seconds:
        raise ValueError("UI validation reconciliation timeout is shorter than stability duration")
    started = time.monotonic()
    quiet_since = started
    deadline = started + timeout_seconds
    while True:
        now = time.monotonic()
        try:
            validate_validation_output_inventory(target_output, expected)
        except ValueError:
            removed = remove_validation_conflict_copies(target_output, expected)
            quiet_since = now
            print(
                f"Removed {removed} delayed UI validation conflict copies; "
                f"restarting the {stability_seconds:g}-second stability window."
            )
        if now - quiet_since >= stability_seconds:
            return
        if now >= deadline:
            raise ValueError(
                "UI validation output inventory did not remain stable before the "
                f"{timeout_seconds:g}-second reconciliation timeout"
            )
        time.sleep(
            min(
                poll_seconds,
                stability_seconds - (now - quiet_since),
                deadline - now,
            )
        )


def validate_expected_validation_outputs(output_root: Path, outputs: list[Path]) -> None:
    actual_counts: dict[str, int] = {}
    for output in outputs:
        relative = output.relative_to(output_root)
        category = relative.parent.as_posix()
        actual_counts[category] = actual_counts.get(category, 0) + 1
    if actual_counts != EXPECTED_VALIDATION_OUTPUT_COUNTS:
        raise ValueError(
            f"UI validation output categories differ from the expected {sum(EXPECTED_VALIDATION_OUTPUT_COUNTS.values())}-file evidence set: "
            f"expected {EXPECTED_VALIDATION_OUTPUT_COUNTS}, got {actual_counts}"
        )


def remove_isolated_user_data(application_support: Path, user_dir_name: str) -> None:
    target = custom_user_data_path(user_dir_name, application_support)
    expected_parent = application_support.resolve()
    if target.parent != expected_parent or not target.name.startswith(USER_DIR_PREFIX):
        raise ValueError(f"refusing to remove unexpected UI smoke path: {target}")
    if target.is_dir():
        shutil.rmtree(target)
    elif target.exists():
        raise ValueError(f"refusing to remove non-directory UI smoke path: {target}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run tests/ui_smoke.tscn without changing HOME or player save data."
    )
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--godot", type=Path, default=DEFAULT_GODOT)
    parser.add_argument("--evidence-root", type=Path, default=DEFAULT_EVIDENCE_ROOT)
    parser.add_argument("--generated-art-regressions", action="store_true", help="run the focused four-frame scaling and photo isolation regressions without replacing full UI evidence")
    return parser.parse_args()


def main() -> int:
    arguments = parse_args()
    focused = getattr(arguments, "generated_art_regressions", False)
    source_root = arguments.root.resolve()
    godot = arguments.godot.resolve()
    if sys.platform != "darwin":
        print("UI smoke runner currently supports the macOS development host only.", file=sys.stderr)
        return 2
    if not godot.is_file():
        print(f"Godot executable does not exist: {godot}", file=sys.stderr)
        return 2
    user_dir_name = USER_DIR_PREFIX + uuid.uuid4().hex
    application_support = Path.home() / "Library" / "Application Support"
    exit_code = 2
    cleanup_failed = False
    try:
        with tempfile.TemporaryDirectory(prefix="piggame-ui-smoke-") as directory:
            staging_root = Path(directory) / "project"
            stage_project(source_root, staging_root, user_dir_name)
            provenance = capture_validation_provenance(staging_root, godot)
            import_command = [
                str(godot),
                "--headless",
                "--audio-driver",
                "Dummy",
                "--path",
                str(staging_root),
                "--import",
            ]
            imported = run_godot(import_command)
            import_exit_code = godot_exit_code(imported)
            if import_exit_code != 0:
                return import_exit_code
            command = [
                str(godot),
                "--path",
                str(staging_root),
                "--rendering-driver",
                "opengl3",
                "--audio-driver",
                "Dummy",
                "res://tests/generated_art_regressions.tscn" if focused else "res://tests/ui_smoke.tscn",
            ]
            completed = run_godot(command)
            if focused:
                exit_code = generated_art_exit_code(completed)
            else:
                smoke_exit_code = ui_smoke_exit_code(completed)
                if smoke_exit_code == 0:
                    evidence = persist_validation_evidence(
                        staging_root, arguments.evidence_root, completed, provenance, imported,
                    )
                    print(f"Preserved verified UI rendering evidence at {evidence}")
                copied = copy_validation_outputs(staging_root, source_root)
                validate_expected_validation_outputs(
                    source_root / "build" / "validation" / "ui",
                    copied,
                )
                if smoke_exit_code == 0:
                    wait_for_stable_validation_output_inventory(
                        source_root / "build" / "validation" / "ui",
                        copied,
                    )
                if copied:
                    print(
                        f"Copied and verified {len(copied)} UI validation files to "
                        f"{source_root / 'build/validation/ui'}"
                    )
                exit_code = smoke_exit_code
    except (OSError, ValueError, subprocess.SubprocessError) as error:
        print(f"UI smoke runner failed: {error}", file=sys.stderr)
    finally:
        try:
            remove_isolated_user_data(application_support, user_dir_name)
        except (OSError, ValueError) as error:
            print(f"UI smoke cleanup failed: {error}", file=sys.stderr)
            cleanup_failed = True
    return 2 if cleanup_failed else exit_code


if __name__ == "__main__":
    sys.exit(main())
