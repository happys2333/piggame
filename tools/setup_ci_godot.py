"""Install pinned official Godot binaries and verified platform template bundles."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import time
import urllib.request
import zipfile


VERSION = "4.6.3"
TEMPLATE_VERSION = VERSION + ".stable"
BASE_URL = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/"
PREFIX = f"Godot_v{VERSION}-stable_"
TEMPLATE_FILE = PREFIX + "export_templates.tpz"
SHA512 = {
    TEMPLATE_FILE: "da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68",
    PREFIX + "linux.x86_64.zip": "a035258da32b77f966a5376f9fa29c30a6adde826a85ba918e1605bd1fc9823eba7d85f1dd5e748956bd2ba72827c0025ffa11bb82aec91128c407a2e723c99c",
    PREFIX + "macos.universal.zip": "0155bbc8dcf179edab4ef08e3dbbd4480d7434ab1990cb3fb25517d453b1b65787c7fe6dfc8824b15ff25e1fdcec59e8584f765054106894fee00311868c3964",
    PREFIX + "win64.exe.zip": "d44ea7ef5bab754cacd49d581b6062836b2eea12a82e1d183aebfad9cd8c7db2bd82513337bd657d6d2d5c04d46239c0570b029faf1343e81e8a2fa7b85dd83b",
}
ENGINES = {
    "linux": (PREFIX + "linux.x86_64.zip", PREFIX + "linux.x86_64"),
    "macos": (PREFIX + "macos.universal.zip", "Godot.app/Contents/MacOS/Godot"),
    "windows": (PREFIX + "win64.exe.zip", PREFIX + "win64_console.exe"),
}
REQUIRED_TEMPLATES = {
    "linux": {"linux_debug.x86_64", "linux_release.x86_64", "version.txt"},
    "macos": {"macos.zip", "version.txt"},
    "windows": {"windows_debug_x86_64.exe", "windows_release_x86_64.exe", "version.txt"},
}


def digest(path: Path, algorithm: str = "sha256") -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, algorithm).hexdigest()


def application_data_root() -> Path:
    if sys.platform == "darwin":
        return Path.home() / "Library/Application Support"
    if sys.platform == "win32":
        return Path(os.environ.get("APPDATA", str(Path.home() / "AppData/Roaming")))
    return Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))


def template_install_root() -> Path:
    folder = "godot" if sys.platform.startswith("linux") else "Godot"
    return application_data_root() / folder / "export_templates" / TEMPLATE_VERSION


def download_verified(filename: str, directory: Path) -> Path:
    expected = SHA512[filename]
    directory.mkdir(parents=True, exist_ok=True)
    destination = directory / filename
    if destination.is_file() and digest(destination, "sha512") == expected:
        return destination
    temporary = destination.with_suffix(destination.suffix + ".part")
    for attempt in range(3):
        try:
            request = urllib.request.Request(BASE_URL + filename, headers={"User-Agent":"piggame-ci"})
            with urllib.request.urlopen(request, timeout=120) as response, temporary.open("wb") as handle:
                shutil.copyfileobj(response, handle, length=1024 * 1024)
            if digest(temporary, "sha512") != expected:
                raise ValueError("official download checksum mismatch: " + filename)
            temporary.replace(destination)
            return destination
        except (OSError, ValueError):
            temporary.unlink(missing_ok=True)
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)
    raise RuntimeError("download failed: " + filename)


def safe_zip_name(name: str) -> bool:
    path = PurePosixPath(name)
    return bool(path.parts) and "\\" not in name and not path.is_absolute() and ".." not in path.parts and ":" not in path.parts[0]


def install_engine(platform: str, directory: Path) -> Path:
    archive = download_verified(ENGINES[platform][0], directory / "downloads")
    engine_directory = directory / "engine"
    with zipfile.ZipFile(archive) as source:
        if not all(safe_zip_name(item.filename) for item in source.infolist()):
            raise ValueError("unsafe path in engine archive")
        source.extractall(engine_directory)
    executable = engine_directory / ENGINES[platform][1]
    executable.chmod(0o755)
    result = subprocess.run([str(executable), "--headless", "--version"], capture_output=True, text=True, encoding="utf-8", timeout=60, check=True)
    if not result.stdout.strip().startswith(TEMPLATE_VERSION + ".official."):
        raise ValueError("downloaded engine does not match the pinned stable version")
    return executable.resolve()


def select_templates(platform: str, names: set[str]) -> set[str]:
    selected = REQUIRED_TEMPLATES[platform] | ({"icudt_godot.dat"} & names)
    if platform == "windows":
        selected |= {name for name in names if name.endswith(".x86_64.dll")}
        selected |= {"windows_debug_x86_64_console.exe", "windows_release_x86_64_console.exe"} & names
    if not selected <= names:
        raise ValueError("official archive is missing platform templates: " + platform)
    return selected


def prepare_template_bundles(archive: Path, output: Path) -> None:
    if digest(archive, "sha512") != SHA512[TEMPLATE_FILE]:
        raise ValueError("unverified export template archive")
    with zipfile.ZipFile(archive) as source:
        members = {PurePosixPath(item.filename).name:item for item in source.infolist() if PurePosixPath(item.filename).parent == PurePosixPath("templates") and not item.is_dir()}
        if source.read(members["version.txt"]).decode().strip() != TEMPLATE_VERSION:
            raise ValueError("template version mismatch")
        for platform in ENGINES:
            directory = output / platform
            directory.mkdir(parents=True, exist_ok=True)
            files = []
            for name in sorted(select_templates(platform, set(members))):
                if not safe_zip_name(name) or PurePosixPath(name).name != name:
                    raise ValueError("unsafe template name")
                destination = directory / name
                with source.open(members[name]) as handle, destination.open("wb") as target:
                    shutil.copyfileobj(handle, target)
                files.append({"name":name, "sha256":digest(destination)})
            record = {"godot_version":VERSION, "platform":platform, "official_archive_sha512":SHA512[TEMPLATE_FILE], "files":files}
            (directory / "template-manifest.json").write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")


def install_template_bundle(platform: str, directory: Path, destination: Path | None = None) -> None:
    manifest = json.loads((directory / "template-manifest.json").read_text(encoding="utf-8"))
    if manifest.get("godot_version") != VERSION or manifest.get("platform") != platform or manifest.get("official_archive_sha512") != SHA512[TEMPLATE_FILE]:
        raise ValueError("template bundle provenance does not match pinned release")
    files = manifest.get("files", [])
    names = {entry["name"] for entry in files}
    if len(names) != len(files) or not REQUIRED_TEMPLATES[platform] <= names:
        raise ValueError("incomplete or duplicate template bundle")
    for entry in files:
        name = entry["name"]
        if not safe_zip_name(name) or PurePosixPath(name).name != name or digest(directory / name) != entry["sha256"]:
            raise ValueError("unsafe or modified template: " + name)
    if (directory / "version.txt").read_text().strip() != TEMPLATE_VERSION:
        raise ValueError("installed template version mismatch")
    target = destination if destination is not None else template_install_root()
    target.mkdir(parents=True, exist_ok=True)
    for entry in files:
        shutil.copy2(directory / entry["name"], target / entry["name"])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=ENGINES, required=True)
    parser.add_argument("--directory", type=Path, required=True)
    parser.add_argument("--prepare-templates", type=Path)
    parser.add_argument("--templates", type=Path)
    arguments = parser.parse_args()
    executable = install_engine(arguments.platform, arguments.directory.resolve())
    if arguments.prepare_templates is not None:
        archive = download_verified(TEMPLATE_FILE, arguments.directory / "downloads")
        prepare_template_bundles(archive, arguments.prepare_templates)
    if arguments.templates is not None:
        install_template_bundle(arguments.platform, arguments.templates)
    environment_file = os.environ.get("GITHUB_ENV")
    if environment_file:
        with Path(environment_file).open("a", encoding="utf-8") as handle:
            handle.write("GODOT_BIN=" + executable.as_posix() + "\n")
    print("GODOT_BIN=" + str(executable), flush=True)


if __name__ == "__main__":
    main()
