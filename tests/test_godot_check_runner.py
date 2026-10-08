from __future__ import annotations

import contextlib
import importlib.util
import io
import subprocess
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "tools" / "run_godot_checks.py"
SPEC = importlib.util.spec_from_file_location("run_godot_checks", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)
SAFE_NAME = RUNNER.USER_DIR_PREFIX + "a" * 32


class GodotCheckRunnerTests(unittest.TestCase):
    def test_accepts_clean_output_and_required_pass_marker(self) -> None:
        clean = subprocess.CompletedProcess(args=["godot"], returncode=0, stdout="clean\n")
        passed = subprocess.CompletedProcess(
            args=["godot"],
            returncode=0,
            stdout=f"{RUNNER.CORE_RULES_PASS_MARKER}\n",
        )
        self.assertEqual(RUNNER.result_exit_code(clean, "import", None), 0)
        self.assertEqual(
            RUNNER.result_exit_code(passed, "core", RUNNER.CORE_RULES_PASS_MARKER),
            0,
        )

    def test_rejects_fatal_output_with_zero_exit_status(self) -> None:
        for marker in RUNNER.FATAL_GODOT_OUTPUT_MARKERS:
            with self.subTest(marker=marker):
                completed = subprocess.CompletedProcess(
                    args=["godot"],
                    returncode=0,
                    stdout=f"{marker} fixture failure\n{RUNNER.CORE_RULES_PASS_MARKER}\n",
                )
                with contextlib.redirect_stderr(io.StringIO()):
                    self.assertEqual(
                        RUNNER.result_exit_code(
                            completed,
                            "core",
                            RUNNER.CORE_RULES_PASS_MARKER,
                        ),
                        1,
                    )

    def test_rejects_nonzero_exit_and_missing_pass_marker(self) -> None:
        failed = subprocess.CompletedProcess(args=["godot"], returncode=7, stdout="")
        missing = subprocess.CompletedProcess(args=["godot"], returncode=0, stdout="clean\n")
        self.assertEqual(RUNNER.result_exit_code(failed, "core", None), 7)
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(
                RUNNER.result_exit_code(
                    missing,
                    "core",
                    RUNNER.CORE_RULES_PASS_MARKER,
                ),
                1,
            )

    def test_rejects_stale_core_assertion_count(self) -> None:
        stale = subprocess.CompletedProcess(
            args=["godot"],
            returncode=0,
            stdout="PASS: 727 assertions\n",
        )
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(
                RUNNER.result_exit_code(stale, "core", RUNNER.CORE_RULES_PASS_MARKER),
                1,
            )

    def test_rejects_progression_contract_drift_or_duplication(self) -> None:
        fixtures = (
            ("full", RUNNER.FULL_PROGRESSION_PASS_MARKER, "first_furniture=567s", "first_furniture=568s"),
            ("demo", RUNNER.DEMO_PROGRESSION_PASS_MARKER, "completion=1800s", "completion=1801s"),
            ("demo profile", RUNNER.DEMO_PROFILE_PASS_MARKER, "areas=sleep", "areas=sleep,snack"),
        )
        for label, expected, current, drifted in fixtures:
            outputs = (expected.replace(current, drifted), f"{expected}\n{expected}")
            for output in outputs:
                with self.subTest(label=label, output=output):
                    completed = subprocess.CompletedProcess(
                        args=["godot"],
                        returncode=0,
                        stdout=f"{output}\n",
                    )
                    with contextlib.redirect_stderr(io.StringIO()):
                        self.assertEqual(
                            RUNNER.result_exit_code(completed, label, expected),
                            1,
                        )

    def test_builds_dummy_audio_headless_command(self) -> None:
        command = RUNNER.build_command(
            Path("/godot"),
            Path("/project"),
            ("--script", "res://tests/test_runner.gd"),
        )
        self.assertEqual(command[:6], ["/godot", "--headless", "--audio-driver", "Dummy", "--path", "/project"])
        self.assertEqual(command[-2:], ["--script", "res://tests/test_runner.gd"])
        pack_command = RUNNER.build_pack_command(
            Path("/godot"),
            Path("/project/demo-profile-audit.zip"),
            Path("/project/tests/demo_profile_audit.gd"),
        )
        self.assertEqual(
            pack_command,
            [
                "/godot",
                "--headless",
                "--audio-driver",
                "Dummy",
                "--main-pack",
                "/project/demo-profile-audit.zip",
                "--script",
                "/project/tests/demo_profile_audit.gd",
            ],
        )

    def test_stages_sources_and_cleans_only_isolated_user_data(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source"
            staging = root / "staging"
            application_support = root / "Application Support"
            (source / "game").mkdir(parents=True)
            (source / "tests").mkdir()
            (source / "project.godot").write_text("config_version=5\n", encoding="utf-8")
            (source / "export_presets.cfg").write_text("[preset.0]\n", encoding="utf-8")
            (source / "game" / "runtime.gd").write_text("extends Node\n", encoding="utf-8")
            (source / "tests" / "test_runner.gd").write_text("extends SceneTree\n", encoding="utf-8")
            RUNNER.stage_project(source, staging, SAFE_NAME)
            self.assertTrue((staging / "game" / "runtime.gd").is_file())
            self.assertTrue((staging / "tests" / "test_runner.gd").is_file())
            self.assertIn(SAFE_NAME, (staging / "override.cfg").read_text(encoding="utf-8"))
            isolated = application_support / SAFE_NAME
            neighbor = application_support / "PiggameGodotChecks-neighbor"
            isolated.mkdir(parents=True)
            neighbor.mkdir()
            RUNNER.remove_isolated_user_data(application_support, SAFE_NAME)
            self.assertFalse(isolated.exists())
            self.assertTrue(neighbor.is_dir())
            with self.assertRaises(ValueError):
                RUNNER.custom_user_data_path("../escape", application_support)


if __name__ == "__main__":
    unittest.main()
