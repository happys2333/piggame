"""Prepare offline audition candidates without changing the game's audio manifest."""

from __future__ import annotations

import argparse
import array
import hashlib
import html
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parents[1]
RATE = 44100


def run(command: list[str]) -> subprocess.CompletedProcess:
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(result.stderr.decode(errors="replace"))
    return result


def digest(path: Path) -> str:
    value = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1048576), b""):
            value.update(block)
    return value.hexdigest()


def decode(path: Path, channels: int) -> array.array:
    result = run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", str(channels), "-ar", str(RATE), "-f", "f32le", "pipe:1"])
    samples = array.array("f", result.stdout)
    if sys.byteorder != "little":
        samples.byteswap()
    if not samples or len(samples) % channels or any(not math.isfinite(value) for value in samples):
        raise ValueError("empty, truncated or non-finite audio: " + str(path))
    return samples


def metrics(samples: array.array, channels: int) -> dict:
    peak = max(abs(value) for value in samples)
    rms = math.sqrt(sum(value * value for value in samples) / len(samples))
    if peak < 0.0001:
        raise ValueError("audio is effectively silent")
    return {
        "seconds":len(samples) / channels / RATE,
        "sample_rate":RATE,
        "channels":channels,
        "sample_peak_dbfs":20 * math.log10(peak),
        "rms_dbfs":20 * math.log10(rms) if rms else None,
        "samples_at_or_above_full_scale":sum(abs(value) >= 1 for value in samples),
        "first_last_sample_jump":max(abs(samples[channel] - samples[-channels + channel]) for channel in range(channels)),
    }


def effect_region(samples: array.array, maximum: float) -> tuple[float, float]:
    block_size = RATE // 100
    energies = [sum(value * value for value in samples[start:start + block_size]) / block_size for start in range(0, len(samples), block_size)]
    maximum_energy = max(energies)
    if maximum_energy < 1e-8:
        raise ValueError("effect has no usable signal")
    active = [index for index, value in enumerate(energies) if value > max(1e-8, maximum_energy * 0.015)]
    first = max(0, active[0] - 3)
    last = min(len(energies), active[-1] + 5)
    window = max(1, int(maximum * 100))
    if last - first > window:
        current = sum(energies[first:first + window])
        best_energy, best_start = current, first
        for start in range(first + 1, last - window + 1):
            current += energies[start + window - 1] - energies[start - 1]
            if current > best_energy:
                best_energy, best_start = current, start
        first, last = best_start, best_start + window
    start_seconds = first / 100
    length = min(maximum, len(samples) / RATE - start_seconds, (last - first) / 100)
    if length <= 0.01:
        raise ValueError("effect selection is too short")
    return start_seconds, length


def find_source(directory: Path, identifier: str, music: bool) -> Path:
    expected = identifier + ("_master_00001.flac" if music else "_00001.flac")
    candidates = [path for path in directory.rglob("*.flac") if path.name in (expected, "audio_piggame_20261012_" + expected)]
    if not candidates:
        raise FileNotFoundError("missing Cloud output: " + expected)
    if len({digest(path) for path in candidates}) != 1:
        raise ValueError("ambiguous Cloud candidates: " + identifier)
    return candidates[0]


def verify_generation_metadata(source: Path, entry: dict, music: bool) -> dict:
    result = run(["ffprobe", "-v", "error", "-show_entries", "format_tags", "-of", "json", str(source)])
    tags = json.loads(result.stdout).get("format", {}).get("tags", {})
    workflow_text = tags.get("workflow", "")
    workflow = json.loads(workflow_text)
    matching = [node for node in workflow.get("nodes", []) if node.get("widgets_values", [None])[0] == entry["prompt"]]
    seed_index = 3 if music else 2
    if len(matching) != 1 or matching[0]["widgets_values"][seed_index] != entry["seed"]:
        raise ValueError("source prompt or seed disagrees with generation plan: " + source.name)
    expected_prefix = "audio/piggame_20261012/" + entry["id"] + ("_master" if music else "")
    if not any(node["type"] == "SaveAudioAdvanced" and node.get("widgets_values", [None])[0] == expected_prefix for node in workflow.get("nodes", [])):
        raise ValueError("source output prefix disagrees with generation plan")
    return {"embedded_workflow_sha256":hashlib.sha256(workflow_text.encode()).hexdigest(), "prompt_seed_and_output_prefix_verified":True, "model_weights_sha256":"not exposed by Cloud"}


