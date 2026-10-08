from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
import zipfile
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "tools" / "validate_export_package.py"
PROJECT_ROOT = MODULE_PATH.parents[1]
SPEC = importlib.util.spec_from_file_location("validate_export_package", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
VALIDATOR = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = VALIDATOR
SPEC.loader.exec_module(VALIDATOR)


def write_package(
    path: Path,
    *,
    omit: set[str] | None = None,
    extras: dict[str, bytes] | None = None,
    remap_target: str = ".godot/exported/main.scn",
) -> None:
    omitted = omit or set()
    entries: dict[str, bytes] = {}
    for required in VALIDATOR.REQUIRED_FILES:
        if required in omitted:
            continue
        source_path = PROJECT_ROOT / required
        entries[required] = source_path.read_bytes() if source_path.is_file() else b"fixture"
    entries["game/scenes/main.tscn.remap"] = (
        f'path="res://{remap_target}"\n'.encode("utf-8")
    )
    entries[remap_target] = b"compiled scene"
    entries.update(extras or {})
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, data in entries.items():
            archive.writestr(name, data)


class ExportPackageValidatorTests(unittest.TestCase):
    def test_valid_minimal_package(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "full.zip"
            write_package(path)
            summary, errors = VALIDATOR.audit_package("full", path)
            self.assertEqual(errors, [])
            self.assertIsNotNone(summary)

    def test_rejects_release_candidate_and_development_docs(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "full.zip"
            write_package(
                path,
                extras={
                    "docs/release/candidate-manifest.json": b"{}",
                    "docs/release/build-and-release.md": b"internal instructions",
                    "addons/telemetry/telemetry.gdextension": b"unreviewed extension",
                    "game/bin/telemetry.dll": b"unreviewed native binary",
                },
            )
            _, errors = VALIDATOR.audit_package("full", path)
            self.assertTrue(any("candidate-manifest.json" in error for error in errors))
            self.assertTrue(any("build-and-release.md" in error for error in errors))
            self.assertTrue(any("unreviewed external integration paths" in error for error in errors))

    def test_rejects_development_mother_art_and_test_icons(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "full.zip"
            write_package(path, extras={
                "game/assets/upstream/noto/emoji_u1f416.svg": b"archival source",
                "game/assets/ui/app_icon.svg": b"test fixture",
            })
            _, errors = VALIDATOR.audit_package("full", path)
            self.assertTrue(any("game/assets/upstream/" in error for error in errors))
            self.assertTrue(any("game/assets/ui/" in error for error in errors))

    def test_rejects_tampered_license_and_release_notice(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "full.zip"
            privacy = (PROJECT_ROOT / "docs" / "release" / "privacy.md").read_bytes()
            notice = (PROJECT_ROOT / "docs" / "release" / "third-party-notices.md").read_bytes()
            write_package(
                path,
                extras={
                    "LICENSES/NotoEmoji/LICENSE.txt": b"tampered license",
                    "docs/release/privacy.md": privacy.replace(
                        "## 繁體中文".encode(), b"## Traditional Chinese Missing", 1
                    ),
                    "docs/release/third-party-notices.md": notice.replace(
                        "## 简体中文".encode(), b"## Simplified Chinese Missing", 1
                    ),
                },
            )
            _, errors = VALIDATOR.audit_package("full", path)
            self.assertTrue(any("required file SHA-256 mismatch" in error for error in errors))
            self.assertTrue(any("required release notice markers" in error for error in errors))

    def test_rejects_unsafe_archive_path(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "full.zip"
            write_package(path, extras={"../escape.txt": b"escape"})
            _, errors = VALIDATOR.audit_package("full", path)
            self.assertTrue(any("unsafe archive paths" in error for error in errors))

    def test_rejects_missing_required_file_and_remap_target(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "full.zip"
            write_package(
                path,
                omit={"project.binary"},
                remap_target=".godot/exported/missing.scn",
            )
            with zipfile.ZipFile(path, "a") as archive:
                pass
            with zipfile.ZipFile(path, "r") as source:
                entries = {
                    item.filename: source.read(item.filename)
                    for item in source.infolist()
                    if item.filename != ".godot/exported/missing.scn"
                }
            rewritten = path.with_suffix(".rewritten.zip")
            with zipfile.ZipFile(rewritten, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                for name, data in entries.items():
                    archive.writestr(name, data)
            _, errors = VALIDATOR.audit_package("full", rewritten)
            self.assertTrue(any("missing required files" in error for error in errors))
            self.assertTrue(any("remap target is absent" in error for error in errors))


if __name__ == "__main__":
    unittest.main()
