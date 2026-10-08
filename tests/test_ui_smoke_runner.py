from __future__ import annotations

import argparse
import contextlib
import hashlib
import importlib.util
import io
import json
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest import mock


MODULE_PATH = Path(__file__).parents[1] / "tools" / "run_ui_smoke.py"
SPEC = importlib.util.spec_from_file_location("run_ui_smoke", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)
SAFE_NAME = RUNNER.USER_DIR_PREFIX + "a" * 32


def write_fake_project(root: Path) -> tuple[Path, Path]:
    source = root / "source"
    (source / "game").mkdir(parents=True)
    (source / "tests").mkdir()
    (source / "project.godot").write_text("config_version=5\n", encoding="utf-8")
    (source / "game/runtime.gd").write_text("extends Node\n", encoding="utf-8")
    (source / "tests/ui_smoke.gd").write_text("extends Node\n", encoding="utf-8")
    (source / "tests/ui_smoke.tscn").write_text("[gd_scene format=3]\n", encoding="utf-8")
    godot = root / "godot"
    godot.write_bytes(b"fixture Godot executable")
    return source, godot


def write_fake_outputs(staging: Path) -> list[Path]:
    target = staging / "build/validation/ui"
    paths: list[Path] = []
    for category, count in RUNNER.EXPECTED_VALIDATION_OUTPUT_COUNTS.items():
        parent = target if category == "." else target / category
        parent.mkdir(parents=True, exist_ok=True)
        for index in range(count):
            path = parent / f"fixture-{index}.png"
            path.write_bytes(f"fixture {category} {index}".encode())
            paths.append(path)
    return paths


def successful_run() -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(
        ["fixture-godot", "res://tests/ui_smoke.tscn"], 0,
        "Godot Engine v4.6.3.stable.official.7d41c59c4\n"
        f"PASS: {RUNNER.EXPECTED_UI_SMOKE_ASSERTIONS} UI smoke assertions\n",
    )


def successful_import() -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(
        ["fixture-godot", "--import"], 0,
        "Godot Engine v4.6.3.stable.official.7d41c59c4\nImport complete\n",
    )


