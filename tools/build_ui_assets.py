from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path
import sys
import urllib.request


ROOT = Path(__file__).resolve().parents[1]
CACHE = Path.home() / "Library/Caches/piggame/ui-design-sources"
sys.path.insert(0, str(Path.home() / "Library/Caches/piggame/python"))
from fontTools import subset
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont


PINS = {
    "google/fonts": "51303ca9e8ac9dcea7b12d307ba568fd0e6fcfca",
    "lxgw/LxgwWenKai": "7e4325d61d6217e86776733a94d28e6a528f7b8c",
    "lucide-icons/lucide": "6d01fea3d3925cab6480e5f65203421b24a35cff",
}
ICONS = ["armchair", "cookie", "shirt", "sparkles", "monitor", "book-open", "camera", "settings-2", "coins", "smile", "notebook-pen", "mail", "x", "check", "lock-keyhole", "chevron-down", "volume-2", "sliders-horizontal", "users", "coffee", "pause", "play", "square", "moon", "circle", "circle-check", "heart", "arrow-left"]


def fetch(repo: str, relative: str) -> tuple[bytes, str]:
    url = f"https://raw.githubusercontent.com/{repo}/{PINS[repo]}/{relative}"
    cache = CACHE / repo.replace("/", "-") / relative
    if not cache.is_file():
        cache.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(url, timeout=60) as response:
            cache.write_bytes(response.read())
    return cache.read_bytes(), url


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def characters() -> set[int]:
    glyphs = set(range(32, 256)) | set(range(0x2000, 0x2070))
    with (ROOT / "game/data/localization/game.csv").open(newline="") as handle:
        for row in csv.DictReader(handle):
            for locale in ("zh_CN", "zh_TW", "en"):
                glyphs.update(ord(character) for character in row[locale])
    for leading in range(0xA1, 0xF8):
        for trailing in range(0xA1, 0xFF):
            try:
                glyphs.update(ord(character) for character in bytes([leading, trailing]).decode("gb2312"))
            except UnicodeDecodeError:
                continue
    return glyphs


def main() -> None:
    target = ROOT / "game/assets/interface"
    (target / "fonts").mkdir(parents=True, exist_ok=True)
    (target / "lucide").mkdir(exist_ok=True)
    records = []
    glyphs = characters()
    for repo, relative, filename, family in [
        ("google/fonts", "ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf", "pig-ui-body.ttf", "Piggame UI Sans"),
        ("lxgw/LxgwWenKai", "fonts/TTF/LXGWWenKai-Medium.ttf", "pig-ui-title.ttf", "Piggame UI Hand"),
    ]:
        raw, url = fetch(repo, relative)
        source = CACHE / repo.replace("/", "-") / relative
        font = TTFont(source, recalcTimestamp=False)
        if "fvar" in font:
            font = instantiateVariableFont(font, {"wght": 450}, inplace=True)
        options = subset.Options()
        options.recalc_timestamp = False
        options.name_IDs = ["*"]
        options.name_legacy = True
        options.name_languages = ["*"]
        sub = subset.Subsetter(options=options)
        sub.populate(unicodes=glyphs)
        sub.subset(font)
        for name_id, value in [(1, family), (4, family + " Regular"), (6, family.replace(" ", "") + "-Regular"), (16, family), (17, "Regular")]:
            font["name"].setName(value, name_id, 3, 1, 0x409)
        destination = target / "fonts" / filename
        font.save(destination)
        records.append({"path": "res://" + destination.relative_to(ROOT).as_posix(), "source_url": url, "source_sha256": digest(raw), "sha256": digest(destination.read_bytes()), "modified": True, "modification": "UI localization plus GB2312 character subset; Noto variable weight instantiated at 450; derived family renamed; copyright/license names retained", "glyphs": len(font.getBestCmap()), "bytes": destination.stat().st_size})
        font.close()
    for name in ICONS:
        upstream_name = "face-slightly-smiling" if name == "smile" else name
        raw, url = fetch("lucide-icons/lucide", f"icons/{upstream_name}.svg")
        svg = raw.decode().replace('stroke="currentColor"', 'stroke="#ffffff"').replace('width="24"', 'width="48"').replace('height="24"', 'height="48"')
        destination = target / "lucide" / (name + ".svg")
        destination.write_text(svg)
        records.append({"path": "res://" + destination.relative_to(ROOT).as_posix(), "source_url": url, "source_sha256": digest(raw), "sha256": digest(destination.read_bytes()), "modified": True, "modification": "White stroke for native Theme tint; 48px raster canvas with unchanged 24-unit viewBox and path geometry"})
    for repo, relative, label in [("google/fonts", "ofl/notosanssc/OFL.txt", "NotoSansSC"), ("lxgw/LxgwWenKai", "OFL.txt", "LXGWWenKai"), ("lucide-icons/lucide", "LICENSE", "Lucide")]:
        raw, url = fetch(repo, relative)
        destination = ROOT / "LICENSES" / label / "LICENSE.txt"
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_bytes(raw)
        records.append({"path": destination.relative_to(ROOT).as_posix(), "source_url": url, "sha256": digest(raw), "modified": False})
    print(json.dumps({"schema_version": 1, "retrieved_on": "2026-10-09", "offline_runtime": True, "ai_generated": False, "purpose": "Native UI fonts and supplemental line icons, not replacement pig art", "pinned_commits": PINS, "records": records}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
