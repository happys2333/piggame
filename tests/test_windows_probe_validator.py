from __future__ import annotations

import copy
import hashlib
import importlib.util
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "tools" / "validate_windows_probe.py"
PROBE_PATH = Path(__file__).parents[1] / "tools" / "windows_runtime_probe.ps1"
CANDIDATE_MANIFEST_PATH = Path(__file__).parents[1] / "docs" / "release" / "candidate-manifest.json"
SPEC = importlib.util.spec_from_file_location("validate_windows_probe", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)
CANDIDATE_MANIFEST = json.loads(CANDIDATE_MANIFEST_PATH.read_text(encoding="utf-8"))
FULL_CANDIDATE = next(
    artifact
    for artifact in CANDIDATE_MANIFEST["artifacts"]
    if artifact["profile"] == "full"
)


def report_fixture() -> dict:
    samples = [
        {
            "offsetSeconds": index,
            "cpuPercent": 1.0,
            "workingSetMiB": 180.0,
            "privateMemoryMiB": 150.0,
            "threadCount": 12,
            "handleCount": 200,
        }
        for index in range(1, 11)
    ]
    return {
        "schemaVersion": 1,
        "probe": "piggy-windows-runtime",
        "audioExpectedSilent": True,
        "scenario": "desktop-idle",
        "candidate": {
            "path": r"C:\qa\PiggyDidNothingToday.exe",
            "fileName": "PiggyDidNothingToday.exe",
            "sizeBytes": FULL_CANDIDATE["size_bytes"],
            "sha256": FULL_CANDIDATE["sha256"],
            "fileVersion": "1.0.0",
            "productVersion": "1.0.0",
        },
        "environment": {
            "computerName": "QA-PC",
            "operatingSystem": "Microsoft Windows 11 Pro",
            "osVersion": "10.0.26100",
            "osBuild": "26100",
            "architecture": "64-bit",
            "is64BitOperatingSystem": True,
            "processor": "Fixture CPU",
            "logicalProcessors": 8,
            "totalMemoryMiB": 16_384.0,
            "videoControllers": [{"name": "Fixture GPU", "driverVersion": "1.0"}],
            "qaProfileRoot": r"C:\Temp\PiggyDidNothingToday-QA",
        },
        "timing": {
            "processStartedUtc": "2026-07-26T00:00:00Z",
            "probeStartedUtc": "2026-07-26T00:00:15Z",
            "probeFinishedUtc": "2026-07-26T00:00:25Z",
            "warmupSeconds": 15,
            "requestedDurationSeconds": 10,
            "sampleIntervalSeconds": 1,
            "sampleCount": 10,
        },
        "metrics": {
            "averageCpuPercent": 1.0,
            "p95CpuPercent": 1.0,
            "peakWorkingSetMiB": 180.0,
            "peakPrivateMemoryMiB": 150.0,
        },
        "budgets": {"cpuPercent": 2.0, "workingSetMiB": 300.0},
        "verdicts": {"cpuUnderBudget": True, "memoryUnderBudget": True},
        "samples": samples,
    }


class WindowsProbeValidatorTests(unittest.TestCase):
    def test_valid_idle_report(self) -> None:
        report = report_fixture()
        expected = {
            report["candidate"]["fileName"]: (
                report["candidate"]["sizeBytes"],
                report["candidate"]["sha256"],
            )
        }
        self.assertEqual(
            VALIDATOR.validate_report(Path("idle.json"), report, expected),
            [],
        )

    def test_rejects_non_windows_or_non_silent_evidence(self) -> None:
        report = report_fixture()
        report["audioExpectedSilent"] = False
        report["environment"]["operatingSystem"] = "macOS"
        report["environment"]["is64BitOperatingSystem"] = False
        errors = VALIDATOR.validate_report(Path("wrong-platform.json"), report, {})
        self.assertTrue(any("audioExpectedSilent" in error for error in errors))
        self.assertTrue(any("real Windows" in error for error in errors))
        self.assertTrue(any("is64BitOperatingSystem" in error for error in errors))

    def test_recomputes_metrics_and_strict_budget_verdicts(self) -> None:
        report = report_fixture()
        report["metrics"]["averageCpuPercent"] = 0.1
        report["verdicts"]["cpuUnderBudget"] = False
        errors = VALIDATOR.validate_report(Path("tampered.json"), report, {})
        self.assertTrue(any("averageCpuPercent does not match" in error for error in errors))
        self.assertTrue(any("cpuUnderBudget must be True" in error for error in errors))

    def test_rejects_candidate_identity_mismatch(self) -> None:
        report = report_fixture()
        expected = {"PiggyDidNothingToday.exe": (123, "0" * 64)}
        errors = VALIDATOR.validate_report(Path("identity.json"), report, expected)
        self.assertTrue(any("candidate size differs" in error for error in errors))
        self.assertTrue(any("candidate hash differs" in error for error in errors))

    def test_main_room_has_no_desktop_cpu_verdict(self) -> None:
        report = copy.deepcopy(report_fixture())
        report["scenario"] = "main-room"
        report["budgets"]["cpuPercent"] = None
        report["verdicts"]["cpuUnderBudget"] = None
        self.assertEqual(
            VALIDATOR.validate_report(Path("main-room.json"), report, {}),
            [],
        )

    def test_cli_validates_report_against_artifact_bytes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            artifact = root / "PiggyDidNothingToday.exe"
            artifact.write_bytes(b"fixture Windows candidate")
            report = report_fixture()
            report["candidate"]["sizeBytes"] = artifact.stat().st_size
            report["candidate"]["sha256"] = hashlib.sha256(artifact.read_bytes()).hexdigest()
            report_path = root / "idle.json"
            report_path.write_text(json.dumps(report), encoding="utf-8")
            completed = subprocess.run(
                [
                    sys.executable,
                    str(MODULE_PATH),
                    "--expected-exe",
                    str(artifact),
                    str(report_path),
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            self.assertEqual(completed.returncode, 0, completed.stderr)
            self.assertIn("PASS", completed.stdout)

    def test_probe_and_validator_share_the_strict_contract(self) -> None:
        script = PROBE_PATH.read_text(encoding="utf-8")
        for marker in (
            'ValidateSet("main-room", "desktop-active", "desktop-idle")',
            'probe = "piggy-windows-runtime"',
            "audioExpectedSilent = $true",
            '"desktop-idle" { 2.0 }',
            '"desktop-active" { 5.0 }',
            "workingSetMiB = 300.0",
        ):
            self.assertIn(marker, script)


if __name__ == "__main__":
    unittest.main()
