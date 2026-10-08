from __future__ import annotations

import copy
import hashlib
import json
import sys
import tempfile
import unittest
from pathlib import Path


TOOLS = Path(__file__).parents[1] / "tools"
sys.path.insert(0, str(TOOLS))
import import_final_assets as IMPORTER  # noqa: E402


EXPECTED = {"ui:app_icon", "expression:test", "audio:room_morning"}


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n")


def make_fixture(base: Path) -> tuple[Path, Path, dict]:
    root = base / "project"
    package = base / "delivery"
    (root / "game/assets/final").mkdir(parents=True)
    (root / "game/assets/final/old.txt").write_bytes(b"old final asset")
    (root / "game/data/catalog").mkdir(parents=True)
    (root / "game/assets/audio").mkdir(parents=True)
    (root / "game/scripts/core").mkdir(parents=True)
    (root / "game/data/catalog/final_asset_manifest.json").write_text(
        '{"schema_version":1,"ready":false,"provided_by_user":false,"entries":[]}\n'
    )
    write_json(
        root / "game/assets/audio/audio_manifest.json",
        {
            "development_placeholder": True,
            "music": [
                {
                    "id": "room_morning",
                    "path": "res://game/assets/audio/music/room_morning.wav",
                }
            ],
            "sfx": [],
        },
    )
    (root / "project.godot").write_text(
        '[application]\nconfig/icon="res://game/assets/ui/app_icon.svg"\n'
    )
    (root / "export_presets.cfg").write_text(
        '[preset.0.options]\napplication/icon="res://game/assets/ui/app_icon.svg"\n'
        '[preset.1.options]\napplication/icon="res://game/assets/ui/app_icon.svg"\n'
    )
    (root / "game/scripts/core/release_profile.gd").write_text(
        "const AUDIO_PLAYBACK_ENABLED: bool = false\n"
    )

    package.mkdir()
    visual = b"user-provided visual bytes"
    audio = b"RIFF user-provided audio bytes"
    (package / "visual.png").write_bytes(visual)
    (package / "audio.wav").write_bytes(audio)
    plan = {
        "schema_version": 1,
        "provided_by_user": True,
        "package_id": "fixture-package",
        "entries": [
            {
                "source_file": "visual.png",
                "destination": "visual/final.png",
                "sha256": sha256(visual),
                "covers": ["ui:app_icon", "expression:test"],
                "regions": {"expression:test": [0, 0, 16, 16]},
                "source": "User delivery fixture",
                "license": "User-owned fixture",
            },
            {
                "source_file": "audio.wav",
                "destination": "audio/final.wav",
                "sha256": sha256(audio),
                "covers": ["audio:room_morning"],
                "regions": {},
                "source": "User delivery fixture",
                "license": "User-owned fixture",
            },
        ],
    }
    plan_path = package / "dedicated_asset_package.json"
    write_json(plan_path, plan)
    return root, plan_path, plan


def snapshot(root: Path) -> dict[str, bytes]:
    result: dict[str, bytes] = {}
    for path in sorted(root.rglob("*")):
        if path.is_file():
            result[path.relative_to(root).as_posix()] = path.read_bytes()
    return result