def parse_loudness(output: str) -> dict:
    start = output.rfind("{")
    if start < 0:
        raise ValueError("missing loudness analysis JSON")
    measured, _ = json.JSONDecoder().raw_decode(output[start:])
    for key in ("input_i", "input_tp", "input_lra", "input_thresh", "target_offset"):
        if not math.isfinite(float(measured[key])):
            raise ValueError("invalid loudness analysis")
    return measured


def prepare_effect(source: Path, target: Path, entry: dict) -> dict:
    samples = decode(source, 1)
    start, duration = effect_region(samples, entry["max_processed_seconds"])
    selected = samples[int(start * RATE):int((start + duration) * RATE)]
    peak = max(abs(value) for value in selected)
    gain = min(6.0, -18.0 - 20 * math.log10(peak))
    fade_out = min(0.035, duration / 4)
    filters = f"atrim=start={start:.6f}:duration={duration:.6f},asetpts=PTS-STARTPTS,volume={gain:.6f}dB,afade=t=in:st=0:d=0.003,afade=t=out:st={duration - fade_out:.6f}:d={fade_out:.6f}"
    run(["ffmpeg", "-v", "error", "-y", "-i", str(source), "-af", filters, "-ac", "1", "-ar", str(RATE), "-map_metadata", "-1", "-c:a", "pcm_s16le", str(target)])
    return {"source_metrics_mono":metrics(samples, 1), "selection_start_seconds":start, "selection_seconds":duration, "gain_db":gain, "selection_method":"strongest energy window; semantic listening review required", "loop_prepared":False}


