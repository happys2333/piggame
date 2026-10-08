from __future__ import annotations

import hashlib
import importlib.util
import json
import struct
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "tools" / "validate_release_candidate.py"
SPEC = importlib.util.spec_from_file_location("validate_release_candidate", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
VALIDATOR = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VALIDATOR)


def write_pe(
    path: Path,
    *,
    machine: int = VALIDATOR.PE_MACHINE_X86_64,
    magic: int = VALIDATOR.PE32_PLUS_MAGIC,
    subsystem: int = VALIDATOR.WINDOWS_GUI_SUBSYSTEM,
    payload: bytes = b"",
) -> None:
    data = bytearray(256)
    data[:2] = b"MZ"
    pe_offset = 0x80
    struct.pack_into("<I", data, 0x3C, pe_offset)
    data[pe_offset : pe_offset + 4] = b"PE\0\0"
    struct.pack_into("<H", data, pe_offset + 4, machine)
    struct.pack_into("<H", data, pe_offset + 20, 0xF0)
    struct.pack_into("<H", data, pe_offset + 24, magic)
    struct.pack_into("<H", data, pe_offset + 24 + 68, subsystem)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(bytes(data) + payload)


def identity(path: Path) -> tuple[int, str]:
    data = path.read_bytes()
    return len(data), hashlib.sha256(data).hexdigest()


def write_fixture(root: Path) -> Path:
    for relative, content in (
        ("project.godot", "config_version=5\n"),
        ("export_presets.cfg", "[preset.0]\n"),
        ("README.md", "fixture readme\n"),
        ("LICENSE", "fixture license\n"),
        ("docs/release/privacy.md", "fixture privacy\n"),
        ("docs/release/third-party-notices.md", "fixture notices\n"),
        ("LICENSES/fixture.txt", "fixture dependency license\n"),
        ("game/runtime_fixture.gd", "extends Node\n"),
    ):
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
    release_profile_path = root / "game" / "scripts" / "core" / "release_profile.gd"
    release_profile_path.parent.mkdir(parents=True, exist_ok=True)
    release_profile_path.write_text(
        "const AUDIO_PLAYBACK_ENABLED: bool = false\n",
        encoding="utf-8",
    )
    definitions = (
        ("full", "PiggyDidNothingToday.exe"),
        ("demo", "PiggyDidNothingTodayDemo.exe"),
    )
    artifacts: list[dict] = []
    for profile, file_name in definitions:
        path = root / "build" / "windows" / file_name
        write_pe(path, payload=profile.encode("ascii"))
        size_bytes, sha256 = identity(path)
        artifacts.append(
            {
                "profile": profile,
                "path": f"build/windows/{file_name}",
                "file_name": file_name,
                "size_bytes": size_bytes,
                "sha256": sha256,
                "format": "PE32+ GUI x86-64",
            }
        )
    manifest = {
        "schema_version": 1,
        "generated_date": "2026-07-26",
        "release_stage": "silent-development-candidate",
        "engine_version": "4.6.3.stable.official.fixture",
        "export_host": "macOS",
        "audio_playback_enabled": False,
        "source_tree_sha256": VALIDATOR.source_tree_sha256(root),
        "artifacts": artifacts,
    }
    manifest_path = root / "docs" / "release" / "candidate-manifest.json"
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    markers = "\n".join([
        manifest["source_tree_sha256"],
        *(
            f"{item['file_name']} {item['size_bytes']:,} {item['sha256']}"
            for item in artifacts
        ),
    ])
    (manifest_path.parent / "build-and-release.md").write_text(markers, encoding="utf-8")
    matrix_scope = "\n".join(
        " ".join(required_markers)
        for _, required_markers in VALIDATOR.WINDOWS_MATRIX_REQUIRED_SCENARIOS
    )
    (manifest_path.parent / "windows-test-matrix.md").write_text(
        f"{markers}\n{matrix_scope}",
        encoding="utf-8",
    )
    return manifest_path