class FinalAssetImporterTests(unittest.TestCase):
    def test_dry_run_prepares_without_mutating_project(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, plan_path, _ = make_fixture(Path(directory))
            before = snapshot(root)
            prepared = IMPORTER.prepare_import(
                plan_path, root=root, expected_tokens=EXPECTED
            )
            self.assertEqual(len(prepared.entries), 2)
            self.assertEqual(snapshot(root), before)

    def test_apply_copies_verbatim_and_updates_all_routes(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, plan_path, _ = make_fixture(Path(directory))
            release_before = (
                root / "game/scripts/core/release_profile.gd"
            ).read_bytes()
            prepared = IMPORTER.prepare_import(
                plan_path, root=root, expected_tokens=EXPECTED
            )
            IMPORTER.apply_prepared(prepared)
            self.assertEqual(
                (root / "game/assets/final/visual/final.png").read_bytes(),
                b"user-provided visual bytes",
            )
            self.assertEqual(
                (root / "game/assets/final/audio/final.wav").read_bytes(),
                b"RIFF user-provided audio bytes",
            )
            self.assertFalse((root / "game/assets/final/old.txt").exists())
            manifest = json.loads(
                (root / "game/data/catalog/final_asset_manifest.json").read_text()
            )
            self.assertTrue(manifest["ready"] and manifest["provided_by_user"])
            self.assertEqual(
                {
                    token
                    for entry in manifest["entries"]
                    for token in entry["covers"]
                },
                EXPECTED,
            )
            audio = json.loads(
                (root / "game/assets/audio/audio_manifest.json").read_text()
            )
            self.assertFalse(audio["development_placeholder"])
            self.assertEqual(
                audio["music"][0]["path"],
                "res://game/assets/final/audio/final.wav",
            )
            icon_path = "res://game/assets/final/visual/final.png"
            self.assertIn(
                f'config/icon="{icon_path}"', (root / "project.godot").read_text()
            )
            self.assertEqual(
                (root / "export_presets.cfg").read_text().count(
                    f'application/icon="{icon_path}"'
                ),
                2,
            )
            self.assertEqual(
                (root / "game/scripts/core/release_profile.gd").read_bytes(),
                release_before,
            )

    def test_rejects_incomplete_coverage_before_mutation(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, plan_path, plan = make_fixture(Path(directory))
            plan["entries"][0]["covers"] = ["ui:app_icon"]
            plan["entries"][0]["regions"] = {}
            write_json(plan_path, plan)
            before = snapshot(root)
            with self.assertRaisesRegex(IMPORTER.ImportFailure, "missing"):
                IMPORTER.prepare_import(
                    plan_path, root=root, expected_tokens=EXPECTED
                )
            self.assertEqual(snapshot(root), before)

    def test_rejects_hash_mismatch_and_path_traversal(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, plan_path, plan = make_fixture(Path(directory))
            wrong_hash = copy.deepcopy(plan)
            wrong_hash["entries"][0]["sha256"] = "0" * 64
            write_json(plan_path, wrong_hash)
            with self.assertRaisesRegex(IMPORTER.ImportFailure, "SHA-256 mismatch"):
                IMPORTER.prepare_import(
                    plan_path, root=root, expected_tokens=EXPECTED
                )
            traversal = copy.deepcopy(plan)
            traversal["entries"][0]["destination"] = "../escape.png"
            write_json(plan_path, traversal)
            with self.assertRaisesRegex(IMPORTER.ImportFailure, "normalized relative"):
                IMPORTER.prepare_import(
                    plan_path, root=root, expected_tokens=EXPECTED
                )

    def test_rejects_mixed_audio_visual_entry(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, plan_path, plan = make_fixture(Path(directory))
            plan["entries"][0]["covers"].append("audio:room_morning")
            plan["entries"].pop()
            write_json(plan_path, plan)
            with self.assertRaisesRegex(IMPORTER.ImportFailure, "cannot mix"):
                IMPORTER.prepare_import(
                    plan_path, root=root, expected_tokens=EXPECTED
                )

    def test_failure_rolls_back_assets_and_every_config(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, plan_path, _ = make_fixture(Path(directory))
            before = snapshot(root)
            prepared = IMPORTER.prepare_import(
                plan_path, root=root, expected_tokens=EXPECTED
            )
            with self.assertRaisesRegex(RuntimeError, "injected"):
                IMPORTER.apply_prepared(
                    prepared, fail_after_step="export_presets"
                )
            self.assertEqual(snapshot(root), before)
            self.assertFalse(
                any(
                    path.name.startswith((".final-import-", ".final-backup-"))
                    for path in (root / "game/assets").iterdir()
                )
            )

    def test_post_commit_validation_failure_rolls_back_everything(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, plan_path, _ = make_fixture(Path(directory))
            before = snapshot(root)
            prepared = IMPORTER.prepare_import(
                plan_path, root=root, expected_tokens=EXPECTED
            )
            validator_calls = 0

            def reject_committed_state() -> bool:
                nonlocal validator_calls
                validator_calls += 1
                manifest = json.loads(
                    (
                        root
                        / "game/data/catalog/final_asset_manifest.json"
                    ).read_text()
                )
                self.assertTrue(manifest["ready"])
                self.assertTrue(
                    (root / "game/assets/final/visual/final.png").is_file()
                )
                return False

            with self.assertRaisesRegex(
                IMPORTER.ImportFailure, "post-commit final-asset validation failed"
            ):
                IMPORTER.apply_prepared(
                    prepared, post_commit_validator=reject_committed_state
                )
            self.assertEqual(validator_calls, 1)
            self.assertEqual(snapshot(root), before)

    def test_audio_playback_must_remain_disabled(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root, plan_path, _ = make_fixture(Path(directory))
            release_profile = root / "game/scripts/core/release_profile.gd"
            release_profile.write_text(
                "const AUDIO_PLAYBACK_ENABLED: bool = true\n"
            )
            before = snapshot(root)
            with self.assertRaisesRegex(
                IMPORTER.ImportFailure, "audio playback must remain disabled"
            ):
                IMPORTER.prepare_import(
                    plan_path, root=root, expected_tokens=EXPECTED
                )
            self.assertEqual(snapshot(root), before)

    def test_production_contract_has_252_tokens(self) -> None:
        self.assertEqual(len(IMPORTER.validate_final_assets.expected_coverage()), 252)


if __name__ == "__main__":
    unittest.main()
