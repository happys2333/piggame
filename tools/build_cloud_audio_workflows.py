"""Build candidate Cloud audio graphs from exported native ComfyUI workflows."""

from __future__ import annotations

import argparse
import copy
import json
from pathlib import Path
import uuid


ROOT = Path(__file__).resolve().parents[1]
PLAN = ROOT / "docs/design/comfy-cloud-audio-plan.json"


def read_object(path: Path) -> dict:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError("workflow must be a JSON object")
    return value


def build_effects(template: dict, entries: list[dict]) -> dict:
    source = next(node for node in template["nodes"] if node["type"] == "8b66c757-fe2f-4184-91f3-479a19deb565")
    output = next(node for node in template["nodes"] if node["type"] == "SaveAudioAdvanced")
    graph = copy.deepcopy(template)
    graph.update(id=str(uuid.uuid4()), revision=0, nodes=[], links=[], groups=[])
    graph["extra"] = {"ds":{"scale":0.55, "offset":[30, 30]}}
    for index, entry in enumerate(entries):
        source_node = copy.deepcopy(source)
        output_node = copy.deepcopy(output)
        source_id, output_id, link_id = index * 2 + 1, index * 2 + 2, index + 1
        source_node.update(id=source_id, title=entry["id"], pos=[index % 3 * 800, index // 3 * 570], order=index * 2)
        source_node["widgets_values"][:5] = [entry["prompt"], entry["seconds"], entry["seed"], False, entry["category"]]
        for slot in source_node["inputs"]:
            slot["link"] = None
        source_node["outputs"][0]["links"] = [link_id]
        output_node.update(id=output_id, title="FLAC · " + entry["id"], pos=[index % 3 * 800 + 420, index // 3 * 570], order=index * 2 + 1)
        output_node["inputs"][0]["link"] = link_id
        output_node["widgets_values"] = ["audio/piggame_20261012/" + entry["id"], "flac"]
        for slot in output_node.get("outputs", []):
            slot["links"] = []
        graph["nodes"].extend([source_node, output_node])
        graph["links"].append([link_id, source_id, 0, output_id, 0, "AUDIO"])
    graph.update(last_node_id=len(entries) * 2, last_link_id=len(entries))
    return graph


def build_music(template: dict, entry: dict) -> dict:
    graph = copy.deepcopy(template)
    graph.update(id=str(uuid.uuid4()), revision=0)
    source = next(node for node in graph["nodes"] if node["type"] == "ac99f841-a3de-4329-9564-953b81cf9e16")
    structure = "[Intro]\n[Instrumental]\n[Verse]\n[Instrumental]\n[Chorus]\n[Instrumental]\n[Verse]\n[Instrumental]\n[Bridge]\n[Instrumental]\n[Chorus]\n[Instrumental]\n[Outro]"
    source["widgets_values"][:4] = [entry["prompt"], structure, entry["max_seconds"], entry["seed"]]
    source["title"] = "MiniMax Music 3 · " + entry["id"]
    for node in graph["nodes"]:
        if node["type"] == "SaveAudioAdvanced":
            suffix = "master" if node["widgets_values"][1] == "flac" else "preview"
            node["widgets_values"][0] = "audio/piggame_20261012/" + entry["id"] + "_" + suffix
    return graph


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sfx-template", type=Path, required=True)
    parser.add_argument("--music-template", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    arguments = parser.parse_args()
    plan = read_object(PLAN)
    arguments.output.mkdir(parents=True, exist_ok=True)
    graphs = {
        "Piggame_SFX_Core_20261012":build_effects(read_object(arguments.sfx_template), plan["effects"][:16]),
        "Piggame_Ambient_20261012":build_effects(read_object(arguments.sfx_template), plan["effects"][16:]),
    }
    for entry in plan["music"]:
        graphs["Piggame_BGM_" + entry["id"] + "_20261012"] = build_music(read_object(arguments.music_template), entry)
    for name, graph in graphs.items():
        path = arguments.output / (name + ".json")
        path.write_text(json.dumps(graph, ensure_ascii=False, indent=2) + "\n")
        print(path)


if __name__ == "__main__":
    main()
