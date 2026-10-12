"""Inspect existing WAV assets and isolated Godot audio routes without enabling game audio."""

from __future__ import annotations

import argparse
import array
from collections import Counter
import csv
import hashlib
import json
import math
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import uuid
import wave

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run_godot_checks as checks
from validate_release_candidate import source_tree_sha256


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "game/assets/audio/audio_manifest.json"


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def dbfs(value: float) -> float | None:
    return round(20.0 * math.log10(value), 3) if value > 0.0 else None


def analyze_wav(path: Path) -> dict:
    with wave.open(str(path), "rb") as source:
        channels = source.getnchannels()
        rate = source.getframerate()
        frames = source.getnframes()
        if source.getsampwidth() != 2 or source.getcomptype() != "NONE":
            raise ValueError("WAV inspection currently expects uncompressed 16-bit PCM")
        samples = array.array("h", source.readframes(frames))
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples or len(samples) != frames * channels:
        raise ValueError("missing or truncated WAV samples")
    peak = max(abs(value) for value in samples) / 32768.0
    rms = math.sqrt(sum(value * value for value in samples) / len(samples)) / 32768.0
    dc = sum(samples) / len(samples) / 32768.0
    jumps = [abs(samples[-channels + channel] - samples[channel]) / 32768.0 for channel in range(channels)]
    return {"seconds":round(frames / rate, 6), "sample_rate":rate, "channels":channels, "bit_depth":16, "frames":frames, "peak_dbfs":dbfs(peak), "peak_linear":peak, "rms_dbfs":dbfs(rms), "dc_offset":dc, "clipped_samples":sum(abs(value) >= 32767 for value in samples), "first_last_sample_jump_dbfs":dbfs(max(jumps)), "sha256":sha256(path), "bytes":path.stat().st_size}


def inspect_inventory(root: Path = ROOT) -> dict:
    manifest_path = root / "game/assets/audio/audio_manifest.json"
    manifest = json.loads(manifest_path.read_text())
    records = []
    errors = []
    identifiers = set()
    for kind, expected in (("music", 4), ("sfx", 30)):
        entries = manifest.get(kind, [])
        if len(entries) != expected:
            errors.append(f"{kind}: expected {expected} entries, found {len(entries)}")
        for entry in entries:
            identifier = entry["id"]
            path = (root / entry["path"].removeprefix("res://")).resolve()
            if identifier in identifiers:
                errors.append(f"duplicate id: {identifier}")
            identifiers.add(identifier)
            try:
                path.relative_to(root.resolve())
                record = {"id":identifier, "kind":kind, "path":entry["path"], **analyze_wav(path)}
                if record["clipped_samples"]:
                    errors.append(f"{identifier}: source has full-scale samples")
                if record["peak_linear"] == 0.0:
                    errors.append(f"{identifier}: source is entirely silent")
                records.append(record)
            except (OSError, ValueError, wave.Error) as error:
                errors.append(f"{identifier}: {error}")
    return {"development_placeholder":bool(manifest.get("development_placeholder", True)), "files":records, "technical_failures":errors, "bytes":sum(record["bytes"] for record in records), "listening_performed":False, "measured_loudness":"sample peak and unweighted RMS only; not LUFS or true peak", "manifest_sha256":sha256(manifest_path)}


def copy_preflight(root: Path = ROOT) -> dict:
    path = root / "docs/copy-review-2026-10-11/return-2026-10-11-zh-copyedit.json"
    if not path.is_file():
        return {"found":False, "applied_by_this_audit":False}
    data = json.loads(path.read_text())
    with (root / "game/data/localization/game.csv").open(newline="", encoding="utf-8-sig") as handle:
        rows = {row["keys"]:row for row in csv.DictReader(handle)}
    issues = []
    keys = set()
    for entry in data.get("changes", []):
        key = entry["key"]
        if key not in rows or key in keys:
            issues.append(key + ": unknown or duplicate key")
            continue
        keys.add(key)
        current = {locale:rows[key][locale] for locale in ("zh_CN", "zh_TW", "en")}
        current_hash = hashlib.sha256(json.dumps(current, ensure_ascii=False, sort_keys=True).encode()).hexdigest()
        if current_hash != entry.get("original_text_sha256"):
            issues.append(key + ": baseline text hash mismatch")
        for locale in current:
            proposed = entry.get(locale)
            if proposed is not None and Counter(re.findall(r"\{[^{}]+\}", proposed)) != Counter(re.findall(r"\{[^{}]+\}", current[locale])):
                issues.append(key + ": changed placeholders in " + locale)
    baseline_match = data.get("localization_csv_sha256") == sha256(root / "game/data/localization/game.csv")
    return {"found":True, "path":path.relative_to(root).as_posix(), "changes":len(data.get("changes", [])), "metadata_suggestions":len(data.get("metadata_changes", [])), "image_suggestions":len(data.get("image_caption_suggestions", [])), "baseline_csv_matches":baseline_match, "structural_issues":issues, "applied_by_this_audit":False, "note":"Copyediting suggestions are a separate handoff, not new music or sound effects."}


