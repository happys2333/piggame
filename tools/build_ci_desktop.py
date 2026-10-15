"""Build sequential Full/Demo development artifacts and audit isolated packs."""

from __future__ import annotations

import argparse
from copy import copy
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tarfile
import tempfile
import uuid
import zipfile

import run_godot_checks as checks
import setup_ci_godot as setup
import validate_export_package as packages
import validate_release_candidate as identity


ROOT = Path(__file__).resolve().parents[1]
TARGETS = {
    "windows": ("Windows x64", ".exe"),
    "macos": ("macOS Universal", ".zip"),
    "linux": ("Linux x64", ".x86_64"),
}


def run(command: list[str], label: str, logs: Path, environment: dict[str, str] | None = None, marker: str | None = None) -> str:
    logs.mkdir(parents=True, exist_ok=True)
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=600, env=environment)
    except subprocess.TimeoutExpired as error:
        output = error.stdout or b""
        if isinstance(output, bytes):
            output = output.decode("utf-8", errors="replace")
        (logs / (label + ".log")).write_text(output + "\nTIMEOUT: command exceeded 600 seconds\n", encoding="utf-8")
        raise RuntimeError(label + " timed out; see the uploaded log") from error
    (logs / (label + ".log")).write_text(result.stdout, encoding="utf-8")
    print(f"[{label}] exit={result.returncode}", flush=True)
    if checks.result_exit_code(result, label, marker) or "ObjectDB instances leaked" in result.stdout or "resources still in use at exit" in result.stdout:
        print(result.stdout, flush=True)
        raise RuntimeError(label + " failed; see the uploaded log")
    return result.stdout


def stage_project(root: Path, stage: Path, user_name: str) -> None:
    checks.stage_project(root, stage, user_name)
    shutil.copytree(root / "LICENSES", stage / "LICENSES")
    for relative in identity.SOURCE_INPUT_FILES:
        destination = stage / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(root / relative, destination)


def validate_native(platform: str, path: Path, demo: bool) -> None:
    if platform == "windows":
        errors = identity.validate_pe(path)
        if errors:
            raise ValueError("; ".join(errors))
    elif platform == "linux":
        with path.open("rb") as handle:
            header = handle.read(20)
        if len(header) != 20 or header[:6] != b"\x7fELF\x02\x01" or int.from_bytes(header[18:20], "little") != 62:
            raise ValueError("expected an ELF64 x86-64 runtime")
        if not path.stat().st_mode & 0o111:
            raise ValueError("Linux executable permission is missing")
    else:
        with zipfile.ZipFile(path) as archive:
            if any(not setup.safe_zip_name(name) for name in archive.namelist()):
                raise ValueError("unsafe macOS archive")
            plists = [name for name in archive.namelist() if name.endswith(".app/Contents/Info.plist")]
            if len(plists) != 1:
                raise ValueError("expected exactly one macOS app bundle")
            info = plistlib.loads(archive.read(plists[0]))
            expected = "io.github.happys2333.piggame" + (".demo" if demo else "")
            if info.get("CFBundleIdentifier") != expected:
                raise ValueError("macOS Full/Demo bundle identifiers are not isolated")
            executable = plists[0].removesuffix("Info.plist") + "MacOS/" + info["CFBundleExecutable"]
            with archive.open(executable) as handle:
                header = handle.read(8)
                magic = header[:4]
                count = int.from_bytes(header[4:8], "big")
                width = 20 if magic == b"\xca\xfe\xba\xbe" else 32
                records = handle.read(width * count) if count <= 8 else b""
            if magic not in {b"\xca\xfe\xba\xbe", b"\xca\xfe\xba\xbf"}:
                raise ValueError("expected a universal macOS executable")
            architectures = {int.from_bytes(records[offset:offset + 4], "big") for offset in range(0, len(records), width)}
            if not {0x01000007, 0x0100000C} <= architectures:
                raise ValueError("macOS bundle must include both Intel and Apple Silicon")


def package_runtime(platform: str, runtime: Path, native_path: Path, output: Path, stem: str) -> Path:
    if platform == "macos":
        target = output / (stem + ".zip")
        with zipfile.ZipFile(native_path) as source, zipfile.ZipFile(target, "w") as archive:
            for member in source.infolist():
                bundle, _, relative = member.filename.partition("/")
                if not bundle.endswith(".app"):
                    raise ValueError("unexpected file outside the macOS app bundle")
                renamed = copy(member)
                renamed.filename = native_path.stem + ".app/" + relative
                with source.open(member) as original, archive.open(renamed, "w") as destination:
                    shutil.copyfileobj(original, destination)
    elif platform == "windows":
        target = output / (stem + ".zip")
        with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(runtime.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(runtime))
    else:
        target = output / (stem + ".tar.gz")
        with tarfile.open(target, "w:gz") as archive:
            archive.add(runtime, arcname=stem)
    return target


