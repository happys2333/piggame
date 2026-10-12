from __future__ import annotations

import array
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
import wave


ROOT = Path(__file__).resolve().parents[1]


def import_tool(name: str):
    specification = importlib.util.spec_from_file_location(name, ROOT / "tools" / (name + ".py"))
    module = importlib.util.module_from_spec(specification)
    specification.loader.exec_module(module)
    return module


PROCESS = import_tool("process_cloud_audio")
BUILDER = import_tool("build_cloud_audio_workflows")


class CloudAudioTests(unittest.TestCase):
    def test_plan_has_complete_unique_candidates_without_enabling_playback(self) -> None:
        plan = json.loads(BUILDER.PLAN.read_text())
        identifiers = [entry["id"] for entry in plan["music"] + plan["effects"]]
        self.assertEqual(len(identifiers), 20)
        self.assertEqual(len(set(identifiers)), 20)
        self.assertFalse(plan["playback_enabled"])
        self.assertEqual(len(plan["music"]), 2)
        self.assertEqual(len(plan["effects"]), 18)
        self.assertTrue(all(entry["seed"] > 0 and entry["prompt"] for entry in plan["music"] + plan["effects"]))

    def test_effect_region_is_bounded_and_includes_usable_signal(self) -> None:
        samples = array.array("f", [0.0]) * (PROCESS.RATE * 3)
        samples[PROCESS.RATE:PROCESS.RATE + 1000] = array.array("f", [0.25]) * 1000
        start, length = PROCESS.effect_region(samples, 0.35)
        self.assertLessEqual(start, 1.0)
        self.assertGreater(start + length, 1.0)
        self.assertGreater(length, 0)
        self.assertLessEqual(length, 0.35)

    def test_silent_metrics_and_regions_are_rejected(self) -> None:
        samples = array.array("f", [0.0]) * PROCESS.RATE
        with self.assertRaises(ValueError):
            PROCESS.effect_region(samples, 1.0)
        with self.assertRaises(ValueError):
            PROCESS.metrics(samples, 1)

    def test_effect_fades_apply_after_trimming_late_signal(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source, target = directory / "source.wav", directory / "prepared.wav"
            samples = array.array("h", [0]) * PROCESS.RATE
            samples.extend(array.array("h", [8192]) * (PROCESS.RATE // 20))
            samples.extend(array.array("h", [0]) * PROCESS.RATE)
            with wave.open(str(source), "wb") as output:
                output.setnchannels(1)
                output.setsampwidth(2)
                output.setframerate(PROCESS.RATE)
                output.writeframes(samples.tobytes())
            processing = PROCESS.prepare_effect(source, target, {"max_processed_seconds":0.3})
            self.assertGreater(processing["selection_start_seconds"], 0.9)
            measured = PROCESS.metrics(PROCESS.decode(target, 1), 1)
            self.assertGreater(measured["sample_peak_dbfs"], -30)
            self.assertLess(measured["sample_peak_dbfs"], -17.9)

    def test_metrics_keep_full_scale_failures_visible(self) -> None:
        result = PROCESS.metrics(array.array("f", [0.0, 1.0, -1.1, 0.5]), 1)
        self.assertEqual(result["samples_at_or_above_full_scale"], 2)
        self.assertGreater(result["sample_peak_dbfs"], 0.0)

    def test_loudness_json_allows_ffmpeg_trailer_but_rejects_invalid_metrics(self) -> None:
        measured = {"input_i":"-24", "input_tp":"-8", "input_lra":"3", "input_thresh":"-34", "target_offset":"0"}
        self.assertEqual(PROCESS.parse_loudness("ffmpeg header\n" + json.dumps(measured) + "\nprogress trailer"), measured)
        measured["input_i"] = "-inf"
        with self.assertRaises(ValueError):
            PROCESS.parse_loudness(json.dumps(measured))
        with self.assertRaises(ValueError):
            PROCESS.parse_loudness("no analysis")

    def test_source_selection_does_not_confuse_pilot_or_music_tracks(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / "pet_content_pilot_00001.flac").write_bytes(b"pilot")
            with self.assertRaises(FileNotFoundError):
                PROCESS.find_source(directory, "pet_content", False)
            target = directory / "audio_piggame_20261012_pet_content_00001.flac"
            target.write_bytes(b"candidate")
            self.assertEqual(PROCESS.find_source(directory, "pet_content", False), target)
            with self.assertRaises(FileNotFoundError):
                PROCESS.find_source(directory, "day_room", True)

    def test_conflicting_source_files_are_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            (directory / "pet_content_00001.flac").write_bytes(b"first")
            (directory / "audio_piggame_20261012_pet_content_00001.flac").write_bytes(b"second")
            with self.assertRaises(ValueError):
                PROCESS.find_source(directory, "pet_content", False)

    def test_effect_graph_has_independent_links_seeds_and_outputs(self) -> None:
        source = {"id":52, "type":"8b66c757-fe2f-4184-91f3-479a19deb565", "widgets_values":["old", 4, 1, True, "Music", "checkpoint", "encoder", "planner"], "inputs":[{"name":"user_input", "link":None}], "outputs":[{"links":[85]}]}
        output = {"id":57, "type":"SaveAudioAdvanced", "widgets_values":["old", "mp3", "V0"], "inputs":[{"name":"audio", "link":85}], "outputs":[]}
        template = {"nodes":[source, output], "links":[[85, 52, 0, 57, 0, "AUDIO"]], "definitions":{"subgraphs":[{"id":source["type"]}]}}
        before = copy.deepcopy(template)
        entries = json.loads(BUILDER.PLAN.read_text())["effects"]
        graph = BUILDER.build_effects(template, entries)
        self.assertEqual(template, before)
        self.assertEqual(len(graph["nodes"]), 36)
        self.assertEqual(len(graph["links"]), 18)
        self.assertEqual(graph["definitions"], template["definitions"])
        self.assertEqual(len({node["id"] for node in graph["nodes"]}), 36)
        for index, entry in enumerate(entries):
            source_node, output_node = graph["nodes"][index * 2:index * 2 + 2]
            self.assertEqual(source_node["widgets_values"][:5], [entry["prompt"], entry["seconds"], entry["seed"], False, entry["category"]])
            self.assertEqual(output_node["widgets_values"], ["audio/piggame_20261012/" + entry["id"], "flac"])
            self.assertEqual(graph["links"][index][1:5], [source_node["id"], 0, output_node["id"], 0])


if __name__ == "__main__":
    unittest.main()