def validate_runtime_result(result: subprocess.CompletedProcess[str], path: Path) -> dict:
    fatal_markers = (*checks.FATAL_GODOT_OUTPUT_MARKERS, "ObjectDB instances leaked", "resources still in use at exit")
    if any(marker in (result.stdout or "") for marker in fatal_markers):
        raise RuntimeError("Godot audio audit reported an engine error or leaked resources: " + result.stdout)
    runtime = json.loads(path.read_text())
    if not isinstance(runtime, dict) or runtime.get("completed") is not True:
        raise ValueError("Godot audio audit did not complete")
    assertions = runtime.get("assertions")
    failures = runtime.get("failures")
    streams = runtime.get("decoded_streams")
    observations = runtime.get("future_enabled_policy_observations")
    if type(assertions) is not int or assertions <= 0 or not isinstance(failures, list) or not all(isinstance(entry, str) for entry in failures) or len(failures) > assertions:
        raise ValueError("Godot audio audit has invalid assertion results")
    if not isinstance(streams, list) or len(streams) != 34 or not all(isinstance(entry, dict) for entry in streams):
        raise ValueError("Godot audio audit has incomplete stream results")
    if not isinstance(observations, list) or len(observations) != 16 or not all(isinstance(entry, dict) and type(entry.get("unsafe_autonomous_bus_eligibility")) is bool for entry in observations):
        raise ValueError("Godot audio audit has incomplete policy results")
    if runtime.get("driver") != "Dummy" or runtime.get("physical_output_tested") is not False or runtime.get("production_playback_enabled") is not False:
        raise ValueError("Godot audio audit did not preserve silent isolation")
    marker = f"AUDIO_AUDIT: assertions={assertions} failures={len(failures)} streams=34 production_silent=true physical_output=false"
    if (result.stdout or "").splitlines().count(marker) != 1:
        raise ValueError("Godot audio audit completion marker is missing or inconsistent")
    expected_exit = 1 if failures else 0
    if result.returncode != expected_exit:
        raise ValueError("Godot audio audit exit code disagrees with assertion results")
    return {**runtime, "process_exit_code":result.returncode}