def prepare_loop(source: Path, target: Path, music: bool, temporary: Path) -> dict:
    source_metrics = metrics(decode(source, 2), 2)
    duration = source_metrics["seconds"]
    if duration < (90 if music else 10):
        raise ValueError("loop source is shorter than the candidate requirement")
    trim_start = 3.0 if music else 0.0
    trim_end = duration - (3.0 if music else 0.0)
    usable = trim_end - trim_start
    fade = 2.0 if music else 1.0
    loop_path = temporary / (target.stem + "_loop.wav")
    filters = (
        f"[0:a]atrim=start={trim_start}:end={trim_end},asetpts=PTS-STARTPTS,asplit=3[body][head][tail];"
        f"[body]atrim=start={fade}:end={usable - fade},asetpts=PTS-STARTPTS[middle];"
        f"[head]atrim=start=0:end={fade},asetpts=PTS-STARTPTS[beginning];"
        f"[tail]atrim=start={usable - fade},asetpts=PTS-STARTPTS[ending];"
        f"[ending][beginning]acrossfade=d={fade}:c1=tri:c2=tri[seam];"
        "[middle][seam]concat=n=2:v=0:a=1[loop]"
    )
    run(["ffmpeg", "-v", "error", "-y", "-i", str(source), "-filter_complex", filters, "-map", "[loop]", "-ar", str(RATE), "-map_metadata", "-1", "-c:a", "pcm_f32le", str(loop_path)])
    target_loudness, target_peak = (-24, -8) if music else (-32, -9)
    normalization = f"loudnorm=I={target_loudness}:TP={target_peak}:LRA=7"
    analysis = run(["ffmpeg", "-hide_banner", "-i", str(loop_path), "-af", normalization + ":print_format=json", "-f", "null", "-"])
    output = analysis.stderr.decode()
    measured = parse_loudness(output)
    normalization += f":measured_I={measured['input_i']}:measured_TP={measured['input_tp']}:measured_LRA={measured['input_lra']}:measured_thresh={measured['input_thresh']}:offset={measured['target_offset']}:linear=true"
    normalized = temporary / (target.stem + "_normalized.wav")
    run(["ffmpeg", "-v", "error", "-y", "-i", str(loop_path), "-af", normalization, "-ar", str(RATE), "-map_metadata", "-1", "-c:a", "pcm_s16le", str(normalized)])
    run(["oggenc", "--quiet", "--quality", "5", "--output", str(target), str(normalized)])
    return {"source_metrics_stereo":source_metrics, "loop_prepared":True, "crossfade_seconds":fade, "loop_seam_listening_accepted":False, "normalization_targets":{"integrated_lufs":target_loudness, "true_peak_dbtp":target_peak}, "pre_normalization_analysis":measured}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    for executable in ("ffmpeg", "ffprobe", "oggenc"):
        if shutil.which(executable) is None:
            raise FileNotFoundError("required audio preparation tool is missing: " + executable)
    plan = json.loads((ROOT / "docs/design/comfy-cloud-audio-plan.json").read_text())
    entries = [(entry, "music") for entry in plan["music"]] + [(entry, "ambient" if entry["id"] in ("rain_window", "wind_chime") else "sfx") for entry in plan["effects"]]
    sources = {entry["id"]:find_source(arguments.sources, entry["id"], kind == "music") for entry, kind in entries}
    if arguments.output.exists():
        raise FileExistsError("use a fresh output directory; existing candidates are not overwritten")
    arguments.output.mkdir(parents=True)
    (arguments.output / ".gdignore").write_text("")
    (arguments.output / "masters").mkdir()
    (arguments.output / "prepared").mkdir()
    (arguments.output / "previews").mkdir()
    records = []
    with tempfile.TemporaryDirectory(prefix="piggame-audio-edit-") as directory:
        temporary = Path(directory)
        for entry, kind in entries:
            identifier = entry["id"]
            source = sources[identifier]
            provenance = verify_generation_metadata(source, entry, kind == "music")
            master = arguments.output / "masters" / (identifier + ".flac")
            shutil.copy2(source, master)
            is_loop = kind == "music" or identifier == "rain_window"
            target = arguments.output / "prepared" / (identifier + (".ogg" if is_loop else ".wav"))
            processing = prepare_loop(source, target, kind == "music", temporary) if is_loop else prepare_effect(source, target, entry)
            channels = 2 if is_loop else 1
            result_metrics = metrics(decode(target, channels), channels)
            if result_metrics["samples_at_or_above_full_scale"]:
                raise ValueError("prepared candidate has full-scale samples: " + identifier)
            preview = target.relative_to(arguments.output).as_posix()
            if kind == "music":
                preview_path = arguments.output / "previews" / (identifier + ".mp3")
                run(["ffmpeg", "-v", "error", "-y", "-i", str(target), "-t", "40", "-map_metadata", "-1", "-c:a", "libmp3lame", "-q:a", "2", str(preview_path)])
                preview = preview_path.relative_to(arguments.output).as_posix()
            records.append({"id":identifier, "kind":kind, "model":plan["music_model"] if kind == "music" else plan["sfx_model"], "seed":entry["seed"], "prompt":entry["prompt"], "source_filename":source.name, "provenance":provenance, "master_path":master.relative_to(arguments.output).as_posix(), "master_sha256":digest(master), "prepared_path":target.relative_to(arguments.output).as_posix(), "prepared_sha256":digest(target), "prepared_bytes":target.stat().st_size, "preview_path":preview, "processing":processing, "metrics":result_metrics, "subjective_review_passed":False})
            print(identifier, round(result_metrics["seconds"], 3), "seconds", flush=True)
    manifest = {"schema_version":1, "generation_date":"2026-10-12", "generator":"ComfyUI Cloud Run", "status":"audition_candidates_only", "final_audio_accepted":False, "production_audio_enabled":False, "license_status":plan["license_status"], "files":records}
    (arguments.output / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n")
    cards = []
    for record in records:
        cards.append(f"<section><h2>{html.escape(record['id'])}</h2><p>{record['metrics']['seconds']:.2f}s · {record['metrics']['sample_peak_dbfs']:.1f} dBFS</p><audio controls preload='none' src='{html.escape(record['preview_path'])}'></audio></section>")
    (arguments.output / "index.html").write_text("<!doctype html><html lang='zh-CN'><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>猪咪音频候选试听</title><style>body{font:16px system-ui;background:#fffdf7;color:#2b3030;max-width:1000px;margin:40px auto;padding:20px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:18px}section{padding:18px;border:1px solid #e6e4d9;border-radius:18px}h2{font-size:18px}audio{width:100%}</style><h1>猪咪音频候选</h1><p>2 首 BGM、16 类短音效、2 类环境声。仅供试听；未启用游戏声音，听感与最终授权验收尚未通过。音乐播放器为 40 秒节选，完整文件在 prepared 目录。</p><main>" + "".join(cards) + "</main></html>")
    print("Prepared", len(records), "candidates; production remains silent")


if __name__ == "__main__":
    main()
