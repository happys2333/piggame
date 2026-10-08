#!/usr/bin/env python3
"""Atomically import, but never generate or transform, user-provided final assets."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import shutil
import sys
import tempfile
import uuid
from dataclasses import dataclass
from pathlib import Path, PurePosixPath
from typing import Any, Callable

import validate_final_assets


ROOT = Path(__file__).resolve().parents[1]
FINAL_DIRECTORY = Path("game/assets/final")
FINAL_MANIFEST = Path("game/data/catalog/final_asset_manifest.json")
AUDIO_MANIFEST = Path("game/assets/audio/audio_manifest.json")
PROJECT_CONFIG = Path("project.godot")
EXPORT_PRESETS = Path("export_presets.cfg")
RELEASE_PROFILE = Path("game/scripts/core/release_profile.gd")
PACKAGE_SCHEMA_VERSION = 1
VISUAL_SUFFIXES = {".png", ".webp", ".svg", ".tres", ".res"}
AUDIO_SUFFIXES = {".ogg", ".wav"}
SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")


class ImportFailure(ValueError):
    pass


@dataclass(frozen=True)
class PreparedEntry:
    source_path: Path
    destination: PurePosixPath
    resource_path: str
    sha256: str
    covers: tuple[str, ...]
    regions: dict[str, list[float | int]]
    source: str
    license: str


@dataclass(frozen=True)
class PreparedImport:
    root: Path
    package_manifest: Path
    package_id: str
    entries: tuple[PreparedEntry, ...]
    final_manifest_bytes: bytes
    audio_manifest_bytes: bytes
    project_config_bytes: bytes
    export_presets_bytes: bytes


def load_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ImportFailure(f"cannot read JSON {path}: {error}") from error


def json_bytes(value: Any) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def package_relative_path(raw_value: Any, field: str) -> PurePosixPath:
    value = str(raw_value)
    path = PurePosixPath(value)
    if (
        not value
        or "\\" in value
        or path.is_absolute()
        or any(part in ("", ".", "..") for part in path.parts)
        or path.as_posix() != value
    ):
        raise ImportFailure(f"{field} must be a normalized relative POSIX path: {value!r}")
    return path


def replace_setting(text: str, key: str, value: str, expected_count: int) -> str:
    pattern = re.compile(rf'^{re.escape(key)}="[^"]*"$', re.MULTILINE)
    matches = pattern.findall(text)
    if len(matches) != expected_count:
        raise ImportFailure(
            f"{key} must appear exactly {expected_count} time(s), found {len(matches)}"
        )
    return pattern.sub(f'{key}="{value}"', text)


def validate_regions(
    raw_regions: Any,
    covers: tuple[str, ...],
    entry_index: int,
) -> dict[str, list[float | int]]:
    if raw_regions is None:
        return {}
    if not isinstance(raw_regions, dict):
        raise ImportFailure(f"entry {entry_index} regions must be an object")
    result: dict[str, list[float | int]] = {}
    for raw_token, raw_region in raw_regions.items():
        token = str(raw_token)
        if token not in covers:
            raise ImportFailure(
                f"entry {entry_index} region {token!r} is not listed in covers"
            )
        if (
            not isinstance(raw_region, list)
            or len(raw_region) != 4
            or any(
                not isinstance(value, (int, float)) or isinstance(value, bool)
                for value in raw_region
            )
            or raw_region[0] < 0
            or raw_region[1] < 0
            or raw_region[2] <= 0
            or raw_region[3] <= 0
        ):
            raise ImportFailure(
                f"entry {entry_index} region {token!r} must be "
                "[x, y, width, height] with positive size"
            )
        result[token] = list(raw_region)
    return result


def prepare_import(
    package_manifest: Path,
    *,
    root: Path = ROOT,
    expected_tokens: set[str] | None = None,
) -> PreparedImport:
    root = root.resolve()
    package_manifest = package_manifest.resolve()
    package_root = package_manifest.parent
    final_directory = (root / FINAL_DIRECTORY).resolve()
    if package_root == final_directory or final_directory in package_root.parents:
        raise ImportFailure("the source package must stay outside game/assets/final")

    package = load_json(package_manifest)
    if not isinstance(package, dict):
        raise ImportFailure("package manifest root must be an object")
    if package.get("schema_version") != PACKAGE_SCHEMA_VERSION:
        raise ImportFailure(
            f"package schema_version must be {PACKAGE_SCHEMA_VERSION}"
        )
    if package.get("provided_by_user") is not True:
        raise ImportFailure("package provided_by_user must be true")
    package_id = str(package.get("package_id", "")).strip()
    if not package_id:
        raise ImportFailure("package_id is required")
    raw_entries = package.get("entries")
    if not isinstance(raw_entries, list) or not raw_entries:
        raise ImportFailure("package entries must be a non-empty array")

    expected = (
        set(validate_final_assets.expected_coverage())
        if expected_tokens is None
        else set(expected_tokens)
    )
    if not expected or "" in expected:
        raise ImportFailure("expected final-asset coverage must be non-empty")

    prepared_entries: list[PreparedEntry] = []
    covered: set[str] = set()
    destinations: set[PurePosixPath] = set()
    for index, raw_entry in enumerate(raw_entries):
        if not isinstance(raw_entry, dict):
            raise ImportFailure(f"entry {index} must be an object")
        source_relative = package_relative_path(
            raw_entry.get("source_file", ""), f"entry {index} source_file"
        )
        destination = package_relative_path(
            raw_entry.get("destination", ""), f"entry {index} destination"
        )
        if destination in destinations:
            raise ImportFailure(
                f"entry {index} repeats destination {destination.as_posix()!r}; "
                "combine its coverage tokens into one entry"
            )
        destinations.add(destination)

        source_path = package_root.joinpath(*source_relative.parts)
        resolved_source = source_path.resolve()
        if package_root != resolved_source and package_root not in resolved_source.parents:
            raise ImportFailure(f"entry {index} source escapes the package directory")
        if source_path.is_symlink():
            raise ImportFailure(f"entry {index} source_file must not be a symlink")
        if not resolved_source.is_file() or resolved_source.stat().st_size <= 0:
            raise ImportFailure(f"entry {index} source_file is missing or empty")
        if resolved_source.suffix.lower() != destination.suffix.lower():
            raise ImportFailure(
                f"entry {index} source and destination suffixes must match"
            )

        declared_hash = str(raw_entry.get("sha256", "")).lower()
        if not SHA256_PATTERN.fullmatch(declared_hash):
            raise ImportFailure(f"entry {index} sha256 must be a lowercase SHA-256")
        actual_hash = file_sha256(resolved_source)
        if declared_hash != actual_hash:
            raise ImportFailure(
                f"entry {index} SHA-256 mismatch for {source_relative.as_posix()}"
            )

        raw_covers = raw_entry.get("covers")
        if (
            not isinstance(raw_covers, list)
            or not raw_covers
            or any(not isinstance(token, str) or not token for token in raw_covers)
        ):
            raise ImportFailure(
                f"entry {index} covers must be a non-empty array of strings"
            )
        covers = tuple(raw_covers)
        if len(set(covers)) != len(covers):
            raise ImportFailure(f"entry {index} repeats a coverage token")
        duplicates = sorted(set(covers) & covered)
        if duplicates:
            raise ImportFailure(
                f"entry {index} duplicates already covered tokens: {duplicates}"
            )
        covered.update(covers)

        audio_flags = {token.startswith("audio:") for token in covers}
        if len(audio_flags) != 1:
            raise ImportFailure(
                f"entry {index} cannot mix audio and visual coverage tokens"
            )
        allowed_suffixes = AUDIO_SUFFIXES if True in audio_flags else VISUAL_SUFFIXES
        if destination.suffix.lower() not in allowed_suffixes:
            kind = "audio" if True in audio_flags else "visual"
            raise ImportFailure(
                f"entry {index} {kind} destination has unsupported suffix "
                f"{destination.suffix!r}"
            )

        provenance = str(raw_entry.get("source", "")).strip()
        license_terms = str(raw_entry.get("license", "")).strip()
        if not provenance:
            raise ImportFailure(f"entry {index} source provenance is required")
        if not license_terms:
            raise ImportFailure(f"entry {index} license or ownership terms are required")
        regions = validate_regions(raw_entry.get("regions", {}), covers, index)
        prepared_entries.append(
            PreparedEntry(
                source_path=resolved_source,
                destination=destination,
                resource_path=(
                    "res://game/assets/final/" + destination.as_posix()
                ),
                sha256=actual_hash,
                covers=covers,
                regions=regions,
                source=provenance,
                license=license_terms,
            )
        )

    missing = sorted(expected - covered)
    unknown = sorted(covered - expected)
    if missing:
        raise ImportFailure(
            f"{len(missing)} required coverage tokens are missing: {missing[:12]}"
        )
    if unknown:
        raise ImportFailure(f"unknown coverage tokens: {unknown}")

    audio_manifest_path = root / AUDIO_MANIFEST
    audio_manifest = load_json(audio_manifest_path)
    if not isinstance(audio_manifest, dict):
        raise ImportFailure("audio manifest root must be an object")
    updated_audio = copy.deepcopy(audio_manifest)
    audio_paths = {
        token: entry.resource_path
        for entry in prepared_entries
        for token in entry.covers
        if token.startswith("audio:")
    }
    routed_audio_tokens: set[str] = set()
    for kind in ("music", "sfx"):
        entries = updated_audio.get(kind)
        if not isinstance(entries, list):
            raise ImportFailure(f"audio manifest {kind} must be an array")
        for item in entries:
            if not isinstance(item, dict):
                raise ImportFailure(f"audio manifest {kind} entries must be objects")
            token = f"audio:{item.get('id', '')}"
            if token in audio_paths:
                item["path"] = audio_paths[token]
                routed_audio_tokens.add(token)
    unrouted = sorted(set(audio_paths) - routed_audio_tokens)
    if unrouted:
        raise ImportFailure(f"audio coverage has no runtime route: {unrouted}")
    updated_audio["development_placeholder"] = False

    app_icon_paths = [
        entry.resource_path
        for entry in prepared_entries
        if "ui:app_icon" in entry.covers
    ]
    if len(app_icon_paths) != 1:
        raise ImportFailure("ui:app_icon must resolve to exactly one resource")
    app_icon_path = app_icon_paths[0]

    project_text = (root / PROJECT_CONFIG).read_text(encoding="utf-8")
    export_text = (root / EXPORT_PRESETS).read_text(encoding="utf-8")
    release_text = (root / RELEASE_PROFILE).read_text(encoding="utf-8")
    if "const AUDIO_PLAYBACK_ENABLED: bool = false" not in release_text:
        raise ImportFailure(
            "audio playback must remain disabled during the current import phase"
        )
    updated_project = replace_setting(project_text, "config/icon", app_icon_path, 1)
    updated_exports = replace_setting(
        export_text, "application/icon", app_icon_path, 2
    )

    final_manifest = {
        "schema_version": 1,
        "ready": True,
        "provided_by_user": True,
        "package_id": package_id,
        "entries": [
            {
                "path": entry.resource_path,
                "sha256": entry.sha256,
                "covers": list(entry.covers),
                "regions": entry.regions,
                "source": entry.source,
                "license": entry.license,
            }
            for entry in prepared_entries
        ],
        "note": (
            "Imported byte-for-byte from a user-provided package. "
            "Audio playback remains disabled pending separate approval."
        ),
    }
    return PreparedImport(
        root=root,
        package_manifest=package_manifest,
        package_id=package_id,
        entries=tuple(prepared_entries),
        final_manifest_bytes=json_bytes(final_manifest),
        audio_manifest_bytes=json_bytes(updated_audio),
        project_config_bytes=updated_project.encode("utf-8"),
        export_presets_bytes=updated_exports.encode("utf-8"),
    )


def write_atomic(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{path.name}.", suffix=".tmp", dir=path.parent
    )
    temporary_path = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary_path, path)
    finally:
        if temporary_path.exists():
            temporary_path.unlink()


def apply_prepared(
    prepared: PreparedImport,
    *,
    post_commit_validator: Callable[[], bool] | None = None,
    fail_after_step: str | None = None,
) -> None:
    root = prepared.root
    final_directory = root / FINAL_DIRECTORY
    final_parent = final_directory.parent
    final_parent.mkdir(parents=True, exist_ok=True)
    transaction_id = uuid.uuid4().hex
    staging = final_parent / f".final-import-{transaction_id}"
    backup = final_parent / f".final-backup-{transaction_id}"
    config_paths = [
        root / AUDIO_MANIFEST,
        root / PROJECT_CONFIG,
        root / EXPORT_PRESETS,
        root / FINAL_MANIFEST,
    ]
    original_configs = {
        path: path.read_bytes() if path.exists() else None for path in config_paths
    }
    swapped_directory = False

    def maybe_fail(step: str) -> None:
        if fail_after_step == step:
            raise RuntimeError(f"injected final-asset import failure after {step}")

    try:
        staging.mkdir()
        for entry in prepared.entries:
            destination = staging.joinpath(*entry.destination.parts)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(entry.source_path, destination)
            if file_sha256(destination) != entry.sha256:
                raise ImportFailure(
                    f"staged copy hash mismatch for {entry.destination.as_posix()}"
                )
        maybe_fail("staging")

        if final_directory.exists():
            os.replace(final_directory, backup)
        os.replace(staging, final_directory)
        swapped_directory = True
        maybe_fail("assets")

        write_atomic(root / AUDIO_MANIFEST, prepared.audio_manifest_bytes)
        maybe_fail("audio_manifest")
        write_atomic(root / PROJECT_CONFIG, prepared.project_config_bytes)
        maybe_fail("project_config")
        write_atomic(root / EXPORT_PRESETS, prepared.export_presets_bytes)
        maybe_fail("export_presets")

        # The ready manifest is deliberately the last write. A machine loss
        # before this point cannot enable a partial final-asset set at runtime.
        write_atomic(root / FINAL_MANIFEST, prepared.final_manifest_bytes)
        maybe_fail("final_manifest")
        if post_commit_validator is not None and not post_commit_validator():
            raise ImportFailure("post-commit final-asset validation failed")
    except Exception:
        for path, original in original_configs.items():
            if original is None:
                if path.exists():
                    path.unlink()
            else:
                write_atomic(path, original)
        if swapped_directory and final_directory.exists():
            shutil.rmtree(final_directory)
        if backup.exists():
            os.replace(backup, final_directory)
        if staging.exists():
            shutil.rmtree(staging)
        raise
    else:
        if backup.exists():
            shutil.rmtree(backup)
        if staging.exists():
            shutil.rmtree(staging)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "package_manifest",
        type=Path,
        help="user-provided package manifest; source files are resolved beside it",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="commit the already validated package; without this flag only validate",
    )
    arguments = parser.parse_args()

    try:
        prepared = prepare_import(arguments.package_manifest)
        print(
            f"Validated final-asset package {prepared.package_id!r}: "
            f"{len(prepared.entries)} files, "
            f"{sum(len(entry.covers) for entry in prepared.entries)} coverage tokens"
        )
        if not arguments.apply:
            print(
                "Dry run only: no project file changed. "
                "Re-run with --apply after reviewing the package."
            )
            return 0
        apply_prepared(
            prepared,
            post_commit_validator=lambda: validate_final_assets.main() == 0,
        )
    except (ImportFailure, OSError, RuntimeError) as error:
        print(f"Final asset import failed: {error}", file=sys.stderr)
        return 1

    print(
        "Final asset import committed atomically. "
        "Audio playback remains disabled pending separate approval."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