def run_runtime(output: Path) -> dict:
    name = checks.USER_DIR_PREFIX + uuid.uuid4().hex
    support = Path.home() / "Library/Application Support"
    environment = os.environ.copy()
    environment["PIGGAME_EXPECTED_USER_DIR"] = name
    environment["PIGGAME_AUDIO_AUDIT_DIR"] = str(output)
    environment["PIGGAME_AUDIO_DUMMY_ONLY"] = "1"
    runtime_path = output / "runtime.json"
    runtime_path.unlink(missing_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix="piggame-audio-audit-") as temporary:
            stage = Path(temporary) / "project"
            checks.stage_project(ROOT, stage, name)
            common = [str(checks.DEFAULT_GODOT), "--headless", "--audio-driver", "Dummy", "--path", str(stage)]
            for label, arguments in (("import", ["--editor", "--quit"]), ("runtime", ["res://tests/audio_audit.tscn"])):
                result = subprocess.run(common + arguments, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=300)
                (output / (label + ".log")).write_text(result.stdout)
                print(label, result.returncode, flush=True)
                if label == "runtime":
                    return validate_runtime_result(result, runtime_path)
                if checks.result_exit_code(result, label, None):
                    raise RuntimeError(result.stdout)
    finally:
        checks.remove_isolated_user_data(support, name)
    raise RuntimeError("Godot audio audit runtime was not executed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    output = arguments.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    before = source_tree_sha256(ROOT)
    inventory = inspect_inventory()
    if inventory["technical_failures"]:
        (output / "inventory.json").write_text(json.dumps(inventory, indent=2) + "\n")
        raise RuntimeError("WAV file audit failed: " + str(inventory["technical_failures"]))
    runtime = run_runtime(output)
    assert before == source_tree_sha256(ROOT), "game code or assets changed during audit"
    warnings = []
    if runtime["failures"]:
        warnings.append("Runtime assertions failed; completing the report does not turn these failures into a passing audit.")
    if inventory["development_placeholder"]:
        warnings.append("All 34 audio resources are declared development placeholders; no dedicated final audio supplied.")
    warnings.append("No physical-device output or subjective listening acceptance was performed; the actual game remains silent.")
    observations = runtime["future_enabled_policy_observations"]
    unsafe = [entry for entry in observations if entry["unsafe_autonomous_bus_eligibility"]]
    if unsafe:
        warnings.append("A Dummy-only enabled fixture leaves buses eligible during loss of focus/quiet/do-not-disturb; the production silent gate currently prevents sound.")
    warnings.append("BGM is forward-looped, while track succession depends on finished; no time/weather switch caller or crossfade is present in current AudioService.")
    music = [record for record in inventory["files"] if record["kind"] == "music"]
    if all(record["seconds"] <= 16.01 for record in music):
        warnings.append("All four BGM placeholders are 16-second synthesized loops; long-session musical comfort is not validated.")
    pet = next(record for record in inventory["files"] if record["id"] == "pet_1")
    worst_peak = pet["peak_linear"] * 0.8 * 8
    warnings.append("Single-file no-clipping does not prove mix headroom; eight same-phase pet voices at default gain can theoretically exceed full scale.")
    exit_code = 1 if runtime["failures"] else 0
    report = {"schema_version":1, "audit_date":"2026-10-12", "source_tree_sha256":before, "game_sources_changed":False, "technical_audit_passed":exit_code == 0, "audit_exit_code":exit_code, "readiness":"BLOCKED: dedicated audio and enabling-stage behavior/subjective acceptance outstanding", "final_audio_accepted":False, "inventory":inventory, "runtime":runtime, "future_policy_risk_cases":len(unsafe), "theoretical_eight_voice_peak_dbfs":dbfs(worst_peak), "warnings":warnings, "copy_return_preflight":copy_preflight()}
    (output / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    lines = ["# 音效与BGM专项核验：2026-10-12", "", "## 结论", "", "现有音频路由、导入和强制静音核验完成，但循环检查存在失败，不是音频验收通过：全部34个资源仍是开发占位，没有接入新的专属音频。没有改变游戏开关、音量、资源、文案或普通玩家存档。本次只新增声音审计工具和测试，未修复生产播放代码。", "", f"- 源树：`{before}`", f"- Godot专项：{runtime['assertions']} 项，{len(runtime['failures'])} 失败；4个BGM和30个音效均解码。报告保留失败，工具退出码为{exit_code}。", f"- WAV总大小：{inventory['bytes'] / 1048576:.3f} MiB；均为22050 Hz、单声道、16位PCM，没有源文件满幅样本。", "- 所测为采样峰值/RMS，不是LUFS/真峰值；Dummy驱动不证明扬声器输出或听感舒适。", "", "## 运行失败明细", ""]
    lines.extend(f"- {failure}" for failure in runtime["failures"])
    music_streams = runtime["decoded_streams"][:4]
    lines.extend(["", "四首导入的BGM均为16秒QOA WAV，loop_begin=0、loop_end=0；AudioService只设置LOOP_FORWARD，没有补齐循环结束采样点。下表是Dummy驱动实际观测，不是物理输出。诊断列只在测试内使用独立播放器、复制流并设置完整循环长度，不改源文件，不代表生产修复或循环接缝试听通过。", "", "| ID | 原实现播放位置秒 | 测试完整循环结束采样点 | 诊断播放位置秒 |", "|---|---:|---:|---:|"])
    lines.extend(f"| {stream['id']} | {stream['dummy_playback_position']:.8f} | {stream['diagnostic_loop_end']} | {stream['diagnostic_playback_position']:.8f} |" for stream in music_streams)
    lines.extend(["", "## 恢复音频前必须处理", "", "- 修复WAV完整循环边界并重新核验连续播放、曲目切换及循环接缝；当前四首循环边界检查失败。", f"- 测试专用EnabledFixture在{len(unsafe)}个失焦/安静/勿扰组合中仍有未静音总线。当前生产构建禁播，所以玩家不会遭遇声音打扰；未来不能仅翻转AUDIO_PLAYBACK_ENABLED就交付。自动收益points、升级和小剧场音效需区分主动互动与后台自主触发，并由同一防打扰策略控制。", "- play_music设置无限正向循环，自动下一首却只监听finished；现无昼夜/天气调用与淡入淡出。不能把四个文件名当作四种场景已自动切换的证据。", "- 四首BGM均是16秒的合成循环；源文件首尾采样相接不代表和声衔接、音色或长时间舒适度已验收。", f"- 单文件没有削波，不代表同时混音安全。按当前8路interaction池、pet_1源峰值和默认0.8音量估算，同相叠加理论峰值约+{dbfs(worst_peak):.2f} dBFS；这是压力上界，不是本次观察到的用户实际削波，需要测混音余量、限幅和短时重复触发。", "- 声音需附来源/使用授权，并保持永久音频ID。最终资源门禁和Windows实机/真实设备声音验收不得跳过。", "", "## 素材清单", "", "| ID | 时长秒 | 采样峰值dBFS | RMS dBFS |", "|---|---:|---:|---:|"])
    lines.extend(f"| {record['id']} | {record['seconds']:.3f} | {record['peak_dbfs']} | {record['rms_dbfs']} |" for record in inventory["files"])
    copy = report["copy_return_preflight"]
    lines.extend(["", "## 文案回传", "", f"已找到文案回传：{copy.get('changes', 0)}条文字修改、{copy.get('metadata_suggestions', 0)}条项目元数据建议、{copy.get('image_suggestions', 0)}条图中文字建议。基线匹配和键/原文哈希/变量预检结果见report.json；本次声音核验不回填文案，也不改图内文字。", "", "## 范围", "", "只运行音频专项、文件分析和文案结构预检；未跑全量UI/进度/导出流程。Windows输出设备、多屏切换、系统静音、耳机/扬声器、长时听感及混音听感仍未验证。"])
    (output / "report.md").write_text("\n".join(lines) + "\n")
    print(f"AUDIO: {len(inventory['files'])} WAV files verified, {runtime['assertions']} runtime assertions; production silent, final readiness blocked", flush=True)
    return exit_code


if __name__ == "__main__":
    sys.exit(main())
