#!/usr/bin/env python3
"""Validate Windows runtime evidence without weakening release thresholds."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import statistics
import sys
from pathlib import Path
from typing import Any


SCHEMA_VERSION = 1
PROBE_NAME = "piggy-windows-runtime"
SCENARIO_CPU_BUDGETS = {
    "main-room": None,
    "desktop-active": 5.0,
    "desktop-idle": 2.0,
}
MEMORY_BUDGET_MIB = 300.0


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"{path}: cannot read JSON: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{path}: root must be an object")
    return value


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def close(left: float, right: float, tolerance: float = 0.01) -> bool:
    return math.isclose(left, right, rel_tol=0.0, abs_tol=tolerance)


def validate_report(
    path: Path,
    report: dict[str, Any],
    expected_artifacts: dict[str, tuple[int, str]],
) -> list[str]:
    errors: list[str] = []

    if report.get("schemaVersion") != SCHEMA_VERSION:
        errors.append(f"schemaVersion must be {SCHEMA_VERSION}")
    if report.get("probe") != PROBE_NAME:
        errors.append(f"probe must be {PROBE_NAME!r}")
    if report.get("audioExpectedSilent") is not True:
        errors.append("audioExpectedSilent must remain true")

    scenario = report.get("scenario")
    if scenario not in SCENARIO_CPU_BUDGETS:
        errors.append(f"unknown scenario: {scenario!r}")
        scenario = None

    candidate = report.get("candidate")
    if not isinstance(candidate, dict):
        errors.append("candidate must be an object")
        candidate = {}
    file_name = candidate.get("fileName")
    size_bytes = candidate.get("sizeBytes")
    sha256 = candidate.get("sha256")
    if not isinstance(file_name, str) or not file_name.lower().endswith(".exe"):
        errors.append("candidate.fileName must name an EXE")
    if not isinstance(size_bytes, int) or isinstance(size_bytes, bool) or size_bytes <= 0:
        errors.append("candidate.sizeBytes must be a positive integer")
    if (
        not isinstance(sha256, str)
        or len(sha256) != 64
        or any(character not in "0123456789abcdef" for character in sha256)
    ):
        errors.append("candidate.sha256 must be a lowercase SHA-256 digest")
    if isinstance(file_name, str) and file_name in expected_artifacts:
        expected_size, expected_hash = expected_artifacts[file_name]
        if size_bytes != expected_size:
            errors.append(
                f"candidate size differs from {file_name}: expected {expected_size}, got {size_bytes}"
            )
        if sha256 != expected_hash:
            errors.append(
                f"candidate hash differs from {file_name}: expected {expected_hash}, got {sha256}"
            )
    elif expected_artifacts:
        errors.append(f"candidate.fileName is not one of the expected artifacts: {file_name!r}")

    environment = report.get("environment")
    if not isinstance(environment, dict):
        errors.append("environment must be an object")
        environment = {}
    operating_system = environment.get("operatingSystem")
    architecture = environment.get("architecture")
    is_64_bit = environment.get("is64BitOperatingSystem")
    logical_processors = environment.get("logicalProcessors")
    if not isinstance(operating_system, str) or "windows" not in operating_system.lower():
        errors.append("environment.operatingSystem must identify real Windows")
    if not isinstance(architecture, str) or not architecture:
        errors.append("environment.architecture must be a non-empty string")
    if is_64_bit is not True:
        errors.append("environment.is64BitOperatingSystem must be true")
    if (
        not isinstance(logical_processors, int)
        or isinstance(logical_processors, bool)
        or logical_processors <= 0
    ):
        errors.append("environment.logicalProcessors must be a positive integer")

    timing = report.get("timing")
    if not isinstance(timing, dict):
        errors.append("timing must be an object")
        timing = {}
    duration = timing.get("requestedDurationSeconds")
    interval = timing.get("sampleIntervalSeconds")
    recorded_sample_count = timing.get("sampleCount")
    if not isinstance(duration, int) or isinstance(duration, bool) or duration < 10:
        errors.append("timing.requestedDurationSeconds must be at least 10")
    if not isinstance(interval, int) or isinstance(interval, bool) or not 1 <= interval <= 10:
        errors.append("timing.sampleIntervalSeconds must be between 1 and 10")

    samples = report.get("samples")
    if not isinstance(samples, list) or len(samples) < 5:
        errors.append("samples must contain at least five observations")
        samples = []
    if recorded_sample_count != len(samples):
        errors.append(
            f"timing.sampleCount must equal samples length ({len(samples)}), got {recorded_sample_count!r}"
        )
    if isinstance(duration, int) and isinstance(interval, int) and interval > 0:
        expected_sample_count = math.ceil(duration / interval)
        if len(samples) != expected_sample_count:
            errors.append(
                f"sample count must cover the requested duration: expected {expected_sample_count}, got {len(samples)}"
            )

    cpu_values: list[float] = []
    working_set_values: list[float] = []
    private_values: list[float] = []
    previous_offset = 0.0
    for index, sample in enumerate(samples):
        if not isinstance(sample, dict):
            errors.append(f"samples[{index}] must be an object")
            continue
        try:
            offset = float(sample["offsetSeconds"])
            cpu = float(sample["cpuPercent"])
            working_set = float(sample["workingSetMiB"])
            private_memory = float(sample["privateMemoryMiB"])
        except (KeyError, TypeError, ValueError):
            errors.append(f"samples[{index}] has invalid numeric fields")
            continue
        if not math.isfinite(offset) or offset <= previous_offset:
            errors.append(f"samples[{index}].offsetSeconds must increase")
        previous_offset = offset
        if not math.isfinite(cpu) or not 0.0 <= cpu <= 100.0:
            errors.append(f"samples[{index}].cpuPercent must be between 0 and 100")
        if not math.isfinite(working_set) or working_set <= 0.0:
            errors.append(f"samples[{index}].workingSetMiB must be positive")
        if not math.isfinite(private_memory) or private_memory <= 0.0:
            errors.append(f"samples[{index}].privateMemoryMiB must be positive")
        cpu_values.append(cpu)
        working_set_values.append(working_set)
        private_values.append(private_memory)

    metrics = report.get("metrics")
    if not isinstance(metrics, dict):
        errors.append("metrics must be an object")
        metrics = {}
    budgets = report.get("budgets")
    if not isinstance(budgets, dict):
        errors.append("budgets must be an object")
        budgets = {}
    verdicts = report.get("verdicts")
    if not isinstance(verdicts, dict):
        errors.append("verdicts must be an object")
        verdicts = {}

    if cpu_values and len(cpu_values) == len(samples):
        average_cpu = statistics.fmean(cpu_values)
        sorted_cpu = sorted(cpu_values)
        p95_index = min(len(sorted_cpu) - 1, math.floor((len(sorted_cpu) - 1) * 0.95))
        p95_cpu = sorted_cpu[p95_index]
        peak_working_set = max(working_set_values)
        peak_private = max(private_values)
        metric_pairs = (
            ("averageCpuPercent", average_cpu),
            ("p95CpuPercent", p95_cpu),
            ("peakWorkingSetMiB", peak_working_set),
            ("peakPrivateMemoryMiB", peak_private),
        )
        for key, computed in metric_pairs:
            try:
                recorded = float(metrics[key])
            except (KeyError, TypeError, ValueError):
                errors.append(f"metrics.{key} must be numeric")
                continue
            if not close(recorded, computed):
                errors.append(
                    f"metrics.{key} does not match samples: expected {computed:.3f}, got {recorded:.3f}"
                )

        expected_cpu_budget = SCENARIO_CPU_BUDGETS.get(scenario)
        if budgets.get("cpuPercent") != expected_cpu_budget:
            errors.append(
                f"budgets.cpuPercent must be {expected_cpu_budget!r} for {scenario!r}"
            )
        if budgets.get("workingSetMiB") != MEMORY_BUDGET_MIB:
            errors.append(f"budgets.workingSetMiB must remain {MEMORY_BUDGET_MIB}")
        expected_cpu_verdict = (
            None if expected_cpu_budget is None else average_cpu < expected_cpu_budget
        )
        if verdicts.get("cpuUnderBudget") is not expected_cpu_verdict:
            errors.append(
                f"verdicts.cpuUnderBudget must be {expected_cpu_verdict!r}"
            )
        expected_memory_verdict = peak_working_set < MEMORY_BUDGET_MIB
        if verdicts.get("memoryUnderBudget") is not expected_memory_verdict:
            errors.append(
                f"verdicts.memoryUnderBudget must be {expected_memory_verdict!r}"
            )

    return [f"{path}: {error}" for error in errors]


def parse_expected_artifacts(paths: list[Path]) -> dict[str, tuple[int, str]]:
    result: dict[str, tuple[int, str]] = {}
    for path in paths:
        if not path.is_file():
            raise ValueError(f"expected artifact does not exist: {path}")
        result[path.name] = (path.stat().st_size, file_sha256(path))
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("reports", nargs="+", type=Path)
    parser.add_argument(
        "--expected-exe",
        action="append",
        default=[],
        type=Path,
        help="candidate EXE whose exact filename, size and SHA-256 must match",
    )
    arguments = parser.parse_args()

    try:
        expected_artifacts = parse_expected_artifacts(arguments.expected_exe)
    except ValueError as error:
        print(f"Windows runtime evidence validation failed:\n- {error}", file=sys.stderr)
        return 1

    errors: list[str] = []
    for path in arguments.reports:
        try:
            report = load_json(path)
        except ValueError as error:
            errors.append(str(error))
            continue
        report_errors = validate_report(path, report, expected_artifacts)
        errors.extend(report_errors)
        if not report_errors:
            scenario = report["scenario"]
            metrics = report["metrics"]
            verdicts = report["verdicts"]
            print(
                f"PASS {path}: {scenario}, average CPU "
                f"{metrics['averageCpuPercent']:.3f}%, peak working set "
                f"{metrics['peakWorkingSetMiB']:.3f} MiB, "
                f"cpu={verdicts['cpuUnderBudget']}, "
                f"memory={verdicts['memoryUnderBudget']}"
            )

    if errors:
        print("Windows runtime evidence validation failed:", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
