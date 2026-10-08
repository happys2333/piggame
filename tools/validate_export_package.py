#!/usr/bin/env python3
"""Audit full and Demo Godot ZIP packs before release export."""

from __future__ import annotations

import argparse
import hashlib
import re
import sys
import zipfile
from collections import Counter
from dataclasses import dataclass
from pathlib import Path, PurePosixPath


REQUIRED_FILES = {
    "game/data/catalog/pig_performances.json",
    "game/data/catalog/pig_visual_rig.json",
    "game/scripts/ui/pig_visual_rig.gdc",
    "game/scripts/ui/pig_behavior_portrait.gdc",
    "LICENSE",
    "README.md",
    "LICENSES/NotoEmoji/LICENSE.txt",
    "LICENSES/NotoEmoji/SOURCE.md",
    "docs/release/privacy.md",
    "docs/release/third-party-notices.md",
    "project.binary",
    "game/scenes/main.tscn.remap",
    "game/scripts/core/content_catalog.gdc",
    "game/scripts/core/game_session.gdc",
    "game/scripts/core/release_profile.gdc",
    "game/scripts/ui/main.gdc",
}
FORBIDDEN_PREFIXES = (
    "build/",
    "assest/",
    "script/",
    "game/assets/upstream/",
    "game/assets/ui/",
    "tests/",
    "tools/",
    "docs/design/",
    "docs/decisions/",
)
FORBIDDEN_FILES = {
    "start.tscn",
    "popup.tscn",
    "settings.tscn",
}
ALLOWED_RELEASE_DOCUMENTS = {
    "docs/release/privacy.md",
    "docs/release/third-party-notices.md",
}
EXTERNAL_INTEGRATION_SUFFIXES = {
    ".dll",
    ".dylib",
    ".exe",
    ".gdextension",
    ".gdnlib",
    ".so",
    ".wasm",
}
REMAP_TARGET = re.compile(rb'^path="res://([^"\r\n]+)"$', re.MULTILINE)
REQUIRED_FILE_SHA256 = {
    "LICENSES/NotoEmoji/LICENSE.txt": "5c2258478882d24fecd707c685e480c5ddd352ab4ab984bc8ee5919d04f42048",
}
REQUIRED_TEXT_MARKERS = {
    "LICENSES/NotoEmoji/SOURCE.md": (
        "f2a4f72bffe0212c72949a22698be235269bfab5",
        "1352019e5be1dff3308f3bc6c9fb2d35b3f8bed971ef43c5c2aa96e59b7481c3",
        "63163d0374eb36b54081cda18063664e47efcfc186137a5d5eb786edbfd82b3b",
        "only archival-file byte difference",
    ),
    "docs/release/third-party-notices.md": (
        "## 简体中文",
        "## 繁體中文",
        "## English",
        "f2a4f72bffe0212c72949a22698be235269bfab5",
        "Apache License 2.0",
        "本项目不受 Google 赞助、认可，也不隶属于 Google",
        "本專案不受 Google 贊助、認可，也不隸屬於 Google",
        "not sponsored, endorsed by, or affiliated with Google",
        "legacy `assest/` directory",
    ),
    "docs/release/privacy.md": (
        "## 简体中文",
        "## 繁體中文",
        "## English",
        "不要求账号",
        "不要求帳號",
        "requires no account",
        "no advertising SDK",
        "不会自动上传",
        "不會自動上傳",
        "never uploaded automatically",
        "两个安全备份",
        "兩份安全備份",
        "two safety backups",
        "正式版和 Demo 使用互相隔离的云路径",
        "正式版與 Demo 使用互相隔離的雲端路徑",
        "full game and Demo use isolated cloud paths",
    ),
}


@dataclass(frozen=True)
class PackageSummary:
    label: str
    path: Path
    files: int
    game_resources: int
    compiled_scripts: int
    imported_resources: int
    archive_bytes: int
    uncompressed_bytes: int


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate the contents of full and Demo Godot ZIP export packs."
    )
    parser.add_argument("full", type=Path, help="ZIP pack exported with the Windows x64 preset")
    parser.add_argument("demo", type=Path, help="ZIP pack exported with the Windows x64 Demo preset")
    return parser.parse_args()


def is_unsafe_name(name: str) -> bool:
    path = PurePosixPath(name)
    return (
        not name
        or "\\" in name
        or path.is_absolute()
        or any(part in {"", ".", ".."} for part in path.parts)
    )


