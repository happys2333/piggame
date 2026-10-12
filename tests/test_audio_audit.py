from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import wave


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("audio_audit", ROOT / "tools/audit_audio.py")
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


class AudioAuditTests(unittest.TestCase):
    def runtime_fixture(self, failures: list[str] | None = None) -> dict:
        manifest = json.loads(MODULE.MANIFEST.read_text())
        streams = [{"id":entry["id"], "dummy_playback_position":0.000045, "diagnostic_loop_end":352800, "diagnostic_playback_position":0.2} for entry in manifest["music"] + manifest["sfx"]]
        return {"completed":True, "assertions":250, "failures":failures or [], "physical_output_tested":False, "driver":"Dummy", "production_playback_enabled":True, "decoded_streams":streams, "policy_observations":[{"unsafe_autonomous_bus_eligibility":False} for _ in range(32)]}

    def runtime_result(self, runtime: dict, returncode: int) -> subprocess.CompletedProcess[str]:
        marker = f"AUDIO_AUDIT: assertions={runtime['assertions']} failures={len(runtime['failures'])} streams=13 feedback_only=true physical_output=false"
        return subprocess.CompletedProcess([], returncode, marker + "\n")

    def test_pcm_metrics_detect_full_scale_and_loop_jump(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "fixture.wav"
            with wave.open(str(path), "wb") as target:
                target.setnchannels(1)
                target.setsampwidth(2)
                target.setframerate(4)
                target.writeframes(struct.pack("<hhhh", 0, 32767, -32768, 1000))
            metrics = MODULE.analyze_wav(path)
            self.assertEqual(metrics["seconds"], 1.0)
            self.assertEqual(metrics["frames"], 4)
            self.assertEqual(metrics["clipped_samples"], 2)
            self.assertEqual(metrics["peak_dbfs"], 0.0)
            self.assertIsNotNone(metrics["first_last_sample_jump_dbfs"])

    def test_current_inventory_is_read_only_and_not_release_approved(self) -> None:
        before = MODULE.sha256(MODULE.MANIFEST)
        report = MODULE.inspect_inventory()
        self.assertEqual(report["technical_failures"], [])
        self.assertEqual(len(report["files"]), 13)
        self.assertFalse(report["development_placeholder"])
        self.assertFalse(report["listening_performed"])
        self.assertEqual(sum(record["kind"] == "music" for record in report["files"]), 0)
        self.assertTrue(all(record["channels"] == 1 and record["sample_rate"] == 44100 for record in report["files"]))
        self.assertEqual(MODULE.sha256(MODULE.MANIFEST), before)

    def test_copy_preflight_does_not_apply_returned_copy(self) -> None:
        before = MODULE.sha256(ROOT / "game/data/localization/game.csv")
        report = MODULE.copy_preflight()
        if report["found"]:
            self.assertIsInstance(report["baseline_csv_matches"], bool)
            self.assertIsInstance(report["structural_issues"], list)
        self.assertFalse(report["applied_by_this_audit"])
        self.assertEqual(MODULE.sha256(ROOT / "game/data/localization/game.csv"), before)

    def test_completed_semantic_failure_is_reportable_but_not_a_pass(self) -> None:
        runtime = self.runtime_fixture(["invalid loop bounds"])
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "runtime.json"
            path.write_text(json.dumps(runtime))
            report = MODULE.validate_runtime_result(self.runtime_result(runtime, 1), path)
        self.assertEqual(report["failures"], ["invalid loop bounds"])
        self.assertEqual(report["process_exit_code"], 1)

    def test_missing_marker_incomplete_report_or_exit_mismatch_is_rejected(self) -> None:
        runtime = self.runtime_fixture(["invalid loop bounds"])
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "runtime.json"
            path.write_text(json.dumps(runtime))
            with self.assertRaises(ValueError):
                MODULE.validate_runtime_result(subprocess.CompletedProcess([], 1, ""), path)
            with self.assertRaises(ValueError):
                MODULE.validate_runtime_result(self.runtime_result(runtime, 0), path)
            with self.assertRaises(ValueError):
                MODULE.validate_runtime_result(self.runtime_result(runtime, 3), path)
            runtime["completed"] = False
            path.write_text(json.dumps(runtime))
            with self.assertRaises(ValueError):
                MODULE.validate_runtime_result(self.runtime_result(runtime, 1), path)
            runtime["completed"] = True
            runtime["decoded_streams"].pop()
            path.write_text(json.dumps(runtime))
            with self.assertRaises(ValueError):
                MODULE.validate_runtime_result(self.runtime_result(runtime, 1), path)

    def test_engine_errors_and_leaks_are_not_semantic_results(self) -> None:
        runtime = self.runtime_fixture(["invalid loop bounds"])
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "runtime.json"
            path.write_text(json.dumps(runtime))
            for marker in (*MODULE.checks.FATAL_GODOT_OUTPUT_MARKERS, "ObjectDB instances leaked", "resources still in use at exit"):
                with self.subTest(marker=marker):
                    result = self.runtime_result(runtime, 1)
                    result.stdout += marker + "\n"
                    with self.assertRaises(RuntimeError):
                        MODULE.validate_runtime_result(result, path)

    def test_cli_writes_failure_report_and_returns_nonzero(self) -> None:
        runtime = {**self.runtime_fixture(["invalid loop bounds"]), "process_exit_code":1}
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary)
            with patch.object(MODULE.sys, "argv", ["audit_audio.py", "--output", str(output)]), patch.object(MODULE, "run_runtime", return_value=runtime):
                self.assertEqual(MODULE.main(), 1)
            report = json.loads((output / "report.json").read_text())
            self.assertFalse(report["technical_audit_passed"])
            self.assertFalse(report["final_audio_accepted"])
            self.assertFalse(report["game_sources_changed"])
            self.assertEqual(report["audit_exit_code"], 1)
            self.assertIn("invalid loop bounds", (output / "report.md").read_text())


if __name__ == "__main__":
    unittest.main()