def build(godot: Path, root: Path, output: Path, platform: str | None) -> None:
    output.mkdir(parents=True, exist_ok=True)
    logs = output / "logs"
    user_name = checks.USER_DIR_PREFIX + uuid.uuid4().hex
    source_hash = identity.source_tree_sha256(root)
    report = {"build_type":"development", "release_approved":False, "godot_version":setup.VERSION, "source_tree_sha256":source_hash, "source_revision":os.environ.get("GITHUB_SHA", "local-working-tree"), "platform":platform, "native_ui_verified":False, "physical_audio_verified":False, "artifacts":[], "completed":False}
    environment = {**os.environ, "PIGGAME_EXPECTED_USER_DIR":user_name}
    try:
        with tempfile.TemporaryDirectory(prefix="piggame-ci-") as temporary:
            stage = Path(temporary) / "project"
            stage_project(root, stage, user_name)
            if identity.source_tree_sha256(stage) != source_hash:
                raise RuntimeError("staged export inputs differ from the source snapshot")
            common = [str(godot), "--headless", "--audio-driver", "Dummy", "--path", str(stage)]
            run(common + ["--editor", "--quit"], "import", logs, environment)
            if platform is None:
                for label, arguments, marker in checks.CHECKS[1:]:
                    run(common + list(arguments), label.replace(" ", "-"), logs, environment, marker)
                gate = subprocess.run([os.sys.executable, str(root / "tools/validate_final_assets.py")], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", timeout=60)
                (logs / "final-assets.log").write_text(gate.stdout, encoding="utf-8")
                report["final_asset_gate_exit_code"] = gate.returncode
                if gate.returncode not in (0, 1):
                    raise RuntimeError("final asset validator crashed")
            else:
                (stage / "override.cfg").unlink()
                artifacts = output / "artifacts"
                artifacts.mkdir(exist_ok=True)
                packs: dict[str, Path] = {}
                for profile in ("full", "demo"):
                    demo = profile == "demo"
                    name = "PiggyDidNothingToday" + ("Demo" if demo else "")
                    preset = TARGETS[platform][0] + (" Demo" if demo else "")
                    runtime = Path(temporary) / ("runtime-" + profile)
                    runtime.mkdir()
                    pack = Path(temporary) / (profile + ".zip")
                    packs[profile] = pack
                    native_path = runtime / (name + TARGETS[platform][1])
                    run(common + ["--export-pack", preset, str(pack)], "pack-" + profile, logs)
                    run(common + ["--export-release", preset, str(native_path)], "export-" + profile, logs)
                    validate_native(platform, native_path, demo)
                    load_root = Path(temporary) / ("load-" + profile)
                    load_root.mkdir()
                    local_pack = load_root / pack.name
                    shutil.copy2(pack, local_pack)
                    (load_root / "override.cfg").write_text('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + user_name + '"\n', encoding="utf-8")
                    run([str(godot), "--headless", "--audio-driver", "Dummy", "--path", str(load_root), "--main-pack", str(local_pack), "--script", str(stage / "tests/export_pack_probe.gd")], "load-" + profile, logs, {**environment, "PIGGAME_EXPECTED_APP_TYPE":"1" if demo else "0"}, "PASS: exported pack startup app_type=%d visuals=222 frames=4 residents=2 cache<=8 feedback_only=true protection=true timer=25/5 personalities=5 performances=9/9/6/2 postcards=8 splash=false outfits=head/face:8 retired=4" % (1 if demo else 0))
                    stem = name + "-" + platform + "-development"
                    packaged = package_runtime(platform, runtime, native_path, artifacts, stem)
                    if platform == "macos" and os.sys.platform == "darwin":
                        extracted = Path(temporary) / ("signature-" + profile)
                        run(["/usr/bin/ditto", "-xk", str(packaged), str(extracted)], "unzip-" + profile, logs)
                        run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(extracted / (name + ".app"))], "signature-" + profile, logs)
                    report["artifacts"].append({"profile":profile, "file":packaged.name, "sha256":identity.file_sha256(packaged), "size_bytes":packaged.stat().st_size})
                for profile, pack in packs.items():
                    summary, errors = packages.audit_package(profile, pack)
                    if errors or summary is None:
                        raise ValueError("resource pack audit: " + "; ".join(errors))
                report["resource_pack_audit_passed"] = True
                (artifacts / "SHA256SUMS.txt").write_text("".join(entry["sha256"] + "  " + entry["file"] + "\n" for entry in report["artifacts"]), encoding="utf-8")
            if identity.source_tree_sha256(root) != source_hash:
                raise RuntimeError("source tree changed during build")
            report["completed"] = True
    finally:
        checks.remove_isolated_user_data(setup.application_data_root(), user_name)
        report["generated_at"] = datetime.now(timezone.utc).isoformat()
        destination = output / "artifacts/build-manifest.json" if platform and report["completed"] else output / "build-manifest.json"
        destination.parent.mkdir(parents=True, exist_ok=True)
        metadata = json.dumps(report, indent=2) + "\n"
        destination.write_text(metadata, encoding="utf-8")
        logs.mkdir(parents=True, exist_ok=True)
        (logs / "build-manifest.json").write_text(metadata, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--root", type=Path, default=ROOT)
    parser.add_argument("--output", type=Path, required=True)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--platform", choices=TARGETS)
    mode.add_argument("--checks-only", action="store_true")
    arguments = parser.parse_args()
    build(arguments.godot.resolve(), arguments.root.resolve(), arguments.output.resolve(), arguments.platform)


if __name__ == "__main__":
    main()