def audit_package(label: str, path: Path) -> tuple[PackageSummary | None, list[str]]:
    errors: list[str] = []
    if not path.is_file():
        return None, [f"{label}: archive does not exist: {path}"]

    try:
        with zipfile.ZipFile(path) as archive:
            infos = [item for item in archive.infolist() if not item.is_dir()]
            names = [item.filename for item in infos]
            duplicates = sorted(name for name, count in Counter(names).items() if count != 1)
            if duplicates:
                errors.append(f"{label}: duplicate archive paths: {duplicates}")

            unsafe = sorted(name for name in names if is_unsafe_name(name))
            if unsafe:
                errors.append(f"{label}: unsafe archive paths: {unsafe}")

            files = set(names)
            missing = sorted(REQUIRED_FILES - files)
            if missing:
                errors.append(f"{label}: missing required files: {missing}")

            for name, expected_digest in REQUIRED_FILE_SHA256.items():
                if name not in files:
                    continue
                actual_digest = hashlib.sha256(archive.read(name)).hexdigest()
                if actual_digest != expected_digest:
                    errors.append(
                        f"{label}: required file SHA-256 mismatch for {name}: "
                        f"expected {expected_digest}, got {actual_digest}"
                    )
            for name, markers in REQUIRED_TEXT_MARKERS.items():
                if name not in files:
                    continue
                text = archive.read(name).decode("utf-8", errors="replace")
                missing_markers = [marker for marker in markers if marker not in text]
                if missing_markers:
                    errors.append(
                        f"{label}: required release notice markers are missing from {name}: "
                        f"{missing_markers}"
                    )

            forbidden = sorted(
                name
                for name in files
                if name in FORBIDDEN_FILES
                or any(name.startswith(prefix) for prefix in FORBIDDEN_PREFIXES)
                or (
                    name.startswith("docs/release/")
                    and name not in ALLOWED_RELEASE_DOCUMENTS
                )
            )
            if forbidden:
                errors.append(f"{label}: forbidden development or legacy paths: {forbidden}")

            external_integrations = sorted(
                name
                for name in files
                if "addons" in PurePosixPath(name).parts
                or PurePosixPath(name).suffix.lower() in EXTERNAL_INTEGRATION_SUFFIXES
            )
            if external_integrations:
                errors.append(
                    f"{label}: unreviewed external integration paths: {external_integrations}"
                )

            validation_images = sorted(
                name
                for name in files
                if PurePosixPath(name).suffix.lower() == ".png"
                and any("validation" in part.lower() for part in PurePosixPath(name).parts)
            )
            if validation_images:
                errors.append(f"{label}: validation screenshots leaked into package: {validation_images}")

            for name in sorted(item for item in files if item.endswith(".remap")):
                data = archive.read(name)
                match = REMAP_TARGET.search(data)
                if match is None:
                    errors.append(f"{label}: invalid remap file without a resource target: {name}")
                    continue
                target = match.group(1).decode("utf-8", errors="replace")
                if target not in files:
                    errors.append(f"{label}: remap target is absent: {name} -> {target}")

            corrupt = archive.testzip()
            if corrupt is not None:
                errors.append(f"{label}: CRC check failed for {corrupt}")

            summary = PackageSummary(
                label=label,
                path=path,
                files=len(infos),
                game_resources=sum(name.startswith("game/") for name in names),
                compiled_scripts=sum(name.endswith(".gdc") for name in names),
                imported_resources=sum(name.startswith(".godot/imported/") for name in names),
                archive_bytes=path.stat().st_size,
                uncompressed_bytes=sum(item.file_size for item in infos),
            )
            return summary, errors
    except (OSError, UnicodeError, zipfile.BadZipFile, zipfile.LargeZipFile) as error:
        return None, [f"{label}: cannot read ZIP archive: {error}"]


def format_mib(value: int) -> str:
    return f"{value / (1024 * 1024):.2f} MiB"


def main() -> int:
    args = parse_args()
    results = (
        audit_package("full", args.full),
        audit_package("demo", args.demo),
    )
    errors = [error for _, package_errors in results for error in package_errors]
    if errors:
        print("Export package validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    for summary, _ in results:
        assert summary is not None
        print(
            f"PASS {summary.label}: {summary.files} files, "
            f"{summary.game_resources} game resources, "
            f"{summary.compiled_scripts} compiled scripts, "
            f"{summary.imported_resources} imported resources, "
            f"ZIP {format_mib(summary.archive_bytes)}, "
            f"uncompressed {format_mib(summary.uncompressed_bytes)}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
