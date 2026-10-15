from __future__ import annotations

import configparser
import json
import os
from pathlib import Path
import plistlib
import struct
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch
import zipfile

import yaml


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import setup_ci_godot as setup
import build_ci_desktop as builds


class DesktopCITests(unittest.TestCase):
    def template_archive(self, directory: Path) -> Path:
        archive = directory / "templates.tpz"
        names = set().union(*setup.REQUIRED_TEMPLATES.values()) | {"icudt_godot.dat", "accesskit.x86_64.dll", "accesskit.x86_32.dll", "windows_release_x86_64_console.exe"}
        with zipfile.ZipFile(archive, "w") as source:
            for name in names:
                source.writestr("templates/" + name, setup.TEMPLATE_VERSION if name == "version.txt" else name)
        return archive

    def test_pinned_release_checksums_and_paths(self) -> None:
        self.assertEqual(set(setup.ENGINES), {"windows", "macos", "linux"})
        self.assertTrue(all(len(value) == 128 and all(character in "0123456789abcdef" for character in value) for value in setup.SHA512.values()))
        for filename in setup.SHA512:
            self.assertIn("4.6.3-stable", filename)
        for name in ["", ".", "../outside", "/outside", "C:/outside", "inside\\outside"]:
            self.assertFalse(setup.safe_zip_name(name))
        self.assertTrue(setup.safe_zip_name("Godot.app/Contents/MacOS/Godot"))

    def test_official_templates_are_split_and_verified_before_install(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = self.template_archive(root)
            with patch.dict(setup.SHA512, {setup.TEMPLATE_FILE:setup.digest(archive, "sha512")}):
                setup.prepare_template_bundles(archive, root / "bundles")
                for platform in setup.ENGINES:
                    bundle = root / "bundles" / platform
                    destination = root / "installed" / platform
                    setup.install_template_bundle(platform, bundle, destination)
                    self.assertTrue(all((destination / name).is_file() for name in setup.REQUIRED_TEMPLATES[platform]))
                self.assertTrue((root / "installed/windows/accesskit.x86_64.dll").is_file())
                self.assertTrue((root / "installed/windows/windows_release_x86_64_console.exe").is_file())
                self.assertFalse((root / "installed/windows/accesskit.x86_32.dll").exists())
                self.assertFalse((root / "installed/linux/macos.zip").exists())
                bundle = root / "bundles/linux"
                (bundle / "linux_release.x86_64").write_bytes(b"modified")
                with self.assertRaisesRegex(ValueError, "modified"):
                    setup.install_template_bundle("linux", bundle, root / "blocked")
                self.assertFalse((root / "blocked").exists())

    def test_bad_template_archive_or_manifest_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            archive = self.template_archive(root)
            with self.assertRaisesRegex(ValueError, "unverified"):
                setup.prepare_template_bundles(archive, root / "bundles")
            bundle = root / "unsafe"
            bundle.mkdir()
            record = {"godot_version":setup.VERSION, "platform":"linux", "official_archive_sha512":setup.SHA512[setup.TEMPLATE_FILE], "files":[{"name":name, "sha256":"0" * 64} for name in setup.REQUIRED_TEMPLATES["linux"] | {"../outside"}]}
            (bundle / "template-manifest.json").write_text(json.dumps(record))
            with self.assertRaises((ValueError, FileNotFoundError)):
                setup.install_template_bundle("linux", bundle, root / "blocked")
            self.assertFalse((root / "blocked").exists())

    def test_download_cache_must_match_pinned_hash(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            filename = setup.PREFIX + "linux.x86_64.zip"
            path = directory / filename
            path.write_bytes(b"verified fixture")
            with patch.dict(setup.SHA512, {filename:setup.digest(path, "sha512")}), patch.object(setup.urllib.request, "urlopen") as request:
                self.assertEqual(setup.download_verified(filename, directory), path)
                request.assert_not_called()

    def test_template_locations_match_native_platforms(self) -> None:
        with patch.object(setup.sys, "platform", "linux"), patch.dict(os.environ, {"XDG_DATA_HOME":"/fixture/share"}):
            self.assertEqual(setup.template_install_root(), Path("/fixture/share/godot/export_templates/4.6.3.stable"))
        with patch.object(setup.sys, "platform", "win32"), patch.dict(os.environ, {"APPDATA":"/fixture/roaming"}):
            self.assertEqual(setup.template_install_root(), Path("/fixture/roaming/Godot/export_templates/4.6.3.stable"))
        with patch.object(setup.sys, "platform", "darwin"), patch.object(setup.Path, "home", return_value=Path("/fixture")):
            self.assertEqual(setup.template_install_root(), Path("/fixture/Library/Application Support/Godot/export_templates/4.6.3.stable"))

    def test_six_presets_keep_profiles_architectures_and_filters(self) -> None:
        config = configparser.ConfigParser(interpolation=None)
        config.read(ROOT / "export_presets.cfg", encoding="utf-8")
        presets = {config[f"preset.{index}"]["name"].strip('"'):index for index in range(6)}
        self.assertEqual(set(presets), {name + suffix for name, _ in builds.TARGETS.values() for suffix in ["", " Demo"]})
        identifiers = []
        for name, index in presets.items():
            section = config[f"preset.{index}"]
            options = config[f"preset.{index}.options"]
            self.assertEqual(section["custom_features"], '"demo"' if name.endswith(" Demo") else '""')
            self.assertIn("tests/**", section["exclude_filter"])
            self.assertIn("build/**", section["exclude_filter"])
            self.assertIn("LICENSES/**", section["include_filter"])
            self.assertEqual(options["binary_format/architecture"], '"universal"' if name.startswith("macOS") else '"x86_64"')
            if name.startswith("macOS"):
                identifiers.append(options["application/bundle_identifier"])
                self.assertEqual(options["codesign/codesign"], "1")
                self.assertEqual(options["notarization/notarization"], "0")
        self.assertEqual(len(set(identifiers)), 2)
        rendering = (ROOT / "project.godot").read_text().split("[rendering]\n", 1)[1].split("\n[", 1)[0]
        for key in ("textures/vram_compression/import_s3tc_bptc", "textures/vram_compression/import_etc2_astc"):
            self.assertIn(key + "=true", rendering.splitlines())

    def test_workflow_uses_native_matrix_and_no_publish_permissions(self) -> None:
        workflow = yaml.load((ROOT / ".github/workflows/build-desktop.yml").read_text(), Loader=yaml.BaseLoader)
        self.assertEqual(workflow["permissions"], {"contents":"read"})
        self.assertIn("workflow_dispatch", workflow["on"])
        self.assertNotIn("pull_request_target", workflow["on"])
        self.assertEqual(workflow["jobs"]["build"]["needs"], "prepare")
        matrix = workflow["jobs"]["build"]["strategy"]["matrix"]["include"]
        self.assertEqual({row["platform"] for row in matrix}, set(builds.TARGETS))
        self.assertEqual({row["runner"] for row in matrix}, {"windows-2022", "macos-15", "ubuntu-24.04"})
        for job in workflow["jobs"].values():
            for step in job["steps"]:
                if "uses" in step:
                    action, revision = step["uses"].split("@")
                    self.assertTrue(action.startswith("actions/"))
                    self.assertEqual(len(revision), 40)
        self.assertTrue(any(step.get("if") == "always()" for step in workflow["jobs"]["build"]["steps"]))
        upload = next(step for step in workflow["jobs"]["build"]["steps"] if step.get("name") == "Upload playable development builds")
        self.assertNotIn("if", upload)
        self.assertEqual(upload["with"]["if-no-files-found"], "error")

    def test_linux_archive_preserves_execution_permission(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            runtime = root / "runtime"
            runtime.mkdir()
            executable = runtime / "pig.x86_64"
            header = b"\x7fELF\x02\x01" + b"\x00" * 12 + struct.pack("<H", 62)
            executable.write_bytes(header)
            executable.chmod(0o755)
            builds.validate_native("linux", executable, False)
            archive = builds.package_runtime("linux", runtime, executable, root, "pig")
            with tarfile.open(archive) as source:
                self.assertEqual(source.getmember("pig/pig.x86_64").mode & 0o777, 0o755)
            executable.chmod(0o644)
            with self.assertRaisesRegex(ValueError, "permission"):
                builds.validate_native("linux", executable, False)

    def test_mac_archive_requires_both_cpus_and_correct_profile(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "pig.zip"
            info = {"CFBundleIdentifier":"io.github.happys2333.piggame", "CFBundleExecutable":"pig"}
            header = b"\xca\xfe\xba\xbe" + struct.pack(">I", 2)
            for cpu in (0x01000007, 0x0100000C):
                header += struct.pack(">IIIII", cpu, 0, 0, 0, 0)
            with zipfile.ZipFile(archive, "w") as target:
                target.writestr("pig.app/Contents/Info.plist", plistlib.dumps(info))
                target.writestr("pig.app/Contents/MacOS/pig", header)
            builds.validate_native("macos", archive, False)
            with self.assertRaisesRegex(ValueError, "identifiers"):
                builds.validate_native("macos", archive, True)

    def test_runner_rejects_godot_errors_even_if_exit_is_zero(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            result = subprocess.CompletedProcess([], 0, "SCRIPT ERROR: fixture\n")
            with patch.object(builds.subprocess, "run", return_value=result):
                with self.assertRaisesRegex(RuntimeError, "failed"):
                    builds.run(["godot"], "probe", Path(temporary))
            self.assertTrue((Path(temporary) / "probe.log").is_file())

    def test_mac_packages_have_distinct_app_names_without_changing_signed_files(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            for name in ("PiggyDidNothingToday", "PiggyDidNothingTodayDemo"):
                original = root / (name + ".zip")
                member = zipfile.ZipInfo("pig.app/Contents/MacOS/pig")
                member.create_system = 3
                member.external_attr = 0o100755 << 16
                with zipfile.ZipFile(original, "w") as archive:
                    archive.writestr(member, b"signed executable bytes")
                    archive.writestr("pig.app/Contents/_CodeSignature/CodeResources", b"signature bytes")
                packaged = builds.package_runtime("macos", root, original, root, name + "-development")
                with zipfile.ZipFile(packaged) as archive:
                    self.assertEqual(archive.read(name + ".app/Contents/MacOS/pig"), b"signed executable bytes")
                    self.assertEqual(archive.getinfo(name + ".app/Contents/MacOS/pig").external_attr, member.external_attr)
                    self.assertEqual(archive.read(name + ".app/Contents/_CodeSignature/CodeResources"), b"signature bytes")

    def test_timeout_keeps_partial_log(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            error = subprocess.TimeoutExpired(["godot"], 600, output=b"partial import\n")
            with patch.object(builds.subprocess, "run", side_effect=error):
                with self.assertRaisesRegex(RuntimeError, "timed out"):
                    builds.run(["godot"], "import", Path(temporary))
            self.assertIn("partial import\n\nTIMEOUT:", (Path(temporary) / "import.log").read_text())

    def test_build_exports_profiles_sequentially_and_isolates_pack_loading(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "output"

            def stage_fixture(root: Path, stage: Path, user_name: str) -> None:
                builds.checks.validate_user_dir_name(user_name)
                stage.mkdir()
                (stage / "override.cfg").write_text("fixture")

            def command_fixture(command: list[str], label: str, logs: Path, environment=None, marker=None) -> str:
                if "--export-pack" in command:
                    Path(command[-1]).write_bytes(b"pack")
                if "--export-release" in command:
                    Path(command[-1]).write_bytes(b"runtime")
                if "--main-pack" in command:
                    pack = Path(command[command.index("--main-pack") + 1])
                    override = pack.parent / "override.cfg"
                    self.assertIn(environment["PIGGAME_EXPECTED_USER_DIR"], override.read_text())
                    self.assertEqual(Path(command[command.index("--path") + 1]), pack.parent)
                    self.assertIn("app_type=" + environment["PIGGAME_EXPECTED_APP_TYPE"], marker)
                return ""

            with patch.object(builds, "stage_project", side_effect=stage_fixture), patch.object(builds.identity, "source_tree_sha256", return_value="a" * 64), patch.object(builds, "run", side_effect=command_fixture) as run, patch.object(builds, "validate_native"), patch.object(builds.packages, "audit_package", return_value=(object(), [])), patch.object(builds.checks, "remove_isolated_user_data") as cleanup:
                builds.build(Path("godot"), ROOT, output, "windows")
            self.assertEqual([call.args[1] for call in run.call_args_list], ["import", "pack-full", "export-full", "load-full", "pack-demo", "export-demo", "load-demo"])
            cleanup.assert_called_once()
            record = json.loads((output / "artifacts/build-manifest.json").read_text())
            self.assertTrue(record["completed"])
            self.assertFalse(record["release_approved"])
            self.assertEqual([entry["profile"] for entry in record["artifacts"]], ["full", "demo"])
            self.assertEqual(len((output / "artifacts/SHA256SUMS.txt").read_text().splitlines()), 2)

    def test_failed_build_records_failure_and_cleans_isolated_user_data(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / "output"
            with patch.object(builds, "stage_project"), patch.object(builds.identity, "source_tree_sha256", return_value="a" * 64), patch.object(builds, "run", side_effect=RuntimeError("fixture failed")), patch.object(builds.checks, "remove_isolated_user_data") as cleanup:
                with self.assertRaisesRegex(RuntimeError, "fixture failed"):
                    builds.build(Path("godot"), ROOT, output, "linux")
            cleanup.assert_called_once()
            record = json.loads((output / "build-manifest.json").read_text())
            self.assertFalse(record["completed"])
            self.assertFalse(record["release_approved"])
            self.assertFalse((output / "artifacts/build-manifest.json").exists())
            self.assertEqual(record, json.loads((output / "logs/build-manifest.json").read_text()))


if __name__ == "__main__":
    unittest.main()
