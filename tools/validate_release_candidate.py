#!/usr/bin/env python3
"""Validate the machine-readable Windows candidate identity and PE artifacts."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path, PurePosixPath
from typing import Any


DEFAULT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = Path("docs/release/candidate-manifest.json")
WINDOWS_MATRIX_PATH = Path("docs/release/windows-test-matrix.md")
DOCUMENT_PATHS = (
    Path("docs/release/build-and-release.md"),
    WINDOWS_MATRIX_PATH,
)
RELEASE_PROFILE_PATH = Path("game/scripts/core/release_profile.gd")
SOURCE_INPUT_FILES = (
    Path("project.godot"),
    Path("export_presets.cfg"),
    Path("README.md"),
    Path("LICENSE"),
    Path("docs/release/privacy.md"),
    Path("docs/release/third-party-notices.md"),
)
SOURCE_INPUT_DIRECTORIES = (Path("LICENSES"), Path("game"))
EXPECTED_ARTIFACTS = {
    "full": (
        "build/windows/PiggyDidNothingToday.exe",
        "PiggyDidNothingToday.exe",
    ),
    "demo": (
        "build/windows/PiggyDidNothingTodayDemo.exe",
        "PiggyDidNothingTodayDemo.exe",
    ),
}
MAX_ARTIFACT_BYTES = 500 * 1024 * 1024
PE_MACHINE_X86_64 = 0x8664
PE32_PLUS_MAGIC = 0x20B
WINDOWS_GUI_SUBSYSTEM = 2
WINDOWS_MATRIX_REQUIRED_SCENARIOS = (
    ("minimum-layout", ("960×540", "设置/相册/照片/事件控件")),
    ("caption-reading-duration", ("字幕/气泡停留时间", "75%/100%/200%", "10 FPS")),
    ("main-window-modes", ("窗口化/全屏切换", "尺寸与位置恢复")),
    ("dpi", ("100% / 125% / 150% / 200% DPI",)),
    ("display-topology", ("单屏、双屏、拔插显示器",)),
    ("transparent-fallback", ("透明窗口与普通小窗降级",)),
    ("desktop-controls", ("置顶、穿透、缩放、三向停靠",)),
    ("desktop-background-protection", ("其他游戏", "独占全屏", "无边框全屏", "Alt-Tab", "安静/勿扰", "过期提醒")),
    ("resident-personalities", ("性格随机/自选", "多住客", "旧档", "不重抽")),
    ("pig-performances", ("基础猪五类表现", "四帧姿势", "装扮解锁", "临时梗状态", "头部嘴眼锚定", "游戏前台不补演")),
    (
        "desktop-action-frequency",
        ("降低动作频率", "至少 45 秒", "底层模拟、奖励、熟悉度、冷却与事件发现"),
    ),
    ("desktop-hit-testing", ("透明区点击可穿透", "事件气泡可点击")),
    ("desktop-lifecycle", ("暂停/继续", "隐藏到任务栏", "返回小屋", "全部退出")),
    ("reduced-motion", ("减少动态", "减少桌面游走范围")),
    ("host-compatibility", ("全屏应用", "浏览器视频", "录屏软件", "显卡驱动")),
    ("os-session-clock", ("睡眠", "休眠", "锁屏", "切换用户", "系统时间")),
    ("long-running", ("连续 2/8/24 小时",)),
    ("install-lifecycle", ("首次启动", "升级覆盖", "卸载重装", "只读目录")),
    ("steam-runtime", ("Steam 在线/离线/云冲突/无客户端",)),
    ("steam-profile-isolation", ("App ID", "Auto-Cloud 路径隔离")),
    ("language-review", ("简体中文", "繁体中文", "英语", "占位键", "关键歧义")),
    ("performance", ("静止 CPU", "活动 CPU", "内存", "主屋 60 FPS")),
)


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise ValueError(f"{path}: cannot read candidate manifest: {error}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{path}: candidate manifest root must be an object")
    return value


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def source_tree_sha256(root: Path) -> str:
    paths: list[Path] = []
    for relative in SOURCE_INPUT_FILES:
        path = root / relative
        if not path.is_file():
            raise ValueError(f"required candidate source file is missing: {path}")
        paths.append(path)
    for relative in SOURCE_INPUT_DIRECTORIES:
        directory = root / relative
        if not directory.is_dir():
            raise ValueError(f"required candidate source directory is missing: {directory}")
        paths.extend(
            path
            for path in directory.rglob("*")
            if path.is_file()
            and not any(part.startswith(".") for part in path.relative_to(root).parts)
        )
    digest = hashlib.sha256()
    for path in sorted(set(paths), key=lambda item: item.relative_to(root).as_posix()):
        relative_bytes = path.relative_to(root).as_posix().encode("utf-8")
        digest.update(struct.pack(">I", len(relative_bytes)))
        digest.update(relative_bytes)
        digest.update(struct.pack(">Q", path.stat().st_size))
        with path.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
    return digest.hexdigest()


def validate_pe(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        with path.open("rb") as stream:
            dos_header = stream.read(64)
            if len(dos_header) < 64 or dos_header[:2] != b"MZ":
                return [f"{path}: missing DOS MZ header"]
            pe_offset = struct.unpack_from("<I", dos_header, 0x3C)[0]
            if pe_offset < 64 or pe_offset > path.stat().st_size - 94:
                return [f"{path}: invalid PE header offset {pe_offset}"]
            stream.seek(pe_offset)
            header = stream.read(94)
    except OSError as error:
        return [f"{path}: cannot inspect PE header: {error}"]

    if header[:4] != b"PE\0\0":
        errors.append(f"{path}: missing PE signature")
        return errors
    machine = struct.unpack_from("<H", header, 4)[0]
    optional_header_size = struct.unpack_from("<H", header, 20)[0]
    if machine != PE_MACHINE_X86_64:
        errors.append(f"{path}: PE machine must be x86-64 (0x8664), got 0x{machine:04x}")
    if optional_header_size < 70:
        errors.append(f"{path}: PE optional header is too short: {optional_header_size}")
        return errors
    magic = struct.unpack_from("<H", header, 24)[0]
    subsystem = struct.unpack_from("<H", header, 24 + 68)[0]
    if magic != PE32_PLUS_MAGIC:
        errors.append(f"{path}: optional header must be PE32+ (0x20b), got 0x{magic:x}")
    if subsystem != WINDOWS_GUI_SUBSYSTEM:
        errors.append(f"{path}: subsystem must be Windows GUI (2), got {subsystem}")
    return errors


def is_safe_relative_path(value: str) -> bool:
    path = PurePosixPath(value)
    return (
        bool(value)
        and "\\" not in value
        and not path.is_absolute()
        and all(part not in {"", ".", ".."} for part in path.parts)
    )


def validate_windows_matrix_scope(source: str, path: Path) -> list[str]:
    errors: list[str] = []
    for scenario, markers in WINDOWS_MATRIX_REQUIRED_SCENARIOS:
        missing = [marker for marker in markers if marker not in source]
        if missing:
            errors.append(
                f"{path}: missing required Windows acceptance scenario "
                f"{scenario!r}: {missing}"
            )
    return errors


def validate_windows_probe_commands(
    source: str, path: Path, artifacts: list[dict[str, Any]]
) -> list[str]:
    errors: list[str] = []
    command_index = 0
    blocks = re.findall(
        r"^```(?:powershell|pwsh)[ \t]*\r?\n(.*?)^```[ \t]*\r?$",
        source,
        re.IGNORECASE | re.MULTILINE | re.DOTALL,
    )
    for block in blocks:
        normalized = re.sub(r"`[ \t]*\r?\n[ \t]*", " ", block)
        commands = re.findall(
            r"^[ \t]*&[ \t]+[^\r\n]*\bwindows_runtime_probe\.ps1\b[^\r\n]*\r?$",
            normalized,
            re.IGNORECASE | re.MULTILINE,
        )
        for command in commands:
            command_index += 1
            context = f"{path}: Windows probe command {command_index}"
            parameters: dict[str, list[str]] = {}
            for match in re.finditer(
                r'''(?<!\S)-([A-Za-z][A-Za-z0-9]*)\s+(?:"([^"\r\n]*)"|'([^'\r\n]*)'|((?!-)[^\s`]+))''',
                command,
            ):
                value = next(value for value in match.groups()[1:] if value is not None)
                parameters.setdefault(match[1].lower(), []).append(value)
            sizes = parameters.get("expectedsizebytes", [])
            hashes = parameters.get("expectedsha256", [])
            if len(sizes) != 1 or len(hashes) != 1:
                errors.append(
                    f"{context} must contain exactly one -ExpectedSizeBytes "
                    "and one -ExpectedSha256"
                )
                continue
            executables = parameters.get("executablepath", [])
            processes = parameters.get("processid", [])
            if len(executables) + len(processes) != 1:
                errors.append(
                    f"{context} must contain exactly one -ExecutablePath or -ProcessId"
                )
                continue
            candidates = artifacts
            if executables:
                file_name = executables[0].replace("\\", "/").rsplit("/", 1)[-1]
                candidates = [
                    item for item in artifacts
                    if str(item["file_name"]).casefold() == file_name.casefold()
                ]
                if not candidates:
                    errors.append(f"{context} must target a known candidate executable")
                    continue
            if not any(
                sizes[0] == str(item["size_bytes"])
                and hashes[0].lower() == str(item["sha256"])
                for item in candidates
            ):
                errors.append(
                    f"{context} expected size and SHA-256 must match the same candidate identity"
                )
    return errors


def validate_candidate_set(
    root: Path,
    manifest_path: Path,
    document_paths: tuple[Path, ...] | list[Path] | None = None,
) -> list[str]:
    errors: list[str] = []
    try:
        manifest = load_json(manifest_path)
    except ValueError as error:
        return [str(error)]

    if manifest.get("schema_version") != 1:
        errors.append("candidate manifest schema_version must be 1")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(manifest.get("generated_date", ""))):
        errors.append("candidate manifest generated_date must use YYYY-MM-DD")
    if manifest.get("release_stage") != "silent-development-candidate":
        errors.append("release_stage must remain silent-development-candidate")
    engine_version = str(manifest.get("engine_version", ""))
    if not engine_version.startswith("4.6.") or ".stable." not in engine_version:
        errors.append("engine_version must identify a Godot 4.6 stable build")
    if manifest.get("export_host") != "macOS":
        errors.append("export_host must record the current macOS cross-export environment")
    if manifest.get("audio_playback_enabled") is not False:
        errors.append("audio_playback_enabled must remain false")
    declared_source_hash = manifest.get("source_tree_sha256")
    if not isinstance(declared_source_hash, str) or not re.fullmatch(
        r"[0-9a-f]{64}", declared_source_hash
    ):
        errors.append("source_tree_sha256 must be a lowercase SHA-256 digest")
    else:
        try:
            actual_source_hash = source_tree_sha256(root)
        except ValueError as error:
            errors.append(str(error))
        else:
            if declared_source_hash != actual_source_hash:
                errors.append(
                    "source tree SHA-256 differs from the exported candidate snapshot: "
                    f"expected {declared_source_hash}, got {actual_source_hash}"
                )
    release_profile_path = root / RELEASE_PROFILE_PATH
    try:
        release_profile_source = release_profile_path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        errors.append(f"cannot read ReleaseProfile audio gate {release_profile_path}: {error}")
    else:
        if not re.search(
            r"^const\s+AUDIO_PLAYBACK_ENABLED:\s*bool\s*=\s*false\s*$",
            release_profile_source,
            re.MULTILINE,
        ):
            errors.append("ReleaseProfile.AUDIO_PLAYBACK_ENABLED must remain typed false")

    artifacts = manifest.get("artifacts")
    if not isinstance(artifacts, list):
        return errors + ["candidate manifest artifacts must be an array"]
    profile_counts: dict[str, int] = {}
    for item in artifacts:
        if isinstance(item, dict):
            profile = str(item.get("profile", ""))
            profile_counts[profile] = profile_counts.get(profile, 0) + 1
    if profile_counts != {"full": 1, "demo": 1}:
        errors.append(
            "candidate manifest must contain exactly one full and one demo artifact: "
            f"{profile_counts}"
        )

    validated_items: list[dict[str, Any]] = []
    for index, item in enumerate(artifacts):
        if not isinstance(item, dict):
            errors.append(f"artifacts[{index}] must be an object")
            continue
        profile = str(item.get("profile", ""))
        if profile not in EXPECTED_ARTIFACTS:
            errors.append(f"artifacts[{index}].profile is unsupported: {profile!r}")
            continue
        expected_path, expected_file_name = EXPECTED_ARTIFACTS[profile]
        relative_path = str(item.get("path", ""))
        file_name = str(item.get("file_name", ""))
        size_bytes = item.get("size_bytes")
        sha256 = item.get("sha256")
        if not is_safe_relative_path(relative_path):
            errors.append(f"{profile}: artifact path is unsafe: {relative_path!r}")
            continue
        if relative_path != expected_path:
            errors.append(f"{profile}: artifact path must be {expected_path!r}")
        if file_name != expected_file_name or PurePosixPath(relative_path).name != file_name:
            errors.append(f"{profile}: file_name must be {expected_file_name!r} and match path")
        if not isinstance(size_bytes, int) or isinstance(size_bytes, bool) or size_bytes <= 0:
            errors.append(f"{profile}: size_bytes must be a positive integer")
        elif size_bytes >= MAX_ARTIFACT_BYTES:
            errors.append(f"{profile}: artifact must remain below 500 MiB")
        if (
            not isinstance(sha256, str)
            or not re.fullmatch(r"[0-9a-f]{64}", sha256)
        ):
            errors.append(f"{profile}: sha256 must be a lowercase SHA-256 digest")
        if item.get("format") != "PE32+ GUI x86-64":
            errors.append(f"{profile}: format must be 'PE32+ GUI x86-64'")

        artifact_path = root.joinpath(*PurePosixPath(relative_path).parts)
        if not artifact_path.is_file():
            errors.append(f"{profile}: artifact does not exist: {artifact_path}")
            continue
        actual_size = artifact_path.stat().st_size
        actual_hash = file_sha256(artifact_path)
        if size_bytes != actual_size:
            errors.append(f"{profile}: size differs from artifact bytes: expected {size_bytes}, got {actual_size}")
        if sha256 != actual_hash:
            errors.append(f"{profile}: SHA-256 differs from artifact bytes: expected {sha256}, got {actual_hash}")
        errors.extend(validate_pe(artifact_path))
        validated_items.append(item)

    docs = list(document_paths) if document_paths is not None else [root / path for path in DOCUMENT_PATHS]
    for document_path in docs:
        try:
            source = document_path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            errors.append(f"cannot read candidate identity document {document_path}: {error}")
            continue
        errors.extend(validate_windows_probe_commands(source, document_path, validated_items))
        if document_path.name == WINDOWS_MATRIX_PATH.name:
            errors.extend(validate_windows_matrix_scope(source, document_path))
        if isinstance(declared_source_hash, str) and declared_source_hash not in source:
            errors.append(
                f"{document_path}: missing candidate source tree SHA-256 marker: "
                f"{declared_source_hash}"
            )
        for item in validated_items:
            profile = str(item["profile"])
            expected_markers = (
                str(item["file_name"]),
                f"{int(item['size_bytes']):,}",
                str(item["sha256"]),
            )
            missing = [marker for marker in expected_markers if marker not in source]
            if missing:
                errors.append(
                    f"{document_path}: missing {profile} candidate identity markers: {missing}"
                )
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate Windows candidate manifest, PE bytes, budgets, and release docs."
    )
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    arguments = parser.parse_args()
    root = arguments.root.resolve()
    manifest_path = arguments.manifest
    if not manifest_path.is_absolute():
        manifest_path = root / manifest_path
    errors = validate_candidate_set(root, manifest_path)
    if errors:
        print("Release candidate validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1
    manifest = load_json(manifest_path)
    for item in manifest["artifacts"]:
        print(
            f"PASS {item['profile']}: {item['file_name']}, "
            f"{item['size_bytes']} bytes, SHA-256 {item['sha256']}"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