def load_manifest(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


class ReleaseCandidateValidatorTests(unittest.TestCase):
    def test_valid_candidate_set(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            self.assertEqual(
                VALIDATOR.validate_candidate_set(root, manifest_path),
                [],
            )

    def test_rejects_artifact_size_and_hash_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            manifest = load_manifest(manifest_path)
            manifest["artifacts"][0]["size_bytes"] += 1
            manifest["artifacts"][0]["sha256"] = "0" * 64
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(any("size differs from artifact bytes" in error for error in errors))
            self.assertTrue(any("SHA-256 differs from artifact bytes" in error for error in errors))

    def test_rejects_unsafe_or_unexpected_artifact_path(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            manifest = load_manifest(manifest_path)
            manifest["artifacts"][0]["path"] = "../PiggyDidNothingToday.exe"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(any("artifact path is unsafe" in error for error in errors))

    def test_rejects_x86_console_pe(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            manifest = load_manifest(manifest_path)
            full_path = root / manifest["artifacts"][0]["path"]
            write_pe(full_path, machine=0x014C, magic=0x010B, subsystem=3)
            size_bytes, sha256 = identity(full_path)
            manifest["artifacts"][0]["size_bytes"] = size_bytes
            manifest["artifacts"][0]["sha256"] = sha256
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(any("PE machine must be x86-64" in error for error in errors))
            self.assertTrue(any("optional header must be PE32+" in error for error in errors))
            self.assertTrue(any("subsystem must be Windows GUI" in error for error in errors))

    def test_rejects_final_label_or_audio_enablement(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            manifest = load_manifest(manifest_path)
            manifest["release_stage"] = "final-release"
            manifest["audio_playback_enabled"] = True
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            release_profile_path = root / "game" / "scripts" / "core" / "release_profile.gd"
            release_profile_path.write_text(
                "const AUDIO_PLAYBACK_ENABLED: bool = true\n",
                encoding="utf-8",
            )
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(any("release_stage must remain" in error for error in errors))
            self.assertTrue(any("audio_playback_enabled must remain false" in error for error in errors))
            self.assertTrue(any("AUDIO_PLAYBACK_ENABLED must remain typed false" in error for error in errors))

    def test_rejects_release_document_identity_drift(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            matrix_path = root / "docs" / "release" / "windows-test-matrix.md"
            matrix_path.write_text("stale candidate identity", encoding="utf-8")
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(any("missing full candidate identity markers" in error for error in errors))
            self.assertTrue(any("missing demo candidate identity markers" in error for error in errors))

    def test_accepts_current_windows_probe_commands(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            manifest = load_manifest(manifest_path)
            full, demo = manifest["artifacts"]
            commands = (
                f"& .\\tools\\windows_runtime_probe.ps1 `\n"
                f"  -ExecutablePath .\\build\\windows\\{full['file_name']} `\n"
                f"  -ExpectedSizeBytes {full['size_bytes']} `\n"
                f"  -ExpectedSha256 {full['sha256']}\n"
                f"& .\\tools\\windows_runtime_probe.ps1 -ProcessId $gameProcessId -KeepRunning "
                f"-ExpectedSha256 {full['sha256']} -ExpectedSizeBytes {full['size_bytes']}\n"
            )
            document = root / "docs/release/build-and-release.md"
            with document.open("a", encoding="utf-8") as stream:
                stream.write(f"\n```powershell\n{commands}```\n")
                stream.write(
                    "\r\n```pwsh\r\n"
                    "& '.\\tools\\windows_runtime_probe.ps1' `\r\n"
                    f"  -ExecutablePath '.\\build\\windows\\{demo['file_name']}' `\r\n"
                    f"  -expectedsizebytes '{demo['size_bytes']}' `\r\n"
                    f"  -expectedsha256 \"{demo['sha256'].upper()}\"\r\n"
                    "```\r\n"
                )
            self.assertEqual(VALIDATOR.validate_candidate_set(root, manifest_path), [])

    def test_rejects_stale_size_in_each_windows_probe_command(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            full = load_manifest(manifest_path)["artifacts"][0]
            document = root / "docs/release/build-and-release.md"
            with document.open("a", encoding="utf-8") as stream:
                stream.write(
                    "\n```powershell\n"
                    "& .\\tools\\windows_runtime_probe.ps1 -ProcessId $gameProcessId "
                    f"-ExpectedSizeBytes {full['size_bytes']} -ExpectedSha256 {full['sha256']}\n"
                    "& .\\tools\\windows_runtime_probe.ps1 -ProcessId $gameProcessId "
                    f"-ExpectedSizeBytes {full['size_bytes'] - 1} -ExpectedSha256 {full['sha256']}\n"
                    "```\n"
                )
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(any("Windows probe command 2" in error and "candidate identity" in error for error in errors))

    def test_rejects_stale_hash_in_windows_probe_command(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            full = load_manifest(manifest_path)["artifacts"][0]
            document = root / "docs/release/build-and-release.md"
            with document.open("a", encoding="utf-8") as stream:
                stream.write(
                    "\n```powershell\n"
                    "& .\\tools\\windows_runtime_probe.ps1 -ProcessId $gameProcessId "
                    f"-ExpectedSizeBytes {full['size_bytes']} -ExpectedSha256 {'0' * 64}\n"
                    "```\n"
                )
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(any("Windows probe command 1" in error and "candidate identity" in error for error in errors))

    def test_rejects_cross_profile_windows_probe_identity(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            full, demo = load_manifest(manifest_path)["artifacts"]
            document = root / "docs/release/build-and-release.md"
            with document.open("a", encoding="utf-8") as stream:
                stream.write(
                    "\n```powershell\n"
                    "& .\\tools\\windows_runtime_probe.ps1 "
                    f"-ExecutablePath .\\build\\windows\\{demo['file_name']} "
                    f"-ExpectedSizeBytes {full['size_bytes']} -ExpectedSha256 {full['sha256']}\n"
                    "```\n"
                )
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(any("Windows probe command 1" in error and "candidate identity" in error for error in errors))

    def test_rejects_missing_or_duplicate_windows_probe_identity(self) -> None:
        for variant in ("missing-size", "missing-hash", "duplicate-size", "duplicate-hash"):
            with self.subTest(variant=variant), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                manifest_path = write_fixture(root)
                full = load_manifest(manifest_path)["artifacts"][0]
                size_argument = f"-ExpectedSizeBytes {full['size_bytes']}"
                hash_argument = f"-ExpectedSha256 {full['sha256']}"
                arguments = {
                    "missing-size": hash_argument,
                    "missing-hash": size_argument,
                    "duplicate-size": f"{size_argument} {hash_argument} {size_argument}",
                    "duplicate-hash": f"{size_argument} {hash_argument} {hash_argument}",
                }[variant]
                document = root / "docs/release/build-and-release.md"
                with document.open("a", encoding="utf-8") as stream:
                    stream.write(
                        "\n```powershell\n"
                        "& .\\tools\\windows_runtime_probe.ps1 -ProcessId $gameProcessId "
                        f"{arguments}\n```\n"
                    )
                errors = VALIDATOR.validate_candidate_set(root, manifest_path)
                self.assertTrue(any("Windows probe command 1" in error and "exactly one" in error for error in errors))

    def test_rejects_unknown_windows_probe_executable(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            full = load_manifest(manifest_path)["artifacts"][0]
            document = root / "docs/release/build-and-release.md"
            with document.open("a", encoding="utf-8") as stream:
                stream.write(
                    "\n```powershell\n"
                    "& .\\tools\\windows_runtime_probe.ps1 -ExecutablePath .\\Other.exe "
                    f"-ExpectedSizeBytes {full['size_bytes']} -ExpectedSha256 {full['sha256']}\n"
                    "```\n"
                )
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(any("Windows probe command 1" in error and "candidate executable" in error for error in errors))

    def test_rejects_incomplete_windows_acceptance_scope(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            matrix_path = root / "docs" / "release" / "windows-test-matrix.md"
            source = matrix_path.read_text(encoding="utf-8").replace("切换用户", "", 1)
            matrix_path.write_text(source, encoding="utf-8")
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(
                any(
                    "os-session-clock" in error and "切换用户" in error
                    for error in errors
                )
            )

    def test_rejects_missing_windows_caption_acceptance(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            matrix_path = root / "docs/release/windows-test-matrix.md"
            source = matrix_path.read_text(encoding="utf-8").replace("字幕/气泡停留时间", "", 1)
            matrix_path.write_text(source, encoding="utf-8")
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(any("caption-reading-duration" in error for error in errors))

    def test_rejects_source_tree_drift_after_export(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            manifest_path = write_fixture(root)
            runtime_path = root / "game" / "runtime_fixture.gd"
            runtime_path.write_text("extends Node\nvar changed := true\n", encoding="utf-8")
            errors = VALIDATOR.validate_candidate_set(root, manifest_path)
            self.assertTrue(
                any("source tree SHA-256 differs" in error for error in errors)
            )


if __name__ == "__main__":
    unittest.main()