class UiSmokeRunnerTests(unittest.TestCase):
    def test_evidence_records_preimport_inputs_engine_runner_and_logs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, godot = write_fake_project(root)
            staging = root / "staging"
            RUNNER.stage_project(source, staging, SAFE_NAME)
            provenance = RUNNER.capture_validation_provenance(staging, godot)
            outputs = write_fake_outputs(staging)
            destination = RUNNER.persist_validation_evidence(
                staging, root / "evidence", successful_run(), provenance, successful_import(),
            )
            manifest = json.loads((destination / "identity.json").read_text())
            self.assertEqual(manifest["provenance"], provenance)
            self.assertEqual(manifest["stage"], "verified-ui-rendering")
            self.assertEqual(manifest["assertions"], RUNNER.EXPECTED_UI_SMOKE_ASSERTIONS)
            self.assertEqual(manifest["png_count"], 193)
            self.assertTrue(manifest["created_at_utc"].endswith("+00:00"))
            self.assertTrue(provenance["captured_at_utc"].endswith("+00:00"))
            self.assertEqual(provenance["engine"]["sha256"], hashlib.sha256(godot.read_bytes()).hexdigest())
            self.assertEqual(provenance["runner"]["sha256"], hashlib.sha256(MODULE_PATH.read_bytes()).hexdigest())
            self.assertEqual(provenance["user_data_override"]["sha256"], hashlib.sha256((staging / "override.cfg").read_bytes()).hexdigest())
            self.assertEqual(manifest["engine_banner"], "Godot Engine v4.6.3.stable.official.7d41c59c4")
            self.assertEqual(manifest["runtime"]["command"], successful_run().args)
            self.assertEqual(manifest["import"]["command"], successful_import().args)
            for key in ("runtime", "import"):
                identity = manifest[key]
                contents = (destination / identity["path"]).read_bytes()
                self.assertEqual(identity["size_bytes"], len(contents))
                self.assertEqual(identity["sha256"], hashlib.sha256(contents).hexdigest())
            self.assertEqual(len(outputs), len(manifest["files"]))
            for identity in manifest["files"]:
                contents = (destination / "png" / identity["path"]).read_bytes()
                original = (staging / "build/validation/ui" / identity["path"]).read_bytes()
                self.assertEqual(contents, original)
                self.assertEqual(identity["size_bytes"], len(contents))
                self.assertEqual(identity["sha256"], hashlib.sha256(contents).hexdigest())

    def test_input_identity_ignores_generated_noise_but_detects_source_changes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, godot = write_fake_project(root)
            staging = root / "staging"
            RUNNER.stage_project(source, staging, SAFE_NAME)
            initial = RUNNER.capture_validation_provenance(staging, godot)["source_inputs"]
            write_fake_outputs(staging)
            cache = staging / "tests/__pycache__/fixture.pyc"
            cache.parent.mkdir()
            cache.write_bytes(b"generated cache")
            (staging / "game/runtime.gd.import").write_bytes(b"generated import metadata")
            unchanged = RUNNER.capture_validation_provenance(staging, godot)["source_inputs"]
            self.assertEqual(initial, unchanged)
            self.assertEqual(initial["file_count"], 4)
            self.assertEqual({entry["path"] for entry in initial["files"]}, {
                "project.godot", "game/runtime.gd", "tests/ui_smoke.gd", "tests/ui_smoke.tscn",
            })
            (staging / "game/runtime.gd").write_bytes(b"extends Control\n")
            changed = RUNNER.capture_validation_provenance(staging, godot)["source_inputs"]
            self.assertNotEqual(initial["tree_sha256"], changed["tree_sha256"])

    def test_rejects_staged_source_drift_after_provenance_capture(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, godot = write_fake_project(root)
            staging = root / "staging"
            RUNNER.stage_project(source, staging, SAFE_NAME)
            provenance = RUNNER.capture_validation_provenance(staging, godot)
            write_fake_outputs(staging)
            (staging / "game/runtime.gd").write_bytes(b"changed during rendering")
            with self.assertRaisesRegex(ValueError, "input identity changed"):
                RUNNER.persist_validation_evidence(
                    staging, root / "evidence", successful_run(), provenance, successful_import(),
                )
            self.assertFalse((root / "evidence").exists())

    def test_complete_generated_art_marker(self) -> None:
        output = f"PASS: {RUNNER.EXPECTED_GENERATED_ART_ASSERTIONS} generated art regression assertions\n"
        self.assertEqual(RUNNER.generated_art_exit_code(subprocess.CompletedProcess([], 0, output)), 0)

    def test_generated_art_rejects_failed_or_incomplete_output(self) -> None:
        output = f"PASS: {RUNNER.EXPECTED_GENERATED_ART_ASSERTIONS} generated art regression assertions\n"
        runs = (
            subprocess.CompletedProcess([], 1, output),
            subprocess.CompletedProcess([], 0, "ERROR: fixture\n" + output),
            subprocess.CompletedProcess([], 0, "missing marker"),
            subprocess.CompletedProcess([], 0, output * 2),
            subprocess.CompletedProcess([], 0, output.replace(str(RUNNER.EXPECTED_GENERATED_ART_ASSERTIONS), "1")),
        )
        for completed in runs:
            with self.subTest(output=completed.stdout), contextlib.redirect_stderr(io.StringIO()):
                self.assertNotEqual(RUNNER.generated_art_exit_code(completed), 0)

    def test_failed_or_reduced_run_never_creates_verified_evidence(self) -> None:
        failures = (
            subprocess.CompletedProcess([], 1, successful_run().stdout),
            subprocess.CompletedProcess([], 0, "ERROR: fixture\n" + successful_run().stdout),
            subprocess.CompletedProcess([], 0, "missing pass marker"),
            subprocess.CompletedProcess([], 0, f"PASS: {RUNNER.EXPECTED_UI_SMOKE_ASSERTIONS - 1} UI smoke assertions\n"),
            subprocess.CompletedProcess([], 0, successful_run().stdout * 2),
        )
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, godot = write_fake_project(root)
            staging = root / "staging"
            RUNNER.stage_project(source, staging, SAFE_NAME)
            provenance = RUNNER.capture_validation_provenance(staging, godot)
            write_fake_outputs(staging)
            for completed in failures:
                with self.subTest(output=completed.stdout), contextlib.redirect_stderr(io.StringIO()):
                    with self.assertRaises(ValueError):
                        RUNNER.persist_validation_evidence(
                            staging, root / "evidence", completed, provenance, successful_import(),
                        )
                    self.assertFalse((root / "evidence").exists())

    def test_missing_screenshot_never_creates_verified_evidence(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, godot = write_fake_project(root)
            staging = root / "staging"
            RUNNER.stage_project(source, staging, SAFE_NAME)
            provenance = RUNNER.capture_validation_provenance(staging, godot)
            write_fake_outputs(staging)[0].unlink()
            with self.assertRaisesRegex(ValueError, "categories differ"):
                RUNNER.persist_validation_evidence(
                    staging, root / "evidence", successful_run(), provenance, successful_import(),
                )
            self.assertFalse((root / "evidence").exists())

    def test_corrupt_evidence_copy_is_removed_without_touching_neighbors(self) -> None:
        for corrupted_name in ("fixture-0.png", "runtime.log", "import.log", "identity.json"):
            with self.subTest(file=corrupted_name), tempfile.TemporaryDirectory() as directory:
                self.check_corrupt_evidence_copy(Path(directory), corrupted_name)

    def check_corrupt_evidence_copy(self, root: Path, corrupted_name: str) -> None:
        source, godot = write_fake_project(root)
        staging = root / "staging"
        RUNNER.stage_project(source, staging, SAFE_NAME)
        provenance = RUNNER.capture_validation_provenance(staging, godot)
        write_fake_outputs(staging)
        evidence_root = (root / "evidence").resolve()
        neighbor = evidence_root / "existing-evidence/identity.json"
        neighbor.parent.mkdir(parents=True)
        neighbor.write_bytes(b"keep this evidence")
        original_write = Path.write_bytes

        def corrupt_copy(path: Path, contents: bytes) -> int:
            if evidence_root in path.parents and path.name == corrupted_name:
                contents += b"corrupted"
            return original_write(path, contents)

        with mock.patch.object(Path, "write_bytes", corrupt_copy):
            with self.assertRaisesRegex(ValueError, "copy identity mismatch"):
                RUNNER.persist_validation_evidence(
                    staging, evidence_root, successful_run(), provenance, successful_import(),
                )
        self.assertEqual(neighbor.read_bytes(), b"keep this evidence")
        self.assertEqual(list(evidence_root.iterdir()), [neighbor.parent])

    def test_evidence_write_failures_remove_only_current_directory(self) -> None:
        for failed_name in ("fixture-0.png", "runtime.log", "import.log", "identity.json"):
            with self.subTest(file=failed_name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source, godot = write_fake_project(root)
                staging = root / "staging"
                RUNNER.stage_project(source, staging, SAFE_NAME)
                provenance = RUNNER.capture_validation_provenance(staging, godot)
                write_fake_outputs(staging)
                evidence_root = (root / "evidence").resolve()
                neighbor = evidence_root / "existing-evidence/identity.json"
                neighbor.parent.mkdir(parents=True)
                neighbor.write_bytes(b"keep this evidence")
                original_open = Path.open

                def failing_open(path: Path, mode: str = "r", *args: object, **kwargs: object):
                    if evidence_root in path.parents and path.name == failed_name and "w" in mode:
                        raise OSError("fixture cache write failure")
                    return original_open(path, mode, *args, **kwargs)

                with mock.patch.object(Path, "open", failing_open):
                    with self.assertRaises(OSError):
                        RUNNER.persist_validation_evidence(
                            staging, evidence_root, successful_run(), provenance, successful_import(),
                        )
                self.assertEqual(neighbor.read_bytes(), b"keep this evidence")
                self.assertEqual(list(evidence_root.iterdir()), [neighbor.parent])

    def test_each_run_preserves_an_independent_evidence_directory(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, godot = write_fake_project(root)
            staging = root / "staging"
            RUNNER.stage_project(source, staging, SAFE_NAME)
            provenance = RUNNER.capture_validation_provenance(staging, godot)
            write_fake_outputs(staging)
            first = RUNNER.persist_validation_evidence(
                staging, root / "evidence", successful_run(), provenance, successful_import(),
            )
            original_identity = (first / "identity.json").read_bytes()
            second = RUNNER.persist_validation_evidence(
                staging, root / "evidence", successful_run(), provenance, successful_import(),
            )
            self.assertNotEqual(first, second)
            self.assertEqual((first / "identity.json").read_bytes(), original_identity)
            self.assertEqual(len(list((root / "evidence").iterdir())), 2)

    def test_main_captures_before_import_and_preserves_workspace_gates(self) -> None:
        for stability_error in (None, ValueError("fixture unstable mirror")):
            with self.subTest(stability_error=stability_error), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                source, godot = write_fake_project(root)
                evidence_root = root / "evidence"

                def run_fixture(command: list[str]) -> subprocess.CompletedProcess[str]:
                    capture.assert_called_once()
                    staging = Path(command[command.index("--path") + 1])
                    if "--import" in command:
                        return successful_import()
                    write_fake_outputs(staging)
                    return successful_run()

                with (
                    mock.patch.object(RUNNER, "parse_args", return_value=argparse.Namespace(
                        root=source, godot=godot, evidence_root=evidence_root,
                    )),
                    mock.patch.object(RUNNER.sys, "platform", "darwin"),
                    mock.patch.object(RUNNER, "capture_validation_provenance", wraps=RUNNER.capture_validation_provenance) as capture,
                    mock.patch.object(RUNNER, "run_godot", side_effect=run_fixture),
                    mock.patch.object(RUNNER, "wait_for_stable_validation_output_inventory", side_effect=stability_error) as stability,
                    mock.patch.object(RUNNER, "remove_isolated_user_data") as cleanup,
                    contextlib.redirect_stdout(io.StringIO()),
                    contextlib.redirect_stderr(io.StringIO()),
                ):
                    self.assertEqual(RUNNER.main(), 0 if stability_error is None else 2)
                    stability.assert_called_once()
                    cleanup.assert_called_once()
                self.assertEqual(len(list(evidence_root.iterdir())), 1)
                self.assertEqual(len(list((source / "build/validation/ui").rglob("*.png"))), 193)

    def test_retains_staged_evidence_when_workspace_copy_fails(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, godot = write_fake_project(root)
            evidence_root = root / "evidence"
            evidence_root.mkdir()

            def run_fixture(command: list[str]) -> subprocess.CompletedProcess[str]:
                output = "Godot Engine v4.6.3.stable.official.7d41c59c4\n"
                if "res://tests/ui_smoke.tscn" in command:
                    staging = Path(command[command.index("--path") + 1])
                    write_fake_outputs(staging)
                    output += f"PASS: {RUNNER.EXPECTED_UI_SMOKE_ASSERTIONS} UI smoke assertions\n"
                return subprocess.CompletedProcess(command, 0, output)

            with (
                mock.patch.object(RUNNER, "parse_args", return_value=argparse.Namespace(
                    root=source, godot=godot, evidence_root=evidence_root,
                )),
                mock.patch.object(RUNNER.sys, "platform", "darwin"),
                mock.patch.object(RUNNER, "run_godot", side_effect=run_fixture),
                mock.patch.object(RUNNER, "copy_validation_outputs", side_effect=OSError("fixture provider timeout")),
                mock.patch.object(RUNNER, "remove_isolated_user_data"),
                contextlib.redirect_stdout(io.StringIO()),
                contextlib.redirect_stderr(io.StringIO()),
            ):
                self.assertEqual(RUNNER.main(), 2)
            entries = list(evidence_root.iterdir())
            self.assertEqual(len(entries), 1)
            self.assertEqual(len(list((entries[0] / "png").rglob("*.png"))), 193)
            self.assertIn(f"PASS: {RUNNER.EXPECTED_UI_SMOKE_ASSERTIONS} UI smoke assertions", (entries[0] / "runtime.log").read_text())

    def test_accepts_clean_godot_output(self) -> None:
        completed = subprocess.CompletedProcess(
            args=["godot"],
            returncode=0,
            stdout=f"PASS: {RUNNER.EXPECTED_UI_SMOKE_ASSERTIONS} UI smoke assertions\n",
        )
        self.assertEqual(RUNNER.ui_smoke_exit_code(completed), 0)

    def test_rejects_fatal_godot_output_with_zero_exit_status(self) -> None:
        for marker in RUNNER.FATAL_GODOT_OUTPUT_MARKERS:
            with self.subTest(marker=marker):
                completed = subprocess.CompletedProcess(
                    args=["godot"],
                    returncode=0,
                    stdout=(
                        f"{marker} fixture failure\n"
                        f"PASS: {RUNNER.EXPECTED_UI_SMOKE_ASSERTIONS} UI smoke assertions\n"
                    ),
                )
                with contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(RUNNER.ui_smoke_exit_code(completed), 1)

    def test_rejects_missing_incorrect_or_duplicate_pass_markers(self) -> None:
        expected = RUNNER.EXPECTED_UI_SMOKE_ASSERTIONS
        outputs = (
            "clean exit without assertions\n",
            f"PASS: {expected - 1} UI smoke assertions\n",
            f"PASS: {expected} UI smoke assertions\nPASS: {expected} UI smoke assertions\n",
        )
        for output in outputs:
            with self.subTest(output=output):
                completed = subprocess.CompletedProcess(
                    args=["godot"],
                    returncode=0,
                    stdout=output,
                )
                with contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(RUNNER.ui_smoke_exit_code(completed), 1)

    def test_stages_only_runtime_and_test_sources(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            staging = root / "staging"
            (source / "game").mkdir(parents=True)
            (source / "tests").mkdir()
            (source / "build").mkdir()
            (source / "project.godot").write_text("config_version=5\n", encoding="utf-8")
            (source / "game" / "runtime.gd").write_text("extends Node\n", encoding="utf-8")
            (source / "tests" / "ui_smoke.gd").write_text("extends Node\n", encoding="utf-8")
            (source / "tests" / "ui_smoke.tscn").write_text("[gd_scene format=3]\n", encoding="utf-8")
            (source / "build" / "candidate.exe").write_bytes(b"must not be staged")
            RUNNER.stage_project(source, staging, SAFE_NAME)
            self.assertTrue((staging / "project.godot").is_file())
            self.assertTrue((staging / "game" / "runtime.gd").is_file())
            self.assertTrue((staging / "tests" / "ui_smoke.tscn").is_file())
            self.assertFalse((staging / "build").exists())
            override = (staging / "override.cfg").read_text(encoding="utf-8")
            self.assertIn(SAFE_NAME, override)

    def test_rejects_private_player_entry_calls(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            smoke_source = root / "tests" / "ui_smoke.gd"
            smoke_source.parent.mkdir(parents=True)
            smoke_source.write_text(
                "\n".join([
                    *(f'fixture.call("_{name}")' for name in (
                        "open_album",
                        "open_settings",
                        "open_legal",
                        "open_help",
                        "open_tendency",
                        "menu_action",
                        "finish",
                    )),
                    "fixture.play_next_pending_memory()",
                    "func _test_ending_flow() -> void:",
                    '\tui.call("_play_event", {}, true)',
                ]),
                encoding="utf-8",
            )
            with self.assertRaises(ValueError) as raised:
                RUNNER.validate_ui_smoke_player_entry_paths(root)
            message = str(raised.exception)
            self.assertIn("real Button.pressed signals", message)
            self.assertIn("open_album", message)
            self.assertIn("finish", message)
            self.assertIn("play_next_pending_memory", message)
            self.assertIn("_play_event in _test_ending_flow", message)
            smoke_source.write_text(
                "func _test_event_branch_handoff() -> void:\n"
                '\tui.call("_play_event", {}, true)\n',
                encoding="utf-8",
            )
            RUNNER.validate_ui_smoke_player_entry_paths(root)

    def test_copies_nested_validation_outputs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            staging = root / "staging"
            source = root / "source"
            output = staging / "build" / "validation" / "ui" / "expressions"
            output.mkdir(parents=True)
            (output / "fixture.png").write_bytes(b"rendered fixture")
            (output / "fixture.png.import").write_text("temporary import metadata", encoding="utf-8")
            stale_png = source / "build" / "validation" / "ui" / "stale.png"
            stale = source / "build" / "validation" / "ui" / "stale.png.import"
            stale.parent.mkdir(parents=True)
            target_inode = stale.parent.stat().st_ino
            stale_png.write_bytes(b"outdated screenshot")
            stale.write_text("stale import metadata", encoding="utf-8")
            copied = RUNNER.copy_validation_outputs(staging, source)
            target = source / "build" / "validation" / "ui" / "expressions" / "fixture.png"
            self.assertEqual(copied, [target])
            self.assertEqual(target.read_bytes(), b"rendered fixture")
            self.assertFalse((target.parent / "fixture.png.import").exists())
            self.assertFalse(stale_png.exists())
            self.assertFalse(stale.exists())
            self.assertEqual(stale.parent.stat().st_ino, target_inode)

    def test_clears_previous_validation_outputs_when_run_produces_none(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            staging = root / "staging"
            source = root / "source"
            stale = source / "build" / "validation" / "ui" / "stale.png"
            stale.parent.mkdir(parents=True)
            stale.write_bytes(b"outdated screenshot")
            copied = RUNNER.copy_validation_outputs(staging, source)
            self.assertEqual(copied, [])
            self.assertTrue(stale.parent.is_dir())
            self.assertEqual(list(stale.parent.iterdir()), [])

    def test_rejects_validation_output_inventory_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "build" / "validation" / "ui"
            expected = target / "expressions" / "fixture.png"
            unexpected = target / "expressions" / "fixture 2.png"
            unexpected.parent.mkdir(parents=True)
            unexpected.write_bytes(b"unexpected duplicate")
            with self.assertRaises(ValueError) as raised:
                RUNNER.validate_validation_output_inventory(target, [expected])
            message = str(raised.exception)
            self.assertIn("missing: expressions/fixture.png", message)
            self.assertIn("unexpected: expressions/fixture 2.png", message)

    def test_reconciles_delayed_validation_conflict_copy(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "build" / "validation" / "ui"
            expected = target / "expressions" / "fixture.png"
            unexpected = target / "expressions" / "fixture 2.png"
            expected.parent.mkdir(parents=True)
            expected.write_bytes(b"current screenshot")
            restored = False

            def restore_conflict(_seconds: float) -> None:
                nonlocal restored
                if not restored:
                    unexpected.write_bytes(b"restored screenshot")
                    restored = True

            with (
                mock.patch.object(
                    RUNNER.time,
                    "monotonic",
                    side_effect=(0.0, 0.0, 0.5, 1.5),
                ),
                mock.patch.object(RUNNER.time, "sleep", side_effect=restore_conflict),
                contextlib.redirect_stdout(io.StringIO()),
            ):
                RUNNER.wait_for_stable_validation_output_inventory(
                    target,
                    [expected],
                    stability_seconds=1.0,
                    timeout_seconds=3.0,
                )
            self.assertTrue(expected.is_file())
            self.assertFalse(unexpected.exists())

    def test_rejects_validation_output_category_drift_at_same_total(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / "build" / "validation" / "ui"
            outputs: list[Path] = []
            for category, count in RUNNER.EXPECTED_VALIDATION_OUTPUT_COUNTS.items():
                parent = target if category == "." else target / category
                outputs.extend(parent / f"fixture-{index}.png" for index in range(count))
            RUNNER.validate_expected_validation_outputs(target, outputs)
            furniture_index = next(
                index
                for index, output in enumerate(outputs)
                if output.parent.name == "furniture"
            )
            outputs[furniture_index] = target / "events" / "replacement.png"
            with self.assertRaises(ValueError) as raised:
                RUNNER.validate_expected_validation_outputs(target, outputs)
            message = str(raised.exception)
            self.assertIn("'events': 25", message)
            self.assertIn("'furniture': 31", message)

    def test_rejects_unsafe_user_directory_names(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            application_support = Path(directory)
            for unsafe in ("PiggameUISmoke-short", "../escape", "PiggameUISmoke-" + "g" * 32):
                with self.assertRaises(ValueError):
                    RUNNER.custom_user_data_path(unsafe, application_support)

    def test_removes_only_the_exact_isolated_directory(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            application_support = Path(directory)
            isolated = application_support / SAFE_NAME
            neighbor = application_support / "PiggameUISmoke-neighbor"
            isolated.mkdir()
            neighbor.mkdir()
            (isolated / "save.json").write_text("fixture", encoding="utf-8")
            RUNNER.remove_isolated_user_data(application_support, SAFE_NAME)
            self.assertFalse(isolated.exists())
            self.assertTrue(neighbor.is_dir())


if __name__ == "__main__":
    unittest.main()
