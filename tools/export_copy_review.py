"""Export a read-only, key-preserving copywriting handoff."""

from __future__ import annotations

import argparse
import ast
from collections import Counter, defaultdict
import csv
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile


ROOT = Path(__file__).resolve().parents[1]
LOCALES = ("zh_CN", "zh_TW", "en")
GROUPS = [
    ("01 界面导航与通用操作", ("UI_", "LANGUAGE_")),
    ("02 命名、教程与帮助", ("NAME_", "TUTORIAL_", "HELP_")),
    ("03 桌面陪伴与专注", ("DESKTOP_", "FOCUS_")),
    ("04 性格与多猪住客", ("PERSONALITY_", "RESIDENTS_")),
    ("05 日常行为、状态与倾向", ("BEHAVIOR_", "STATUS_", "TENDENCY_")),
    ("06 家具、房间与互动", ("FURN_", "FURNITURE_", "AREA_", "ROOM_")),
    ("07 零食与投喂反应", ("SNACK_", "REACTION_")),
    ("08 头脸饰品", ("OUTFIT_",)),
    ("09 表情、姿势、梗状态与形态", ("PERFORMANCE_", "FACE_", "POSE_", "MEME_", "FORM_")),
    ("10 收藏表情及解锁线索", ("EXPR_",)),
    ("11 小剧场标题、摘要与对白", ("EVENT_",)),
    ("12 相册与照片", ("ALBUM_", "PHOTO_")),
    ("13 章节日记、小计划与结尾", ("DIARY_", "LIFE_", "PLAN_", "NOTE_", "ENDING_")),
    ("14 明信片标题与来信", ("POSTCARD_",)),
    ("15 成就", ("ACH_",)),
    ("16 操作反馈、离线、保存与退出", ("TOAST_", "OFFLINE_", "SAVE_", "EXIT_")),
    ("17 设置", ("SETTINGS_",)),
    ("18 隐私与来源声明", ("LEGAL_",)),
    ("19 Demo", ("DEMO_",)),
]
GENERATOR_TABLES = {
    "BEHAVIOR_": ("BEHAVIORS",),
    "FURN_": ("FURNITURE_NAMES", "FURNITURE_COPY"),
    "SNACK_": ("SNACKS",),
    "REACTION_": ("SNACKS",),
    "OUTFIT_": ("OUTFITS", "OUTFIT_COPY"),
    "EVENT_": ("EVENT_COPY",),
    "EXPR_": ("EXPRESSION_NAMES", "EVENT_COPY"),
    "ACH_": ("ACHIEVEMENTS",),
    "PLAN_": ("LIFE_PLAN_COPY",),
    "NOTE_": ("LIFE_PLAN_COPY",),
}
VARIABLE_MEANINGS = {
    "area": "房间区域名称", "behavior": "当前行为名称", "body": "格式化后的正文",
    "count": "当前数量", "current": "当前进度", "date": "本地日期", "done": "已完成数量",
    "event": "关联小剧场标题", "from": "起始时间/范围", "hours": "小时数", "items": "物品名称列表",
    "item": "物品名称", "level": "熟悉度等级", "maximum": "最大数量/进度", "minutes": "分钟数",
    "name": "玩家自定义猪名，不能改为固定人名", "notes": "手账段数", "note": "手账内容",
    "number": "住客序号", "outfit": "饰品名称", "path": "文件/存档路径，必须清晰保留",
    "paused": "暂停状态文本", "percent": "百分比数值", "personality": "性格名称", "phase": "专注阶段",
    "points": "点数", "pose": "姿势名称", "price": "点数价格", "rate": "速度/倍率",
    "time": "剩余时间", "title": "标题", "total": "总数量", "to": "结束时间/范围",
}
IMAGE_COPY = {
    "postcard_wake": ("你醒啦，你刚刚一直在说\n什么要考试、要找工作什么的，\n是不是吃错饲料了，\n我们只是小猪猪呀", "主文字人工看图转录；换行是图像排版，不是本地化变量。"),
    "postcard_carrot": ("萝卜猪", "图内标题。"),
    "postcard_flat": ("", "未发现可辨文字，只有猪形象。"),
    "postcard_huddle": ("欢乐多猪", "图内标题。"),
    "postcard_park": ("乱停猪\n罚单\nZ / z", "罚单内部英文与表格细字不能可靠辨读，未猜写；原图随包附上供复核。"),
    "postcard_fact": ("你知道吗（多次重复）……我饿了", "记录重复句的结构而非猜测次数；右下浅色水印不能可靠辨读，不删改水印。"),
    "postcard_bold": ("笨笨的我气势汹汹地登场", "人工看图转录。来源登记标题用“猪”，实际图中文字用“我”，两者分开保留。"),
    "postcard_belly": ("肥猪", "图内标题。"),
}
EXTERNAL_DOCUMENTS = (
    "docs/release/steam-store-copy.md",
    "docs/release/privacy.md",
    "docs/release/third-party-notices.md",
    "docs/release/support-and-known-issues.md",
    "LICENSES/PigHub/SOURCE.md",
)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def text_digest(current: dict[str, str]) -> str:
    return hashlib.sha256(json.dumps(current, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def placeholders(text: str) -> list[str]:
    return re.findall(r"\{[^{}]+\}", text)


def group_for(key: str) -> str:
    for name, prefixes in GROUPS:
        if key.startswith(prefixes):
            return name
    return "20 其他"


def generator_index(root: Path) -> dict[str, list[str]]:
    tree = ast.parse((root / "tools/build_localization.py").read_text())
    result: dict[str, list[str]] = defaultdict(list)
    for statement in tree.body:
        if not isinstance(statement, ast.Assign):
            continue
        names = [target.id for target in statement.targets if isinstance(target, ast.Name)]
        if not names:
            continue
        for node in ast.walk(statement.value):
            if isinstance(node, ast.Constant) and isinstance(node.value, str):
                result[node.value].append(f"tools/build_localization.py:{node.lineno} ({names[0]})")
    for table in GENERATOR_TABLES.values():
        for name in table:
            for statement in tree.body:
                if isinstance(statement, ast.Assign) and any(isinstance(target, ast.Name) and target.id == name for target in statement.targets):
                    result[name] = [f"tools/build_localization.py:{statement.lineno} ({name})"]
    return result


def references(root: Path, keys: set[str]) -> tuple[dict[str, list[dict]], dict[str, list[str]]]:
    data_refs: dict[str, list[dict]] = defaultdict(list)
    runtime_refs: dict[str, list[str]] = defaultdict(list)

    def visit(value: object, path: str, location: str, owners: tuple[str, ...] = (), context: dict | None = None) -> None:
        if isinstance(value, dict):
            identifier = str(value.get("id", ""))
            if identifier:
                owners = owners + (identifier,)
                context = {name: value[name] for name in ("category", "min_level", "area", "anchor", "price", "points", "associated_event", "condition") if name in value}
            for field, child in value.items():
                visit(child, path, f"{location}.{field}", owners, context)
        elif isinstance(value, list):
            for index, child in enumerate(value):
                visit(child, path, f"{location}[{index}]", owners, context)
        elif isinstance(value, str) and value in keys:
            data_refs[value].append({"file":path, "field":location, "content_ids":list(owners), "context":context or {}})

    for path in sorted((root / "game/data").rglob("*.json")):
        visit(json.loads(path.read_text()), path.relative_to(root).as_posix(), "$")
    for path in sorted((root / "game").rglob("*.gd")):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            for match in re.finditer(r"[\"']([A-Z][A-Z0-9_]+)[\"']", line):
                if match[1] in keys:
                    runtime_refs[match[1]].append(f"{path.relative_to(root).as_posix()}:{number}")
    return data_refs, runtime_refs


def usage_for(key: str, refs: list[dict]) -> str:
    fields = " ".join(reference["field"] for reference in refs)
    if "hint_key" in fields or key.endswith("_HINT"):
        return "解锁/操作线索；需与事件、物品及条件保持对应"
    if "variant_keys" in fields or ".variants[" in fields or "_LINE_" in key:
        return "小剧场随机对白；多个版本需保持各自差异"
    if key.endswith(("_BODY", "_TEXT")):
        return "来信或手账正文"
    if key.endswith("_SUMMARY"):
        return "摘要或回顾"
    if key.startswith(("TOAST_", "REACTION_")) or key.endswith(("_PET", "_POKE")):
        return "短时反馈/角色反应"
    if key.endswith(("_NAME", "_TITLE")):
        return "名称/标题；关联线索和成就里的同名引用应同步"
    if key.endswith(("_DESC", "_DESCRIPTION")):
        return "简短说明/角色刻画"
    if key.startswith(("HELP_", "LEGAL_", "SAVE_", "EXIT_", "OFFLINE_", "DEMO_")):
        return "说明或关键提示；保持事实、范围与安全操作含义"
    return "界面标签、状态、按钮或格式化文本；具体位置见引用"


def constraints_for(key: str, text: str) -> str:
    facts = key.startswith(("LEGAL_", "HELP_", "SAVE_", "EXIT_", "DEMO_")) or "PRIVACY" in key or "AUDIO_SILENT" in key
    notes = ["语义/事实受保护，仅优化表达" if facts else "可优化语气，不新增功能或改变玩法"]
    if placeholders(text):
        notes.append("变量名称、数量与花括号必须原样保留")
    if "\n" in text:
        notes.append("含换行；CSV需保留引号，JSON使用\\n")
    if key.startswith(("UI_", "SETTINGS_", "DESKTOP_")):
        notes.append("UI优先短句，兼顾150%字号；长度建议不是运行时硬限")
    if key.startswith("EXPR_") and key.endswith("_HINT"):
        notes.append("现由事件标题生成；回填不能只修改CSV，否则重生成会覆盖")
    return "；".join(notes)


def input_paths(root: Path) -> list[Path]:
    return sorted(set([
        root / "project.godot", root / "game/data/localization/game.csv", root / "tools/build_localization.py",
        root / "game/assets/final/pighub/source.json", *[root / path for path in EXTERNAL_DOCUMENTS],
        *(root / "game/data").rglob("*.json"), *(root / "game").rglob("*.gd"),
        *[path for path in (root / "game/assets/final/pighub").iterdir() if path.suffix in (".webp", ".jpg")],
    ]))


def export_review(root: Path, output: Path) -> dict:
    inputs = {path.relative_to(root).as_posix(): digest(path) for path in input_paths(root)}
    with (root / "game/data/localization/game.csv").open(newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    keys = {row["keys"] for row in rows}
    if len(keys) != len(rows):
        raise ValueError("duplicate localization keys")
    data_refs, runtime_refs = references(root, keys)
    generator = generator_index(root)
    entries = []
    for row in rows:
        key = row["keys"]
        current = {locale:row[locale] for locale in LOCALES}
        expected = Counter(placeholders(current["zh_CN"]))
        if any(Counter(placeholders(current[locale])) != expected for locale in LOCALES):
            raise ValueError(f"baseline placeholder mismatch: {key}")
        locations = list(generator.get(key, []))
        if not locations:
            for prefix, tables in GENERATOR_TABLES.items():
                if key.startswith(prefix):
                    locations = [location for table in tables for location in generator.get(table, [])]
                    break
        entries.append({
            "key":key, "module":group_for(key), "usage":usage_for(key, data_refs[key]),
            "reference_status":"存在数据/代码直接键引用，不等于已证明所有分支均可见" if data_refs[key] or runtime_refs[key] else "未发现直接引用：可能动态选用或兼容遗留，不要擅自删除",
            "constraints":constraints_for(key, current["zh_CN"]), "current":current,
            "proposed":{locale:None for locale in LOCALES}, "edit_note":"",
            "variables":placeholders(current["zh_CN"]), "original_text_sha256":text_digest(current),
            "generator_sources":locations or ["tools/build_localization.py（由模板生成）"],
            "data_references":data_refs[key], "runtime_references":sorted(set(runtime_refs[key])),
        })
    output.mkdir(parents=True, exist_ok=True)
    document = {"schema_version":1, "localization_csv_sha256":inputs["game/data/localization/game.csv"], "locale_order":list(LOCALES), "entries":entries}
    (output / "all-text.json").write_text(json.dumps(document, ensure_ascii=False, indent=2) + "\n")
    columns = ["key", "module", "usage", "reference_status", "constraints", "variables", "original_text_sha256", "generator_sources", "data_references", "runtime_references"]
    columns += [field for locale in LOCALES for field in (f"{locale}_current", f"{locale}_optimized")]
    columns.append("edit_note")
    with (output / "all-text-editable.csv").open("w", encoding="utf-8-sig", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=columns, lineterminator="\n")
        writer.writeheader()
        for entry in entries:
            record = {column:entry[column] for column in columns[:10]}
            for column in ("variables", "generator_sources", "data_references", "runtime_references"):
                record[column] = json.dumps(record[column], ensure_ascii=False)
            for locale in LOCALES:
                record[f"{locale}_current"] = entry["current"][locale]
                record[f"{locale}_optimized"] = ""
            record["edit_note"] = ""
            writer.writerow(record)
    groups = Counter(entry["module"] for entry in entries)
    lines = ["# 全部游戏文案：三语逐条阅读版", "", f"{len(entries)} 个本地化键。当前文本原样导出；建议回填编辑CSV或JSON，不直接覆盖原文本。", "", "## 分类总览", ""]
    lines.extend(f"- {name}：{count} 条" for name, count in sorted(groups.items()))
    for name in sorted(groups):
        lines.extend(["", "## " + name, ""])
        for entry in entries:
            if entry["module"] != name:
                continue
            lines.extend(["### " + entry["key"], "", "- 用途：" + entry["usage"], "- 约束：" + entry["constraints"], "- 引用状态：" + entry["reference_status"]])
            if entry["variables"]:
                lines.append("- 变量：" + "、".join(f"`{value}`" for value in entry["variables"]))
            for locale, label in (("zh_CN", "简体"), ("zh_TW", "繁体"), ("en", "English")):
                lines.extend(["", f"**{label}**", "", *["> " + line for line in entry["current"][locale].split("\n")]])
            lines.extend(["", "源文案：" + "；".join(entry["generator_sources"]), ""])
    (output / "all-text-readable.md").write_text("\n".join(lines))
    chinese = ["# 全部简体中文游戏文案", "", "按模块整理全部键；key和花括号变量保留原样。三语全集、用途和回填协议见同包其他文件。未找到直接引用的键仅作标记，不等于确认已退休。", ""]
    for name in sorted(groups):
        chinese.extend(["## " + name, ""])
        for entry in entries:
            if entry["module"] != name:
                continue
            chinese.extend(["### " + entry["key"], "", *["> " + line for line in entry["current"]["zh_CN"].split("\n")]])
            if entry["variables"]:
                chinese.append("\n保留变量：" + "、".join(entry["variables"]))
            if not entry["data_references"] and not entry["runtime_references"]:
                chinese.append("\n引用待确认；不要删键或恢复旧功能。")
            chinese.append("")
    (output / "zh-CN-only.md").write_text("\n".join(chinese))
    tokens = sorted({token for entry in entries for token in entry["variables"]})
    meanings = {token:VARIABLE_MEANINGS.get(token[1:-1], "结合本条数据/代码上下文确认，不能猜改") for token in tokens}
    (output / "placeholder-guide.json").write_text(json.dumps({"note":"这些是通用释义；具体类型和含义以条目引用为准。变量名称、花括号和出现数量不可修改。", "variables":meanings}, ensure_ascii=False, indent=2) + "\n")
    metadata = []
    for number, line in enumerate((root / "project.godot").read_text().splitlines(), 1):
        match = re.fullmatch(r'config/(name|description)=(".*")', line)
        if match:
            metadata.append({"review_id":"PROJECT_CONFIG_" + match[1].upper(), "not_a_localization_key":True, "source":f"project.godot:{number}", "current":json.loads(match[2]), "proposed":None})
    (output / "project-metadata.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + "\n")
    image_folder = output / "reference-images"
    image_folder.mkdir(exist_ok=True)
    image_records = []
    source = json.loads((root / "game/assets/final/pighub/source.json").read_text())
    for record in source["records"]:
        original = root / record["path"].removeprefix("res://")
        shutil.copy2(original, image_folder / original.name)
        text, note = IMAGE_COPY[record["id"]]
        image_records.append({"id":record["id"], "original_gallery_title":record["original_title"], "observed_image_text":text, "transcription_note":note, "file":"reference-images/" + original.name, "sha256":digest(original), "editable_via_localization_csv":False, "proposed_caption":None})
    (output / "embedded-image-text.json").write_text(json.dumps(image_records, ensure_ascii=False, indent=2) + "\n")
    image_lines = ["# 图内文字与非本地化标记", "", "八张现有PigHub原图逐一人工查看。标题/信件在主CSV内；下面是位图自身文字，不能通过翻译表修改。不修改原图、水印或来源声明。细字无法可靠辨认时明确保留未知。", "", "锁定表情的 `?` 属于绘制标记，不是缺失译文；操作系统/Godot提供的原生菜单不是本地化CSV内容。其他生成角色、家具和UI图标不是本轮可编辑文案表；若发现位图里的装饰字形需另外看图确认。", ""]
    for record in image_records:
        image_lines.extend(["## " + record["id"], "", "- 图库原标题：" + record["original_gallery_title"], "- 可辨图内文字：" + (record["observed_image_text"].replace("\n", " / ") or "无"), "- 备注：" + record["transcription_note"], "", f"![{record['id']}]({record['file']})", ""])
    (output / "embedded-image-text.md").write_text("\n".join(image_lines))
    original_folder = output / "originals"
    original_folder.mkdir(exist_ok=True)
    shutil.copy2(root / "game/data/localization/game.csv", original_folder / "game.csv")
    for relative in EXTERNAL_DOCUMENTS:
        shutil.copy2(root / relative, original_folder / Path(relative).name)
    (output / "return-template.json").write_text(json.dumps({"schema_version":1, "localization_csv_sha256":document["localization_csv_sha256"], "changes":[], "metadata_changes":[], "image_caption_suggestions":[], "questions":[]}, ensure_ascii=False, indent=2) + "\n")
    readme = (root / "docs/design/copy-review-handoff-guide.md").read_text()
    (output / "README-first.md").write_text(readme.replace("{{LOCALIZATION_COUNT}}", str(len(entries))).replace("{{GROUP_COUNTS}}", "\n".join(f"- {name}：{count}" for name, count in sorted(groups.items()))))
    manifest = {"schema_version":1, "localization_entries":len(entries), "translations":len(entries) * len(LOCALES), "modules":dict(sorted(groups.items())), "project_metadata_entries":len(metadata), "postcard_images":len(image_records), "placeholder_tokens":sorted({token for entry in entries for token in entry["variables"]}), "game_text_changed":False, "source_inputs_sha256":inputs}
    manifest["direct_reference_entries"] = sum(bool(entry["data_references"] or entry["runtime_references"]) for entry in entries)
    manifest["unconfirmed_reference_entries"] = len(entries) - manifest["direct_reference_entries"]
    manifest["output_files_sha256"] = {path.relative_to(output).as_posix():digest(path) for path in sorted(output.rglob("*")) if path.is_file() and path.name != "manifest.json"}
    (output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    if inputs != {path.relative_to(root).as_posix():digest(path) for path in input_paths(root)}:
        raise RuntimeError("source inputs changed during read-only export")
    return manifest


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/copy-review-2026-10-11")
    parser.add_argument("--zip", dest="archive", type=Path)
    arguments = parser.parse_args()
    output = arguments.output.resolve()
    if output == ROOT or output == ROOT / "game" or (ROOT / "game") in output.parents:
        raise ValueError("review output must not replace game sources")
    manifest = export_review(ROOT, output)
    if arguments.archive:
        archive = arguments.archive.resolve()
        if archive == output or output in archive.parents:
            raise ValueError("archive must be outside the exported folder")
        archive.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as package:
            for path in sorted(output.rglob("*")):
                if path.is_file():
                    package.write(path, output.name + "/" + path.relative_to(output).as_posix())
    print(f"COPY_REVIEW: {manifest['localization_entries']} keys, {manifest['translations']} translations, {manifest['project_metadata_entries']} metadata fields, {manifest['postcard_images']} original images; game sources unchanged")


if __name__ == "__main__":
    main()
